#!/bin/bash
set -eu
export PATH=/usr/local/bin/:$PATH
if [ -z "${WORKSPACE:-}" ]; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
fi
[[ ! -d "$WORKSPACE/openjdk-build" ]] && git clone https://github.com/adoptopenjdk/openjdk-build $WORKSPACE/openjdk-build

# If detected GCC version is <7, set it to 7 
export gccVer=$(gcc --version | grep "gcc" | awk '{ print $4 }' | cut -d. -f1)
[[ ${gccVer} -lt 7 ]] && ln -sf /usr/bin/gcc-7 /usr/bin/gcc && ln -sf /usr/bin/g++-7 /usr/bin/g++

export TARGET_OS=linux
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8u
export VARIANT=openj9
export JDK7_BOOT_DIR=/usr/lib/jvm/java-1.7.0
# Differences in openJDK8 name between Ubuntu and CentOS
export JAVA_HOME=$(find /usr/lib/jvm/ -name java-1.8.0-openjdk-\*)
cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh

