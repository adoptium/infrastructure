#!/bin/bash
#
########################
# Author: Brad Blondin #
########################
#
########################
# General Information: #
########################
# This script will enable monitoring of a Nagios client system for the following standard services:
# Current Load, Current Users, Disk Space Root Partition, PING, RAM, SSH, Total Processes, Zombie Process
# Anything beyond the standard defaults would require manual configuration. Such has adding monitoring for web sites.
# If the client system is already being monitored by Nagios it will be skipped.
#
################
# Assumptions: #
################
# This tool will be executed from the Nagios Master
# The Nagios plugins are installed on the Nagios client system 
# The Nagios user and its ssh key is configured
# The Nagios client system is using an IPv4 address, for IPv6 configuration will have to be done manually
# * If the Nagios client requires a jumpbox or tunnel manual setup is required
# Nagios Server Configuration Tool expects 6 command line arguments passed to it from Ansible in the followin order:
# {{ ansible_distribution }} {{ ansible_architecture }} {{ inventory_hostname }} {{ ansible_host }} {{ provider }} {{ ansible_port }}
#
####################
# Global Variables #
####################
#
Time_Stamp=`date +%Y%m%d-%H%M%S`
Work_Dir=/usr/local/nagios/Nagios_Ansible_Config_tool/
Nagios_Server_Folder=/usr/local/nagios/etc/servers/
Template_Dir=$Work_Dir/templates
Nagios_Logo_Folder=/usr/local/nagios/share/images/logos
Nagios_Objects_folder=/usr/local/nagios/etc/objects
Hostgroups_File=$Nagios_Objects_folder/hostgroups.cfg
#
###################
# Slack Variables #
###################
SLACK_CHANNEL=`cat /usr/local/nagios/bin/slack_nagios.pl | grep "SLACK_CHANNEL=" | sed -e 's/.*="//' -e 's/"//'`
SLACK_BOTNAME="nagios"
ICON_EMOJI=":computer:"
WEBHOOK_URL=`cat /usr/local/nagios/bin/slack_nagios.pl | grep "WEBHOOK_URL=" | sed -e 's/.*="//' -e 's/".*//'`
#
########################
# Data/Enabled Options #
########################
#
###############################
# Test command line arguments #
###############################
#
if [[ $1 = "" ]] || [[ $2 = "" ]] || [[ $3 = "" ]] || [[ $4 = "" ]] || [[ $5 = "" ]] || [[ $6 = "" ]] ; then							# Test: Ensure that 6 command line arguments have been passed
	echo "Error: one or more command line arguments are missing"
	echo "Expected arguments: {{ ansible_distribution }} {{ ansible_architecture }} {{ inventory_hostname  }} {{ ansible_host }} {{ provider }} {{ ansible_port }} "
	exit
fi
if [[ ! $4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then														# Test: Ensure the 4th command line argument is an IP Address
	echo "Error: IP address was entered with an invalid format: "$Sys_IPAddress
	exit
fi
#
if [ ! -f $Template_Dir/template_with_graph.cfg ] || [ ! -f $Template_Dir/template.cfg ] || [ ! -f $Template_Dir/template_with_graph_no_ping.cfg ] ; then	# Test: Ensure templates exist
        echo "Error: Unable to locate templates" $Template_Dir/template_with_graph.cfg $Template_Dir/template.cfg $Template_Dir/template_with_graph_no_ping.cfg
        exit
fi
#
if ! [[ "$6" =~ ^[0-9]+$ ]] ; then																# Test: Ensure {{ ansible_port }} is an integer
        echo "Error: {{ ansible_port }} must be an integers" $6
	exit
fi
#
##########################################################
# Convert command line arguments to the sciprt variables #
##########################################################
#
Distro=$1 																			# {{ ansible_distribution }} 
Arch=$2																				# {{ ansible_architecture }}
Sys_Hostname=$3 																		# {{ inventory_hostname }} 	
Sys_IPAddress=$4																		# {{ ansible_host }}
Provider_Name=`echo $5 | tr '[:upper:]' '[:lower:]' | python -c "print raw_input().capitalize()"`								# Convert {{ provider }} to lower case and set first char to uppercase
Client_Shortname=`echo $Sys_Hostname | sed 's/\..*//'`														# Convert $Sys_Hostname to $Client_Shortname
SSH_Port_Num=$6																			# {{ ansible_port }}
#
#################################
# Test if client already exists #
#################################
#
Client_Check=`ls $Nagios_Server_Folder | grep $Client_Shortname`		
if [[ ! $Client_Check = "" ]] ; then																# Test: If the client is already being monitored by Nagios skip
	echo "The Nagaios client" $Sys_Hostname "is already being monitored by Nagios... Skipping."
	exit
fi
#
############################
# Enabled Standard Options #
############################
# This code is here to provide manually override options if you environment differs 
Sys_Checkmem="yes"
Sys_Graphs="yes"
Sys_Notifications="yes"
Sys_Alias="yes"
Sys_Alias_Info="Add by Ansible"
Sys_Icon="yes"
#
#############
# Ping Test #
#############
# Test: If the Nagios client system is pingable from the Nagio server (ICMP is enabled) if not disable the ping test 
Ping_Test=`ping -q -c2 $Sys_IPAddress > /dev/null`
if [[ $? -eq 0 ]] ; then
	Sys_Pingable="yes"
else
	Sys_Pingable="no"
fi
if [[ ! $SSH_Port_Num = 22 ]] ; then																# Test: if not using default ssh port
	Sys_Pingable="no"																	# set $Sys_Pingable to no
fi
#
################
# Nagios Icons # 
################
# Test: If client $Arch {{ ansible_architecture }} is aarch64 or armv7l then set the Nagios icon to "arm", else use $Distro {{ ansible_distribution }}
if [[ $Arch = "aarch64" ]] || [[ $Arch = "armv7l" ]] ; then
        Sys_Icon_Picked=arm
else
        Sys_Icon_Picked=$Distro
fi
if [ ! -f $Nagios_Logo_Folder/$Sys_Icon_Picked.gd2 ] ; then													# If there is no matching icon in Nagios's logo folder default to nagios.gd2
	echo "Logo icon was not found" $Sys_Icon_Picked "Defaulting to nagios icon"
	Sys_Icon_Picked=nagios.gd2
fi
###################
# Package Manager #
###################
# Detect the right package manager to monitor
Sys_OS="yes"
case "$Distro" in
        Ubuntu)
                Sys_OS_pkg_Template=$Template_Dir/apt.cfg ;;
        RedHat|CentOS)
                Sys_OS_pkg_Template=$Template_Dir/yum.cfg ;;
        SLES)
                Sys_OS_pkg_Template=$Template_Dir/zypper.cfg ;;
	FreeBSD|freebsd)
		Sys_OS_pkg_Template=$Template_Dir/pkg.cfg ;;
        *)
                echo "Error: Unable to select package manager. Thus it will not be monitored" ;;
esac
#
#####################
# Debug Infromation #
#####################
#
echo -e "\n\n##################################################"
echo "Hostname: "$Client_Shortname
echo "IP Address: "$Sys_IPAddress
echo "SSH Port Number: "$SSH_Port_Num
echo "Enable check_mem: "$Sys_Checkmem
echo "Enable Nagios Graphs: "$Sys_Graphs
echo "Host is pingable: "$Sys_Pingable
echo "Enable Icons: "$Sys_Icon $Sys_Icon_Picked
echo "Enable Notifications: "$Sys_Notifications
echo "Add Description Info: "$Sys_Alias $Sys_Alias_Info
echo "Operating System patches "$Sys_OS $Sys_OS_pkg_Template
echo -e "##################################################\n"
#
########
# Main #
########
#
###################
# SSH Nagios test #
###################
#
# Test: Ensure an ssh connecttion can be made to Nagios client system by the Nagios user and automatically add fingerprint key
Nagios_Login=`su nagios -c "ssh -o StrictHostKeyChecking=no $Sys_IPAddress uptime"`
#
if [[ $Nagios_Login = "" ]] || [[ $Nagios_Login = "Permission denied, please try again." ]]; then
	echo "ERROR: Unable to connect to client $Sys_IPAddress as the nagios user"
	echo "Please ensure that the nagios user is able to ssh into the client machine using keys"
	exit
fi
#
#
###################
# Create CFG file #
###################
#
cd $Work_Dir																			# Ensure we are in the right folder
# Template Section
if [[ $Sys_Graphs = "yes" ]] && [[ $Sys_Pingable = "yes" ]] ; then												# Select template to use, with or without mouse of graphs, pingable or not 
	config_template=$Template_Dir/template_with_graph.cfg
else
        if [[ $Sys_Graphs = "yes" ]] && [[ $Sys_Pingable = "no" ]] ; then
                config_template=$Template_Dir/template_with_graph_no_ping.cfg
        else
                config_template=$Template_Dir/template.cfg
        fi
fi
cp $config_template $Client_Shortname.cfg															# Create working file for new host config
#
#########
# Icons #
#########
#
if [[ $Sys_Icon = "yes" ]] ; then
        # Insert icon information starting one line below notification_period
        sed -i "/notification_period/a bbb        icon_image                      ICON_NAME.png" $Client_Shortname.cfg
        sed -i "/icon_image/a bbb        icon_image_alt                  ICON_NAME" $Client_Shortname.cfg
        sed -i "/icon_image_alt/a bbb        statusmap_image                 ICON_NAME.gd2" $Client_Shortname.cfg
        sed -i 's/bbb//' $Client_Shortname.cfg															# Remove fake tab place holder bbb
        sed -i "s/ICON_NAME/$Sys_Icon_Picked/" $Client_Shortname.cfg												# Change ICON_NAME with the name of the icon picked
fi
#
if [[ $Sys_Checkmem = "yes" ]] ; then																# Include check_mem service
        if [[ $Sys_Graphs = "yes" ]] ; then															# with graphs?
		Check_Mem_TMP_File=$Template_Dir/check_mem_tmp.file.$RANDOM   		                                                                        # Name tmp file with random number
                cp $Template_Dir/check_mem.cfg $Check_Mem_TMP_File
                sed -i "/check_command/a bbb        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450" $Check_Mem_TMP_File
                sed -i 's/bbb//' $Check_Mem_TMP_File                       		                                                                 	# Remove fake tab place holder bbb
                cat $Check_Mem_TMP_File >> $Client_Shortname.cfg	
                rm $Check_Mem_TMP_File	  		                                                                                           		# Remove tmp file
        else
                cat $Template_Dir/check_mem.cfg >> $Client_Shortname.cfg
	fi
fi
#
if [[ $Sys_Notifications = "yes" ]] ; then															# Enable notifications
	sed -i '/notifications_enabled/d' $Client_Shortname.cfg
fi
#
if [[ $Sys_OS = "yes" ]] ; then																	# Enable checking for Operating System patches
	if [[ ! $Sys_OS_pkg_Template = "" ]] ; then														# Ensure a package manager was selected $Sys_OS_pkg_Template
		cat $Sys_OS_pkg_Template >> $Client_Shortname.cfg
	fi
fi
#####################################
# Swap vars with system information #
#####################################
#
sed -i "s/ReplaceHostName/$Client_Shortname/" $Client_Shortname.cfg												# Swap out ReplaceHostName with $Client_Shortname
#
# Additional configuration for system using a tunnel connection
if [[ $SSH_Port_Num = 22 ]] ; then																# Test: what port number is in use for SSH
	sed -i "s/ReplaceIPAddress/$Sys_IPAddress/" $Client_Shortname.cfg											# Swap out ReplaceIPAddress with $Sys_IPAddress
else
	sed -i "s/ReplaceIPAddress/$Sys_IPAddress -p $SSH_Port_Num/" $Client_Shortname.cfg 									# Swap out ReplaceIPAddress with $Sys_IPAddress and add -p SSH_Port_Num
	sed -i  '/check_dummy/d' $Client_Shortname.cfg 														# Remove host check ping command 
	sed -i "/notification_period/a SYS_NOTES        notes                           *** This host is using a Reverse SSH Tunnel on port $SSH_Port_Num ***" 	# Insert 'notes' after 'notification_period' and fack tab place holder SYS_NOTES
	sed -i 's/SYS_NOTES//' $Client_Shortname.cfg 														# Remove fake tab place holder SYSTEM_NOTES
fi
#
if [[ $Sys_Alias = "yes" ]] ; then																# Swap and ReplaceAliasDescription
	sed -i "s/ReplaceAliasDescription/$Sys_Alias_Info/" $Client_Shortname.cfg										# Insert Description provided by $Sys_Alias_info
else
	sed -i 's/ReplaceAliasDescription/No information/' $Client_Shortname.cfg										# Description = No Information
fi
#
# Nagios client configuration file has been created.
#
##############
# Hostgroups #
##############
#
Provider_Exists=`cat $Hostgroups_File | grep "hostgroup_name" | grep $Provider_Name`										# Test if Hostgroup already exists for the Provider_Name 
if [[ $Provider_Exist = "" ]] ; then
	# The Provider_Name doesn't exists, Create new hostgroup from template for Provider
        Hostgroup_Template_TMP_File=$Template_Dir/hostgroup_template.cfg.file.$RANDOM                                                                           # Name tmp file with random number
        cp $Template_Dir/hostgroup_template.cfg $Hostgroup_Template_TMP_File                                    	                	                # Create a temp file to work with
        sed -i "s/PROVIDER/$Provider_Name/" $Hostgroup_Template_TMP_File                                	        	                                # Swap out PROVIDER in temp file
        sed -i "s/ALIAS_INFO/$Provider_Name/" $Hostgroup_Template_TMP_File                      	                        	                # Swap out ALIAS_INFO in temp file
        cat $Hostgroup_Template_TMP_File >> $Hostgroups_File                            	                                                        	# Add new hostgroup provider to the hostgroups file
        rm $Hostgroup_Template_TMP_File                                             	                   		                                        # Remvoe temp file
	# Send slack notifications to Admins
        curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"icon_emoji\": \":nagios:\", \"text\": \"${ICON_EMOJI} New Nagios hostgroup was created while running an Ansible playbook on ${Client_Shortname} Please see $Template_Dir/hostgroup_template.cfg \"}" ${WEBHOOK_URL}
fi
#
Hostgroups_Line_NUM=`cat -n $Hostgroups_File | grep "hostgroup_name" | grep $Provider_Name | awk '{print $1}'`							# Get line number of hostgroup_name that matches $Provider_Name
# Test if $Client_Shortname already exists as a member of the hostgroup
# Start reading hostgroups.cfg file at $Hostgroups_Line_NUM. Stop at "members". greping for $Client_Shortname
Hostgroups_Member=`cat $Hostgroups_File | sed -n $Hostgroups_Line_NUM',$p' | sed '/members/q' | grep $Client_Shortname`
#
if [[ $Hostgroups_Member = "" ]] ; then
        Hostgroups_Crop_NUM=`cat $Hostgroups_File | sed -n $Hostgroups_Line_NUM',$p' | sed '/members/q' | wc -l`						# Get number of line between hostgroup_name/$Provider_Name and members
        Hostgroups_Count=`expr $Hostgroups_Line_NUM + $Hostgroups_Crop_NUM - "1"`										# Add $Hostgroups_Line_NUM to $Hostgroups_Crop_NUM and subtract 1
        sed -i "${Hostgroups_Count}s/$/,$Client_Shortname/" $Hostgroups_File											# On line $Hostgroups_Count add $Client_Shortname to the end of the line
else
        echo $Client_Shortname "Already exists in the hostgroup, skipping"
fi
#
#####################
# Pre-flight checks #
#####################
#
echo "Conducting Pre-flight checks..."																# System configure file has been created, start Pre-flight checks
mv $Client_Shortname.cfg $Nagios_Server_Folder															# Move new cfg file into Nagios
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg > flight_check_$Time_Stamp.log									# Pre-flight check
flight_error=`cat flight_check_$Time_Stamp.log | grep Errors | awk '{print $3}'`
flight_warn=`cat flight_check_$Time_Stamp.log | grep Warnings | awk '{print $3}'`
if [[ ! $flight_error = "0" ]] || [[ ! $flight_warn = "0" ]] ; then
	echo "ERROR: Something when wrong..."
	/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg > $Work_Dir/$Client_Shortname.cfg.error_$Time_Stamp.log				# Create error log
	mv $Nagios_Server_Folder/$Client_Shortname.cfg $Work_Dir/												# Remove $Client_Shortname.cfg
	echo "Please see error log: $Work_Dir/$Client_Shortname.cfg.error_$Time_Stamp.log"
	echo "Host configure: $Work_Dir/$Client_Shortname.cfg"
	# Send slack notifications to Admins
	curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"icon_emoji\": \":nagios:\", \"text\": \"${ICON_EMOJI} Nagios pre-flight check failed on host ${Client_Shortname} while running an Ansible playbook please see $Work_Dir/$Client_Shortname.cfg.error_$Time_Stamp.log for more information \"}" ${WEBHOOK_URL}
	exit
fi
rm flight_check_$Time_Stamp.log																	# All is good, remove log file
echo "Pre-flight checks have all passed"
sudo /usr/sbin/service nagios restart																# Restart the Nagios service to reload new configuration
echo "Nagios has been restart, have a nice day!"
