#!/bin/bash

# System update
sudo apt update

# Java JDK installation
sudo apt update
sudo apt install default-jdk -y

# Check if Scala is already installed
if command -v scala >/dev/null 2>&1 ; then
    echo "Scala is already installed. Skipping installation."
else
    # Install Scala
    echo "Installing Scala..."
    sudo apt install scala -y
fi

# Scala Build Tool (sbt) installation
echo "Installing sbt..."
sudo apt-get remove sbt
sudo apt-get update
sudo apt-get install sbt

#Install additional sbt dependencies
echo "Installing additional sbt dependencies..."
sbt package
sbt dependencyUpdates
sbt dependencyGraph
sbt dependencyList
sbt scalastyle
sbt compile
sbt run
sbt publish
sbt clean
sbt package
sbt publishLocal

# Apache Spark installation
wget https://downloads.apache.org/spark/spark-3.2.0/spark-3.2.0-bin-hadoop3.2.tgz
tar xvf spark-3.2.0-bin-hadoop3.2.tgz
sudo mv spark-3.2.0-bin-hadoop3.2 /opt/
sudo ln -s /opt/spark-3.2.0-bin-hadoop3.2 /opt/spark
echo 'export SPARK_HOME=/opt/spark' >> ~/.bashrc
echo 'export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin' >> ~/.bashrc
source ~/.bashrc

# Development libraries
sudo apt install -y libatlas3-base
sudo apt-get install -y libopenblas-base
sudo apt-get install -y libnlopt-dev
sudo apt-get install -y coinor-cbc
sudo apt-get install -y glpk-utils
sudo apt-get install -y libgslcblas0
sudo apt-get install -y libpq-dev
sudo apt-get install -y libmysqlclient-dev
sudo apt-get install -y libsqlite3-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y libffi-dev
sudo apt-get install -y libfontconfig1-dev
sudo apt-get install -y libfreetype6-dev
sudo apt-get install -y libxrender-dev
sudo apt-get install -y libxext-dev
sudo apt-get install -y libpng-dev
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y libbz2-dev
sudo apt-get install -y liblzma-dev
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libxml2-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y libgraphviz-dev
sudo apt-get install -y libmicrohttpd-dev
sudo apt-get install -y libcurl4-gnutls-dev
sudo apt-get install -y libsvm-dev
sudo apt-get install -y libopencv-dev
sudo apt-get install -y libgsl-dev
sudo apt-get install -y libboost-all-dev
sudo apt-get install -y libblas-dev
sudo apt-get install -y liblapack-dev
sudo apt-get install -y libmlpack-dev
sudo apt-get install -y libmlpack-arma-dev
sudo apt-get install -y libmlpack-csv-dev
sudo apt-get install -y libmlpack-doc
sudo apt-get install -y libmlpack-python-dev
sudo apt-get install -y libmlpack-tests-dev

echo "Packages installation complete!"

#Download IntelliJ IDEA last edition
cd /tmp
wget https://download-cf.jetbrains.com/scala/ideaIC-2021.1.2.tar.gz

# Extract file
tar -xvzf ideaIC-2021.1.2.tar.gz

# Move directory to /opt/
sudo mv idea-IC-* /opt/idea

# Create simbolic link to access IntelliJ IDEA globally
sudo ln -s /opt/idea/bin/idea.sh /usr/local/bin/idea

# Define adequate permissions to IntelliJ IDEA directory
sudo chown -R $USER:$USER /opt/idea

# Starts IntelliJ IDEA (optional)
#idea
