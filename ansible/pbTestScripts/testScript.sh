#!/bin/bash
set -u

branchName='NULL'
folderName=' '
gitURL=' '

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
	cd $HOME
	mkdir -p adoptopenjdkPBTests || true
	cd adoptopenjdkPBTests
	mkdir -p logFiles || true
}

# Takes in git URL as arg 1, foldername as arg 2, branchName as arg 3
setupGit()
{
	cd $HOME/adoptopenjdkPBTests
	if [ "$3" = "NULL" ]; then
		echo "Not a branch"
		if [ ! -d "$2-master" ]; then
   			git clone $1
			mv $2 $2-master
		else
			cd "$2-master"
    			git pull $1
		fi
	else
		echo "Branch detected"
		if [ ! -d "$2-$3" ]; then
   			git clone -b $3 --single-branch $1
			mv $2 "$2-$3"
		else
			cd "$2-$3"
			git pull origin $3
		fi
	fi
}

testBuild()
{
	vagrant ssh -c "git clone https://github.com/AdoptOpenJDK/openjdk-build"
	vagrant ssh -c "cd /vagrant/pbTestScripts && ./buildJDK.sh"
}

# Takes the OS as arg 1, foldername as arg 2, branchName as arg 3
startVMPlaybook()
{
	if [ "$3" = "NULL" ]; then	
		cd $HOME/adoptopenjdkPBTests/$2-master/ansible
		$3="master"
	else
		cd $HOME/adoptopenjdkPBTests/$2-$3/ansible
	fi
	ln -sf Vagrantfile.$1 Vagrantfile
	vagrant up
	# Remotely moves to the correct directory in the VM and builds the playbook. Then logs the VM's output to a file, in a separate directory
	vagrant ssh -c "cd /vagrant/playbooks/AdoptOpenJDK_Unix_Playbook && sudo ansible-playbook --skip-tags "adoptopenjdk,jenkins" main.yml" 2>&1 | tee ~/adoptopenjdkPBTests/logFiles/$2.$3.$1.log
	testBuild
	vagrant halt
}

destroyVM()
{
	printf "Destroying Machine . . .\n"
	vagrant destroy -f
}

# Takes in OS as arg 1, branchName as arg 2
searchLogFiles()
{
	cd $HOME/adoptopenjdkPBTests/logFiles
	if grep -q 'failed=[1-9]' *$2.$1.log
	then
		printf "\n$1 Failed\n"
	elif grep -q '\[ERROR\]' *$2.$1.log
	then
		printf "\n$1 playbook was stopped\n"
	else
		printf "\n$1 playbook succeeded\n"
	fi
}

# Takes in the URL passed to the script
splitURL()
{
	# breaks down url to array, and extracts info
	IFS='/' read -r -a array <<< "$1"
	if [ ${array[@]: -2:1} == 'tree' ]
	then
		branchName=${array[@]: -1:1}
		folderName=${array[@]: -3:1}
		unset 'array[${#array[@]}-1]'
		unset 'array[${#array[@]}-1]'
		for I in "${array[@]}"
		do
			gitURL="$gitURL$I/"
		done
	else
		folderName=${array[@]: -1:1}
		gitURL=$1
	fi
}
# var1 = GitURL, var2 = y/n for VM retention
processArgs $*
splitURL $1
setupFiles
setupGit $gitURL $folderName $branchName
# For all tested OSs / Playbooks
for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7
do
	startVMPlaybook $OS $folderName $branchName
	if [[ $2 = "n" ]]
	then
		destroyVM
	fi
done
for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7
do
	searchLogFiles $OS $branchName
done
