#!/bin/bash
set -eu
export PATH=/usr/local/bin/:$PATH
if [ -z "${WORKSPACE:-}" ]; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
fi
[[ ! -d "$WORKSPACE/openjdk-build" ]] && git clone https://github.com/adoptopenjdk/openjdk-build $WORKSPACE/openjdk-build
export TARGET_OS=linux
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8u
export VARIANT=openj9
export JDK7_BOOT_DIR=/usr/lib/jvm/java-1.7.0
export JDK_BOOT_DIR=/usr/lib/jvm/java-1.8.0-openjdk-amd64
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh

