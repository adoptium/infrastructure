#!/bin/bash
set -eu

osToDestroy=''
force=False
provider='virtualbox'
scriptPath=$(realpath $0)
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
			"--provider" | "-p" )
				provider="$1"; shift;;
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
		--provider | -p		Specify the provider: virtualbox (default) or libvirt
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
		"Windows2012" | "Win2012" | "W12" | "w12" )
                        osToDestroy="W2012";;
 "Windows2022" | "Win2022" | "W22" | "w22" )
  	                     osToDestroy="W2022";;
 "Windows2025" | "Win2025" | "W25" | "w25" )
  	                     osToDestroy="W2025";;
  	            "all" )
  	                     osToDestroy="U16 U18 U20 U21 U22 C6 C7 C8 D8 D10 F40 FBSD12 Sol10 W2012 W2022 W2025" ;;
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
		- Win2012
		- Win2022
		- Win2025"
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
	if [[ "$provider" == "libvirt" ]]; then
		cleanupLibvirtVolumes "$OS"
	fi
}

# Remove orphaned libvirt storage pool volumes left behind after vagrant box remove.
# vagrant-libvirt only removes the box from ~/.vagrant.d/boxes; the pool image must
# be deleted manually.  Volume names follow the pattern:
#   <box-name>_vagrant_box_image_<version>.img
# where '/' in the box name is encoded as '-VAGRANTSLASH-'.
cleanupLibvirtVolumes()
{
	local OS=$1
	local pool="default"
	local vagrantfileDir="${scriptPath%/*}/../vagrant"
	local vagrantfile="${vagrantfileDir}/Vagrantfile.${OS}.Libvirt"
	if [[ ! -f "$vagrantfile" ]]; then
		vagrantfile="${vagrantfileDir}/Vagrantfile.${OS}"
	fi
	local boxName=""
	if [[ -f "$vagrantfile" ]]; then
		boxName=$(grep 'vm\.box\s*=' "$vagrantfile" | head -1 | sed 's/.*vm\.box\s*=\s*["\x27]\([^"'\'']*\)["\x27].*/\1/')
	fi
	if [[ -z "$boxName" ]]; then
		echo "=== cleanupLibvirtVolumes: could not determine box name for $OS, skipping pool cleanup"
		return
	fi
	# Encode '/' as '-VAGRANTSLASH-' to match libvirt volume naming
	local volPrefix="${boxName//\//-VAGRANTSLASH-}_vagrant_box_image_"
	echo "=== Removing libvirt storage pool volumes matching '${volPrefix}*' from pool '${pool}'"
	local volumes
	volumes=$(virsh vol-list "$pool" 2>/dev/null | awk 'NR>2 && $1!="" { print $1 }' | grep "^${volPrefix}" || true)
	if [[ -z "$volumes" ]]; then
		echo "=== No libvirt volumes found for box '${boxName}' in pool '${pool}'"
	else
		while IFS= read -r vol; do
			echo "=== Deleting libvirt volume: $vol"
			virsh vol-delete --pool "$pool" "$vol" || echo "WARNING: failed to delete volume $vol"
		done <<< "$volumes"
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
