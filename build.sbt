ThisBuild / scalaVersion := "2.13.18"
ThisBuild / version := "0.1.0"

lazy val root = (project in file("."))
  .settings(
    name := "root",
    Compile / mainClass := Some("HelloWorld"),
    Compile / run / mainClass := Some("HelloWorld")
  )
