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
[ ! -d $HOME/testLocation/aqa-tests ] && git clone https://github.com/adoptium/aqa-tests.git $HOME/testLocation/aqa-tests
# cd to aqa-tests as required by https://github.com/adoptium/aqa-tests/issues/2691#issue-932959102
cd $HOME/testLocation/aqa-tests
$HOME/testLocation/aqa-tests/get.sh
cd $HOME/testLocation/aqa-tests/TKG || exit 1
export BUILD_LIST=functional
$MAKE_COMMAND compile
# Runs this test to check for prerequisite perl modules
$MAKE_COMMAND _MBCS_Tests_pref_ja_JP_linux_0
