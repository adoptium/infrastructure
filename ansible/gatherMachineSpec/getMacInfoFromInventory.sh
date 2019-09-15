#!/bin/bash

set -e
set -u
set -o pipefail

nmapscan() {
  host_ip=$1
  CAN_SSH="$(nmap ${host_ip} --host-timeout 10 --max-retries 5 | grep -i ssh || true)"
  sleep 1
  ### On some machines, checking twice reveals the ssh port
  if [ -z "${CAN_SSH}" ]; then
    CAN_SSH="$(nmap ${host_ip} --host-timeout 10 --max-retries 5 | grep -i ssh || true)"
  fi
  echo ${CAN_SSH}
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

totalCount=$(cat machines.txt | wc -l | tr -d ' ')
count=0

machines=( $( cat machines.txt ) )
for machine in "${machines[@]}"
do
  count=$((count+1))

  servername=$(echo "$machine" | awk -F ',' '{print $1}')
  host_ip=$(echo "$machine" | awk -F ',' '{print $2}')
  user=jenkins

  echo ""
  echo "[${count}/${totalCount}] Scanning ${servername} with ip '${host_ip}' and username '${user}'"

  echo "Checking to see if we can ssh on to ip ${host_ip}"
  CAN_SSH=$(nmapscan ${host_ip})
  echo "nmap scan results: '${CAN_SSH}'"

  if [[ -z "${CAN_SSH}" ]]; then
    echo "Cannot ssh onto this machine, skipping gathering info, moving to next machine..."
    continue
  fi

set -x
  if [[ ! -z "$(echo ${servername} | grep -i win)" ]]; then
       echo "Windows box"
       ssh -T "${user}@${host_ip}" ${SSH_KEY} < windows.sh || true 
  elif [[ ! -z "$(echo ${servername} | grep -i macos)" ]]; then
        echo "MacOS box"
        ssh -T "${user}@${host_ip}" ${SSH_KEY} < macos.sh || true 
  else
        echo "Unix/Linux box"
        ssh -T "${user}@${host_ip}" ${SSH_KEY} < linux.sh || true 
  fi
set +x  
  echo "-----------------------------------------------------------------------------"
done

echo "exit code: $?"