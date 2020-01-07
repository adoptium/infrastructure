#!/bin/bash

mv $HOME/openjdk-build/workspace/build/src/build/linux-x86_64-normal-server-release/images/jdk8* $HOME
export TEST_JDK_HOME=$(find $HOME -maxdepth 1 -type d -name "*jdk8u*"|grep -v ".*jre.*")
mkdir -p $HOME/testLocation
[ ! -d $HOME/testLocation/openjdk-tests ] && git clone https://github.com/adoptopenjdk/openjdk-tests $HOME/testLocation/openjdk-tests
$HOME/testLocation/openjdk-tests/get.sh -t $HOME/testLocation/openjdk-tests
cd $HOME/testLocation/openjdk-tests/TKG || exit 1
make -f run_configure.mk
export BUILD_LIST=MachineInfo
make compile
make _MachineInfo
