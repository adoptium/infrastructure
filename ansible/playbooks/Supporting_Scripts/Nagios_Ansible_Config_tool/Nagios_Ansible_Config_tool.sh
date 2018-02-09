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
# Nagios Server Configuration Tool expects 4 command line arguments passed to it from Ansible in the followin order:
# {{ ansible_distribution }} {{ ansible_architecture }} {{ inventory_hostname }} {{ ansible_host }} {{ provider }}
#
####################
# Global Variables #
####################
#
timestamp=`date +%Y%m%d-%H%M%S`
work_dir=/usr/local/nagios/Nagios_Ansible_Config_tool/
Nagios_Server_Folder=/usr/local/nagios/etc/servers/
template_dir=$work_dir/templates
Nagios_Logo_Folder=/usr/local/nagios/share/images/logos
Nagios_Objects_folder=/usr/local/nagios/etc/objects
Hostgroups_File=$Nagios_Objects_folder/hostgroups.cfg
#
########################
# Data/Enabled Options #
########################
#
###############################
# Test command line arguments #
###############################
#
if [[ $1 = "" ]] || [[ $2 = "" ]] || [[ $3 = "" ]] || [[ $4 = "" ]] || [[ $5 = "" ]] ; then									# Test: Ensure that 5 command line arguments have been passed
	echo "Error: one or more command line arguments are missing"
	echo "Expected arguments: {{ ansible_distribution }} {{ ansible_architecture }} {{ inventory_hostname  }} {{ ansible_host }} {{ provider }} "
	exit
fi
if [[ ! $4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then														# Test: Ensure the 4th command line argument is an IP Address
	echo "Error: IP address was entered with an invalid format: "$sys_ipaddress
  exit
fi
#
if [ ! -f $template_dir/template_with_graph.cfg ] || [ ! -f $template_dir/template.cfg ] || [ ! -f $template_dir/template_with_graph_no_ping.cfg ]; then	# Test: Ensure templates exist
        echo "Error: Unable to locate templates" $template_dir/template_with_graph.cfg $template_dir/template.cfg $template_dir/template_with_graph_no_ping.cfg
        exit
fi
#
##########################################################
# Convert command line arguments to the sciprt variables #
##########################################################
#
sys_hostname=$3 																		# {{ inventory_hostname }} 	
sys_ipaddress=$4																		# {{ ansible_host }}
Provider_Name=`echo $5 | tr '[:upper:]' '[:lower:]' | python -c "print raw_input().capitalize()"`								# Convert {{ provider }} to lower case and set first char to uppercase
Client_shortname=`echo $sys_hostname | sed 's/\..*//'`														# Convert $sys_hostname to $Client_shortname
#
#################################
# Test if client already exists #
#################################
#
Client_Check=`ls $Nagios_Server_Folder | grep $Client_shortname`		
if [[ ! $Client_Check = "" ]] ; then																# Test: If the client is already being monitored by Nagios skip
	echo "The Nagaios client" $3 "is already being monitored by Nagios... Skipping."
	exit
fi
#
############################
# Enabled Standard Options #
############################
# This code is here to provide manually override options if you environment differs 
sys_checkmem="yes"
sys_graphs="yes"
sys_notifications="yes"
sys_alias="yes"
sys_alias_info="Add by Ansible"
sys_icon="yes"
#
#############
# Ping Test #
#############
# Test: If the Nagios client system is pingable from the Nagio server (ICMP is enabled) if not disable the ping test 
ping_test=`ping -q -c2 $sys_ipaddress > /dev/null`
if [[ $? -eq 0 ]] ; then
	sys_pingable="yes"
else
	sys_pingable="no"
fi
#
################
# Nagios Icons # 
################
# Test: If client $2 {{ ansible_architecture }} is aarch64 or armv7l then set the Nagios icon to "arm", else use $1 {{ ansible_distribution }}
if [[ $2 = "aarch64" ]] || [[ $2 = "armv7l" ]] ; then
        sys_icon_picked=arm
else
        sys_icon_picked=$1
fi
if [ ! -f $Nagios_Logo_Folder/$sys_icon_picked.gd2 ] ; then													# If there is no matching icon in Nagios's logo folder default to nagios.gd2
	echo "Logo icon was not found" $sys_icon_picked "Defaulting to nagios icon"
	sys_icon_picked=nagios.gd2
fi
###################
# Package Manager #
###################
# Detect the right package manager to monitor
sys_OS="yes"
case "$1" in
        Ubuntu)
                sys_OS_pkg_template=$template_dir/apt.cfg ;;
        RedHat|CentOS)
                sys_OS_pkg_template=$template_dir/yum.cfg ;;
        SLES)
                sys_OS_pkg_template=$template_dir/zypper.cfg ;;
	FreeBSD|freebsd)
		sys_OS_pkg_template=$template_dir/pkg.cfg ;;
        *)
                echo "Error: Unable to select package manager. Thus it will not be monitored" ;;
esac
#
#####################
# Debug Infromation #
#####################
#
echo -e "\n\n##################################################"
echo "Hostname: "$Client_shortname
echo "IP Address: "$sys_ipaddress
echo "Enable check_mem: "$sys_checkmem
echo "Enable Nagios Graphs: "$sys_graphs
echo "Host is pingable: "$sys_pingable
echo "Enable Icons: "$sys_icon $sys_icon_picked
echo "Enable Notifications: "$sys_notifications
echo "Add Description Info: "$sys_alias $sys_alias_info
echo "Operating System patches "$sys_OS $sys_OS_pkg_template
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
Nagios_Login=`su nagios -c "ssh -o StrictHostKeyChecking=no $sys_ipaddress uptime"`
#
if [[ $Nagios_Login = "" ]] || [[ $Nagios_Login = "Permission denied, please try again." ]]; then
	echo "ERROR: Unable to connect to client $sys_ipaddress as the nagios user"
	echo "Please ensure that the nagios user is able to ssh into the client machine using keys"
	exit
fi
#
#
###################
# Create CFG file #
###################
#
cd $work_dir																			# Ensure we are in the right folder
# Template Section
if [[ $sys_graphs = "yes" ]] && [[ $sys_pingable = "yes" ]] ; then												# Select template to use, with or without mouse of graphs, pingable or not 
	config_template=$template_dir/template_with_graph.cfg
else
        if [[ $sys_graphs = "yes" ]] && [[ $sys_pingable = "no" ]] ; then
                config_template=$template_dir/template_with_graph_no_ping.cfg
        else
                config_template=$template_dir/template.cfg
        fi
fi
cp $config_template $Client_shortname.cfg															# Create working file for new host config
#
#########
# Icons #
#########
#
if [[ $sys_icon = "yes" ]] ; then
        # Insert icon information starting one line below notification_period
        sed -i "/notification_period/a bbb        icon_image                      ICON_NAME.png" $Client_shortname.cfg
        sed -i "/icon_image/a bbb        icon_image_alt                  ICON_NAME" $Client_shortname.cfg
        sed -i "/icon_image_alt/a bbb        statusmap_image                 ICON_NAME.gd2" $Client_shortname.cfg
        sed -i 's/bbb//' $Client_shortname.cfg															# Remove fake tab place holder bbb
        sed -i "s/ICON_NAME/$sys_icon_picked/" $Client_shortname.cfg												# Change ICON_NAME with the name of the icon picked
fi
#
if [[ $sys_checkmem = "yes" ]] ; then																# Include check_mem service
        if [[ $sys_graphs = "yes" ]] ; then															# with graphs?
		Check_Mem_TMP_File=$template_dir/check_mem_tmp.file.$RANDOM   		                                                                        # Name tmp file with random number
                cp $template_dir/check_mem.cfg $Check_Mem_TMP_File
                sed -i "/check_command/a bbb        action_url      /nagiosgraph/cgi-bin/show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=$HOSTNAME$&service=$SERVICEDESC$&period=hour&rrdopts=-w+450" $Check_Mem_TMP_File
                sed -i 's/bbb//' $Check_Mem_TMP_File                       		                                                                       # Remove fake tab place holder bbb
                cat $Check_Mem_TMP_File >> $Client_shortname.cfg	
                rm $Check_Mem_TMP_File	  		                                                                                                       # Remove tmp file
        else
                cat $template_dir/check_mem.cfg >> $Client_shortname.cfg
	fi
fi
#
if [[ $sys_notifications = "yes" ]] ; then															# Enable notifications
	sed -i '/notifications_enabled/d' $Client_shortname.cfg
fi
#
if [[ $sys_OS = "yes" ]] ; then																	# Enable checking for Operating System patches
	if [[ ! $sys_OS_pkg_template = "" ]] ; then														# Ensure a package manager was selected $sys_OS_pkg_template
		cat $sys_OS_pkg_template >> $Client_shortname.cfg
	fi
fi
#
sed -i "s/ReplaceHostName/$Client_shortname/" $Client_shortname.cfg												# Swap out ReplaceHostName with $Client_shortname
sed -i "s/ReplaceIPAddress/$sys_ipaddress/" $Client_shortname.cfg												# Swap out ReplaceIPAddress with $sys_ipaddress
if [[ $sys_alias = "yes" ]] ; then																# Swap and ReplaceAliasDescription
	sed -i "s/ReplaceAliasDescription/$sys_alias_info/" $Client_shortname.cfg										# Insert Description provided by $sys_alias_info
else
	sed -i 's/ReplaceAliasDescription/No information/' $Client_shortname.cfg										# Description = No Information
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
        Hostgroup_Template_TMP_File=$template_dir/hostgroup_template.cfg.file.$RANDOM                                                                           # Name tmp file with random number
        cp $template_dir/hostgroup_template.cfg $Hostgroup_Template_TMP_File                                    	                	                # Create a temp file to work with
        sed -i "s/PROVIDER/$Provider_Name/" $Hostgroup_Template_TMP_File                                	        	                                # Swap out PROVIDER in temp file
        sed -i "s/ALIAS_INFO/$Provider_Name/" $Hostgroup_Template_TMP_File                      	                        	        	        # Swap out ALIAS_INFO in temp file
        cat $Hostgroup_Template_TMP_File >> $Hostgroups_File                            	                                                        	# Add new hostgroup provider to the hostgroups file
        rm $Hostgroup_Template_TMP_File                                             	                   		                                        # Remvoe temp file
fi
#
Hostgroups_Line_NUM=`cat -n $Hostgroups_File | grep "hostgroup_name" | grep $Provider_Name | awk '{print $1}'`							# Get line number of hostgroup_name that matches $Provider_Name
# Test if $Client_shortname already exists as a member of the hostgroup
# Start reading hostgroups.cfg file at $Hostgroups_Line_NUM. Stop at "members". greping for $Client_shortname
Hostgroups_Member=`cat $Hostgroups_File | sed -n $Hostgroups_Line_NUM',$p' | sed '/members/q' | grep $Client_shortname`
#
if [[ $Hostgroups_Member = "" ]] ; then
        Hostgroups_Crop_NUM=`cat $Hostgroups_File | sed -n $Hostgroups_Line_NUM',$p' | sed '/members/q' | wc -l`						# Get number of line between hostgroup_name/$Provider_Name and members
        Hostgroups_Count=`expr $Hostgroups_Line_NUM + $Hostgroups_Crop_NUM - "1"`										# Add $Hostgroups_Line_NUM to $Hostgroups_Crop_NUM and subtract 1
        sed -i "${Hostgroups_Count}s/$/,$Client_shortname/" $Hostgroups_File											# On line $Hostgroups_Count add $Client_shortname to the end of the line
else
        echo $Client_shortname "Already exists in the hostgroup, skipping"
fi
#
#####################
# Pre-flight checks #
#####################
#
echo "Conducting Pre-flight checks..."																# System configure file has been created, start Pre-flight checks
mv $Client_shortname.cfg $Nagios_Server_Folder															# Move new cfg file into Nagios
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg > flight_check_$timestamp.log									# Pre-flight check
flight_error=`cat flight_check_$timestamp.log | grep Errors | awk '{print $3}'`
flight_warn=`cat flight_check_$timestamp.log | grep Warnings | awk '{print $3}'`
if [[ ! $flight_error = "0" ]] || [[ ! $flight_warn = "0" ]] ; then
	echo "ERROR: Something when wrong..."
	/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg > $work_dir/$Client_shortname.cfg.error_$timestamp.log					# Create error log
	mv $Nagios_Server_Folder/$Client_shortname.cfg $work_dir/												# Remove $Client_shortname.cfg
	echo "Please see error log: $work_dir/$Client_shortname.cfg.error_$timestamp.log"
	echo "Host configure: $work_dir/$Client_shortname.cfg"
	echo -e "Nagios pre-flight check failed on host" $Client_shortname "\n" | mailx -a $work_dir/$Client_shortname.cfg.error_$timestamp.log -s "Nagios pre-flight check failed at AdoptOpenJDK" brad_blondin@ca.ibm.com
	exit
fi
rm flight_check_$timestamp.log																	# All is good, remove log file
echo "Pre-flight checks have all passed"
sudo /usr/sbin/service nagios restart																# Restart the Nagios service to reload new configuration
echo "Nagios has been restart, have a nice day!"
