#!/bin/bash

check_name=$3
host_name=$5
path_to_config=$7

#declare an associative array for the existing defined services
declare -A checks
checks["Current Load"]="define service{
        use                             generic-service        
	host_name                       $host_name
        service_description             Current Load
        check_command                   check_by_ssh!/usr/local/nagios/libexec/check_load -w 15,10,5 -c 30,24,20
        notifications_enabled   	0
        check_interval                  30
        action_url      		/nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450

}"
checks["Disk Space Root Partition"]="define service{
        use                             generic-service        
        host_name                       $host_name
        service_description             Disk Space Root Partition
        check_command                   check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /
        check_interval                  60
	}"
checks["PING"]="define service{
        use                             local-service
        host_name                       $host_name
        service_description             PING
	check_command			check_ping!200.0,20%!500.0,60%
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
	}"
checks["Check if Jenkins Agent Connected"]="define service {
        use                             generic-service
        host_name                       $host_name
        service_description             Check if Jenkins Agent Connected
        check_command                   check_agent!$host_name
        notification_options            c,r
        check_interval                  30
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
}"
checks["RAM"]="define service{
        use                             generic-service
        host_name                       $host_name
        service_description             RAM
        check_command                   check_by_ssh!/usr/local/nagios/libexec/check_mem -f -C -w 15 -c 5
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=nagios$&service=$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=nagios$&service=$&period=hour&rrdopts=-w+450
        }"
checks["Updates Required - YUM"]="define service{
        use                             generic-service
        host_name                       $host_name
        check_period                    once-a-day-at-8
        service_description             Updates Required - YUM
        check_command                   check_by_ssh!/usr/local/nagios/libexec/check_yum 2>1 /dev/null
        notifications_enabled   0
        }"
checks["Check Network Time System"]="define service{
        use                             generic-service
        host_name                       $host_name
        service_description             Check Network Time System
        check_command                   check_by_ssh!/usr/local/nagios/libexec/check_ntp_timesync
        check_interval                  15
}"
checks["Updates Required - apt"]="define service{
        use                             generic-service
        host_name                       $host_name
	check_period			once-a-day-at-8
        service_description             Updates Required - apt
        check_command			check_by_ssh!/usr/lib/nagios/plugins/check_apt
	notifications_enabled   0
        }"
checks["Updates Required - Zypper"]="define service{
        use                             generic-service
        host_name                       $host_name
	check_period			once-a-day-at-8
        service_description             Updates Required - Zypper
	check_command                   check_by_ssh!/usr/local/nagios/libexec/check_zypper
	notifications_enabled   0        
	}"
checks["Total Processes"]="define service{
        use                             generic-service        
        host_name                       $host_name
        service_description             Total Processes
        check_command                   check_by_ssh!/usr/lib/nagios/plugins/check_procs -w 185 -c 210
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
	}"
checks["Zombie Processes"]="define service{
        use                             generic-service        
        host_name                       $host_name
        service_description             Zombie Processes
        check_command                   check_by_ssh!/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
	}"
checks["Current Users"]="define service{
        use                             generic-service        
        host_name                       $host_name
        service_description             Current Users
        check_command                   check_by_ssh!/usr/lib/nagios/plugins/check_users -w 5 -c 10
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
	}"
checks["SSH"]="define service{
        use                             local-service
	host_name                       $host_name
	service_description             SSH
	check_command			check_ssh
        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450
	}"


main() {
case $1 in
	--add) add
		;;
	--remove) remove 
		;;
	*) echo "you can only add or remove checks"
		;;
esac
}

#function to add defined services if it matches the check name parameter passed
add() {
	for check_name_key in "${!checks[@]}";
	do
		if [ "$check_name_key" == "$check_name" ]
		then
		echo "${checks[$check_name_key]}" >> $path_to_config
		echo "added successfully"
		fi
	done	

}

#function to remove defined services if it matches the check name parameter passed
remove() {
	for check_name_key in "${!checks[@]}";
	do
		if [ "$check_name_key" == "$check_name" ]
		then
			gawk -v RS='' -v ORS='\n\n' -v pattern="$check_name" -i inplace '$0 !~ pattern' $path_to_config
			 echo "removed successfully"
		fi
	done
}
main "$@"; exit
