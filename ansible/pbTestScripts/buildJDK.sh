#!/bin/bash
set -eu

processArgs() {
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]] ; do
		local opt="$1";
		shift;
		case "$opt" in
			"--version" | "-v" )
				JAVA_TO_BUILD="$1"; shift;;
			"--URL" | "-u" )
				GIT_URL="$1"; shift;;
			"--hotspot" | "-hs" )
				VARIANT=hotspot;;
			"--clean-workspace" | "-c" )
				CLEAN_WORKSPACE=true;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done

	checkJDKVersion $JAVA_TO_BUILD
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
		--URL | -u		Specify the github URL to clone openjdk-build from
		--openj9 | -j9		Builds openJ9, instead of hotspot
		--clean-workspace | -c 	Removes old openjdk-build folder before cloning
		--help | -h		Shows this message
		
	If not specified, JDK8-J9 will be built with the standard openjdk-build repo"
	echo
	showJDKVersions
}

showJDKVersions() {
	echo "Currently supported JDK versions: 
		- JDK8
		- JDK9
		- JDK10
		- JDK11
		- JDK12
		- JDK13
		- JDK14"
	echo
}

checkJDKVersion() {
        local jdk=$1
        case "$jdk" in
                "jdk8u" | "jdk8" | "8" | "8u" )
                        JAVA_TO_BUILD="jdk8u";;
                "jdk9u" | "jdk9" | "9" | "9u" )
                        JAVA_TO_BUILD="jdk9u";;
                "jdk10u" | "jdk10" | "10" | "10u" )
                        JAVA_TO_BUILD="jdk10u";;
                "jdk11u" | "jdk11" | "11" | "11u" )
                        JAVA_TO_BUILD="jdk11u";;
                "jdk12u" | "jdk12" | "12" | "12u" )
                        JAVA_TO_BUILD="jdk12u";;
                "jdk13u" | "jdk13" | "13" | "13u" )
                        JAVA_TO_BUILD="jdk13u";;
                "jdk14u" | "jdk14" | "14" | "14u" )
                        JAVA_TO_BUILD="jdk14u";;
                *)
                        echo "Not a valid JDK Version" ; showJDKVersions; exit 1;;
        esac
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

# Default values
export JAVA_TO_BUILD=jdk8u
export PATH=/usr/local/bin/:$PATH
export TARGET_OS=linux
export VARIANT=openj9
export ARCHITECTURE=x64
GIT_URL="https://github.com/adoptopenjdk/openjdk-build"
CLEAN_WORKSPACE=false

processArgs $*

# All architectures are referred to in make-adopt-build-farm.sh, except x86_64, which is 'x64'
unameOutput=$(uname -m)
if [[ ${unameOutput} != "x86_64" ]]; then
       export ARCHITECTURE=${unameOutput}
fi

# Differences in openJDK7 name between OSs. Search for CentOS one
export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk.x86_64)
# If the CentOS JDK7 can't be found, search for the Ubuntu one
[[ -z "$JDK7_BOOT_DIR" ]] && export JDK7_BOOT_DIR=$(find /usr/lib/jvm/ -name java-1.7.0-openjdk-\*)

# Differences in openJDK8 name between Ubuntu and CentOS
export JAVA_HOME=$(find /usr/lib/jvm/ -name java-1.8.0-openjdk-\*)
if [ -z "$JAVA_HOME" ]; then
	export JAVA_HOME=$(ls -1d /usr/lib/jvm/adoptopenjdk-8-* | head -1)
fi

if grep 'openSUSE' /etc/os-release >/dev/null 2>&1; then
	echo "Running on openSUSE"
	JAVA_HOME=$(find /usr/lib/jvm/ -name jdk8u*)
fi	

# Only build Hotspot on FreeBSD
if [[ $(uname) == "FreeBSD" ]]; then
        echo "Running on FreeBSD"
        export TARGET_OS=FreeBSD
        export VARIANT=hotspot
        export JAVA_TO_BUILD=jdk11u
        export JDK_BOOT_DIR=/usr/local/openjdk11
        export JAVA_HOME=/usr/local/openjdk8
fi

echo "DEBUG:
        TARGET_OS=$TARGET_OS
        ARCHITECTURE=$ARCHITECTURE
        JAVA_TO_BUILD=$JAVA_TO_BUILD
        VARIANT=$VARIANT
        JDK7_BOOT_DIR=$JDK7_BOOT_DIR
        JAVA_HOME=$JAVA_HOME
        WORKSPACE=$WORKSPACE
        GIT_URL=$GIT_URL"

cloneRepo 

cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh
