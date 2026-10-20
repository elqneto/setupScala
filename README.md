# setupScala

Script to install Scala, sbt, Apache Spark, [IntelliJ IDEA](https://www.jetbrains.com/idea/) and build libraries on Ubuntu 26.04 LTS and newer.

IntelliJ IDEA Community and IntelliJ IDEA Ultimate are now one IntelliJ IDEA product. The core that used to be free stays free. The first launch starts a 30-day Ultimate trial.

## Usage

On Ubuntu 26.04.1 LTS or newer:

```bash
chmod +x scala_ubuntu.sh
./scala_ubuntu.sh
```

The script asks for an administrator password and needs internet access. It installs OpenJDK 21, the current Scala CLI, sbt from the official repository, and the latest Spark binary built for Hadoop 3. IntelliJ IDEA is the latest stable release for the machine architecture.

Spark and IntelliJ IDEA are large downloads. The scientific libraries, especially OpenCV and Boost, also take disk space.

Open a new terminal after the script finishes. `JAVA_HOME` points at OpenJDK 21, and `SPARK_HOME` points at `/opt/spark`.

## What the script changes

- Does not install Ubuntu's Scala 2.11 package. Scala comes from the current Scala CLI, available as `scala`, `scalac` and `scala-cli`.
- Installs sbt from the Scala sbt repository instead of running sbt tasks in an empty directory.
- Installs the latest Apache Spark release instead of Spark 3.2.0. Spark 4 uses Scala 2.13 and runs on Java 17, 21 and 25.
- Installs unified IntelliJ IDEA instead of Community 2022.3.3, and selects the amd64 or arm64 archive for the machine.
- Replaces renamed library packages such as `libopenblas-base` and `libfreetype6-dev`, and keeps the single `libmlpack-dev` package.
- Does not append duplicate Spark entries to `.bashrc` on later runs.

## License

The script is provided so it can be used and modified. This repository has no separate license file.
