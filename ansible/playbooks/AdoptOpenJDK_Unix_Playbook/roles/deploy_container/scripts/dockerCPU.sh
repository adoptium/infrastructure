# Reads /var/log/dockerCPU.sh to get start_cpu
# Input is number of cpus to use: cpu_limit
# Uses cpu_limit and start_cpu to determine which cpus to use in the docker container
# If it goes over the max cpus on the machine, it should loop back to 0
#    ie if cpu_limit is 4, start_cpu is 6 and max cpus is 8, the script will output 6,7,1,2

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

for i in $(seq 1 $cpu_limit);
do
        cpus_to_use="$cpus_to_use,$((($i + $start_cpu) % $max_cpus))"
done

# List of cpus, remove first comma
echo $cpus_to_use | awk '{sub(",","")}1'
# Last cpu used, used to update /var/log/dockerCPU.sh
echo ((${cpus_to_use: -1} + 1) % $max_cpus)