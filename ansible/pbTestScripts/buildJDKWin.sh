#!/bin/bash
set -eu
export TARGET_OS=windows
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8u
export VARIANT=hotspot
export JDK7_BOOT_DIR=/usr/lib/jvm/java-1.7.0
export JDK8_BOOT_DIR=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=/usr/bin:$PATH 
/cygdrive/c/openjdk-build/build-farm/make-adopt-build-farm.sh
