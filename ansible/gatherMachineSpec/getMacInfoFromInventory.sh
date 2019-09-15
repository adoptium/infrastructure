#!/bin/bash

set -e
set -u
set -o pipefail

nmapscan() {
  host_ip=$1
  SCAN_RESULTS="$(nmap ${host_ip} --host-timeout 10 --max-retries 5 | grep -i ssh || true)"
  sleep 1
  ### On some machines, checking twice reveals the ssh port after a small gap
  if [ -z "${SCAN_RESULTS}" ]; then
    SCAN_RESULTS="$(nmap ${host_ip} --host-timeout 10 --max-retries 5 | grep -i ssh || true)"
  fi
  echo ${SCAN_RESULTS}
} 

recordMachineLoginStatus() {
  exitCode=$1
  host_ip=$2
  servername=$3
  if [[ ${exitCode} -eq 0 ]]; then
    if [[ -z "$(grep ${host_ip} successfully-accessed-machines.txt || true)" ]]; then
       echo "${servername},${host_ip}" >> successfully-accessed-machines.txt
       echo "Succeeded in accessing machine via ssh"
    fi
  else
    if [[ -z "$(grep ${host_ip} failed-to-access-machines.txt || true)" ]]; then
       echo "${servername},${host_ip}" >> failed-to-access-machines.txt
       echo "Failed to access machine via ssh"
    fi
  fi
}

checkIfSSHIsPossible() {
  host_ip=$1
  servername=$2
  echo "Checking to see if we can ssh on to ip ${host_ip}"
  CAN_SSH=$(nmapscan ${host_ip})
  echo "nmap scan results: '${CAN_SSH}'"

  if [[ -z "${CAN_SSH}" ]]; then
    echo "Cannot ssh onto this machine, skipping gathering info, moving to next machine..."
    if [[ -z "$(grep ${host_ip} ssh-not-available-machines.txt || true)" ]]; then
       echo "${servername},${host_ip}" >> ssh-not-available-machines.txt
    fi
  fi
}

SSH_KEY="${1:-"-i ${HOME}/.ssh/id_rsa-linux"}"

if [[ ! -s "machines.txt" ]]; then 
	grep "ip\|user" ../inventory.yml         \
	                | awk '{print $1 $3 $5}' \
	                | tr  ":" " "            \
	                | tr "," " "             \
	                | tr "}" " "             \
	                > machines.txt
  sed -i machines.txt 's/ /,/g' machines.txt
fi

totalCount=$(cat machines.txt | wc | awk '{print $2}')
count=0

CAN_SSH=""

machines=( $( cat machines.txt ) )
for machine in "${machines[@]}"
do
  count=$((count+1))

  servername=$(echo "$machine" | awk -F ',' '{print $1}')
  host_ip=$(echo "$machine" | awk -F ',' '{print $2}')
  user=jenkins

  echo ""
  echo "[${count}/${totalCount}] Scanning ${servername} with ip '${host_ip}' and username '${user}'"

  checkIfSSHIsPossible ${host_ip} ${servername}
  if [[ -z "${CAN_SSH}" ]]; then
    continue
  fi

  exitCode=0
  if [[ ! -z "$(echo ${servername} | grep -i win)" ]]; then
       echo "Windows box"
       ssh -t ${SSH_KEY} "${user}@${host_ip}" < windows.sh || exitCode=$? && true
  elif [[ ! -z "$(echo ${servername} | grep -i macos)" ]]; then
        echo "MacOS box"
        ssh -t ${SSH_KEY} "${user}@${host_ip}" < macos.sh || exitCode=$? && true
  else
        echo "Unix/Linux box"
        ssh -t ${SSH_KEY} "${user}@${host_ip}" < linux.sh || exitCode=$? && true
  fi

  recordMachineLoginStatus ${exitCode} ${host_ip} ${servername}

  echo "-----------------------------------------------------------------------------"
done

echo "exit code: $?"