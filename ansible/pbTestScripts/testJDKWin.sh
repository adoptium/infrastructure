#!/bin/bash

# Script to execute the MachineInfo test on the previously built JDK.

cd /cygdrive/c/workspace/build/src/build/windows-x86_64-normal-server-release/images/

# If the JDK is where it is after building
if [[ $(find . -name "jdk8*" -type d) ]];
then
	echo "Moving JDK to correct directory";
	mv /cygdrive/c/workspace/build/src/build/windows-x86_64-normal-server-release/images/jdk8* $HOME
fi

# Ensures to set it to the JDK, not the JRE
export TEST_JDK_HOME=C:/cygwin64$(find ~ -maxdepth 1 -type d -name "*jdk8u*"|grep -v ".*jre.*")

cd $HOME
if [ ! -d "testLocation" ];
then
	echo "Creating testLocation directory"
	mkdir testLocation
fi
cd testLocation
if [ ! -d "openjdk-tests" ];
then
	echo "Git cloning openjdk-tests"
	git clone https://github.com/adoptopenjdk/openjdk-tests
fi
cd openjdk-tests

./get.sh -t $HOME/testLocation/openjdk-tests -p x64_windows
cd TestConfig
make -f run_configure.mk AUTO_DETECT=true
export BUILD_LIST=MachineInfo
make compile
make _MachineInfo
