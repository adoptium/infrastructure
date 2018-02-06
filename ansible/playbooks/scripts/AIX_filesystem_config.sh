#!/bin/bash
##############################################################
# AdoptOpenJDK - Script to configure filesystem sizes on AIX #
##############################################################
#
##################
# Error Checking #
##################
#
if ! type bash >/dev/null 2>&1; then										                      # Ensure bash is installed
        echo "Error: Can't find bash, please ensure bash is installed. Exiting..."
        exit
fi
#
if ! [ $(id -u) = 0 ]; then											                              # Ensure we are root
	echo "Error: You must be root (userid 0) to execute this script. Exiting..."
	exit
fi
#
##############################
# Collect System Information #
##############################
#
Total_Disk_Size=`getconf DISK_SIZE /dev/hdisk0`    								          # Determine overall size of disk
Total_Disk_in_GB=`expr $Total_Disk_Size / 1024`    								          # Convert to GB
Maximum_Processes=`lsattr -E -l sys0 | grep maxuproc | awk '{print $2}'`
#
if [[ $Total_Disk_in_GB -lt "40" ]]; then									                  # Disk is too small for script
	echo "Error: Disk is too small (less than 40GB), manually configuration is required. Exiting..."
	exit
fi
#
# Determine the current size of the filesystems
cur_root=`df -g / | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_usr=`df -g /usr | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_var=`df -g /var | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_opt=`df -g /opt | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_tmp=`df -g /tmp | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_home=`df -g /home | tail -1 | awk '{print $2}' | sed 's/\..*//'`
#
# Display Debug Information
echo "******Debug Info: filesystem size******" 
echo "Total_Disk_Size:" $Total_Disk_Size
echo "Total_Disk_in_GB:" $Total_Disk_in_GB
echo "cur_root:" $cur_root
echo "cur_usr:" $cur_usr
echo "cur_var:" $cur_var
echo "cur_opt:" $cur_opt
echo "cur_tmp:" $cur_tmp
echo "cur_home:" $cur_home
echo "maxuproc:" $Maximum_Processes
echo "**************************************"
df -g
echo "**************************************"
#
######################################
# Ensure MAX LPs are set high enough #
######################################
#
chlv -x 2048 $(df -g / | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
chlv -x 2048 $(df -g /usr | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
chlv -x 2048 $(df -g /var | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
chlv -x 2048 $(df -g /opt | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
chlv -x 2048 $(df -g /tmp | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
chlv -x 2048 $(df -g /home | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
#
#############################################################
# Ensure Maximum Processes for parallel jobs is high enough #
#############################################################
#
if [[ $Maximum_Processes -le "512" ]]; then
	chdev -l sys0 -a maxuproc=512
fi
#
##############################
# Configure Filesystem Sizes #
##############################
#
############################################################
# If disk is less than or equal to 75GB but more than 40GB #
############################################################
if [[ $Total_Disk_in_GB -le "75" ]]; then
	##########
	# root / #
	##########
	if [[ $cur_root -lt "5" ]]; then
		add_root=`expr 5 - $cur_root`
		chfs -a size=+$add_root"G" /
	fi
	if [[ $cur_root -gt "5" ]]; then
		chfs -a size=5G /
	fi
	########
	# /usr #
	########
	if [[ $cur_usr -lt "10" ]]; then
		add_usr=`expr 10 - $cur_usr`
		chfs -a size=+$add_usr"G" /usr
	fi
	if [[ $cur_usr -gt "10" ]]; then
		chfs -a size=10G /usr
	fi
	########
	# /var #
	########
	if [[ $cur_var -lt "5" ]]; then
		add_var=`expr 5 - $cur_var`
		chfs -a size=+$add_var"G" /var
	fi
	if [[ $cur_var -gt "5" ]]; then
		chfs -a size=5G /var
	fi
	########
	# /opt #
	########
	if [[ $cur_opt -lt "10" ]]; then
		add_opt=`expr 10 - $cur_opt`
		chfs -a size=+$add_opt"G" /opt
	fi
	if [[ $cur_opt -gt "10" ]]; then
		chfs -a size=10G /opt
	fi
	########
	# /tmp #
	########
	if [[ $cur_tmp -lt "30" ]]; then
		add_tmp=`expr 30 - $cur_tmp`
		chfs -a size=+$add_tmp"G" /tmp
	fi
	if [[ $cur_tmp -gt "30" ]]; then
		chfs -a size=30G /tmp
	fi
	#########
	# /home #
	#########
	unallocated_disk=`lsvg rootvg  | grep "FREE" | sed 's/.*FREE PPs//' | awk '{print $3}' | sed 's/(//'`
	unall_disk_in_GB=`expr $unallocated_disk / 1024`
	chfs -a size=+$unall_disk_in_GB"G" /home
fi 
#
#############################################################
# If disk is less than or equal to 125GB but more than 75GB #
#############################################################
if [[ $Total_Disk_in_GB -gt "75" ]] && [[ $Total_Disk_in_GB -le "125" ]]; then  
	##########
	# root / #
	##########
	if [[ $cur_root -lt "10" ]]; then
		add_root=`expr 10 - $cur_root`
		chfs -a size=+$add_root"G" /
	fi
	if [[ $cur_root -gt "10" ]]; then
		chfs -a size=10G /
	fi
	########
	# /usr #
	########
	if [[ $cur_usr -lt "20" ]]; then
		add_usr=`expr 20 - $cur_usr`
		chfs -a size=+$add_usr"G" /usr
	fi
	if [[ $cur_usr -gt "20" ]]; then
		chfs -a size=20G /usr
	fi
	########
	# /var #
	########
	if [[ $cur_var -lt "10" ]]; then
		add_var=`expr 10 - $cur_var`
		chfs -a size=+$add_var"G" /var
	fi
	if [[ $cur_var -gt "10" ]]; then
		chfs -a size=10G /var
	fi
	########
	# /opt #
	########
	if [[ $cur_opt -lt "20" ]]; then
		add_opt=`expr 20 - $cur_opt`
		chfs -a size=+$add_usr"G" /opt
	fi
	if [[ $cur_opt -gt "20" ]]; then
		chfs -a size=20G /opt
	fi
	########
	# /tmp #
	########
        if [[ $cur_tmp -lt "30" ]]; then
                add_tmp=`expr 30 - $cur_tmp`
                chfs -a size=+$add_tmp"G" /tmp
        fi
        if [[ $cur_tmp -gt "30" ]]; then
                chfs -a size=30G /tmp
        fi
        #########
        # /home #
        #########
	unallocated_disk=`lsvg rootvg  | grep "FREE" | sed 's/.*FREE PPs//' | awk '{print $3}' | sed 's/(//'`
	unall_disk_in_GB=`expr $unallocated_disk / 1024`
	chfs -a size=+$unall_disk_in_GB"G" /home
fi
#
##############################################################
# If disk is less than or equal to 199GB but more than 125GB #
##############################################################
if [[ $Total_Disk_in_GB -gt "125" ]] && [[ $Total_Disk_in_GB -le "199" ]]; then  
	##########
	# root / #
	##########
	if [[ $cur_root -lt "20" ]]; then
		add_root=`expr 20 - $cur_root`
		chfs -a size=+$add_root"G" /
	fi
	if [[ $cur_root -gt "20" ]]; then
		chfs -a size=20G /
	fi
	########
	# /usr #
	########
	if [[ $cur_usr -lt "40" ]]; then
		add_usr=`expr 40 - $cur_usr`
		chfs -a size=+$add_usr"G" /usr
	fi
	if [[ $cur_usr -gt "40" ]]; then
		chfs -a size=40G /usr
	fi
	########
	# /var #
	########
	if [[ $cur_var -lt "20" ]]; then
		add_var=`expr 20 - $cur_var`
		chfs -a size=+$add_var"G" /var
	fi
	if [[ $cur_var -gt "20" ]]; then
		chfs -a size=20G /var
	fi
	########
	# /opt #
	########
	if [[ $cur_opt -lt "40" ]]; then
		add_opt=`expr 40 - $cur_opt`
		chfs -a size=+$add_usr"G" /opt
	fi
	if [[ $cur_opt -gt "40" ]]; then
		chfs -a size=40G /opt
	fi
	########
	# /tmp #
	########
        if [[ $cur_tmp -lt "30" ]]; then
                add_tmp=`expr 30 - $cur_tmp`
                chfs -a size=+$add_tmp"G" /tmp
        fi
        if [[ $cur_tmp -gt "30" ]]; then
                chfs -a size=30G /tmp
        fi
        #########
        # /home #
        #########
	unallocated_disk=`lsvg rootvg  | grep "FREE" | sed 's/.*FREE PPs//' | awk '{print $3}' | sed 's/(//'`
	unall_disk_in_GB=`expr $unallocated_disk / 1024`
	if [[ $unall_disk_in_GB -gt "100" ]]; then
		# Limit home to 100, leave the rest unallocated
		# If home is already larger than 100 leave it as is
		if [[ $cur_home -lt "100" ]]; then
			add_home=`expr 100 - $cur_home`
			chfs -a size=+$add_home"G" /home
		fi
	else
		chfs -a size=+$unall_disk_in_GB"G" /home
	fi
fi
#
#################################
# If disk is greater than 200GB #
#################################
if [[ $Total_Disk_in_GB -ge "200" ]]; then 
	chfs -a size=20G /
	chfs -a size=15G /usr
	chfs -a size=10G /var
	chfs -a size=15G /opt
	chfs -a size=30G /tmp
        # Limit home to 100, leave the rest unallocated
        # If home is already larger than 100 leave it as is
        unallocated_disk=`lsvg rootvg  | grep "FREE" | sed 's/.*FREE PPs//' | awk '{print $3}' | sed 's/(//'`
        unall_disk_in_GB=`expr $unallocated_disk / 1024`
        if [[ $unall_disk_in_GB -gt "100" ]]; then
                if [[ $cur_home -lt "100" ]]; then
                        add_home=`expr 100 - $cur_home`
                        chfs -a size=+$add_home"G" /home
                fi
        else
                chfs -a size=+$unall_disk_in_GB"G" /home
        fi
fi
#
##################################
# Determine new filesystem sizes #
##################################
#
new_root=`df -g / | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_usr=`df -g /usr | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_var=`df -g /var | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_opt=`df -g /opt | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_tmp=`df -g /tmp | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_home=`df -g /home | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_Maximum_Processes=`lsattr -E -l sys0 | grep maxuproc | awk '{print $2}'`
#
# Display Debug Information
echo "******Debug Info: filesystem size******" 
echo "new_root:" $new_root
echo "new_usr:" $new_usr
echo "new_var:" $new_var
echo "new_opt:" $new_opt
echo "new_tmp:" $new_tmp
echo "new_home:" $new_home
echo "maxuproc:" $new_Maximum_Processes
echo "**************************************"
df -g
echo "**************************************"
