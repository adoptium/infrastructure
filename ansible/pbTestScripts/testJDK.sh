#!/bin/bash

export MAKE_COMMAND="make"
if [[ "$(uname)" == "FreeBSD" ]]; then
	export MAKE_COMMAND="gmake"
	cp -r $HOME/openjdk-build/workspace/build/src/build/*/jdk* $HOME
	export TEST_JDK_HOME=$HOME/jdk
else
	ls -ld $HOME/openjdk-build/workspace/build/src/build/*/images/jdk*
 	export TEST_JDK_HOME=$(ls -1d $HOME/openjdk-build/workspace/build/src/build/*/images/jdk* |egrep -v 'jre|-image|static-libs')
fi

echo DEBUG: TEST_JDK_HOME = $TEST_JDK_HOME

# Special case for Solaris. See: https://github.com/adoptium/infrastructure/pull/2405#issuecomment-999498345
if [[ "$(uname)" == "SunOS" ]]; then
	export PATH="/opt/csw/bin:/usr/local/bin:${PATH}"
fi

mkdir -p $HOME/testLocation
[ ! -d $HOME/testLocation/aqa-tests ] && git clone https://github.com/adoptium/aqa-tests.git $HOME/testLocation/aqa-tests
# cd to aqa-tests as required by https://github.com/adoptium/aqa-tests/issues/2691#issue-932959102
cd $HOME/testLocation/aqa-tests
$HOME/testLocation/aqa-tests/get.sh
cd $HOME/testLocation/aqa-tests/TKG || exit 1

# Solaris runs a different test to Linux.
# See: https://adoptium.slack.com/archives/C53GHCXL4/p1641311568115100?thread_ts=1641296204.114900&cid=C53GHCXL4
if [[ "$(uname)" == "SunOS" ]]; then
	export BUILD_LIST=system
	$MAKE_COMMAND compile
	$MAKE_COMMAND _MachineInfo
else
	# Runs this test to check for prerequisite perl modules
	export BUILD_LIST=functional
	$MAKE_COMMAND compile
	$MAKE_COMMAND _MBCS_Tests_pref_ja_JP_linux_0
fi
