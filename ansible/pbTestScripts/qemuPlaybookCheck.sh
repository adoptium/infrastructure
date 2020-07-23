#!/bin/bash

ARCHITECTURE=""
skipFullSetup=""
gitURL="https://github.com/adoptopenjdk/openjdk-infrastructure"
gitBranch="master"
PORTNO=10022
if [ "$EXECUTOR_NUMBER" ]; then
  PORTNO=1002$EXECUTOR_NUMBER
fi
current_dir=false
cleanWorkspace=false
retainVM=false
buildJDK=false
testJDK=false
# Default to building jdk8u
jdkToBuild="jdk8u"

# Parse Arguments
processArgs() {
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]]; do
		local opt="$1";
		shift;
		case "$opt" in
			"--architecture" | "-a" )
				ARCHITECTURE="$1"; shift;;			
			"--build" | "-b" )
				buildJDK=true;;
			"--currentDir " | "-c" )
				current_dir=true;;
			"--clean-workspace" | "-cw" )
				cleanWorkspace=true;;
			"--help" | "-h" )
				usage; exit 0;;
			"--retainVM" | "-r" )
				retainVM=true;;
			"--test" | "-t" )
				testJDK=true;;
			"--infra-repo" | "-ir" )
				gitURL="$1"; shift;;
			"--infra-branch" | "-ib" )
				gitBranch=$1; shift;;
			"--skip-more" | "-sm" )
				skipFullSetup=",nvidia_cuda_toolkit,MSVS_2010,MSVS_2017";;
			"--jdk-version" | "-v" )
				jdkToBuild="$1"; shift;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done
}

usage() {
	echo "Usage: ./qemu_test_script.sh (<options>) -a <architecture>
		--architecture | -a		Specifies the architecture to build the OS on
		--build | -b			Build a JDK on the qemu VM
		--currentDir | -c		Set Workspace to directory of this script
		--clean-workspace | -cw		Removes the old work folder (including logs)
		--help | -h 			Shows this help message
		--infra-repo | -ir		Which openjdk-infrastructure to retrieve the playbooks (default: www.github.com/adoptopenjdk/openjdk-infrastructure)
		--infra-branch | -ib		Specify the branch of the infra-repo (default: master)
		--jdk-version | -v		Specify which JDK to build if '-b' is used (default: jdk8u)
		--retainVM | -r			Retain the VM once running the playbook
		--skip-more | -sm		Skip non-essential roles from the playbook
		--test | -t			Test the built JDK
		"	
	showArchList
}

defaultVars() {
	case "$ARCHITECTURE" in
		"s390x" | "S390X" | "S390x" )
			echo "s390x selected"; ARCHITECTURE=S390X;;
		"aarch64" | "arm64" | "ARM64" )
                        echo "arm64 selected"; ARCHITECTURE=ARM64;;
		"ppc64le" | "ppc64" | "PPC64LE" | "PPC64" )
			echo "ppc64le selected"; ARCHITECTURE=PPC64LE;;
		"" )
			echo "Please input an architecture to test"; exit 1;;
		*) echo "Please select a valid architecture"; showArchList; exit 1;;
	esac
	if [[ -z "${WORKSPACE:-}" && "$current_dir" == false ]] ; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
	elif [[ "$current_dir" = true ]]; then
		echo "Setting WORKSPACE to the current directory"
		WORKSPACE=$PWD	
	fi
	if [[ "$buildJDK" == false && "$testJDK" == true ]]; then
		echo "Unable to test an unbuilt JDK. Please specify both '--build' and '--test'."
		exit 1;
	fi

}

showArchList() {
	echo "Currently supported architectures:
	- ppc64le
	- s390x
	- arm64"
}

# Setup the file system

setupWorkspace() {
	local workFolder=$WORKSPACE/qemu_pbCheck
	# Images are in this consistent place on the 'vagrant' jenkins machines
	local imageLocation="/qemu_base_images"
	
	mkdir -p "$workFolder"/logFiles
	if [[ "$cleanWorkspace" = true ]]; then
		echo "Cleaning old workspace"
		# finds all non-dir files and deletes them
		find "$workFolder" -type f | xargs rm -f
		rm -rf "$workFolder"/openjdk-infrastructure "$workFolder"/openjdk-build
	fi
	if [[ ! -f "${workFolder}/${ARCHITECTURE}.dsk" ]]; then 
		echo "Copying new disk image"
		xz -cd "$imageLocation"/"$ARCHITECTURE".dsk.xz > "$workFolder"/"$ARCHITECTURE".dsk
	else
		echo "Using old disk image"
	fi
}

runImage() {

local EXTRA_ARGS=""
local workFolder="$WORKSPACE/qemu_pbCheck"

# Find/stop port collisions
while netstat -lp 2>/dev/null | grep "tcp.*:$PORTNO " > /dev/null; do
  ((PORTNO++))
done
	echo "Using Port: $PORTNO"

	# Setting architecture specific variables
	case "$ARCHITECTURE" in
		"S390X" )
			export MACHINE="s390-ccw-virtio"
			export DRIVE="-drive file=$workFolder/S390X.dsk,if=none,id=hd0 -device virtio-blk-ccw,drive=hd0,id=virtio-disk0"
			export QEMUARCH="s390x"
			export SSH_CMD="-net user,hostfwd=tcp::$PORTNO-:22 -net nic";;
		"PPC64LE" )
			export MACHINE="pseries-2.12"
			export DRIVE="-hda $workFolder/PPC64LE.dsk"
			export QEMUARCH="ppc64"
			export SSH_CMD="-net user,hostfwd=tcp::$PORTNO-:22 -net nic";;
		"ARM64" )
			export MACHINE="virt"
			export DRIVE="-drive if=none,file=$workFolder/ARM64.dsk,id=hd -device virtio-blk-device,drive=hd"
			export QEMUARCH="aarch64"
			export SSH_CMD="-device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp:127.0.0.1:$PORTNO-:22"
			export EXTRA_ARGS="-cpu cortex-a57 -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd";;
	esac
	
	# Run the command, mask output and send to background
	(qemu-system-$QEMUARCH \
	  -smp 4 \
	  -m 3072 \
     	  -M $MACHINE \
	  $SSH_CMD \
	  $DRIVE \
     	  $EXTRA_ARGS \
	  -nographic) > /dev/null 2>&1 &

	echo "Machine is booting; Please be patient"
	sleep 120
	echo "Machine has started"

	# Remove old ssh key and create a new one
	rm -f "$workFolder"/id_rsa*
	ssh-keygen -q -f "$workFolder"/id_rsa -t rsa -N ''
        ssh-keygen -q -R "[localhost]:$PORTNO"

	# Required to auto-accept the host ECDSA key
	sshpass -p 'password' ssh linux@localhost -p "$PORTNO" -o StrictHostKeyChecking=no 'uname -a' 
	# Add ssh key to VM's authorized_keys
	sshpass -p 'password' ssh-copy-id -p "$PORTNO" -i "$workFolder"/id_rsa.pub linux@localhost 
}

## Run the playbook ( and build/test the JDK if applicable )

runPlaybook() {
	local workFolder="$WORKSPACE"/qemu_pbCheck

	[[ ! -d "$workFolder/openjdk-infrastructure"  ]] && git clone -b "$gitBranch" "$gitURL" "$workFolder"/openjdk-infrastructure
	cd "$workFolder"/openjdk-infrastructure/ansible || exit 1;

	ansible-playbook -i "localhost:$PORTNO," --private-key "$workFolder"/id_rsa -u linux -b --skip-tags adoptopenjdk,jenkins${skipFullSetup} playbooks/AdoptOpenJDK_Unix_Playbook/main.yml 2>&1 | tee "$workFolder"/logFiles/"$ARCHITECTURE".log
	if grep -q 'failed=[1-9]\|unreachable=[1-9]' "$workFolder"/logFiles/"$ARCHITECTURE".log; then
		echo "Playbook failed"
		destroyVM
		exit 1;
	fi

	if [[ "$buildJDK" == true ]]; then
		ssh linux@localhost -p "$PORTNO" -i "$workFolder"/id_rsa "git clone https://github.com/adoptopenjdk/openjdk-infrastructure \$HOME/openjdk-infrastructure && \$HOME/openjdk-infrastructure/ansible/pbTestScripts/buildJDK.sh --version $jdkToBuild"
		if [[ "$testJDK" == true ]]; then
			ssh linux@localhost -p "$PORTNO" -i "$workFolder"/id_rsa "\$HOME/openjdk-infrastructure/ansible/pbTestScripts/testJDK.sh" 
		fi	
	fi
	if [[ "$retainVM" == false ]]; then
		destroyVM
	fi
}

destroyVM() {	
	local PID=$(ps -aux | grep "$PORTNO" | grep -v "grep" | awk '{ print $2 }')
	echo "Killing this process: $PID"
	kill $PID
}

processArgs $*
defaultVars
setupWorkspace
runImage
runPlaybook
