#!/bin/bash
set -eu

# Takes all arguments from the script
processArgs()
{
	if [ $# -lt 2 ]; then
		printf "\nScript takes 2 input arguments\n"
		printf "Github URL, then y/n to retain VMs\n\n"
		exit 1
	fi
}

setupFiles()
{
	cd ~					
	mkdir -p adoptopenjdkPBTests || true
	cd adoptopenjdkPBTests
	mkdir -p logFiles || true
}

# Takes in git URL as arg 1, foldername as arg 2
setupGit()
{
	cd ~/adoptopenjdkPBTests
	if [ ! -d "$2" ]; then		#if folder doesn't exist
   		git clone $1
	else				#if it does, ensure up to date
		cd "$2"
    		git pull $1
	fi
}

# Takes the OS as arg 1, foldername as arg 2
startVMPlaybook()
{
	cd ~/adoptopenjdkPBTests/$2/ansible

	# Alias the correct vagrant file
	ln -sf Vagrantfile.$1 Vagrantfile
	
	vagrant up

	# Remotely moves to the correct directory in the VM and builds the playbook. Then logs the VM's output to a file, in a separate directory
	vagrant ssh -c "cd /vagrant/playbooks/AdoptOpenJDK_Unix_Playbook && sudo ansible-playbook --skip-tags "adoptopenjdk,jenkins" main.yml" 2>&1 | tee ~/adoptopenjdkPBTests/logFiles/$2.$1.log

	vagrant halt
}

destroyVM()
{
	printf "Destroying Machine . . .\n"
	vagrant destroy -f
}

# Takes in OS as arg 1
searchLogFiles()
{
	cd ~/adoptopenjdkPBTests/logFiles
	if grep -q 'failed=[1-9]' *$1.log 
	then 
		printf "\n$1 Failed\n"
	elif grep -q '\[ERROR\]' *$1.log 
	then
		printf "\n$1 playbook was stopped\n"
	else
		printf "\n$1 playbook succeeded\n"
	fi
}

# var1 = GitURL, var2 = y/n for VM retention
folderName=${1##*/}
processArgs $*
setupFiles 
setupGit $1 $folderName

# For all tested OSs / Playbooks
for OS in Ubuntu1804 Ubuntu1604 CentOS6
do 	
	startVMPlaybook $OS $folderName
	if [[ $2 = "n" ]]
	then
		destroyVM
	fi
done

for OS in Ubuntu1804 Ubuntu1604 CentOS6 
do
	searchLogFiles $OS
done
