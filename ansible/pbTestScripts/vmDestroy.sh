#!/bin/bash
set -eu

# Takes in all arguments
processArgs()
{
	if [ ! -n "${WORKSPACE:-}" ]; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
	fi
	if [ $# -lt 1 ]; then
		echo "Script takes 1 input argument: "
		echo "The project whose VMs are to be destroyed"
		exit 1
	fi
	
}

# Takes project name as arg 1, and OS as arg 2
destroyVM()
{
	cd $WORKSPACE/adoptopenjdkPBTests/$1/ansible
	ln -sf Vagrantfile.$2 Vagrantfile	# Correct Vagrantfile alias
	vagrant destroy -f			# Force destroy without question
	echo
	echo "Destroyed $2 Machine"	
}

# Takes the project name as arg1
checkFolder()
{
	cd $WORKSPACE/adoptopenjdkPBTests
	if [ -d "$1" ]; then
		echo "$1 found!"
		return 0
	else
		echo "$1 not found"
		exit 1
	fi
}

# Script takes project name as arg 1
processArgs $*
if checkFolder $1; then	
 	# For all currently supported OSs
	for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7 Win2012
	do
		destroyVM $1 $OS
	done
fi
