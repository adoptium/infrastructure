#!/bin/bash

export MAKE_COMMAND="make"
if [[ "$(uname)" == "FreeBSD" ]]; then
	export MAKE_COMMAND="gmake"
	cp -r $HOME/openjdk-build/workspace/build/src/build/*/jdk* $HOME
	export TEST_JDK_HOME=$HOME/jdk
else
	ls -ld $HOME/openjdk-build/workspace/build/src/build/*/images/jdk*
 	export TEST_JDK_HOME=$(ls -1d $HOME/openjdk-build/workspace/build/src/build/*/images/jdk* |egrep -v 'jre|-image|static-libs|sbom')
fi

echo DEBUG: TEST_JDK_HOME = $TEST_JDK_HOME

# Special case for Solaris. See: https://github.com/adoptium/infrastructure/pull/2405#issuecomment-999498345
if [[ "$(uname)" == "SunOS" ]]; then
	export PATH="/usr/local/bin:/opt/csw/bin:${PATH}"
fi

## Run The Smoke Tests To Ensure The JDK Build OK
mkdir -p $HOME/testLocation
[ ! -d $HOME/testLocation/aqa-tests ] && git clone https://github.com/adoptium/aqa-tests.git $HOME/testLocation/aqa-tests
# cd to aqa-tests as required by https://github.com/adoptium/aqa-tests/issues/2691#issue-932959102
cd $HOME/testLocation/aqa-tests
$HOME/testLocation/aqa-tests/get.sh --vendor_repos https://github.com/adoptium/temurin-build --vendor_branches master --vendor_dirs /test/functional
cd $HOME/testLocation/aqa-tests/TKG || exit 1
export BUILD_LIST=functional/buildAndPackage
$MAKE_COMMAND compile
$MAKE_COMMAND _extended.functional

# Run a few subsets of OpenJDK Tests as a shakedown of the built JDK.
export BUILD_LIST=openjdk
$MAKE_COMMAND compile
$MAKE_COMMAND _hotspot_sanity_0
$MAKE_COMMAND _jdk_math_0

# Run Some Additional Tests To Test The Playbooks Have Run Properly
export BUILD_LIST=functional
$MAKE_COMMAND compile
$MAKE_COMMAND _MBCS_Tests_pref_ja_JP_linux_0
$MAKE_COMMAND _MBCS_Tests_formatter_ja_JP_linux_0

# Run SSL Client Tests Linux Only ( Not Solaris / FreeBSD )
if [[ "$(uname)" == "FreeBSD" ]] || [[ "$(uname)" == "SunOS" ]]; then
	echo "Skipping SSL Tests As Not Supported"
else
	export TESTJAVA=$TEST_JDK_HOME
	echo DEBUG: TESTJAVA = $TEST_JDK_HOME
	mkdir -p $HOME/testLocation
  [ ! -d $HOME/testLocation/ssl-tests ] && git clone https://github.com/rh-openjdk/ssl-tests $HOME/testLocation/ssl-tests
	cd $HOME/testLocation/ssl-tests/jtreg-wrappers
	ls -l
	# Reduce Tests For Alpine/Sles/OpenSuse
	if [[ "$(uname -v)" =~ .*"Alpine"*. ]] || [[ `cat /etc/os-release|grep -i opensuse|wc -l` -gt 0 ]] || [[ `cat /etc/os-release|grep -i SLES|wc -l` -gt 0 ]] ; then
		echo "Run Alpine/OpenSuse/Sles SSL Client Tests"
		./ssl-tests-gnutls-client.sh
		./ssl-tests-openssl-client.sh
	else
		echo "Run Full Set Of SSL Client Tests"
		./ssl-tests-gnutls-client.sh
		./ssl-tests-nss-client.sh
		./ssl-tests-openssl-client.sh
  fi
fi
