#!/usr/bin/ksh
##############################################################
# AdoptOpenJDK - KSH Script to add a RAMDISK on AIX          #
##############################################################
# Called via ansible
#
RAMDISK=`mkramdisk 4G`
mkdir /ramdisk >/dev/null 2>&1
DEVICE="/dev/ramdisk`echo $RAMDISK | awk -F'ramdisk' '{print $2}'`"
echo "yes" | mkfs -V jfs $DEVICE
mount -V jfs -o nointegrity $DEVICE /ramdisk

exit
