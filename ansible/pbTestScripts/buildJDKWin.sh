#!/bin/bash
set -eu
export TARGET_OS=windows
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8u
export VARIANT=hotspot
export JDK7_BOOT_DIR=C:/openjdk/jdk7
export JDK11_BOOT_DIR=C:/openjdk/jdk-11
export PATH=/usr/bin:$PATH 
/cygdrive/c/openjdk-build/build-farm/make-adopt-build-farm.sh
