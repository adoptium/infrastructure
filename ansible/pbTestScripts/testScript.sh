#/bin/bash
set -eu

branchName=''
folderName=''
gitURL=''
vagrantOS=''
retainVM=false
testNativeBuild=false
runTest=false

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
					--retainVM | -r				Option to retain the VM once building them
					--build | -b				Option to enable testing a native build on the VM
					--URL | -u <GitURL>			The URL of the git repository
                                        --test | -t                             Runs a quick test on the built JDK
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
	if [ "$branchName" == "" ]; then
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
	if [ "$branchName" == "" ]; then
		cd $WORKSPACE/adoptopenjdkPBTests/$folderName-master/ansible
		branchName="master"
	else
		cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	fi
	ln -sf Vagrantfile.$OS Vagrantfile
	vagrant up
	# Remotely moves to the correct directory in the VM and builds the playbook. Then logs the VM's output to a file, in a separate directory
	vagrant ssh -c "cd /vagrant/playbooks/AdoptOpenJDK_Unix_Playbook && sudo ansible-playbook --skip-tags adoptopenjdk,jenkins main.yml" 2>&1 | tee $WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
	if [[ "$testNativeBuild" = true ]]; then
		testBuild
		if [[ "$runTest" = true ]]; then
        	        vagrant ssh -c "cd /vagrant/pbTestScripts && ./testJDK.sh"
	        fi
	fi
	vagrant halt
}

startVMPlaybookWin()
{
	local OS=$1
	# The number of bytes the disk should be (this is 95GB in bytes)
	local diskSizeBoundary=102005473280;
	if [ "$branchName" == "" ]; then
		cd $WORKSPACE/adoptopenjdkPBTests/$folderName-master/ansible
		branchName="master"
	else
		cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	fi
	ln -sf Vagrantfile.$OS Vagrantfile
	vagrant up
	# Changes the value of "hosts" in main.yml
	sed -i'' -e "s/.*hosts:.*/- hosts: all/g" playbooks/AdoptOpenJDK_Windows_Playbook/main.yml
	# Uncomments and sets the ansible_password to 'vagrant', in adoptopenjdk_variables.yml
	sed -i'' -e "s/.*ansible_password.*/ansible_password: vagrant/g" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	# if "credssp" isn't found in adoptopenjdk_variables.yml
	if ! grep -q "credssp" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml;
	then
		# Add the "ansible_winrm_transport" to adoptopenjdk_variables.yml
		echo -e "\nansible_winrm_transport: credssp" >> playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi
	# getting the current c drive information and cutting it down to the number of GB it is.
	export currentDiskSize=$(vagrant powershell -c "Start-Process powershell -Verb runAs; Get-Partition -Driveletter c | select Size" | grep '[0-9]{5,}')
	if [[ $currentDiskSize -lt $diskSizeBoundary ]]; then
		echo "Resizing C Drive"
		vagrant powershell -c "Start-Process powershell -Verb runAs; \$size = (Get-PartitionSupportedSize -DriveLetter c); Resize-Partition -DriveLetter c -Size \$size.SizeMax"
	fi
	# run the ansible playbook on the VM & logs the output.
	ansible-playbook -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant --skip-tags jenkins,adoptopenjdk playbooks/AdoptOpenJDK_Windows_Playbook/main.yml 2>&1 | tee $WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
}

destroyVM()
{
	echo "Destroying Machine . . ."
	echo
	vagrant destroy -f
}

# Takes in OS as arg 1, branchName as arg 2
searchLogFiles()
{
	local OS=$1
	cd $WORKSPACE/adoptopenjdkPBTests/logFiles
	echo
	if grep -q 'failed=[1-9]' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook failed"
	elif grep -q '\[ERROR\]' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook was stopped"
	elif grep -q 'failed=0' *$folderName.$branchName.$OS.log
	then
		echo "$OS playbook succeeded"
	else
		echo "$OS playbook success is undetermined"
	fi
	echo
}

# Takes in the URL passed to the script, and extracts the folder name, branch name and builds the gitURL to be used later on.
splitURL()
{
	#IFS stands for Internal Field Seperator and determines the delimiter for splitting.
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
for OS in $vagrantOS
do
	searchLogFiles $OS
done
