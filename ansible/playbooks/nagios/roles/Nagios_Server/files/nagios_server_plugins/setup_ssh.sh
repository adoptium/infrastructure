#!/bin/bash
# ********************************************************************************
# Copyright (c) 2024 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made
# available under the terms of the Apache Software License 2.0
# which is available at https://www.apache.org/licenses/LICENSE-2.0.
#
# SPDX-License-Identifier: Apache-2.0
# ********************************************************************************

# This script runs on the Nagios server as the nagios user,
# and will attempt to setup the SSH connections for each and every host in the Inventory
# ( as the nagios user defined below )

# URL of the Ansible Inventory File
INVENTORY_URL="https://raw.githubusercontent.com/adoptium/infrastructure/master/ansible/inventory.yml"
# List Of Excluded IP Addresses ( Infra + windows )
EXCLUDE_FILE=/usr/local/nagios/libexec/excluded_ips.list
# Nagios Connection User
USER="nagios"

# Download the Ansible Inventory file
curl -s -O "$INVENTORY_URL"

# Check if the file was downloaded
if [[ ! -f inventory.yml ]]; then
  echo "Failed to download inventory.yml"
  exit 1
fi

# Function to extract hosts and attempt SSH connection
add_ssh_keys() {
  local host_ip=$1
  local host_port=$2
  local ssh_cmd

  CHECK=`cat $EXCLUDE_FILE|grep $host_ip|wc -l`

  if [ $CHECK -gt 0 ]; then
    echo "Skipped : $host_ip is in the exclusion list"
  else
    # Fetch the hostname using nslookup (dig can be used as an alternative)
    HOST=$(nslookup $host_ip | grep 'name =' | awk '{print $4}' | sed 's/.$//')

    # If nslookup fails, HOST will be empty, so we can set it to the IP itself
    if [ -z "$HOST" ]; then
      HOST=$host_ip
    fi

    # Fetch the host key and add it to known_hosts
    ssh-keyscan -H $HOST >> ~/.ssh/known_hosts 2>/dev/null
    KEYSCAN_RESULT=$?

    if [ $KEYSCAN_RESULT -gt 0 ]; then
      echo "Failure : $host_ip has failed the Key Scan - Please Check & Add Manually If Required"
    else
      echo "Success : Keys Added Successfully For : $host_ip"
    fi
  fi
}

# Parse the YAML file and extract IP addresses and ports
while read -r line; do
  if [[ $line =~ ip:\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
    host_ip=${BASH_REMATCH[1]}
    if [[ $line =~ port:\ ([0-9]+) ]]; then
      host_port=${BASH_REMATCH[1]}
    else
      host_port=""
    fi
    add_ssh_keys "$host_ip" "$host_port"
  elif [[ $line =~ ip:\ ([a-zA-Z0-9\.]+) ]]; then
    host_ip=${BASH_REMATCH[1]}
    if [[ $line =~ port:\ ([0-9]+) ]]; then
      host_port=${BASH_REMATCH[1]}
    else
      host_port=""
    fi
    add_ssh_keys "$host_ip" "$host_port"
  fi
done < inventory.yml

# Clean up the downloaded file
rm -f inventory.yml
