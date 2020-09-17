#!/usr/bin/ksh -e
##############################################################
# AdoptOpenJDK - Script to configure filesystem sizes on AIX #
# Stop script on error (-e option)
##############################################################
#
##################
# Check for ROOT #
##################
#
if ! [ $(id -u) = 0 ]; then								# Ensure we are root
	echo "Error: You must be root (userid 0) to execute this script. Exiting..."
	exit 127									# Not running as root
fi
#
# Must specify full path, incase GNU df is earlier in PATH
DF="/usr/bin/df"
##############################
# Collect System Information #
##############################
#
# LQUERYVG returns low-level statistics (no text) about the VG
# by using the bootdisk $(bootinfo -b) we get the VG rootvg
# By putting two lines in an environment variable we strip the newline
# and can use awk to multiple the two arguments
NP_SZ=$(lqueryvg -p $(bootinfo -b) -a | head -15 | tail -2)
Total_VG_in_MB=$(echo ${NP_SZ} | awk '{print $1 * $2 }'
# 40G disk has 40960 PP of 128 MB each.
# 40960 - 40832 is 128 PP for VGDA storage - not included in VG size
# So we test for 40832 as smallest accepted value
# assumes single disk volume group
if [[ $Total_VG_in_MB -lt "40832" ]]; then						# Disk is too small
	echo "Error: Disk is too small (less than 40GB), manual configuration is required. Exiting..."
	exit 125									# Disk too small
fi
Total_VG_in_GB=$(expr $Total_VG_in_MB / 1024)						# Convert to GB
#
# Determine the current size of the filesystems
cur_root=`${DF} -g / | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_usr=`${DF} -g /usr | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_var=`${DF} -g /var | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_opt=`${DF} -g /opt | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_tmp=`${DF} -g /tmp | tail -1 | awk '{print $2}' | sed 's/\..*//'`
cur_home=`${DF} -g /home | tail -1 | awk '{print $2}' | sed 's/\..*//'`
#
lsattr -E -l sys0 -a maxuproc | read attr Maximum_Processes rest			# Read Maximum_Processes
#
# Display Debug Information
echo "******Debug Info: filesystem size******" 
echo "Total_VG_in_GB:" $Total_VG_in_GB
echo "cur_root:" $cur_root
echo "cur_usr:" $cur_usr
echo "cur_var:" $cur_var
echo "cur_opt:" $cur_opt
echo "cur_tmp:" $cur_tmp
echo "cur_home:" $cur_home
echo "maxuproc:" $Maximum_Processes
echo "**************************************"
${DF} -g
echo "**************************************"
#
#############################################################
# Ensure Maximum Processes for parallel jobs is high enough #
#############################################################
#
if [[ $Maximum_Processes -le "512" ]]; then
	chdev -l sys0 -a maxuproc=512
fi
#
#
##
## Leave section for historical reference, however, for now,
## accept system default of 512 logical partitions as sufficient 
######################################
# Ensure MAX LPs are set high enough #
######################################
## 
## device names are known - or you have a hacked (non-representative) AIX system.
# for lp in hd4 hd2 hd9var hd10 hd3 ; do
# chlv -x 2048 ${lp}
# done
## For /home that sometimes is not on /hd1
# chlv -x 2048 $(${DF} -g /home | tail -1 | awk '{print $1}' | sed 's/\/dev\///')
##
##############################
# Configure Filesystem Sizes #
##############################
############################################################
# In normal operations AIX does this 'on demand'
# These values are the starting point - based on 40G disk
############################################################
[[ $cur_root -ne "2" ]] && chfs -a size=2G /
[[ $cur_usr -ne "6" ]] && chfs -a size=6G /usr
[[ $cur_opt -ne "3" ]] && chfs -a size=3G /opt
# Temporary files /tmp, /var/tmp and (sys)logging /var/{log|adm}
[[ $cur_var -ne "4" ]] && chfs -a size=4G /var
[[ $cur_tmp -ne "6" ]] && chfs -a size=6G /tmp
####################################################################################
# /home is 15G as starting point - if not suffficient will need additional storage #
####################################################################################
chfs -a size=15G /home
#
##################################
# Determine new filesystem sizes #
##################################
#
new_root=`${DF} -g / | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_usr=`${DF} -g /usr | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_var=`${DF} -g /var | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_opt=`${DF} -g /opt | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_tmp=`${DF} -g /tmp | tail -1 | awk '{print $2}' | sed 's/\..*//'`
new_home=`${DF} -g /home | tail -1 | awk '{print $2}' | sed 's/\..*//'`
lsattr -E -l sys0 -a maxuproc | read attr new_Maximum_Processes rest			# Read new_Maximum_Processes
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
${DF} -g
echo "**************************************"
