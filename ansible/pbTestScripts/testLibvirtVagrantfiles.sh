#!/bin/bash
# testLibvirtVagrantfiles.sh
#
# Local smoke-test script for Libvirt Vagrantfiles.
# Validates that each Vagrantfile.*.Libvirt can boot a VM and optionally run the
# Unix Ansible playbook against it. Build and JDK test phases are not performed.
#
# Prerequisites: vagrant and vagrant-libvirt must be installed on the host.
# Usage: ./testLibvirtVagrantfiles.sh [-v <OS>|-a] [--playbook] [--retain] [-V...]

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$0")")
REPO_ANSIBLE_DIR=$(realpath "${SCRIPT_DIR}/..")
VAGRANT_DIR="${REPO_ANSIBLE_DIR}/vagrant"

vagrantOS=''
runPlaybook=false
retainVM=false
verbosity=''

# Windows Libvirt OSs: skipped entirely — WinRM communicator requires the winrm-elevated
# gem which conflicts with rubyzip 3.x on Vagrant 2.3.x system installations.
# These Vagrantfiles are valid but can only be tested on a host where the gem conflict
# is resolved (e.g. a newer Vagrant version with bundled gems).
WINDOWS_LIBVIRT_OSS="Win2022 Win2025"

processArgs() {
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]]; do
		local opt="$1"
		shift
		case "$opt" in
			"--vagrantfile" | "-v" )
				vagrantOS="$1"; shift;;
			"--all" | "-a" )
				vagrantOS="all";;
			"--playbook" | "-p" )
				runPlaybook=true;;
			"--retain" | "-r" )
				retainVM=true;;
			"-V" | "-VV" | "-VVV" | "-VVVV" )
				verbosity=$(echo "$opt" | tr '[:upper:]' '[:lower:]');;
			"--help" | "-h" )
				usage; exit 0;;
			*) echo >&2 "Invalid option: ${opt}"; usage; exit 1;;
		esac
	done
}

usage() {
	echo "Usage: ./testLibvirtVagrantfiles.sh (-v <OS> | -a) [options]

  --vagrantfile | -v <OS>   Test a single OS (e.g. Ubuntu2004)
  --all         | -a        Test all OSs that have a Vagrantfile.*.Libvirt
  --playbook    | -p        After booting, also run the Ansible Unix playbook
                            (skipped for CentOS6 and Windows Libvirt OSs)
  --retain      | -r        Keep the VM running after a successful test
  --help        | -h        Show this help message
  -V / -VV / -VVV / -VVVV  Ansible playbook verbosity (only used with --playbook)

Examples:
  ./testLibvirtVagrantfiles.sh -v Ubuntu2004
  ./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook
  ./testLibvirtVagrantfiles.sh -a --playbook
  ./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook --retain"
}

checkDeps() {
	if ! command -v vagrant &>/dev/null; then
		echo "ERROR: vagrant is not on PATH. Please install Vagrant before running this script."
		exit 1
	fi
	if ! vagrant plugin list 2>/dev/null | grep -q 'vagrant-libvirt'; then
		echo "ERROR: vagrant-libvirt plugin is not installed."
		echo "       Install it with: vagrant plugin install vagrant-libvirt"
		exit 1
	fi
	# vagrant-libvirt must connect to the system libvirt context to access
	# persistent networks (vagrant-private-dhcp). The session context (the
	# default on many distros) does not have access to them.
	if [[ "${LIBVIRT_DEFAULT_URI:-}" != "qemu:///system" ]]; then
		echo "WARNING: LIBVIRT_DEFAULT_URI is not set to 'qemu:///system'."
		echo "         vagrant-libvirt requires the system context to manage networks."
		echo "         Setting LIBVIRT_DEFAULT_URI=qemu:///system for this run."
		echo "         To make this permanent: export LIBVIRT_DEFAULT_URI=qemu:///system"
		export LIBVIRT_DEFAULT_URI=qemu:///system
	fi
}

discoverOSList() {
	local list
	list=$(ls -1 "${VAGRANT_DIR}"/Vagrantfile.*.Libvirt 2>/dev/null \
		| sed 's|.*/Vagrantfile\.\(.*\)\.Libvirt|\1|')
	if [[ -z "$list" ]]; then
		echo "ERROR: No Vagrantfile.*.Libvirt files found in ${VAGRANT_DIR}"
		exit 1
	fi
	echo "$list"
}

isWindowsOS() {
	local os="$1"
	for winOS in $WINDOWS_LIBVIRT_OSS; do
		[[ "$os" == "$winOS" ]] && return 0
	done
	return 1
}

# testOS <OS> — runs boot test and optionally playbook test for one OS.
# Writes results into the associative arrays boot_results and playbook_results.
testOS() {
	local OS="$1"
	local workDir="${WORKSPACE}/libvirtTests/${OS}"
	local logDir="${WORKSPACE}/libvirtTests/logFiles"
	local logPath="${logDir}/${OS}.log"

	echo ""
	echo "============================================================"
	echo " Testing: ${OS}"
	echo "============================================================"

	mkdir -p "${workDir}" "${logDir}"

	# ----------------------------------------------------------------
	# Copy repo ansible artefacts into the per-OS working directory so
	# that in-place patching of main.yml / ansible.cfg does not dirty
	# the real checkout.
	# roles/ lives inside playbooks/AdoptOpenJDK_Unix_Playbook/ and is
	# picked up automatically by ansible-playbook from the playbook dir.
	# ----------------------------------------------------------------
	rm -rf "${workDir}/playbooks" "${workDir}/plugins" "${workDir}/ansible.cfg" "${workDir}/.vagrant"
	cp -r "${REPO_ANSIBLE_DIR}/playbooks" "${workDir}/playbooks"
	cp -r "${REPO_ANSIBLE_DIR}/plugins"   "${workDir}/plugins"
	cp    "${REPO_ANSIBLE_DIR}/ansible.cfg" "${workDir}/ansible.cfg"

	# ----------------------------------------------------------------
	# Generate SSH keypair BEFORE vagrant up so the provisioning
	# $script can inject id_rsa.pub into the VM's authorized_keys.
	# ----------------------------------------------------------------
	rm -f "${workDir}/id_rsa" "${workDir}/id_rsa.pub"
	ssh-keygen -q -f "${workDir}/id_rsa" -t rsa -N ''

	# Symlink the Vagrantfile into the working directory
	ln -sf "${VAGRANT_DIR}/Vagrantfile.${OS}.Libvirt" "${workDir}/Vagrantfile"

	# ----------------------------------------------------------------
	# ----------------------------------------------------------------
	# Windows Libvirt: skip entirely — winrm-elevated gem conflicts with
	# rubyzip 3.x on system Vagrant installs; cannot boot WinRM guests.
	# ----------------------------------------------------------------
	if isWindowsOS "$OS"; then
		echo "[${OS}] Skipping: Windows Libvirt boot requires winrm-elevated gem which"
		echo "         conflicts with rubyzip 3.x on Vagrant 2.3.x. Skipping this OS."
		boot_results["$OS"]="SKIP"
		playbook_results["$OS"]="SKIP"
		return
	fi

	# ----------------------------------------------------------------
	# Boot test
	# ----------------------------------------------------------------
	echo "[${OS}] Starting vagrant up --provider=libvirt ..."
	if (cd "${workDir}" && BUILD_ID=dontKillMe vagrant up --provider=libvirt); then
		boot_results["$OS"]="PASS"
		echo "[${OS}] Boot: PASS"
	else
		boot_results["$OS"]="FAIL"
		playbook_results["$OS"]="NOT_RUN"
		echo "[${OS}] Boot: FAIL — destroying VM and continuing"
		(cd "${workDir}" && vagrant destroy -f 2>/dev/null || true)
		return
	fi

	# ----------------------------------------------------------------
	# Playbook test (optional)
	# ----------------------------------------------------------------
	if [[ "$runPlaybook" == false ]]; then
		playbook_results["$OS"]="NOT_RUN"
	elif [[ "$OS" == "CentOS6" ]]; then
		echo "[${OS}] Skipping playbook: CentOS6 runs the playbook inside the VM via vagrant ssh, which is not supported by this script."
		playbook_results["$OS"]="SKIP"
	else
		runPlaybookTest "$OS" "$workDir" "$logPath"
	fi

	# ----------------------------------------------------------------
	# Teardown
	# ----------------------------------------------------------------
	if [[ "$retainVM" == false ]]; then
		echo "[${OS}] Halting and destroying VM ..."
		(cd "${workDir}" && vagrant halt 2>/dev/null || true)
		(cd "${workDir}" && vagrant destroy -f 2>/dev/null || true)
	else
		echo "[${OS}] --retain specified: VM left running in ${workDir}"
	fi
}

runPlaybookTest() {
	local OS="$1"
	local workDir="$2"
	local logPath="$3"

	echo "[${OS}] Running Ansible playbook ..."

	# Use vagrant ssh-config to get the SSH host and port — works for both
	# libvirt (real IP, port 22) and VirtualBox (127.0.0.1, forwarded port).
	local sshHost sshPort
	sshHost=$(cd "${workDir}" && vagrant ssh-config 2>/dev/null | awk '/^  HostName / { print $2 }')
	sshPort=$(cd "${workDir}" && vagrant ssh-config 2>/dev/null | awk '/^  Port / { print $2 }')
	if [[ -z "$sshHost" || -z "$sshPort" ]]; then
		echo "[${OS}] Playbook: FAIL — could not determine SSH host/port from vagrant ssh-config"
		playbook_results["$OS"]="FAIL"
		return
	fi

	# Write the hosts file — use [host]:port format so ansible handles both
	# plain IPs (libvirt) and 127.0.0.1 with non-standard ports (VirtualBox)
	local hostsFile="${workDir}/playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx"
	rm -f "$hostsFile"
	if [[ "$sshPort" == "22" ]]; then
		echo "$sshHost" > "$hostsFile"
	else
		echo "[${sshHost}]:${sshPort}" > "$hostsFile"
	fi

	# Clean up known_hosts for this host
	[[ ! -r "${HOME}/.ssh/known_hosts" ]] && touch "${HOME}/.ssh/known_hosts" && chmod 644 "${HOME}/.ssh/known_hosts"
	ssh-keygen -R "${sshHost}" 2>/dev/null || true
	ssh-keygen -R "[${sshHost}]:${sshPort}" 2>/dev/null || true
	ssh-keyscan -t rsa -p "${sshPort}" -H "${sshHost}" >> "${HOME}/.ssh/known_hosts" 2>/dev/null || true

	# Patch the working copy of main.yml: set hosts to all
	sed -i -e "s/.*hosts:.*/  hosts: all/g" \
		"${workDir}/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml"

	# Patch the working copy of ansible.cfg:
	# - add private_key_file, remote_tmp, timeout under [defaults]
	# - append IdentitiesOnly=yes to the existing ssh_args line (prevents
	#   "Too many authentication failures" when ssh-agent has many keys loaded)
	awk '/^\[defaults\]$/{print; print "private_key_file = id_rsa"; print "remote_tmp = $HOME/.ansible/tmp"; print "timeout = 60"; next}
	     /^ssh_args\s*=/{print $0 " -o IdentitiesOnly=yes"; next}
	     {print}' \
		< "${workDir}/ansible.cfg" > "${workDir}/ansible.cfg.tmp" \
		&& mv "${workDir}/ansible.cfg.tmp" "${workDir}/ansible.cfg"

	# Run the playbook from the working directory so relative paths resolve correctly
	local pbExitCode=0
	(
		cd "${workDir}"
		eval ansible-playbook \
			"$verbosity" \
			-i "playbooks/AdoptOpenJDK_Unix_Playbook/hosts.unx" \
			-u vagrant \
			-b \
			--skip-tags "adoptopenjdk,jenkins" \
			"playbooks/AdoptOpenJDK_Unix_Playbook/main.yml" \
			2>&1 | tee "${logPath}"
	) || pbExitCode=$?

	echo "[${OS}] Playbook finished at: $(date +%T)"

	if grep -q 'unreachable=0.*failed=0' "${logPath}"; then
		playbook_results["$OS"]="PASS"
		echo "[${OS}] Playbook: PASS"
	else
		playbook_results["$OS"]="FAIL"
		echo "[${OS}] Playbook: FAIL — see ${logPath}"
	fi
}

printSummary() {
	echo ""
	echo "============================================================"
	echo " Summary"
	echo "============================================================"
	printf "%-30s  %-8s  %-12s  %s\n" "OS" "Boot" "Playbook" "Overall"
	printf "%-30s  %-8s  %-12s  %s\n" "------------------------------" "--------" "------------" "-------"

	local anyFailed=false
	for OS in $vagrantOS; do
		local boot="${boot_results[$OS]:-UNKNOWN}"
		local pb="${playbook_results[$OS]:-NOT_RUN}"
		local overall
		if [[ "$boot" == "SKIP" ]]; then
			overall="SKIP"
		elif [[ "$boot" == "FAIL" || "$pb" == "FAIL" ]]; then
			overall="FAIL"
			anyFailed=true
		else
			overall="PASS"
		fi
		printf "%-30s  %-8s  %-12s  %s\n" "$OS" "$boot" "$pb" "$overall"
	done
	echo ""

	if [[ "$anyFailed" == true ]]; then
		echo "Result: FAILED — one or more OSs did not pass."
		return 1
	else
		echo "Result: ALL PASSED"
		return 0
	fi
}

# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------

processArgs "$@"

if [[ -z "$vagrantOS" ]]; then
	echo "ERROR: No OS specified. Use -v <OS> or -a for all."
	usage
	exit 1
fi

checkDeps

if [[ ! -n "${WORKSPACE:-}" ]]; then
	echo "WORKSPACE not set; defaulting to HOME (${HOME})"
	WORKSPACE="${HOME}"
fi

if [[ "$vagrantOS" == "all" ]]; then
	vagrantOS=$(discoverOSList)
else
	if [[ ! -f "${VAGRANT_DIR}/Vagrantfile.${vagrantOS}.Libvirt" ]]; then
		echo "ERROR: No Vagrantfile.${vagrantOS}.Libvirt found in ${VAGRANT_DIR}"
		echo "Available Libvirt OSs:"
		discoverOSList
		exit 1
	fi
fi

echo "Testing Libvirt Vagrantfiles for: ${vagrantOS}"
echo "Playbook test: ${runPlaybook}"
echo "Retain VM:     ${retainVM}"
echo ""

declare -A boot_results
declare -A playbook_results

for OS in $vagrantOS; do
	testOS "$OS"
done

printSummary
