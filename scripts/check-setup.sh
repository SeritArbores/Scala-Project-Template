#!/usr/bin/env sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
cd "$ROOT_DIR" || exit 1

ERRORS=0
WARNINGS=0
FIRST_BUILD_MISSING=0
METALS_IMPORT_MISSING=0

ok() {
  printf 'OK: %s\n' "$1"
}

info() {
  printf 'INFO: %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  ERRORS=$((ERRORS + 1))
  printf 'ERROR: %s\n' "$1"
}

json_string() {
  json_file=$1
  json_key=$2

  if [ ! -f "$json_file" ]; then
    return 0
  fi

  sed -n "s/.*\"$json_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$json_file" | sed -n '1p'
}

require_file() {
  check_path=$1
  description=$2

  if [ -f "$check_path" ]; then
    ok "$description exists: $check_path"
  else
    fail "$description is missing: $check_path"
  fi
}

require_dir() {
  check_path=$1
  description=$2

  if [ -d "$check_path" ]; then
    ok "$description exists: $check_path"
  else
    fail "$description is missing: $check_path"
  fi
}

printf 'Scala project setup check\n'
printf 'Project root: %s\n\n' "$ROOT_DIR"

printf 'Project structure\n'
require_file "build.sbt" "sbt build file"
require_file "project/build.properties" "sbt version pin"
require_dir "src/main/scala" "main Scala source directory"
require_file "src/main/scala/HelloWorld.scala" "sample main source"
require_file ".vscode/launch.json" "VS Code launch configuration"
require_file ".vscode/tasks.json" "VS Code task configuration"
printf '\n'

printf 'Configured versions and targets\n'
SCALA_VERSION=$(sed -n 's/.*scalaVersion[[:space:]]*:=[[:space:]]*"\([^"]*\)".*/\1/p' build.sbt 2>/dev/null | sed -n '1p')
SBT_VERSION=$(sed -n 's/^sbt\.version=//p' project/build.properties 2>/dev/null | sed -n '1p')
SBT_PROJECT=$(sed -n 's/^[[:space:]]*lazy val \([^ =]*\).*/\1/p' build.sbt 2>/dev/null | sed -n '1p')
SBT_MAIN_CLASS=$(sed -n 's/.*Compile \/ run \/ mainClass[[:space:]]*:=[[:space:]]*Some("\([^"]*\)").*/\1/p' build.sbt 2>/dev/null | sed -n '1p')
LAUNCH_MAIN_CLASS=$(json_string ".vscode/launch.json" "mainClass")
LAUNCH_BUILD_TARGET=$(json_string ".vscode/launch.json" "buildTarget")
PRE_LAUNCH_TASK=$(json_string ".vscode/launch.json" "preLaunchTask")
TASK_LABEL=$(json_string ".vscode/tasks.json" "label")

if [ -n "$SCALA_VERSION" ]; then
  ok "Scala version in build.sbt: $SCALA_VERSION"
else
  fail "Could not find ThisBuild / scalaVersion in build.sbt"
fi

if [ -n "$SBT_VERSION" ]; then
  ok "sbt version in project/build.properties: $SBT_VERSION"
else
  fail "Could not find sbt.version in project/build.properties"
fi

if [ -n "$SBT_PROJECT" ]; then
  ok "sbt project/build target name: $SBT_PROJECT"
else
  warn "Could not infer an sbt project target name from build.sbt"
fi

if [ -n "$LAUNCH_MAIN_CLASS" ]; then
  ok "VS Code mainClass: $LAUNCH_MAIN_CLASS"
else
  fail "VS Code launch.json does not define mainClass"
fi

if [ -n "$LAUNCH_BUILD_TARGET" ]; then
  ok "VS Code buildTarget: $LAUNCH_BUILD_TARGET"
else
  fail "VS Code launch.json does not define buildTarget"
fi

if [ -n "$SBT_PROJECT" ] && [ -n "$LAUNCH_BUILD_TARGET" ] && [ "$SBT_PROJECT" != "$LAUNCH_BUILD_TARGET" ]; then
  warn "launch.json buildTarget is '$LAUNCH_BUILD_TARGET' but build.sbt appears to define '$SBT_PROJECT'"
fi

if [ -n "$SBT_MAIN_CLASS" ] && [ -n "$LAUNCH_MAIN_CLASS" ] && [ "$SBT_MAIN_CLASS" != "$LAUNCH_MAIN_CLASS" ]; then
  warn "build.sbt mainClass is '$SBT_MAIN_CLASS' but launch.json mainClass is '$LAUNCH_MAIN_CLASS'"
fi

if [ -n "$PRE_LAUNCH_TASK" ]; then
  ok "VS Code preLaunchTask: $PRE_LAUNCH_TASK"
else
  warn "launch.json has no preLaunchTask; F5 may launch stale classes unless you build manually"
fi

if [ -n "$PRE_LAUNCH_TASK" ] && [ -n "$TASK_LABEL" ] && [ "$PRE_LAUNCH_TASK" != "$TASK_LABEL" ]; then
  warn "launch.json preLaunchTask is '$PRE_LAUNCH_TASK' but tasks.json first label is '$TASK_LABEL'"
fi
printf '\n'

printf 'Local tools\n'
if command -v java >/dev/null 2>&1; then
  JAVA_CMD=$(command -v java)
  JAVA_VERSION=$(java -version 2>&1 | sed -n '1p')
  ok "java found: $JAVA_CMD ($JAVA_VERSION)"
else
  fail "java was not found on PATH"
fi

if command -v sbt >/dev/null 2>&1; then
  SBT_CMD=$(command -v sbt)
  ok "sbt found: $SBT_CMD"
else
  fail "sbt was not found on PATH. Install sbt, then run this check again."
fi

METALS_FOUND=0
if command -v metals >/dev/null 2>&1; then
  ok "Metals CLI found: $(command -v metals)"
  METALS_FOUND=1
fi

for EDITOR_CMD in code cursor codium; do
  if command -v "$EDITOR_CMD" >/dev/null 2>&1; then
    EXTENSIONS=$("$EDITOR_CMD" --list-extensions 2>/dev/null || true)
    if printf '%s\n' "$EXTENSIONS" | grep -qi '^scalameta\.metals$'; then
      ok "Scala (Metals) extension found in $EDITOR_CMD"
      METALS_FOUND=1
    fi
  fi
done

if [ "$METALS_FOUND" -eq 0 ]; then
  if [ -d ".metals" ]; then
    warn "Metals workspace data exists, but this script could not verify a Metals CLI or editor extension"
  else
    warn "Could not verify Metals. Install the Scala (Metals) extension in VS Code/Cursor before using the launch config."
  fi
fi
printf '\n'

printf 'First build / IDE import state\n'
COMPILED_CLASS=""
if [ -n "$LAUNCH_MAIN_CLASS" ]; then
  CLASS_PATH=$(printf '%s' "$LAUNCH_MAIN_CLASS" | sed 's/\./\//g')
  COMPILED_CLASS=$(find target -path "*/classes/$CLASS_PATH.class" -type f -print 2>/dev/null | sed -n '1p')
fi

if [ -n "$COMPILED_CLASS" ]; then
  ok "compiled main class found: $COMPILED_CLASS"
else
  FIRST_BUILD_MISSING=1
  warn "compiled main class was not found under target/. Run 'sbt compile' before relying on editor launch/debug."
fi

BLOOP_FILE=""
if [ -n "$LAUNCH_BUILD_TARGET" ]; then
  BLOOP_FILE=".bloop/$LAUNCH_BUILD_TARGET.json"
fi

if [ -n "$BLOOP_FILE" ] && [ -f "$BLOOP_FILE" ]; then
  ok "Metals/Bloop target file found: $BLOOP_FILE"
else
  METALS_IMPORT_MISSING=1
  warn "Metals/Bloop target file was not found. Run 'Metals: Import Build' and wait for it to finish."
fi
printf '\n'

printf 'What to customize for a real project\n'
printf '%s\n' '- Change the Scala version in build.sbt if the project should use a different Scala release.'
printf '%s\n' '- If you rename the main object, update build.sbt Compile / run / mainClass and .vscode/launch.json mainClass.'
printf '%s\n' '- If you rename the sbt project target, update .vscode/launch.json buildTarget to match it.'
printf '%s\n' '- If you rename the build task in .vscode/tasks.json, update launch.json preLaunchTask to the same label.'
printf '%s\n' '- Add dependencies and project settings in build.sbt rather than in generated target/, .bloop/, .metals/, or .scala-build/ directories.'
printf '\n'

if [ "$FIRST_BUILD_MISSING" -ne 0 ] || [ "$METALS_IMPORT_MISSING" -ne 0 ]; then
  printf 'First-run note\n'
  printf 'If VS Code/Cursor fails after the compile step with "Build target not found" or "no build target", wait for Metals import to finish and try the same launch again. This can happen on a cold workspace before Metals has indexed the sbt target.\n'
  printf '\n'
fi

if [ "$ERRORS" -eq 0 ]; then
  printf 'Setup check completed with %s warning(s) and no errors.\n' "$WARNINGS"
  exit 0
fi

printf 'Setup check completed with %s error(s) and %s warning(s).\n' "$ERRORS" "$WARNINGS"
exit 1
