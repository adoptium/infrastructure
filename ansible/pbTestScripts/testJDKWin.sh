#!/bin/bash

# Relocate Built JDKS
mv /tmp/workspace/build/src/build/*/images/jdk* c:/tmp

# Remove Redundant Images
rm -rf c:/tmp/*-debug-image
rm -rf c:/tmp/*-jre
rm -rf c:/tmp/*-test-image

#Identify The JDK

# Set Test JDK HOME To The Relocated JDK
# export TEST_JDK_HOME=C:/cygwin64$(find ~ -maxdepth 1 -type d -name "*jdk*"|grep -v ".*jre"| grep -v ".*-image")
export TEST_JDK_HOME=`ls -d c:/tmp/jdk*|grep -v "static"|grep -v "debug"|grep -v "jre"|grep -v "test-image"`
echo TEST_JDK_HOME=$TEST_JDK_HOME

cd /tmp
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

./get.sh -T $HOME/testLocation/openjdk-tests -p x64_windows
cd TKG
export BUILD_LIST=system
make compile
make _extended.system 
