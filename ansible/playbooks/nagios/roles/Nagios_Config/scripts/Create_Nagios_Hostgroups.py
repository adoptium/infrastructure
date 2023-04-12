#!/usr/bin/python3
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import os
import subprocess
import sys
from os import path

import Nagios_Server_Config
excluded_hosts = Nagios_Server_Config.excluded_hosts

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

    ## Get A Unique List Of The Infrastructure Providers
    providerList=[]
    uniqProvider=[]
    hostList=[]
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
                                if formatted_name not in hostList and formatted_name not in excluded_hosts:
                                    hostList.append(formatted_name)
                                    providerList.append(provider_name)
                    for provider_name in providerList:
                         if provider_name not in uniqProvider:
                             uniqProvider.append(provider_name)

    with open(f"{Output_Path}/hostgroups.cfg", "w") as f:
     for hostgroup in uniqProvider:
        f.write('define hostgroup{'+'\n')
        f.write('hostgroup_name'+'\t'+hostgroup+'\n')
        f.write('alias'+'\t\t'+hostgroup+'\n')
        hostsList=[]
        for eachhost in hostList:
            index = eachhost.find(hostgroup)
            if index != -1:
               hostsList.append(eachhost)

        seperator=','
        hosts=str(seperator.join(hostsList))
        f.write('members\t\t'+hosts+'\n')
        f.write('}'+'\n')

    return export

if __name__ == "__main__":
    main()
