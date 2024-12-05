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
					JAVA_TO_BUILD=$JDK_MAX
				else
					JAVA_TO_BUILD=$(echo $1 | tr -d [:alpha:])
				fi
				checkJDK
				shift;;
			"--fork" | "-f" )
				GIT_FORK="$1"; shift;;
			"--branch" | "-b" )
				GIT_BRANCH="$1"; shift;;
			"--hotspot" | "-hs" )
				export VARIANT=hotspot;;
			"--clean-workspace" | "-c" )
				CLEAN_WORKSPACE=true;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done
	if [ -z "$JAVA_TO_BUILD:-}" ]; then
		echo "You must use the '-v' option"
		exit 1
	fi
	if [ -z "${WORKSPACE:-}" ]; then
        	echo "WORKSPACE not found, setting it to /tmp"
        	WORKSPACE=/tmp/
	fi
	if [ $CLEAN_WORKSPACE == true ]; then
		echo "Cleaning workspace"
		rm -rf $WORKSPACE/openjdk-build
	fi
}

usage() {
	echo "Usage: ./buildJDK.sh <options> (-v <JDK>)

	Options:
		--version | -v	<JDK>	Specify the JDK version to build
		--fork | -f             Specify the fork of openjdk-build to build from (Default: adoptopenjdk)
		--branch | -b           Specify the branch of the fork to build from (Default: master)
		--hotspot | -hs		Builds hotspot, instead of openj9 (Default: openj9)
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
	if ((JAVA_TO_BUILD == 8)); then
		export JAVA_TO_BUILD="jdk8u"
	elif ((JAVA_TO_BUILD > JDK_GA)); then
		export JDK_BOOT_DIR=/cygdrive/c/openjdk/jdk-${JDK_GA}
		if ((JAVA_TO_BUILD == JDK_MAX)); then
			export JAVA_TO_BUILD="jdk"
		else
			export JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}"
		fi
	else
		export JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}u"
	fi
}

cloneRepo() {
	if [ -d $WORKSPACE/openjdk-build ]; then
		echo "Found existing openjdk-build folder"
		cd $WORKSPACE/openjdk-build && git pull
	else
		echo "Cloning new openjdk-build directory"

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
# Set defaults
export JAVA_HOME=/cygdrive/c/openjdk/jdk-8

GIT_FORK=adoptopenjdk
GIT_BRANCH=master
CLEAN_WORKSPACE=false
JDK_GA=
JDK_MAX=

setJDKVars
processArgs $*
cloneRepo

echo "buildJDKWin.sh DEBUG:
	TARGET_OS=${TARGET_OS:-}
	ARCHITECTURE=${ARCHITECTURE:-}
	JAVA_TO_BUILD=${JAVA_TO_BUILD:-}
	VARIANT=${VARIANT:-}
	JDK_BOOT_DIR=${JDK_BOOT_DIR:-}
	JAVA_HOME=${JAVA_HOME:-}
	WORKSPACE=${WORKSPACE:-}
	FORK=${GIT_FORK:-}
	BRANCH=${GIT_BRANCH:-}
	FILENAME=${FILENAME:-}"

echo "Running $WORKSPACE/openjdk-build/build-farm/make-adopt-build-farm.sh"
export BUILD_ARGS=--create-sbom
$WORKSPACE/openjdk-build/build-farm/make-adopt-build-farm.sh
