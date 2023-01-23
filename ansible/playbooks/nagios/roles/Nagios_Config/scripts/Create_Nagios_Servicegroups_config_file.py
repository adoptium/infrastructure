#!/usr/bin/python3
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import os
import subprocess
import sys
from os import path

import yaml
try:
    import configparser
except ImportError:
    import ConfigParser as configparser

Input_Path = sys.argv[1]
Output_Path = sys.argv[2]
Nagios_Service_Types = sys.argv[3]

def main():

    # load config file for special cases
    config = configparser.RawConfigParser()
    config.read('ansible.cfg')

    # load public inventory
    basepath = path.dirname(__file__)
    inventory_path = Input_Path
    export = parse_yaml(load_yaml_file(inventory_path), config)

    # export in JSON for Ansible
    # print(json.dumps(export, sort_keys=True, indent=2))

def load_yaml_file(file_name):
    """Loads YAML data from a file"""

    hosts = {}

    # get inventory
    with open(file_name, 'r') as stream:
        try:
            hosts = yaml.safe_load(stream)

        except yaml.YAMLError as exc:
            print(exc)
        finally:
            stream.close()

    return hosts

def parse_yaml(hosts, config):
    """Parses host information from the output of yaml.safe_load"""

    export = {'_meta': {'hostvars': {}}}

    for host_types in hosts['hosts']:
        for host_type, providers in host_types.items():
            export[host_type] = {}
            export[host_type]['hosts'] = []

            key = '~/.ssh/id_rsa'
            export[host_type]['vars'] = {
                'ansible_ssh_private_key_file': key
            }

            for provider in providers:
                #print (provider)
                for provider_name, hosts in provider.items():
                    #print (provider_name)
                    for host, metadata in hosts.items():
                        #print(host_type,'-',provider_name,'-',host)
                        # some hosts have metadata appended to provider
                        # which requires underscore
                        delimiter = "_" if host.count('-') == 3 else "-"
                        hostname = '{}-{}{}{}'.format(host_type, provider_name, delimiter, host)
                        export[host_type]['hosts'].append(hostname)
                        hostvars = {}

                        service_list=Nagios_Service_Types.split(" ")

                for service in service_list:
                       if host_type==service:
                           formatted_name = host_type+'-'+provider_name+'-'+host
                           servicegroup_name = host_type + '-' + provider_name
                           servicegroup_alias = host_type + '-' + provider_name + '-' + host
        
               # Add service group information to servicegroups.cfg file
                       with open(f"{Output_Path}/servicegroups.cfg", "a") as s:
                        s.write(f"define servicegroup{{\n")
                        s.write(f"  servicegroup_name {servicegroup_name}\n")
                        s.write(f"  alias {servicegroup_alias}\n")
                        s.write(f"}}\n")

                export[host_type]['hosts'].sort()
           
if __name__ == "__main__":

    main()
