#!/bin/bash
set -eu

# Takes in all arguments
processArgs()
{
	if [ $# -lt 1 ]; then
		printf "\nScript takes 1 input argument\n"
		printf "The project whose VMs are to be destroyed\n\n"
		exit 1
	fi
}

# Takes project name as arg 1, and OS as arg 2
destroyVM()
{
	cd $HOME/adoptopenjdkPBTests/$1/ansible
	ln -sf Vagrantfile.$2 Vagrantfile	# Correct Vagrantfile alias
	vagrant destroy -f			# Force destroy without question
	printf "\nDestroyed $2 Machine\n"	
}

# Takes the project name as arg1
checkFolder()
{
	cd $HOME/adoptopenjdkPBTests
	if [ -d "$1" ]; then
		printf "\n$1 found!\n"
		return 0
	else
		printf "\n$1 not found\n"
		return 1
	fi
}

# Script takes project name as arg 1
processArgs $*
if checkFolder $1; then	
 	# For all currently supported OSs
	for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7
	do
		destroyVM $1 $OS
	done
fi
