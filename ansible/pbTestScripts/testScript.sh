#!/bin/bash
set -eu

branchName=''
folderName=''
gitURL=''
vagrantOS=''
retainVM=false
testNativeBuild=false
runTest=false
vmHalt=true

# Takes all arguments from the script, and determines options
processArgs()
{
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]] ; do
		local opt="$1";
		shift;
		case "$opt" in
			"--Vagrantfile" | "-v" )
				vagrantOS="$1"; shift;;
			"--all" | "-a" )
				vagrantOS="all";;
			"--build" | "-b" )
				testNativeBuild=true;;
			"--retainVM" | "-r" )
				retainVM=true;;
			"--URL" | "-u" )
				gitURL="$1"; shift;;
			"--test" | "-t" )
				runTest=true;;
			"--no-halt" | "-nh" )
				vmHalt=false;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done
}

usage()
{
	echo
	echo "Usage: ./testScript.sh			--vagrantfile | -v <OS_Version>		Specifies which OS the VM is
					--all | -a 				Builds and tests playbook through every OS
					--retainVM | -r				Option to retain the VM and folder after completion
					--build | -b				Option to enable testing a native build on the VM
					--URL | -u <GitURL>			The URL of the git repository
                                        --test | -t                             Runs a quick test on the built JDK
					--no-halt | -nh				Option to stop the vagrant VMs halting
					--help | -h				Displays this help message"
}

checkVars()
{
	if [[ "$runTest" == true && "$testNativeBuild" == false ]]; then 
                echo "Unable to test an unbuilt JDK. Please specify both '--build' and '--test'"
                exit 1
        fi
	#Sets WORKSPACE to home if WORKSPACE is empty or undefined. 
	if [ ! -n "${WORKSPACE:-}" ]; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
	fi
	if [ "$gitURL" == "" ]; then
		echo "No GitURL specified; Defaulting to adoptopenjdk/openjdk-infrastructure"
		gitURL=https://github.com/adoptopenjdk/openjdk-infrastructure
	fi
	if [ "$vagrantOS" == "" ]; then
		echo "No Vagrant OS specified; Defaulting to testing all of them"
		vagrantOS="all"
	fi
	if [[ "$retainVM" == false && "$vmHalt" == false ]]; then
		echo "Must halt the VM to destroy it; Ignoring '--no-halt' option"
		vmHalt=true;
	fi
        if [[ ! $(vagrant plugin list | grep 'disksize') ]]; then
                echo "Can't find vagrant-disksize plugin, installing . . ."
                vagrant plugin install vagrant-disksize
        fi
}

checkVagrantOS()
{
	case "$vagrantOS" in
		"Ubuntu1604" | "U16" | "u16" )
			vagrantOS="Ubuntu1604";;
		"Ubuntu1804" | "U18" | "u18" )
			vagrantOS="Ubuntu1804";;
		"CentOS6" | "centos6" | "C6" | "c6" )
			vagrantOS="CentOS6" ;;
		"CentOS7" | "centos7" | "C7" | "c7" )
			vagrantOS="CentOS7" ;;
		"Windows2012" | "Win2012" | "W12" | "w12" )
			vagrantOS="Win2012";;
		"all" )
			vagrantOS="Ubuntu1604 Ubuntu1804 CentOS6 CentOS7 Windows2012" ;;
		*) echo "Not a currently supported OS" ; vagrantOSList; exit 1;
	esac
}

vagrantOSList()
{
	echo
	echo "Currently supported Vagrant OSs :
		- Ubuntu1604
		- Ubuntu1804
		- CentOS6
		- CentOS7
		- Win2012"
	echo
}

setupFiles()
{
	cd $WORKSPACE
	if [ ! -d "adoptopenjdkPBTests" ]; then
		mkdir adoptopenjdkPBTests
	fi
	if [ ! -d "adoptopenjdkPBTests/logFiles" ]; then
		mkdir adoptopenjdkPBTests/logFiles
	fi
}

setupGit()
{
	cd $WORKSPACE/adoptopenjdkPBTests
	if [ "$branchName" == "master" ]; then
		echo "Detected as the master branch"
		if [ ! -d "$folderName-master" ]; then
   			git clone $gitURL
			mv $folderName $folderName-master
		else
			cd "$folderName-master"
    			git pull 
		fi
	else
		echo "Branch detected"
		if [ ! -d "$folderName-$branchName" ]; then
  			git clone -b $branchName --single-branch $gitURL
			mv $folderName $folderName-$branchName
		else
			cd "$folderName-$branchName"
			git pull origin $branchName
		fi
	fi
}


# Takes the OS as arg 1
startVMPlaybook()
{
	local OS=$1
	cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	ln -sf Vagrantfile.$OS Vagrantfile
	# Copy the machine's ssh key for the VMs to use, after removing prior files
	rm -f id_rsa.pub id_rsa
	ssh-keygen -q -f $PWD/id_rsa -t rsa -N ''
	vagrant up
	# Generate hosts.unx file for Ansible to use, remove prior hosts.unx if there
	[[ -f playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx ]] && rm playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	cat playbooks/AdoptOpenJDK_Unix_Playbook/hosts.tmp | tr -d \\r | sort -nr | head -1 > playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx && rm playbooks/AdoptOpenJDK_Unix_Playbook/hosts.tmp
	local vagrantIP=$(cat playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx)
	# Remove IP from known_hosts if already found
	grep -q "$vagrantIP" ~/.ssh/known_hosts && ssh-keygen -R $vagrantIP
	sed -i -e "s/.*hosts:.*/- hosts: all/g" playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
	# Alter ansible.cfg to increase timeout and to specify which private key to use
	# NOTE! Only works with GNU sed
	! grep -q "timeout" ansible.cfg && sed -i -e 's/\[defaults\]/&\ntimeout = 30/g' ansible.cfg
	! grep -q "private_key_file" ansible.cfg && sed -i -e 's/\[defaults\]/&\nprivate_key_file = id_rsa/g' ansible.cfg
	ansible-playbook -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx -u vagrant -b --skip-tags adoptopenjdk,jenkins playbooks/AdoptOpenJDK_Unix_Playbook/main.yml 2>&1 | tee $WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
	echo The playbook finished at : `date +%T`
	searchLogFiles $OS
	if [[ "$testNativeBuild" = true ]]; then
		cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
		ansible all -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx -u vagrant -b -m raw -a "cd /vagrant/pbTestScripts && ./buildJDK.sh"
		echo The build finished at : `date +%T`
		if [[ "$runTest" = true ]]; then
	        	ansible all -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx -u vagrant -b -m raw -a "cd /vagrant/pbTestScripts && ./testJDK.sh"
			echo The test finished at : `date +%T`
		fi
	fi
	if [[ "$vmHalt" = true ]]; then
		vagrant halt
	fi
}

startVMPlaybookWin()
{
	local OS=$1
	cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	ln -sf Vagrantfile.$OS Vagrantfile
	# Remove the Hosts files if they're found
	rm -f playbooks/AdoptOpenJDK_Windows_Playbook/hosts.tmp
	rm -f playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win
	vagrant up
	cat playbooks/AdoptOpenJDK_Windows_Playbook/hosts.tmp | tr -d \\r | sort -nr | head -1 > playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win
	echo "This is the content of hosts.win : " && cat playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win
	# Changes the value of "hosts" in main.yml
	sed -i'' -e "s/.*hosts:.*/- hosts: all/g" playbooks/AdoptOpenJDK_Windows_Playbook/main.yml
	# Uncomments and sets the ansible_password to 'vagrant', in adoptopenjdk_variables.yml
	sed -i'' -e "s/.*ansible_password.*/ansible_password: vagrant/g" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	# If "credssp" isn't found in adoptopenjdk_variables.yml
	if ! grep -q "credssp" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml;
	then
		# Add the "ansible_winrm_transport" to adoptopenjdk_variables.yml
		echo -e "\nansible_winrm_transport: credssp" >> playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi
	# Run the ansible playbook on the VM & logs the output.
	ansible-playbook -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant --skip-tags jenkins,adoptopenjdk,build playbooks/AdoptOpenJDK_Windows_Playbook/main.yml 2>&1 | tee $WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
	echo The playbook finished at : `date +%T`
	searchLogFiles $OS
	if [[ "$testNativeBuild" = true ]]; then
		echo "Building a JDK"
		# Runs the build script via ansible, as vagrant powershell gives error messages that ansible doesn't. 
        	# See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/pull/942#issuecomment-539946564
        	cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
		ansible all -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant -m raw -a "Start-Process powershell.exe -Verb runAs; cd C:/; sh C:/vagrant/pbTestScripts/buildJDKWin.sh"
		echo The build finished at : `date +%T`
		if [[ "$runTest" = true ]]; then
			echo "Running test against the built JDK"
			# Runs a script on the VM to test the built JDK
			ansible all -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant -m raw -a "sh C:/vagrant/pbTestScripts/testJDKWin.sh"
			echo The test finished at : `date +%T`
		fi
	fi
        if [[ "$vmHalt" = true ]]; then
                vagrant halt
        fi
}

destroyVM()
{
	echo "Destroying Machine . . ."
	vagrant destroy -f
	echo "Removing Work folder"
	rm -rf $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName
	echo "==$WORKSPACE/adoptopenjdkPBTests/=="
	ls -la $WORKSPACE/adoptopenjdkPBTests
}

# Takes in OS as arg 1
searchLogFiles()
{
	local OS=$1
	cd $WORKSPACE/adoptopenjdkPBTests/logFiles
	echo
	if grep -q 'failed=[1-9]\|unreachable=[1-9]' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook failed"
		exit 1;
	elif grep -q '\[ERROR\]' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook was stopped"
		exit 1;
	elif grep -q 'failed=0' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook succeeded"
	else
		echo "$OS playbook success is undetermined"
		exit 1;
	fi
	echo
}

# Takes in the URL passed to the script, and extracts the folder name, branch name and builds the gitURL to be used later on.
splitURL()
{
	# IFS stands for Internal Field Seperator and determines the delimiter for splitting.
	IFS='/' read -r -a array <<< "$gitURL"
	if [ ${array[@]: -2:1} == 'tree' ]
	then
		gitURL=""
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
		branchName="master"
	fi
}
# var1 = GitURL, var2 = y/n for VM retention
processArgs $*
checkVars
splitURL
checkVagrantOS
setupFiles
setupGit
echo "Testing on the following OSs: $vagrantOS"
for OS in $vagrantOS
do
	if [[ "$OS" == "Win2012" ]]; then
		startVMPlaybookWin $OS
	else
		startVMPlaybook $OS
	fi
	if [[ "$retainVM" = false ]]
	then
		destroyVM
	fi
done
