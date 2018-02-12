#!/bin/bash
# Script to establish Reverse SSH Tunnel to the Nagios server
# Workaround for clients where the Nagios server don't have a direct connection (NAT, Firewalled, etc) 
#
#############
# Variables #
#############
REMOTE_HOST="ReplaceNAGIOSMASTERADDRESS"
USER_NAME="nagios"
REMOTE_PORT="ReplacePortNumber"
LOCAL_PORT="22"
LOGIN_PORT="22"
IDENTITY_KEY="/home/nagios/.ssh/Adopt_Tunnel_User.key"
#
###########
# Command #
###########
Reverse_Tunnel="ssh -o StrictHostKeyChecking=no -f -n -N -R $REMOTE_PORT:127.0.0.1:$LOCAL_PORT $USER_NAME@$REMOTE_HOST -p $LOGIN_PORT -i $IDENTITY_KEY"
# Running? if not start it
pgrep -f -x "$Reverse_Tunnel" > /dev/null 2>&1 || $Reverse_Tunnel
