#!/bin/bash
set -eu
export TARGET_OS=windows
export ARCHITECTURE=x64
export JAVA_TO_BUILD=jdk8
export VARIANT=hotspot
export JDK7_BOOT_DIR=/cygdrive/c/openjdk/jdk7
export PATH=/usr/bin/:$PATH
# Ensures Git won't replace line endings (CRLF)
C:/cygwin64/bin/sed -i -e 's/autocrlf.*/autocrlf = false/g' C:\\ProgramData/Git/config
# Git clone openjdk-build if it's not currently there.
cd C:/
if [ ! -d "openjdk-build" ]; then
        echo 'Cloning openJDK-build repo'
        git clone https://github.com/adoptopenjdk/openjdk-build
fi
/cygdrive/c/openjdk-build/makejdk-any-platform.sh -J /cygdrive/c/openjdk/jdk-8 --configure-args "--disable-ccache --with-toolchain-version=2013" --freetype-version 2.5.3 -v jdk8u
