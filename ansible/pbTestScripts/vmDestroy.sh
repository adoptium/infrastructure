#!/bin/bash
set -eu

osToDestroy=''
force=False
# Takes in all arguments
processArgs()
{
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]] ; do
		local opt="$1";
		shift;
		case "$opt" in
			"--OS" | "-o" )
				if [[ -z "${1:-}" ]]; then
					echo "Please specifiy an OS with the '-o' option"
					usage
					exit 1
				else
					osToDestroy=$1;
				fi
				shift;;
			"--force" | "-f" )
				force=True;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done
}

usage() {
	   echo "Usage: ./vmDestroy.sh (<options>) -o <os_list>
		--OS | -o		Specifies the OS of the vagrant VMs you want to destroy
		--force | -f		Force destroy the VMs without asking confirmation
		--help | -h		Displays this help message"
		listOS
}

checkOS() {
	local OS=$osToDestroy
        case "$OS" in
                "Ubuntu1604" | "U16" | "u16" )
			osToDestroy="U16";;
                "Ubuntu1804" | "U18" | "u18" )
                        osToDestroy="U18";;
                "Ubuntu2004" | "U20" | "u20" )
                        osToDestroy="U20";;
                "Ubuntu2104" | "U21" | "u21" )
                        osToDestroy="U21";;
                "Ubuntu2204" | "U22" | "u22" )
                        osToDestroy="U22";;
                "Ubuntu2404" | "U24" | "u24" )
                        osToDestroy="U24";;
                "CentOS6" | "centos6" | "C6" | "c6" )
                        osToDestroy="C6" ;;
                "CentOS7" | "centos7" | "C7" | "c7" )
                        osToDestroy="C7" ;;
                "CentOS8" | "centos8" | "C8" | "c8" )
                        osToDestroy="C8" ;;
                "Debian8" | "debian8" | "D7" | "d7" )
                        osToDestroy="D8" ;;
                "Debian10" | "debian10" | "D10" | "d10" )
                        osToDestroy="D10" ;;
                "Fedora40" | "fedora40" | "F40" | "f40" )
                        osToDestroy="F40" ;;
		"FreeBSD12" | "freebsd12" | "F12" | "f12" )
			osToDestroy="FBSD12" ;;
		"Solaris10" | "solaris10" | "Sol10" | "sol10" )
			osToDestroy="Sol10" ;;
		"Windows2012" | "Win2012" | "W12" | "w12" )
                        osToDestroy="W2012";;
  	"Windows2022" | "Win2022" | "W22" | "w22" )
	                       osToDestroy="W2022";;
	              "all" )
                        osToDestroy="U16 U18 U20 U21 U22 C6 C7 C8 D8 D10 F40 FBSD12 Sol10 W2012 W2022" ;;
		"")
			echo "No OS detected. Did you miss the '-o' option?" ; usage; exit 1;;
		*) echo "$OS is not a currently supported OS" ; listOS; exit 1;
        esac
}

listOS() {
	echo
	echo "Currently supported OSs:
		- Ubuntu1604
		- Ubuntu1804
		- Ubuntu2004
		- Ubuntu2104
		- Ubuntu2204
		- Ubuntu2404
		- CentOS6
		- CentOS7
		- CentOS8
		- Debian8
		- Debian10
		- FreeBSD12
		- Solaris10
		- Win2012
		- Win2022"
	echo
}

destroyVMs() {
	local OS=$1
	local ID=$(vagrant global-status --prune | awk "/adoptopenjdk$OS/ { print \$1 }")
	if [[ "$ID" != "" ]]; then
		vagrant destroy -f $ID
		echo "Destroyed all $OS vagrant VMs"
	else
		echo "No $1 vagrant VMs, moving on..."
	fi
}

processArgs $*
checkOS
if [[ "$force" == False ]]; then
	userInput=""
	echo "Are you sure you want to destroy ALL Vms with the following OS(s)? (Y/n)"
	echo "$osToDestroy"
	read userInput
	if [ "$userInput" != "Y" ] && [ "$userInput" != "y" ]; then
		echo "Cancelling ..."
		exit 1;
	fi
fi
for OS in $osToDestroy
do
	destroyVMs $OS
done
