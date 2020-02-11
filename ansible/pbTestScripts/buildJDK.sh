#!/bin/bash
set -eu

# Argument parsing
if [[ $# == 0 ]]; then
        echo "No arguments input, defaulting to JDK8"
        export JAVA_TO_BUILD=jdk8u
elif [[ $# == 1 ]]; then
        export JAVA_TO_BUILD=$1
else
        echo "Too many arguments"
        exit 1;
fi

export PATH=/usr/local/bin/:$PATH
if [ -z "${WORKSPACE:-}" ]; then
	echo "WORKSPACE not found, setting it as environment variable 'HOME'"
	WORKSPACE=$HOME
fi

export TARGET_OS=linux
export VARIANT=openj9
export ARCHITECTURE=x64

# Differences in openJDK7 name between OSs. Search for CentOS one
export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk.x86_64)
# If the CentOS JDK7 can't be found, search for the Ubuntu one
[[ -z "$JDK7_BOOT_DIR" ]] && export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk-\*)

# Differences in openJDK8 name between Ubuntu and CentOS
export JAVA_HOME=$(find /usr/lib/jvm/ -name java-1.8.0-openjdk-\*)
if [ -z "$JAVA_HOME" ]; then
	export JAVA_HOME=$(ls -1d /usr/lib/jvm/adoptopenjdk-8-* | head -1)
fi

if grep 'openSUSE' /etc/os-release >/dev/null 2>&1; then
	echo "Running on openSUSE"
	JAVA_HOME=$(find /usr/lib/jvm/ -name jdk8u*)
fi	

# Only build Hotspot on FreeBSD
if [[ $(uname) == "FreeBSD" ]]; then
        echo "Running on FreeBSD"
        export TARGET_OS=FreeBSD
        export VARIANT=hotspot
        export JDK7_BOOT_DIR=/usr/local/openjdk7
	export JAVA_HOME=/usr/local/openjdk8
fi

echo "DEBUG:
        TARGET_OS=$TARGET_OS
        ARCHITECTURE=$ARCHITECTURE
        JAVA_TO_BUILD=$JAVA_TO_BUILD
        VARIANT=$VARIANT
        JDK7_BOOT_DIR=$JDK7_BOOT_DIR
        JAVA_HOME=$JAVA_HOME
        WORKSPACE=$WORKSPACE"

if [[ ! -d "$WORKSPACE/openjdk-build" && "$TARGET_OS" == "FreeBSD" ]]; then
  git clone -b freebsd https://github.com/gdams/openjdk-build $WORKSPACE/openjdk-build
elif [[ ! -d "$WORKSPACE/openjdk-build" ]]; then
  git clone https://github.com/adoptopenjdk/openjdk-build $WORKSPACE/openjdk-build
fi

cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh
