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
		--hotspot | -hs		Builds hotspot, default is openj9
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
	setBootJDK 
}

setBootJDK() {
        local buildJDKNumber=$(echo ${JAVA_TO_BUILD//[!0-9]/})
        local bootJDKNumber=$(($buildJDKNumber - 1));
        # Refer to 8 as 'jdk8'. Anything else is 'jdk-XX'
        [[ $bootJDKNumber != "8" ]] && bootJDKNumber="-$bootJDKNumber"
        if [[ $buildJDKNumber -eq 8 ]]; then
                # CentOS JDK7
                export JDK_BOOT_DIR=$(find /usr/lib/jvm -maxdepth 1 -name java-1.7.0-openjdk.x86_64)
                # Ubuntu JDK7
                [[ -z "$JDK_BOOT_DIR" ]] && export JDK_BOOT_DIR=$(find /usr/lib/jvm/ -maxdepth 1 -name java-1.7.0-openjdk-\*)
                # Zulu-7 for OSs without JDK7
                [[ -z "$JDK_BOOT_DIR" ]] && export JDK_BOOT_DIR=$(find /usr/lib/jvm/ -maxdepth 1 -name zulu7)
        else
                export JDK_BOOT_DIR=/usr/lib/jvm/jdk${bootJDKNumber}
        fi
        # If JDK (jdkToBuild - 1) can't be found, look for equal boot and build jdk
        if [ -z "${JDK_BOOT_DIR}" ]
        then
                [[ $buildJDKNumber != "8" ]] && buildJDKNumber="-$buildJDKNumber"
                echo "Can't find jdk$bootJDKNumber to build JDK, looking for jdk$buildJDKNumber"
                export JDK_BOOT_DIR=/usr/lib/jvm/jdk${buildJDKNumber}
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

# Use the JDK8 installed with the adoptopenjdk_install role to run Gradle with.
export JAVA_HOME=/usr/lib/jvm/jdk8

# Only build Hotspot on FreeBSD
if [[ $(uname) == "FreeBSD" ]]; then
        echo "Running on FreeBSD"
        export TARGET_OS=FreeBSD
        export VARIANT=hotspot
        export JAVA_TO_BUILD=jdk11u
        export JDK_BOOT_DIR=/usr/local/openjdk11
        export JAVA_HOME=/usr/local/openjdk8
fi

# Required as Debian Buster doesn't have gcc-4.8 available
# See https://github.com/AdoptOpenJDK/openjdk-infrastructure/pull/1321#discussion_r426625178
if grep 'buster' /etc/*-release >/dev/null 2>&1; then
	export CC=/usr/bin/gcc-7
	export CXX=/usr/bin/g++-7
fi

if [ "$ARCHITECTURE" == "aarch64" && "$JAVA_TO_BUILD" == "jdk8u" && $VARIANT == "openj9" ]; then
	echo "Can't build OpenJ9 JDK8 on AARCH64, Defaulting to jdk11"
	JAVA_TO_BUILD=jdk11u
fi

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

cloneRepo 

cd $WORKSPACE/openjdk-build
build-farm/make-adopt-build-farm.sh
