#!/bin/bash
set -eu

# If the caller invoked us with bash -x, suppress xtrace immediately.
# The script uses explicit echo statements for meaningful progress; xtrace
# adds thousands of lines of noise (argument parsing, variable assignments,
# [[ comparisons) with no diagnostic value in normal CI runs.
{ set +x; } 2>/dev/null

# Suppress ANSI colour codes from Vagrant output.
export VAGRANT_NO_COLOR=1

gitFork=''
gitBranch=''
buildFork=''
buildBranch=''
vagrantOS=''
retainVM=false
testNativeBuild=false
runTest=false
vmHalt=true
cleanWorkspace=false
newVagrantFiles=false
fastMode=false
useAdopt=false
skipFullSetup=''
jdkToBuild=''
buildHotspot=''
testDocker=false
provider='virtualbox'
scriptPath=$(realpath $0)
verbosity=''

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
			"--fork" | "-f" )
				gitFork="$1"; shift;;
			"--branch" | "-br" )
				gitBranch="$1"; shift;;
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
			"--use-adopt" | "-ua" )
				useAdopt=true;;
			"--build-fork" | "-bf" )
				buildFork="--fork $1"; shift;;
			"--build-branch" | "-bb" )
				buildBranch="--branch $1"; shift;;
			"--build-hotspot" )
				buildHotspot="--hotspot";;
			"--provider" | "-p" )
				provider="$1"; shift;;
			"--test-docker" )
				testDocker=true;;
			"-V" | "-VV" | "-VVV" | "-VVVV" )
				verbosity=$(echo $opt | tr '[:upper:]' '[:lower:]');;
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
  --build-fork | -bf             Specify the fork of openjdk-build to build from (Default: adoptopenjdk)
  --build-branch | -bb           Specify the branch of the fork to build from (Default: master)
  --build-hotspot                Build the JDK with Hotspot (Default: OpenJ9)
  --clean-workspace | -c         Remove the old work folder if detected
  --fork | -f                    Specify the fork of openjdk-infrastructure to run the playbook from (Default: adoptopenjdk)
  --branch | -br                 Specify the branch of the infrastructure fork (Default: master)
  --test | -t                    Runs a quick test on the built JDK
  --no-halt | -nh                Option to stop the vagrant VMs halting
  --new-vagrant-files | -nv      Use vagrantfiles from the the specified git repository
  --skip-more | -sm              Run playbook faster by excluding things not required by buildJDK
  --use-adopt | -ua              Use the local Adoptium vagrantfile instead of the standard (.Adopt extension on Vagrantfile)
  --provider | -p <name>         Select the virtualisation provider: virtualbox (default) or libvirt
  --help | -h                    Displays this help message
  -V                             Apply verbose option to 'ansible-playbook', up to '-VVVV'"
}

checkVars()
{
	if [ "$vagrantOS" == "" ]; then
		usage
		echo "ERROR: No Vagrant OS specified - Use -h for help, -a for all or -v with one of the following:"
		ls -1 ../vagrant/Vagrantfile.* | cut -d. -f4
		exit 1
	fi
	if [[ "$runTest" == true && "$testNativeBuild" == false ]]; then
		echo "Unable to test an unbuilt JDK. Ignoring '--test' argument."
		runTest=false
	fi
	#Sets WORKSPACE to home if WORKSPACE is empty or undefined.
	if [ ! -n "${WORKSPACE:-}" ]; then
		echo "WORKSPACE not found, setting it as environment variable 'HOME'"
		WORKSPACE=$HOME
	fi
	if [ "$gitBranch" == "" ]; then
		echo "No branch specified; Defaulting to 'master'"
		gitBranch="master"
	else # to replace '/' in branch name to '-', avoiding log file name issue
		newGitBranch="${gitBranch////-}"

	fi
	if [ "$gitFork" == "" ]; then
		echo "No Fork specified; Defaulting to 'adoptopenjdk'"
		gitFork="adoptopenjdk"
	fi
	if [[ "$retainVM" == false && "$vmHalt" == false ]]; then
		echo "Must halt the VM to destroy it; Ignoring '--no-halt' option"
		vmHalt=true;
	fi
        if [[ "$provider" == "libvirt" ]]; then
                # vagrant-disksize and vagrant-rsync-back both probe VBoxManage on
                # every 'vagrant up' regardless of provider; remove them if present
                # so they cannot break libvirt runs.
                if vagrant plugin list | grep -q 'disksize'; then
                        echo "Removing vagrant-disksize (incompatible with libvirt) . . ."
                        vagrant plugin uninstall vagrant-disksize
                fi
                if vagrant plugin list | grep -q 'rsync-back'; then
                        echo "Removing vagrant-rsync-back (incompatible with libvirt) . . ."
                        vagrant plugin uninstall vagrant-rsync-back
                fi
        else
                if [[ ! $(vagrant plugin list | grep 'disksize') ]]; then
                        echo "Can't find vagrant-disksize plugin, installing . . ."
                        vagrant plugin install vagrant-disksize
                fi
                if [[ ! $(vagrant plugin list | grep 'rsync-back') ]]; then
                        echo "Can't find vagrant-rsync-back plugin, installing . . ."
                        vagrant plugin install vagrant-rsync-back
                fi
        fi
        if [[ "$provider" == "libvirt" ]]; then
                if [[ ! $(vagrant plugin list | grep 'vagrant-libvirt') ]]; then
                        echo "Can't find vagrant-libvirt plugin, installing . . ."
                        vagrant plugin install vagrant-libvirt
                fi
        fi

				if [[ "$fastMode" == true ]]; then
					skipFullSetup=",nvidia_cuda_toolkit"
					case "$jdkToBuild" in
						"jdk8" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2019"
							fi
							;;
						"jdk11" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2019"
							fi
							;;
						"jdk17" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2017";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2017"
							fi
							;;
						"jdk21" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2017,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2017,MSVS_2019"
							fi
							;;
						"jdk22" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2017,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2017,MSVS_2019"
							fi
							;;
						"jdk25" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2017,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2017,MSVS_2019"
							fi
							;;
						"jdk" )
							skipFullSetup="$skipFullSetup,MSVS_2013,MSVS_2017,MSVS_2019";
							if [ "$buildHotspot" != "" ]; then
								skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1,MSVS_2013,MSVS_2017,MSVS_2019"
							fi
							;;
			                	*)
							skipFullSetup="$skipFullSetup,MSVS_2010,VS2010_SP1";;
					esac
				fi
				jdkToBuild="--version $jdkToBuild"
}

checkVagrantOS()
{
        local vagrantOSList
        if [[ "$newVagrantFiles" = "true" ]]; then
                cd "${WORKSPACE}/adoptopenjdkPBTests/${gitFork}-${newGitBranch}/ansible/vagrant"
        else
                cd ${scriptPath%/*}/../vagrant
        fi

        # Build the OS list filtered to the active provider so --all never mixes providers
        if [[ "$provider" == "libvirt" ]]; then
                vagrantOSList=$(ls -1 Vagrantfile.*.Libvirt 2>/dev/null | sed 's/Vagrantfile\.\(.*\)\.Libvirt/\1/')
        else
                # Default: virtualbox — exclude any suffix-bearing variants (.Libvirt, .Adopt)
                vagrantOSList=$(ls -1 Vagrantfile.* | grep -v '\.Libvirt$' | grep -v '\.Adopt$' | cut -d. -f2)
        fi

        if [[ "$vagrantOS" == "all" ]]; then
                vagrantOS=$vagrantOSList
        elif [[ "$provider" == "libvirt" ]]; then
                if [[ -f "Vagrantfile.${vagrantOS}.Libvirt" ]]; then
                        echo "Vagrantfile Detected (Libvirt)"
                elif [[ -f "Vagrantfile.${vagrantOS}" ]]; then
                        echo "Warning: No Vagrantfile.${vagrantOS}.Libvirt found; falling back to VirtualBox Vagrantfile for ${vagrantOS}"
                        provider='virtualbox'
                else
                        echo "No Vagrantfile for $vagrantOS available - please select from one of the following"
                        echo "$vagrantOSList"
                        exit 1
                fi
        elif [[ -f "Vagrantfile.${vagrantOS}" ]]; then
                echo "Vagrantfile Detected"
        else
                echo "No Vagrantfile for $vagrantOS available - please select from one of the following"
                echo "$vagrantOSList"
                exit 1
        fi

        # The Windows VM is setup to use 5GB of memory, which can be an issue on machines with only 8GB installed.
        # See: https://github.com/adoptium/infrastructure/pull/1532#issue-481189847
        if [[ "$vagrantOS" == "Win2012" && $(free | awk '/Mem:/ { print $2 }') -lt 8000000 ]]; then
                echo "Warning: Windows VM requires 5Gb of free memory to run. On laptops with only 8Gb this can be an issue."
                echo "Reducing the Windows VM memory requirement to 2560Mb."
                sed -i -e "s/5120/2560/g" Vagrantfile.Win2012
        fi
}

setupWorkspace()
{
	local workFolder="$WORKSPACE/adoptopenjdkPBTests"
	local gitDirectory="${workFolder}/${gitFork}-${newGitBranch}"
	mkdir -p "${workFolder}/logFiles"

	local isRepoInfra=$(curl https://api.github.com/repos/$gitFork/infrastructure | grep "Not Found")
	local isRepoOpenjdk=$(curl https://api.github.com/repos/$gitFork/openjdk-infrastructure | grep "Not Found")

	if [[ -z "$isRepoInfra" ]]; then
		gitRepo="https://github.com/${gitFork}/infrastructure"
	elif [[ -z "$isRepoOpenjdk" ]]; then
		gitRepo="https://github.com/${gitFork}/openjdk-infrastructure"
	else
		echo "Repository not found - the fork must be named openjdk-infrastructure or infrastructure"
		exit 1
	fi

	if [[ "$cleanWorkspace" = true && -d "${gitDirectory}" ]]; then
		echo "Cleaning old workspace"
		rm -rf "${gitDirectory}"
	elif [[ "$cleanWorkspace" = true && ! -d "${gitDirectory}" ]]; then
		echo "No old workspace detected, moving on"
	fi

	if [ ! -d "${gitDirectory}" ]; then
		git clone -b "${gitBranch}" --single-branch "${gitRepo}" "${gitDirectory}"
	else
		cd "${gitDirectory}"
		git pull
	fi
}

# Takes the OS as arg 1
startVMPlaybook()
{
	local OS=$1
	local vagrantPORT=""
	local pbLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.log"
	local ssh_args=""

	cd "$WORKSPACE/adoptopenjdkPBTests/${gitFork}-${newGitBranch}/ansible"

	# Select Vagrantfile: append .Libvirt suffix for libvirt provider
	local vagrantfileSuffix=""
	if [[ "$provider" == "libvirt" ]]; then
		vagrantfileSuffix=".Libvirt"
	fi
	if [ "$newVagrantFiles" = "true" ]; then
	  ln -sf vagrant/Vagrantfile.$OS${vagrantfileSuffix} Vagrantfile
	else
	  ln -sf ${scriptPath%/*}/../vagrant/Vagrantfile.$OS${vagrantfileSuffix} Vagrantfile
	fi

	# Copy the machine's ssh key for the VMs to use, after removing prior files
	rm -f id_rsa.pub id_rsa
	ssh-keygen -q -f $PWD/id_rsa -t rsa -N ''

	# Destroy any leftover VM from a previous failed run before bringing up a new one.
	# This prevents "domain name already taken" errors under libvirt.
	# vagrant destroy only works if Vagrant still tracks the VM; for orphaned libvirt
	# domains (e.g. from a failed previous run) fall back to virsh directly.
	vagrant destroy -f 2>/dev/null || true
	if [[ "$provider" == "libvirt" ]]; then
		# vagrant-libvirt names domains as "<user>_<machine_name>". Extract the
		# machine name from the Vagrantfile (the symbol after config.vm.define).
		local machineName
		machineName=$(grep 'vm\.define' Vagrantfile | head -1 | sed 's/.*define[[:space:]]*:\([a-zA-Z0-9_]*\).*/\1/')
		local domainName="${USER}_${machineName}"
		if virsh list --all --name 2>/dev/null | grep -qx "$domainName"; then
			echo "=== Cleaning up orphaned libvirt domain: $domainName"
			virsh destroy "$domainName" 2>/dev/null || true
			virsh undefine "$domainName" --remove-all-storage 2>/dev/null || true
		fi
	fi

	# The BUILD_ID variable is required to stop Jenkins shutting down the wrong VMS
	# See https://github.com/adoptium/infrastructure/issues/1287#issuecomment-625142917
	# Filter [K progress lines — VAGRANT_NO_COLOR strips ANSI colour codes but not
	# progress text.  Two formats appear: vagrant-libvirt volume upload emits
	# "[KProgress: X%" and Vagrant's own box downloader emits "[KProgress: X%
	# (Rate: ...)".  Both start with the ESC-erased "[K" prefix; filtering ^\[K
	# catches both without being overly broad.
	BUILD_ID=dontKillMe vagrant up --provider "$provider" 2>&1 | grep -v '^\[K'

	# libvirt does not support forwarded ports; get SSH host/port from vagrant ssh-config.
	# VirtualBox uses a NAT-forwarded port on 127.0.0.1, so retain the original path.
	local sshHost="127.0.0.1"
	if [[ "$provider" == "libvirt" ]]; then
		local sshPort
		sshHost=$(vagrant ssh-config | awk '/HostName/ { print $2 }')
		sshPort=$(vagrant ssh-config | awk '/Port/ { print $2 }')
		vagrantPORT=$sshPort
		rm -f playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
		echo "[${sshHost}]:${sshPort}" >> playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	else
		vagrantPORT=$(vagrant port | grep host | awk '{ print $4 }')
		rm -f playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
		echo "[127.0.0.1]:${vagrantPORT}" >> playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	fi
	# Remove IP from known_hosts if already found, then pre-seed to avoid interactive prompts.
	# ssh-keygen -R will fail if the known_hosts file does not exist
	[ ! -r $HOME/.ssh/known_hosts ] && touch $HOME/.ssh/known_hosts && chmod 644 $HOME/.ssh/known_hosts
	ssh-keygen -R $(cat playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx)
	ssh-keyscan -p ${vagrantPORT} -H ${sshHost} >> $HOME/.ssh/known_hosts

	sed -i -e "s/.*hosts:.*/  hosts: all/g" playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
	awk '{print}/^\[defaults\]$/{print "private_key_file = id_rsa"; print "remote_tmp = $HOME/.ansible/tmp"; print "timeout = 60"}' < ansible.cfg > ansible.cfg.tmp && mv ansible.cfg.tmp ansible.cfg

	# Initialize the args variable with common arguments
	args="$verbosity -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx -u vagrant -b --skip-tags adoptopenjdk,jenkins${skipFullSetup}"

	## If CentOS6 Delegate Playbook Run To Vagrant Machine Itself For Compatibility
	if [ "$OS" == "CentOS6" ]; then
		# Replace Remote Hosts File With Local Version
		# vagrant ssh --command "cd /vagrant && pwd && echo localhost ansible_connection=local > playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx"
		echo "localhost ansible_connection=local" > playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
		# SSH into machine and run the ansible playbook with the constructed args
		vagrant ssh --command "cd /vagrant && eval ansible-playbook $args playbooks/AdoptOpenJDK_Unix_Playbook/main.yml | tee /vagrant/ansible_playbook.log"
		# Copy The Logfile To The Expected Destination
		cp ansible_playbook.log "$WORKSPACE/adoptopenjdkPBTests/logFiles/$gitFork.$newGitBranch.$OS.log"
		# Return The Temporary Hosts File To Orignal
		echo "[127.0.0.1]:${vagrantPORT}" > playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx
	else
		# Run the ansible playbook with the constructed args
		eval ansible-playbook $args "playbooks/AdoptOpenJDK_Unix_Playbook/main.yml" 2>&1 | tee "$WORKSPACE/adoptopenjdkPBTests/logFiles/$gitFork.$newGitBranch.$OS.log"
	fi

	echo The playbook finished at : `date +%T`
	if ! grep -q 'unreachable=0.*failed=0' $pbLogPath; then
		echo PLAYBOOK FAILED
		exit 1
	fi

	if [ "$OS" == "CentOS6" ]; then
		# Remove IP from known_hosts as the playbook installs an
		# alternate sshd which regenerates the host key infra#2244
		ssh-keygen -R $(cat playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx)
		ssh-keyscan -t rsa -p ${vagrantPORT} -H ${sshHost} > ~/.ssh/known_hosts
		ssh_args="$ssh_args -o PubkeyAcceptedKeyTypes=ssh-rsa -o HostKeyAlgorithms=ssh-rsa"
	fi

	if [[ "$testNativeBuild" = true ]]; then
		local buildLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.build_log"

		ssh -p ${vagrantPORT} $ssh_args -i $PWD/id_rsa vagrant@${sshHost} "cd /vagrant/pbTestScripts && bash buildJDK.sh $buildBranch $buildFork $jdkToBuild $buildHotspot" 2>&1 | tee $buildLogPath
		echo The build finished at : `date +%T`
		if grep -q '] Error' $buildLogPath || grep -q 'configure: error' $buildLogPath; then
			echo BUILD FAILED
			exit 127
		fi

		if [[ "$runTest" = true ]]; then
			local testLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.test_log"
			ssh -p ${vagrantPORT} $ssh_args -i $PWD/id_rsa vagrant@${sshHost} "cd /vagrant/pbTestScripts && bash testJDK.sh" 2>&1 | tee $testLogPath
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
	local pbLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.log"
	local vagrantPort=
	local winrmHost="127.0.0.1"

	cd "$WORKSPACE/adoptopenjdkPBTests/${gitFork}-${newGitBranch}/ansible"

	# Determine the Vagrantfile suffix to use
	# Priority (libvirt):  .Adopt.Libvirt > .Libvirt > virtualbox fallback
	# Priority (vbox):     .Adopt          > default
	local winVagrantfileSuffix=""
	local winProvider="$provider"
	if [[ "$provider" == "libvirt" ]]; then
		local vagrantDir="${scriptPath%/*}/../vagrant"
		if [[ "$newVagrantFiles" = "true" ]]; then
			vagrantDir="vagrant"
		fi
		if [[ "$useAdopt" == "true" ]] && [[ "$OS" == "Win2022" || "$OS" == "Win2025" ]] && [[ -f "${vagrantDir}/Vagrantfile.$OS.Adopt.Libvirt" ]]; then
			echo "Using Adoptium libvirt box for ${OS}"
			winVagrantfileSuffix=".Adopt.Libvirt"
			# The Adopt box ships with a known patch baseline — skip Windows_Updates
			# to avoid the variable 20-40 minute update cycle on every run.
			skipFullSetup="${skipFullSetup},Windows_Updates"
			echo "Skipping Windows_Updates (Adopt box has pre-applied patches)"
		elif [[ "$useAdopt" == "true" ]] && [[ "$OS" == "Win2022" || "$OS" == "Win2025" ]]; then
			echo "Warning: --use-adopt requested but ${vagrantDir}/Vagrantfile.$OS.Adopt.Libvirt not found; falling back to Vagrantfile.$OS.Libvirt"
			winVagrantfileSuffix=".Libvirt"
		elif [[ -f "${vagrantDir}/Vagrantfile.$OS.Libvirt" ]]; then
			winVagrantfileSuffix=".Libvirt"
		else
			echo "Warning: No Vagrantfile.${OS}.Libvirt found; falling back to VirtualBox for ${OS}"
			winProvider="virtualbox"
		fi
	elif [[ "$useAdopt" == "true" ]] && [[ "$OS" == "Win2022" || "$OS" == "Win2025" ]]; then
		echo "Use Adoptium Box For ${OS}"
		winVagrantfileSuffix=".Adopt"
	fi

	if [ "$newVagrantFiles" = "true" ]; then
	  ln -sf vagrant/Vagrantfile.$OS${winVagrantfileSuffix} Vagrantfile
	else
	  ln -sf ${scriptPath%/*}/../vagrant/Vagrantfile.$OS${winVagrantfileSuffix} Vagrantfile
	fi

	# Remove the Hosts files if they're found
	rm -f playbooks/AdoptOpenJDK_Windows_Playbook/hosts.*
	# The BUILD_ID variable is required to stop Jenkins shutting down the wrong VMS
	       # See https://github.com/adoptium/infrastructure/issues/1287#issuecomment-625142917
	# Filter [K progress lines — same as the Unix path above; catches both libvirt
	# volume upload and Vagrant box download progress output.
	BUILD_ID=dontKillMe vagrant up --provider "$winProvider" 2>&1 | grep -v '^\[K'

	# Rearm the evaluation license for 180 days to stop the VMs shutting down
	# See: https://github.com/adoptium/infrastructure/issues/2056
	vagrant winrm --shell cmd -c "slmgr.vbs /rearm //b"
	vagrant reload

	# libvirt uses a real guest IP reachable via the private network; VirtualBox
	# uses NAT-forwarded ports on 127.0.0.1.  vagrant port only reports NAT
	# mappings so it always returns empty under libvirt — use vagrant winrm-config
	# to get the actual host:port for both providers.
	if [[ "$winProvider" == "libvirt" ]]; then
		# vagrant winrm-config outputs:
		#   Host <name>
		#     HostName <ip>
		#     Port <winrm-port>
		#     RDPPort <rdp-port>    <- /Port / would also match this line
		# Use exact field match on HostName and ^[[:space:]]*Port to avoid
		# picking up RDPPort as a second match.
		local winrmConfig
		winrmConfig=$(vagrant winrm-config 2>/dev/null)
		winrmHost=$(echo "$winrmConfig" | awk '/^[[:space:]]*HostName / { print $2 }')
		vagrantPort=$(echo "$winrmConfig" | awk '/^[[:space:]]*Port / { print $2 }')
	else
		# 5986 refers to the winrm_ssl port on the guest
		# See: https://github.com/adoptium/infrastructure/issues/1504#issuecomment-672930832
		vagrantPort=$(vagrant port | awk '/5986/ { print $4 }')
	fi
	echo "[${winrmHost}]:${vagrantPort}" >> playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win
	echo "This is the content of hosts.win : " && cat playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win

	# Changes the value of "hosts" in main.yml
	sed -i'' -e "s/.*hosts:.*/  hosts: all/g" playbooks/AdoptOpenJDK_Windows_Playbook/main.yml
	# Uncomments and sets the ansible_password to 'vagrant', in adoptopenjdk_variables.yml
	sed -i'' -e "s/.*ansible_password.*/ansible_password: vagrant/g" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	# If "credssp" isn't found in adoptopenjdk_variables.yml
	if ! grep -q "credssp" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml;
	then
		# Add the "ansible_winrm_transport" to adoptopenjdk_variables.yml
		echo -e "\nansible_winrm_transport: credssp" >> playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi
	# Under libvirt the VM is accessed on port 5985 (plain HTTP WinRM) rather than
	# the SSL 5986 used on VirtualBox NAT.  Override ansible_port to match.
	if [[ "$winProvider" == "libvirt" ]]; then
		sed -i'' -e "s/^ansible_port:.*/ansible_port: ${vagrantPort}/" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi
	# Large downloads and win_unzip on slow VMs can take 30+ minutes; 600s/630s is too short.
	# Use sed to replace existing entries (avoids duplicates across re-runs), then append if absent.
	if grep -q "ansible_winrm_operation_timeout_sec" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml; then
		sed -i'' -e "s/^ansible_winrm_operation_timeout_sec:.*/ansible_winrm_operation_timeout_sec: 3600/" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	else
		echo "ansible_winrm_operation_timeout_sec: 3600" >> playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi
	if grep -q "ansible_winrm_read_timeout_sec" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml; then
		sed -i'' -e "s/^ansible_winrm_read_timeout_sec:.*/ansible_winrm_read_timeout_sec: 3630/" playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	else
		echo "ansible_winrm_read_timeout_sec: 3630" >> playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml
	fi

	gitSha=$(git rev-parse HEAD)

	# Run the ansible playbook on the VM & logs the output.
	ansible-playbook $verbosity -i playbooks/AdoptOpenJDK_Windows_Playbook/hosts.win -u vagrant --extra-vars "git_sha=${gitSha}" --skip-tags jenkins,adoptopenjdk${skipFullSetup} playbooks/AdoptOpenJDK_Windows_Playbook/main.yml 2>&1 | tee $pbLogPath
	echo The playbook finished at : `date +%T`
	if ! grep -q 'unreachable=0.*failed=0' $pbLogPath; then
		echo PLAYBOOK FAILED
		exit 1
	fi

	if [[ "$testNativeBuild" = true ]]; then
		local buildLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.build_log"

		# Restarting the VM as the shared folder disappears after the playbook runs due to the restarts in the playbook
		vagrant halt && vagrant up 2>&1 | grep -v '^\[K'

		# Restarting the VM may change the port number; re-read from winrm-config for libvirt
		if [[ "$winProvider" == "libvirt" ]]; then
			local winrmConfig
			winrmConfig=$(vagrant winrm-config 2>/dev/null)
			winrmHost=$(echo "$winrmConfig" | awk '/^[[:space:]]*HostName / { print $2 }')
			vagrantPort=$(echo "$winrmConfig" | awk '/^[[:space:]]*Port / { print $2 }')
		else
			vagrantPort=$(vagrant port | awk '/5985/ { print $4 }')
		fi

		# Run a python script to start the build on the Windows VM to give live stdout/stderr
		# See: https://github.com/adoptium/infrastructure/issues/1296
		## This Needs Amendments To Work With Python 3, so check the current version of python, and run the appropriate script

		# Check the Python version
		PYTHON_VERSION=$(python -V 2>&1)

		echo "Starting Build"
		if [[ $PYTHON_VERSION == *"Python 2."* ]]; then
		    echo "Python 2 detected"
		    python pbTestScripts/startScriptWin.py -i "127.0.0.1:$vagrantPort" -a "$buildFork $buildBranch $jdkToBuild $buildHotspot" -b 2>&1 | tee $buildLogPath
		elif [[ $PYTHON_VERSION == *"Python 3."* ]]; then
		    echo "Python 3 detected"
			if [[ "$winProvider" == "libvirt" ]]; then
				# No synced_folder under libvirt — C:\vagrant\ does not exist on the guest.
				# Upload files to the guest by Base64-encoding them on the host and decoding
				# on the guest via PowerShell — this safely handles all special characters.
				winUploadFile() {
					local src="$1" dst="$2"
					local b64
					# Suppress xtrace for the base64 capture and the winrm upload call —
					# both contain the full encoded file content and flood the Jenkins log.
					{ set +x; } 2>/dev/null
					b64=$(base64 -w0 < "$src")
					vagrant winrm -s powershell -e -c "[System.IO.File]::WriteAllBytes('${dst}', [System.Convert]::FromBase64String('${b64}'))"
					{ set -x; } 2>/dev/null
					echo "=== Uploaded: $src -> $dst"
				}
				vagrant winrm -s powershell -e -c 'New-Item -ItemType Directory -Force -Path C:\tmp\pbTestScripts | Out-Null'
				for f in pbTestScripts/*; do
					winUploadFile "$f" "C:\\tmp\\${f//\//\\}"
				done
				# Write the build launcher .ps1 directly on the guest
				if [ "$buildHotspot" != "" ]; then
					printf 'Set-Location -Path "C:/tmp"\n& sh "C:/tmp/pbTestScripts/buildJDKWin.sh" %s %s %s --hotspot\n' \
						"$buildFork" "$buildBranch" "$jdkToBuild" > BuildJDK_Tmp.ps1
				else
					printf 'Set-Location -Path "C:/tmp"\n& sh "C:/tmp/pbTestScripts/buildJDKWin.sh" %s %s %s\n' \
						"$buildFork" "$buildBranch" "$jdkToBuild" > BuildJDK_Tmp.ps1
				fi
				winUploadFile BuildJDK_Tmp.ps1 'C:\tmp\BuildJDK_Tmp.ps1'
				vagrant winrm -e -c 'powershell -ExecutionPolicy Bypass -File c:/tmp/BuildJDK_Tmp.ps1' | tee $buildLogPath
			else
				# Create Powershell Script To Launch Build
				echo "Set-Location -Path \"C:/tmp\"" > BuildJDK_Tmp.ps1
				if [ "$buildHotspot" != "" ]; then
					echo "& sh \"C:/vagrant/pbTestScripts/buildJDKWin.sh\" $buildFork $buildBranch $jdkToBuild --hotspot" >> BuildJDK_Tmp.ps1
				else
					echo "& sh \"C:/vagrant/pbTestScripts/buildJDKWin.sh\" $buildFork $buildBranch $jdkToBuild" >> BuildJDK_Tmp.ps1
				fi
				# Copy PowerShell Script From Vagrant Share For Performance Reasons & Launch
				vagrant winrm -s powershell -e -c 'copy c:/vagrant/BuildJDK_Tmp.ps1 c:/tmp; cd c:/tmp; pwd; ls'
				vagrant winrm -e -c 'powershell -ExecutionPolicy Bypass -File c:/tmp/BuildJDK_Tmp.ps1' | tee $buildLogPath
			fi
		else
		    echo "Python is not installed or is of an unsupported version."
			exit 99
		fi

		echo The build finished at : `date +%T`
		if grep -q '] Error' $buildLogPath || grep -q 'configure: error' $buildLogPath; then
			echo BUILD FAILED
			exit 127
		fi

		echo "Starting Tests.."
		if [[ "$runTest" = true ]]; then
			local testLogPath="$WORKSPACE/adoptopenjdkPBTests/logFiles/${gitFork}.${newGitBranch}.$OS.test_log"
			# Run a python script to start a test for the built JDK on the Windows VM
			if [[ $PYTHON_VERSION == *"Python 2."* ]]; then
					echo "Python 2 detected"
					python pbTestScripts/startScriptWin.py -i "127.0.0.1:$vagrantPort" -a "$jdkToBuild" -t 2>&1 | tee $testLogPath
			elif [[ $PYTHON_VERSION == *"Python 3."* ]]; then
					echo "Python 3 detected"
				if [[ "$winProvider" == "libvirt" ]]; then
					# No synced_folder under libvirt — write test launcher directly on the guest
					printf 'Set-Location -Path "C:/tmp"\n& sh "C:/tmp/pbTestScripts/testJDKWin.sh"\n' \
						> testJDK_Tmp.ps1
					winUploadFile testJDK_Tmp.ps1 'C:\tmp\testJDK_Tmp.ps1'
					vagrant winrm -e -c 'powershell -ExecutionPolicy Bypass -File c:/tmp/testJDK_Tmp.ps1' | tee $testLogPath
				else
					# Create Powershell Script To Launch Test
					echo "Set-Location -Path \"C:/tmp\"" > testJDK_Tmp.ps1
					echo "& sh \"C:/vagrant/pbTestScripts/testJDKWin.sh\" $jdkToBuild" >> testJDK_Tmp.ps1
					vagrant winrm -s powershell -e -c 'copy c:/vagrant/testJDK_Tmp.ps1 c:/tmp; cd c:/tmp; pwd; ls'
					vagrant winrm -e -c 'powershell -ExecutionPolicy Bypass -File c:/tmp/testJDK_Tmp.ps1' | tee $testLogPath
				fi
			else
					echo "Python is not installed or is of an unsupported version."
					exit 99
			fi

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
	if [[ "$retainVM" == false ]]; then
		for OS in $vagrantOS
		do
			echo "Destroying the $OS Machine"
			echo === `date +%T`: showing global status before pruning:
			vagrant global-status
			free
			echo === showing global status while pruning:
			vagrant global-status --prune
			echo === Determining VM to destroy:
			VM_TO_DESTROY=`vagrant global-status --prune | awk "/${gitFork}-${newGitBranch}/ { print \\$1 }"`
			if [ ! -z "$VM_TO_DESTROY" ]; then
				echo === Destroying VM with id $VM_TO_DESTROY
				vagrant destroy -f $VM_TO_DESTROY
			else
				echo === NOT DESTROYING ANY VM as no suitable ID was found searching for ${gitFork}-${newGitBranch}
			fi
			echo === Final status:
			vagrant global-status --prune
			free
			if [[ "$provider" == "libvirt" ]]; then
				cleanupLibvirtVolumes "$OS"
			fi
		done
	else
		echo "You have chosen to retain the VM. It will not be destroyed"
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
	# Derive the box name from the Vagrantfile for this OS
	local vagrantfileDir
	if [[ "$newVagrantFiles" == "true" ]]; then
		vagrantfileDir="${WORKSPACE}/adoptopenjdkPBTests/${gitFork}-${newGitBranch}/ansible/vagrant"
	else
		vagrantfileDir="${scriptPath%/*}/../vagrant"
	fi
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

trap 'destroyVM' EXIT

processArgs $*
checkVars
setupWorkspace
checkVagrantOS

echo "Testing on the following OSs: $vagrantOS"
for OS in $vagrantOS
do
	echo OS = $vagrantOS
	echo "OS : $OS"

	if [[ "$OS" == "Win2012" || "$OS" == "Win2022" || "$OS" == "Win2025" || "$OS" == "Windows2022.Core" ]]; then
		startVMPlaybookWin "$OS"
	else
		startVMPlaybook "$OS"
	fi
	if [[ "$vmHalt" == true ]]; then
		if [[ "$OS" == "Win2012" || "$OS" == "Win2022" || "$OS" == "Win2025" || "$OS" == "Windows2022.Core" ]]; then
			# Windows VMs are destroyed immediately after; halting here would cut off
			# a running test before it completes. destroyVM handles cleanup.
			echo "Skipping halt for Windows VM (destroy will follow immediately)"
		else
			vagrant halt
		fi
	fi
done
destroyVM
