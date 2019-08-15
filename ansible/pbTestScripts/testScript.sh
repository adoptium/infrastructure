#!/bin/bash
set -u

branchName='NULL'
folderName=''
gitURL=''

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
	if [ "$branchName" == "NULL" ]; then
		echo "Detected as the master branch"
		if [ ! -d "$folderName-master" ]; then
   			git clone $gitURL
			mv $folderName $folderName-master
		else
			cd "$folderName-master"
    			git pull $gitURL
		fi
	else
		echo "Branch detected"
		if [ ! -d "$folderName-$branchName" ]; then
  			git clone -b $branchName --single-branch $gitURL
			mv $folderName "$folderName-$branchName"
		else
			cd "$folderName-$branchName"
			git pull origin $branchName
		fi
	fi
}

testBuild()
{
	vagrant ssh -c "git clone https://github.com/AdoptOpenJDK/openjdk-build"
	vagrant ssh -c "cd /vagrant/pbTestScripts && ./buildJDK.sh"
}

# Takes the OS as arg 1
startVMPlaybook()
{
	local OS=$1
	if [ "$branchName" == "NULL" ]; then
		cd $HOME/adoptopenjdkPBTests/$folderName-master/ansible
		$branchName="master"  #Incorrect!
	else
		cd $HOME/adoptopenjdkPBTests/$folderName-$branchName/ansible
	fi
	ln -sf Vagrantfile.$OS Vagrantfile
	vagrant up
	# Remotely moves to the correct directory in the VM and builds the playbook. Then logs the VM's output to a file, in a separate directory
	vagrant ssh -c "cd /vagrant/playbooks/AdoptOpenJDK_Unix_Playbook && sudo ansible-playbook --skip-tags "adoptopenjdk,jenkins" main.yml" 2>&1 | tee ~/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
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

# Takes in the URL passed to the script, and extracts the foldername, branch name and builds the gitURL to be used later on.
splitURL()
{
	local urlSplit
	urlSplit='/' read -r -a array <<< "$1"
	if [ ${array[@]: -2:1} == 'tree' ]
	then
		branchName=${array[@]: -1:1}
		folderName=${array[@]: -3:1}
		unset 'array[${#array[@]}-1]'
		unset 'array[${#array[@]}-1]'
		for i in "${array[@]}"
		do
			gitURL="$gitURL$i/"
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
setupGit
# For all tested OSs / Playbooks
for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7
do
	startVMPlaybook $OS
	if [[ $2 = "n" ]]
	then
		destroyVM
	fi
done
for OS in Ubuntu1804 Ubuntu1604 CentOS6 CentOS7
do
	searchLogFiles $OS $branchName
done
