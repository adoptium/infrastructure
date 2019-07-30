#!/bin/bash
set -eu
export TARGET_OS=linux
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8u
export VARIANT=openj9
export JDK7_BOOT_DIR=/usr/lib/jvm/java-1.7.0
export JDK_BOOT_DIR=/usr/lib/jvm/java-8-openjdk-amd64
cd ~/openjdk-build
build-farm/make-adopt-build-farm.sh

