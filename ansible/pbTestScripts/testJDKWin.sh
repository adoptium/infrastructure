#!/bin/bash
echo $PWD
mv /cygdrive/c/users/vagrant/workspace/build/src/build/windows-x86_64-normal-server-release/images/jdk8* $HOME
export TEST_JDK_HOME=C:/cygwin64$(find ~ -maxdepth 1 -type d -name "*jdk8u*"|grep -v ".*jre.*")
#export TEST_JDK_HOME=C:/cygwin64/home/vagrant/jdk8u232-b07
cd $HOME && mkdir -p testLocation
cd testLocation && git clone https://github.com/adoptopenjdk/openjdk-tests
cd openjdk-tests
./get.sh -t $HOME/testLocation/openjdk-tests -p x64_windows
cd TestConfig
make -f run_configure.mk AUTO_DETECT=true
export BUILD_LIST=MachineInfo
make compile
make _MachineInfo

