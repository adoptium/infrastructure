#!/bin/bash
set -eu

osToDestroy=''

# Takes in all arguments
processArgs()
{
	if [ $# -lt 1 ]; then
		echo "Script takes 1 input argument: "
		echo "The OS of the VMs you want to destroy."
		exit 1
	fi
}

checkOS() {
	local OS=$1
        case "$OS" in
                "Ubuntu1604" | "U16" | "u16" )
			osToDestroy="U16";;
                "Ubuntu1804" | "U18" | "u18" )
                        osToDestroy="U18";;
                "CentOS6" | "centos6" | "C6" | "c6" )
                        osToDestroy="C6" ;;
                "CentOS7" | "centos7" | "C7" | "c7" )
                        osToDestroy="C7" ;;
                "Windows2012" | "Win2012" | "W12" | "w12" )
                        osToDestroy="W2012";;
                "all" )
                        osToDestroy="U16 U18 C6 C7 W2012" ;;
                *) echo "Not a currently supported OS" ; listOS; exit 1;
        esac
}

listOS() {
	echo
	echo "Currently supported OSs:
		- Ubuntu1604
		- Ubuntu1804
		- CentOS6
		- CentOS7
		- Win2012"
	echo
}

destroyVMs() {
	local OS=$1
	vagrant global-status | grep "adoptopenjdk$OS" | awk '{ print $1 }' | xargs -I {} vagrant destroy -f {}
	echo "Destroyed all $OS Vagrant VMs"
}

processArgs $*
checkOS $1
for OS in $osToDestroy
do
	destroyVMs $OS
done

