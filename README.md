# Scala Project Template

A minimal sbt-based Scala project template.

## Requirements

- Java
- sbt

## Build and Run

```sh
sbt compile
sbt run
```

The VS Code/Cursor launch configuration `Build & Run HelloWorld` runs `sbt compile` before launching `HelloWorld` through Metals.

## Setup Check

Run the setup checker after cloning or changing the template:

```sh
scripts/check-setup.sh
```

It checks the project layout, local Java/sbt/Metals availability, VS Code/Cursor launch settings, and whether the first build and Metals import artifacts exist yet. On a cold workspace, the first editor launch can fail after compiling if Metals has not finished importing the sbt target; wait for import to finish and try the launch again.
