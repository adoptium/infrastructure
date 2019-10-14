#!/bin/bash

mv /vagrant/pbTestScripts/workspace/build/src/build/linux-x86_64-normal-server-release/images/jdk8* ~
export TEST_JDK_HOME=$(find ~ -maxdepth 1 -type d -name "*jdk8u*"|grep -v ".*jre.*")
cd $HOME && mkdir -p testLocation
cd testLocation && git clone https://github.com/adoptopenjdk/openjdk-tests
cd openjdk-tests
./get.sh -t $HOME/testLocation/openjdk-tests
cd TestConfig
make -f run_configure.mk
export BUILD_LIST=MachineInfo
make compile
make _MachineInfo

