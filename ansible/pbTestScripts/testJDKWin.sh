#!/bin/bash

# Relocate Built JDKS
mv /cygdrive/c/tmp/workspace/build/src/build/*/images/jdk* c:/tmp

# Remove Redundant Images
rm -rf /cygdrive/c/tmp/*-debug-image
rm -rf /cygdrive/c/tmp/*-jre
rm -rf /cygdrive/c/tmp/*-test-image

#Identify The JDK

# Set Test JDK HOME To The Relocated JDK
# export TEST_JDK_HOME=C:/cygwin64$(find ~ -maxdepth 1 -type d -name "*jdk*"|grep -v ".*jre"| grep -v ".*-image")
export TEST_JDK_HOME=`ls -d c:/tmp/jdk*|grep -v "static"|grep -v "debug"|grep -v "jre"|grep -v "test-image"`
echo TEST_JDK_HOME=$TEST_JDK_HOME

## Run The Same Tests As Test JDK for Linux
## Run The Smoke Tests To Ensure The JDK Build OK

cd /cygdrive/c/tmp
if [ ! -d "testLocation" ];
then
	echo "Creating testLocation directory"
	mkdir testLocation
fi
cd testLocation
git clone https://github.com/adoptium/aqa-tests.git
pwd
ls -tr
cd aqa-tests
./get.sh --vendor_repos https://github.com/adoptium/temurin-build --vendor_branches master --vendor_dirs /test/functional
pwd
ls -ltr
cd TKG || exit 1

## Run The Smoke Tests To Ensure The JDK Build OK
export BUILD_LIST=functional/buildAndPackage
make compile
make _extended.functional

# Run a few subsets of OpenJDK Tests as a shakedown of the built JDK.
export BUILD_LIST=openjdk
make compile
make _hotspot_sanity_0
make _jdk_math_0

# Run Some Additional Tests To Test The Playbooks Have Run Properly
export BUILD_LIST=functional
make _MBCS_Tests_pref_ja_windows_0
make _MBCS_Tests_formatter_ja_windows_0
