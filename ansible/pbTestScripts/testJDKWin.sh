#!/bin/bash

# Script to execute System tests on the previously built JDK.

mv /cygdrive/c/tmp/workspace/build/src/build/*/images/jdk* $HOME
# Ensures to set it to the JDK, not JRE or different images
export TEST_JDK_HOME=C:/cygwin64$(find ~ -maxdepth 1 -type d -name "*jdk*"|grep -v ".*jre"| grep -v ".*-image")

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
cd TKG
export BUILD_LIST=system
make compile
make _extended.system 
