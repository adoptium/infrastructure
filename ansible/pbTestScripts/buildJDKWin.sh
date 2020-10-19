#!/bin/bash
set -eu

setJDKVars() {
	wget -q https://api.adoptopenjdk.net/v3/info/available_releases
	JDK_MAX=$(awk -F: '/tip_version/{gsub("[, ]","",$2); print$2}' < available_releases)
	JDK_GA=$(awk -F: '/most_recent_feature_release/{gsub("[, ]","",$2); print$2}' < available_releases)
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
			"--URL" | "-u" )
				GIT_URL="$1"; shift;;
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
		--URL | -u		Specify the github URL to clone openjdk-build from
		--hotspot | -hs		Builds hotspot, instead of openj9 (openj9 by default)
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
		export JDK_BOOT_DIR=/cygdrive/c/openjdk/jdk-7
		export JAVA_TO_BUILD="jdk8u"
	elif ((JAVA_TO_BUILD > JDK_GA)); then
		export JDK_BOOT_DIR=/cygdrive/c/openjdk/jdk-${JDK_GA}
		if ((JAVA_TO_BUILD == JDK_MAX)); then
			export JAVA_TO_BUILD="jdk"
		else
			export JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}"
		fi
	else
		export JDK_BOOT_DIR=/cygdrive/c/openjdk/jdk-$((JAVA_TO_BUILD - 1))
		export JAVA_TO_BUILD="jdk${JAVA_TO_BUILD}u"
	fi
}

cloneRepo() {
	local branch=""
	IFS='/' read -r -a urlArray <<< "$GIT_URL"
	if [ -d $WORKSPACE/openjdk-build ]; then
		echo "Found existing openjdk-build folder"
		cd $WORKSPACE/openjdk-build && git pull
	elif [ ${urlArray[@]: -2:1} == 'tree' ]; then
		GIT_URL=""
		echo "Branch detected"
		branch=${urlArray[@]: -1:1}
		unset 'urlArray[${#urlArray[@]}-1]'
		unset 'urlArray[${#urlArray[@]}-1]'
		for urlPart in "${urlArray[@]}"
		do
			GIT_URL="$GIT_URL$urlPart/"
		done
		git clone -b $branch $GIT_URL $WORKSPACE/openjdk-build
	else
		echo "No branch detected"
		git clone $GIT_URL $WORKSPACE/openjdk-build
	fi
}
# Set defaults
export JAVA_TO_BUILD=jdk8
export JDK_BOOT_DIR=/cygdrive/c/openjdk/jdk-7
export VARIANT=openj9
export PATH=/usr/bin/:$PATH
export TARGET_OS=windows
export ARCHITECTURE=x64
export JAVA_HOME=/cygdrive/c/openjdk/jdk-8

GIT_URL=https://github.com/adoptopenjdk/openjdk-build
CLEAN_WORKSPACE=false
JDK_GA=
JDK_MAX=

setJDKVars
processArgs $*
cloneRepo

export FILENAME="${JAVA_TO_BUILD}_${VARIANT}_${ARCHITECTURE}"
echo "DEBUG:
	TARGET_OS=$TARGET_OS
	ARCHITECTURE=$ARCHITECTURE
	JAVA_TO_BUILD=$JAVA_TO_BUILD
	VARIANT=$VARIANT
	JDK_BOOT_DIR=$JDK_BOOT_DIR
	JAVA_HOME=$JAVA_HOME
	WORKSPACE=$WORKSPACE
	GIT_URL=$GIT_URL
	FILENAME=$FILENAME"

echo "Running $WORKSPACE/openjdk-build/build-farm/make-adopt-build-farm.sh"
$WORKSPACE/openjdk-build/build-farm/make-adopt-build-farm.sh
