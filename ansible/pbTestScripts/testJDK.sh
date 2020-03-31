#!/bin/bash

export MAKE_COMMAND="make"
if [[ $(uname) == "FreeBSD" ]]; then
	export MAKE_COMMAND="gmake"
	cp -r $HOME/openjdk-build/workspace/build/src/build/*/jdk* $HOME
	export TEST_JDK_HOME=$HOME/jdk
else
	export TEST_JDK_HOME=$(find $HOME/openjdk-build/workspace/build/src/build/*/images/ -maxdepth 1 -type d -name "jdk*"|grep -v ".*jre.*"|grep -v ".*-image")
fi

mkdir -p $HOME/testLocation
[ ! -d $HOME/testLocation/openjdk-tests ] && git clone https://github.com/adoptopenjdk/openjdk-tests $HOME/testLocation/openjdk-tests
$HOME/testLocation/openjdk-tests/get.sh -t $HOME/testLocation/openjdk-tests
cd $HOME/testLocation/openjdk-tests/TKG || exit 1
export BUILD_LIST=system
$MAKE_COMMAND compile
$MAKE_COMMAND _MachineInfo
