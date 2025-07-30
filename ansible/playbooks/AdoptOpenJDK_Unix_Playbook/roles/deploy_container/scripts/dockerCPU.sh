#!/usr/bin/bash
set -eu

cpu_limit=$1
start_cpu=$(tail -n 1 /var/log/docker_cpu)
max_cpus=$(lscpu | grep "CPU(s):" | head -n 1 | awk '{split($0,a," "); print a[2]}')
cpus_to_use=""

if [ $cpu_limit -gt $max_cpus ] || [ $cpu_limit == "0" ]
then
    echo "ERROR: The container cannot have more cpus than there are cpus on the host or be 0"
    exit 1
fi

for i in $(seq 0 $(($cpu_limit - 1)));
do
        cpus_to_use="$cpus_to_use,$((($i + $start_cpu) % $max_cpus))"
done

echo $cpus_to_use | awk '{sub(",","")}1'
echo $(((${cpus_to_use: -1} + 1) % $max_cpus))