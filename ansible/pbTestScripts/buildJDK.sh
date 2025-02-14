#!/bin/bash
set -eu

setJDKVars() {
	wget -q https://api.adoptopenjdk.net/v3/info/available_releases
	JDK_MAX=$(awk -F: '/tip_version/{print$2}' < available_releases | tr -d ,)
	JDK_GA=$(awk -F: '/most_recent_feature_release/{print$2}' < available_releases | tr -d ,)
	rm available_releases
}

processArgs() {
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]] ; do
		local opt="$1";
		shift;
		case "$opt" in
			"--version" | "-v" )
				if [ $1 == "jdk" ]; then
					export JAVA_TO_BUILD=$JDK_MAX
				else
					export JAVA_TO_BUILD=$(echo $1 | tr -d [:alpha:])
				fi
				checkJDK
				shift;;
			"--fork" | "-f" )
				GIT_FORK="$1"; shift;;
			"--branch" | "-b" )
				GIT_BRANCH="$1"; shift;;
			"--hotspot" | "-hs" )
				VARIANT=hotspot;;
			"--clean-workspace" | "-c" )
				CLEAN_WORKSPACE=true;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done

	if [ -z "${WORKSPACE:-}" ]; then
        	echo "WORKSPACE not found, setting it as environment variable 'HOME'"
        	WORKSPACE=$HOME
	fi
	if [ $CLEAN_WORKSPACE == true ]; then
		echo "Cleaning workspace"
		rm -rf $WORKSPACE/openjdk-build
	fi
}

usage() {
	echo "Usage: ./buildJDK.sh <options>
	Options:
		--version | -v		Specify the JDK version to build
		--fork | -f             Specify the fork of openjdk-build to build from (Default: adoptopenjdk)
		--branch | -b           Specify the branch of the fork to build from (Default: master)
		--hotspot | -hs		Builds hotspot, default is openj9
		--clean-workspace | -c 	Removes old openjdk-build folder before cloning
		--help | -h		Shows this message
	If not specified, JDK8-J9 will be built with the standard openjdk-build repo"
	echo
}

checkJDK() {
	if ! ((JAVA_TO_BUILD >= 8 && JAVA_TO_BUILD <= JDK_MAX)); then
		echo "Please input a JDK between 8 & ${JDK_MAX}, or 'jdk'"
		echo "i.e. The following formats will work for jdk8: 'jdk8u', 'jdk8' , '8'"
		exit 1
	fi
	if ((JAVA_TO_BUILD <= JDK_GA)); then
		JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}u"
	elif ((JAVA_TO_BUILD == JDK_MAX)); then
		JAVA_TO_BUILD="jdk"
	else
		JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}"
	fi
}

# This method is required as there isn't a standardised JDK-7 for all platforms.
# Some may be "zulu7", some may be 'java-1.7.0', or 'openjdk-7-jdk`
findJDK7() {
	local jdkPath=""
	local pathSuffix="java-1.7.0 java-7-openjdk-amd64 zulu7 jdk-7"
	for path in $pathSuffix
	do
		jdkPath=$(find /usr/lib/jvm/ -name $path)
		if [[ $jdkPath != "" ]]; then
			break
		fi
	done

	# Last Resort: Use JDK8 to build JDK8
	if [[ $jdkPath == "" ]]; then
		jdkPath="/usr/lib/jvm/jdk8"
	fi

	export JDK7_BOOT_DIR=$jdkPath
}

cloneRepo() {
	if [ -d $WORKSPACE/openjdk-build ]; then
		echo "Found existing openjdk-build folder"
		cd $WORKSPACE/openjdk-build && git pull
	else
		echo "Cloning new openjdk-build/temurin-build folder"

		local isRepoTemurin=$(curl https://api.github.com/repos/$GIT_FORK/temurin-build | grep "Not Found")
		local isRepoOpenjdk=$(curl https://api.github.com/repos/$GIT_FORK/openjdk-build | grep "Not Found")

		if [[ -z "$isRepoTemurin" ]]; then
			GIT_REPO="https://github.com/${GIT_FORK}/temurin-build"
		elif [[ -z "$isRepoOpenjdk" ]]; then
			GIT_REPO="https://github.com/${GIT_FORK}/openjdk-build"
		else
			echo "Repository not found - the fork must be named temurin-build or openjdk-build"
			exit 1
		fi

		git clone -b ${GIT_BRANCH} --single-branch $GIT_REPO $WORKSPACE/openjdk-build
	fi
}

# Default values
GIT_BRANCH="master"
GIT_FORK="adoptopenjdk"
CLEAN_WORKSPACE=false
JDK_MAX=
JDK_GA=
export VARIANT=openj9

setJDKVars
processArgs $*

# Only build Hotspot on FreeBSD
if [[ "$(uname)" == "FreeBSD" ]]; then
        echo "Running on FreeBSD"
        export TARGET_OS=FreeBSD
        export VARIANT=hotspot
        export JAVA_TO_BUILD=jdk11u
        export JDK_BOOT_DIR=/usr/local/openjdk11
        export JAVA_HOME=/usr/local/openjdk8
elif [[ "$(uname)" == "SunOS" ]]; then
	echo "Running on Solaris/SunOS"
	export TARGET_OS=solaris
	echo "We only build Solaris on JDK8/HS"
	export VARIANT=hotspot
	export JAVA_TO_BUILD=jdk8u
	export JAVA_HOME=/usr/lib/jvm/jdk8
fi

# Required as Debian Buster doesn't have gcc-4.8 available
# See https://github.com/adoptium/infrastructure/pull/1321#discussion_r426625178
if grep 'buster' /etc/*-release >/dev/null 2>&1; then
	export CC=/usr/bin/gcc-7
	export CXX=/usr/bin/g++-7
fi

if [[ "$(uname -m)" == "aarch64" && "$JAVA_TO_BUILD" == "jdk8u" && $VARIANT == "openj9" ]]; then
	echo "Can't build OpenJ9 JDK8 on AARCH64, Resetting JAVA_TO_BUILD to jdk11u"
	export JAVA_TO_BUILD=jdk11u
fi

if [[ "$(uname -m)" == "armv7l" && "$VARIANT" == "openj9" ]]; then
	echo "OpenJ9 VM does not support armv7l - resetting VARIANT to hotspot"
	export VARIANT=hotspot
fi

if [[ "$JAVA_TO_BUILD" == "jdk8u" ]]; then
	findJDK7
fi

# Don't build the debug-images as it takes too much space, and doesn't benefit VPC
# See: https://github.com/adoptium/infrastructure/issues/2033
export CONFIGURE_ARGS="--with-native-debug-symbols=none"
export BUILD_ARGS="--custom-cacerts false --create-sbom"

# For Ubuntu24.04 Support - Don't Use gcc-7
if grep 'noble' /etc/*-release >/dev/null 2>&1; then
        export BUILD_ARGS="${BUILD_ARGS} --use-adoptium-devkit gcc-11.3.0-Centos7.9.2009-b03"
fi

echo "buildJDK.sh DEBUG:
        TARGET_OS=${TARGET_OS:-}
        ARCHITECTURE=${ARCHITECTURE:-}
        JAVA_TO_BUILD=${JAVA_TO_BUILD:-}
        VARIANT=${VARIANT:-}
        JDK_BOOT_DIR=${JDK_BOOT_DIR:-}
        JAVA_HOME=${JAVA_HOME:-}
        WORKSPACE=${WORKSPACE:-}
        FORK=${GIT_FORK:-}
        BRANCH=$GIT_BRANCH:-}
        FILENAME=${FILENAME:-}"

cloneRepo

cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh
