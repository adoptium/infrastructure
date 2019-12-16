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

# Differences in openJDK7 name between OSs. Search for CentOS one
export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk.x86_64)
# If the CentOS JDK7 can't be found, search for the Ubuntu one
[[ -z "$JDK7_BOOT_DIR" ]] && export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk-\*)

# Differences in openJDK8 name between Ubuntu and CentOS
export JAVA_HOME=$(find /usr/lib/jvm/ -name java-1.8.0-openjdk-\*)
cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh

