#!/bin/bash
set -eu

branchName=''
folderName=''
gitURL=''
buildURL=''
vagrantOS=''
retainVM=false
testNativeBuild=false
runTest=false
vmHalt=true
cleanWorkspace=false
newVagrantFiles=false
fastMode=false
skipFullSetup=''
jdkToBuild=''
buildHotspot=''
testDocker=false

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
			"--JDK-Version" | "-jdk" )
				jdkToBuild="$1"; shift;;
			"--retainVM" | "-r" )
				retainVM=true;;
			"--URL" | "-u" )
				gitURL="$1"; shift;;
			"--test" | "-t" )
				runTest=true;;
			"--no-halt" | "-nh" )
				vmHalt=false;;
			"--clean-workspace" | "-c" )
				cleanWorkspace=true;;
			"--new-vagrant-files" | "-nv" )
				newVagrantFiles=true;;
			"--skip-more" | "-sm" )
				fastMode=true;;
			"--build-repo" | "-br" )
				buildURL="--URL $1"; shift;;
			"--build-hotspot" )
				buildHotspot="--hotspot";;
			"--test-docker" )
				testDocker=true;;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognised."; usage; exit 1;;
		esac
	done
}

usage()
{
	echo "Usage: ./vagrantPlaybookCheck.sh [options] (-a|-v <OS>)
  --vagrantfile | -v <OS>        Specifies which OS/distribution to test
  --all | -a                     Builds and tests playbook through every OS
  --retainVM | -r                Option to retain the VM and folder after completion
  --build | -b                   Option to enable testing a native build on the VM
  --JDK-Version | -jdk <Version> Specify which JDK to build, if build is specified
  --build-repo | -br <GitURL>    Specify the openjdk-build repo to build with
  --build-hotspot                Build the JDK with Hotspot (Default is OpenJ9)
  --clean-workspace | -c         Remove the old work folder if detected
  --URL | -u <GitURL>            The URL of the git repository
  --test | -t                    Runs a quick test on the built JDK
  --no-halt | -n                 Option to stop the vagrant VMs halting
  --new-vagrant-files | -nv      Use vagrantfiles from the the specified git repository
  --skip-more | -sm              Run playbook faster by excluding things not required by buildJDK
  --help | -h                    Displays this help message"
}

checkVars()
{
	if [ "$vagrantOS" == "" ]; then
                usage
		echo "ERROR: No Vagrant OS specified - Use -h for help, -a for all or -v with one of the following:"
		ls -1 ../Vagrantfile.* | cut -d. -f4
                exit 1
	fi
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
	if [[ "$retainVM" == false && "$vmHalt" == false ]]; then
		echo "Must halt the VM to destroy it; Ignoring '--no-halt' option"
		vmHalt=true;
	fi
        if [[ ! $(vagrant plugin list | grep 'disksize') ]]; then
                echo "Can't find vagrant-disksize plugin, installing . . ."
                vagrant plugin install vagrant-disksize
        fi
        if [[ ! $(vagrant plugin list | grep 'rsync-back') ]]; then
                echo "Can't find vagrant-rsync-back plugin, installing . . ."
                vagrant plugin install vagrant-rsync-back
        fi
	if [[ "$fastMode" == true ]]; then
		skipFullSetup=",nvidia_cuda_toolkit"
		case "$jdkToBuild" in
			"jdk8" )
				skipFullSetup="$skipFullSetup,MSVS_2017";
				if [ "$buildHotspot" != "" ]; then
					skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1"
				fi
				;;
                	*)
				skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013";;
		esac
	fi
	jdkToBuild="--version $jdkToBuild"
}

checkVagrantOS()
{
        local vagrantOSList
        if [[ "$newVagrantFiles" = "true" ]]; then
                cd ${WORKSPACE}/adoptopenjdkPBTests/${folderName}-${branchName}/ansible
        else    
                cd $WORKSPACE/ansible/
        fi
        vagrantOSList=$(ls -1 Vagrantfile.* | cut -d. -f 2)
        if [[ -f "Vagrantfile.${vagrantOS}" ]]; then
                echo "Vagrantfile Detected"
        elif [[ "$vagrantOS" == "all" ]]; then
                vagrantOS=$vagrantOSList
        else    
                echo "No Vagrantfile for $vagrantOS available - please select from one of the following"
                echo $vagrantOSList
                exit 1
        fi
        # The Windows VM is setup to use 5GB of memory, which can be an issue on machines with only 8GB installed.
        # See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/pull/1532#issue-481189847
        if [[ "$vagrantOS" == "Win2012" && $(free | awk '/Mem:/ { print $2 }') -lt 8000000 ]]; then
                echo "Warning: Windows VM requires 5Gb of free memory to run. On laptops with only 8Gb this can be an issue."
                echo "Reducing the Windows VM memory requirement to 2560Mb."
                sed -i -e "s/5120/2560/g" Vagrantfile.Win2012
        fi
}

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

setupWorkspace()
{
	local workFolder=$WORKSPACE/adoptopenjdkPBTests
	mkdir -p ${workFolder}/logFiles

	if [[ "$cleanWorkspace" = true && -d ${workFolder}/${folderName}-${branchName} ]]; then
		echo "Cleaning old workspace"
		rm -rf ${workFolder}/${folderName}-${branchName}
	elif [[ "$cleanWorkspace" = true && ! -d $workFolder/${folderName}-${branchName} ]]; then
		echo "No old workspace detected, moving on"
	fi

        if [ "$branchName" == "master" ]; then
                echo "Detected as the master branch"
                if [ ! -d "${workFolder}/${folderName}-master" ]; then
                        git clone $gitURL ${workFolder}/${folderName}-master
                else
                        cd ${workFolder}/${folderName}-master
                        git pull
                fi
        else
                echo "Branch detected"
                if [ ! -d "${workFolder}/${folderName}-${branchName}" ]; then
                        git clone -b $branchName --single-branch $gitURL ${workFolder}/${folderName}-${branchName}
                else
                        cd ${workFolder}/${folderName}-${branchName}
                        git pull
                fi
        fi

}

# Takes the OS as arg 1
startVMPlaybook()
{
	local OS=$1
	local vagrantPORT=""
	local pbLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log"

	cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	if [ "$newVagrantFiles" = "true" ]; then
	  ln -sf Vagrantfile.$OS Vagrantfile
	else
	  ln -sf $WORKSPACE/ansible/Vagrantfile.$OS Vagrantfile
	fi
	# Copy the machine's ssh key for the VMs to use, after removing prior files
	rm -f id_rsa.pub id_rsa
	ssh-keygen -q -f $PWD/id_rsa -t rsa -N ''
	# The BUILD_ID variable is required to stop Jenkins shutting down the wrong VMS 
	# See https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1287#issuecomment-625142917
	BUILD_ID=dontKillMe vagrant up
	vagrantPORT=$(vagrant port | grep host | awk '{ print $4 }')

	rm -f playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	echo "[127.0.0.1]:${vagrantPORT}" >> playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	# Remove IP from known_hosts if already found
	# ssh-keygen -R will fail if the known_hosts file does not exist
	[ ! -r $HOME/.ssh/known_hosts ] && touch $HOME/.ssh/known_hosts && chmod 644 $HOME/.ssh/known_hosts
	ssh-keygen -R $(cat playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx)
	
	sed -i -e "s/.*hosts:.*/- hosts: all/g" playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
	awk '{print}/^\[defaults\]$/{print "private_key_file = id_rsa"; print "timeout = 30"}' < ansible.cfg > ansible.cfg.tmp && mv ansible.cfg.tmp ansible.cfg
	
	ansible-playbook -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx -u vagrant -b --skip-tags adoptopenjdk,jenkins${skipFullSetup} playbooks/AdoptOpenJDK_Unix_Playbook/main.yml 2>&1 | tee $WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log
	echo The playbook finished at : `date +%T`
	if ! grep -q 'unreachable=0.*failed=0' $pbLogPath; then
		echo PLAYBOOK FAILED 
		exit 1
	fi

	if [[ "$testNativeBuild" = true ]]; then
		local buildLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.build_log"
		ssh -p ${vagrantPORT} -i $PWD/id_rsa vagrant@127.0.0.1 "cd /vagrant/pbTestScripts && ./buildJDK.sh $buildURL $jdkToBuild $buildHotspot" 2>&1 | tee $buildLogPath
		echo The build finished at : `date +%T`
		if grep -q '] Error' $buildLogPath || grep -q 'configure: error' $buildLogPath; then
			echo BUILD FAILED
			exit 127
		fi

		if [[ "$runTest" = true ]]; then
			local testLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.test_log"
			ssh -p ${vagrantPORT} -i $PWD/id_rsa vagrant@127.0.0.1 "cd /vagrant/pbTestScripts && ./testJDK.sh" 2>&1 | tee $testLogPath
			echo The test finished at : `date +%T`
			if ! grep -q 'FAILED: 0' $testLogPath; then
				echo TEST FAILED
				exit 127
			fi
		fi
	fi

        if [[ "$testDocker" == "true" ]]; then
        	if [ "$OS" == "FreeBSD12" -o "$OS" == "CentOS8" -o "$OS" == "CentOS6" ]; then
        		echo Skipping docker test as we do not set it up on $OS
        	else
#			if ! ssh -p ${vagrantPORT} -i $PWD/id_rsa vagrant@127.0.0.1 /usr/sbin/service docker status; then
#				echo WARNING: Docker service was not started on the VM ... Attempting to start
#	        		ssh -p ${vagrantPORT} -i $PWD/id_rsa vagrant@127.0.0.1 /usr/sbin/service docker start
#	        	fi
        		ssh -p ${vagrantPORT} -i $PWD/id_rsa vagrant@127.0.0.1 sudo docker run alpine /bin/echo Hello World from inside docker
			echo The docker validation finished at : `date +%T`
		fi
	fi
}

startVMPlaybookWin()
{
	local OS=$1
	local pbLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.log"
	local vagrantPort=

	cd $WORKSPACE/adoptopenjdkPBTests/$folderName-$branchName/ansible
	if [ "$newVagrantFiles" = "true" ]; then
	  ln -sf Vagrantfile.$OS Vagrantfile
	else
	  ln -sf $WORKSPACE/ansible/Vagrantfile.$OS Vagrantfile
	fi

	# Remove the Hosts files if they're found
	rm -f playbooks/AdoptOpenJDK_Windows_Playbook/hosts.*
	# The BUILD_ID variable is required to stop Jenkins shutting down the wrong VMS
        # See https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1287#issuecomment-625142917
	BUILD_ID=dontKillMe vagrant up
	
	# 5986 refers to the winrm_ssl port on the guest
	# See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1504#issuecomment-672930832
	vagrantPort=$(vagrant port |  awk '/5986/ { print $4 }')
	echo "[127.0.0.1]:$vagrantPort" >> playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win
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
	ansible-playbook -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant --skip-tags jenkins,adoptopenjdk${skipFullSetup} playbooks/AdoptOpenJDK_Windows_Playbook/main.yml 2>&1 | tee $pbLogPath
	echo The playbook finished at : `date +%T`
	if ! grep -q 'unreachable=0.*failed=0' $pbLogPath; then
		echo PLAYBOOK FAILED 
		exit 1
	fi
        
	if [[ "$testNativeBuild" = true ]]; then
		local buildLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.build_log"

		# Restarting the VM as the shared folder disappears after the playbook runs due to the restarts in the playbook
		vagrant halt && vagrant up

		# Restaring the VM may change the port Number
                vagrantPort=$(vagrant port |  awk '/5986/ { print $4 }')
                # The port used by startScriptWin.sh must be the winRM port, not the winRM_ssl port
                # See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1504#issuecomment-673329953
                local winRMPort=$(( vagrantPort -1 ))

		# Run a python script to start the build on the Windows VM to give live stdout/stderr
		# See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1296
		python pbTestScripts/startScriptWin.py -i "127.0.0.1:$winRMPort" -a "$buildURL $jdkToBuild $buildHotspot" -b 2>&1 | tee $buildLogPath
		echo The build finished at : `date +%T`
		if grep -q '] Error' $buildLogPath || grep -q 'configure: error' $buildLogPath; then
			echo BUILD FAILED
			exit 127
		fi
	
		if [[ "$runTest" = true ]]; then
			local testLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/$folderName.$branchName.$OS.test_log"
			
			# Run a python script to start a test for the built JDK on the Windows VM
			python pbTestScripts/startScriptWin.py -i "127.0.0.1:$winRMPort" -t 2>&1 | tee $testLogPath
			echo The test finished at : `date +%T`
			if ! grep -q 'FAILED: 0' $testLogPath; then 
				echo TEST FAILED
				exit 127
			fi
		fi
	fi
}

destroyVM()
{
	local OS=$1
	echo "Destroying the $OS Machine"
	echo === `date +%T`: showing global status before pruning:
	vagrant global-status
	free
	echo === showing global status while pruning:
	vagrant global-status --prune
	echo === Determining VM to destroy:
	VM_TO_DESTROY=`vagrant global-status --prune | grep $OS | awk "/${folderName}-${branchName}/ { print \\$1 }"`
	if [ ! -z "$VM_TO_DESTROY" ]; then
	  echo === Destroying VM with id $VM_TO_DESTROY
	  vagrant destroy -f $VM_TO_DESTROY
	else
	  echo === NOT DESTROYING ANY VM as no suitable ID was found searching for $OS and ${folderName}-${branchName}
	fi
        echo === Final status:
        vagrant global-status --prune
        free
}

processArgs $*
checkVars
splitURL
setupWorkspace
checkVagrantOS

echo "Testing on the following OSs: $vagrantOS"
for OS in $vagrantOS
do
	if [[ "$OS" == "Win2012" ]]; then
		startVMPlaybookWin $OS
	else
		startVMPlaybook $OS
	fi
  	if [[ "$vmHalt" == true ]]; then
                vagrant halt 
	fi
	if [[ "$retainVM" == false ]]; then
		destroyVM $OS
	fi
done
