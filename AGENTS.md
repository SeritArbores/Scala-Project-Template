# Agent Instructions

If `.docs/` exists, always treat `.docs/` as the source of truth.

## Before Making Changes

- Identify relevant invariants and constraints.
- Do not violate architectural or security boundaries.
- Check the repository state with `git status --short --branch`.
- If the project already has uncommitted modifications, stop and ask the user to change or clarify the instructions before continuing. Do not assume the modified files are yours to edit.
- If the project is clean and appears barebone or freshly cloned, run `scripts/check-setup.sh` before making changes.
- Report the setup-check findings to the user, including missing tools, missing build/import artifacts, and any first-run editor warnings.

## During Implementation

- Avoid introducing undocumented behavior.
- Do not bypass governance layers.
- Prefer the sbt project configuration in `build.sbt` and `project/build.properties` as the build authority.
- Keep generated output out of commits. Do not commit `target/`, `.bloop/`, `.metals/`, `.scala-build/`, or `project/metals.sbt`.

## After Changes

- Update `.docs/` to reflect reality if `.docs/` exists.
- Ensure no drift between code and documentation.
- Run the relevant validation commands, usually:

```sh
scripts/check-setup.sh
sbt compile
```

- Surface conflicts instead of working around them.
