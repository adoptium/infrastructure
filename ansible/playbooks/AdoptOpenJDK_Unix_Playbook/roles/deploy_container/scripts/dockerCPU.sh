#!/usr/bin/bash

# Usage - Script takes one argument, the number of cpus for the docker container
# ie bash dockerCPU.sh 4
# Argument cannot be 0 or greater than the number of CPUs on the machine
# If /etc/adoptium_docker_cpu does not exist, run: echo 0 > /etc/adoptium_docker_cpu

set -eu

cpu_limit=$1

if [ ! -f /etc/adoptium_docker_cpu ]; then
    echo "ERROR: /etc/adoptium_docker_cpu does not exist. Exiting script"
    exit 1
fi

if ! [[ "$cpu_limit" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Argument must be a single integer greater than 0"
    exit 1
fi

start_cpu=$(tail -n 1 /etc/adoptium_docker_cpu)
max_cpus=$(lscpu | grep "CPU(s):" | head -n 1 | sed 's/.* //')

if [ $cpu_limit -gt $max_cpus ] || [ $cpu_limit == "0" ]
then
    echo "ERROR: The container cannot have more cpus than there are cpus on the host or be 0"
    exit 1
fi

cpus_to_use=""

for i in $(seq 0 $(($cpu_limit - 1)));
do
    cpus_to_use="$cpus_to_use,$((($i + $start_cpu) % $max_cpus))"
done

# Output: comma separated list of cpus to use, and next cpu to use
echo $cpus_to_use | awk '{sub(",","")}1'
echo $((($(echo $cpus_to_use | sed "s/.*,//") + 1) % $max_cpus))
