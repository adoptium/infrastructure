#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import argparse
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

valid_types = ('build', 'dockerhost', 'test')

def main():

    # load config file for special cases
    config = configparser.RawConfigParser()
    config.read('ansible.cfg')

    # load public inventory
    basepath = path.dirname(__file__)
    inventory_path = "/tmp/ansible_inventory.yml"
    export = parse_yaml(load_yaml_file(inventory_path), config)

    # export in JSON for Ansible
    # print(json.dumps(export, sort_keys=True, indent=2))


# https://stackoverflow.com/a/7205107
def merge(a, b, path=None):
    "merges b into a"
    path = path or []
    for key in b:
        if key in a:
            if isinstance(a[key], dict) and isinstance(b[key], dict):
                merge(a[key], b[key], path + [str(key)])
            elif isinstance(a[key], list) and isinstance(b[key], list):
                a[key] = sorted(set(a[key]).union(b[key]))
            elif a[key] == b[key]:
                pass  # same leaf value
            else:
                raise Exception('Conflict at %s' % '.'.join(path + [str(key)]))
        else:
            a[key] = b[key]
    return a

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
                        if (host_type) in (valid_types):
                            formatted_name = host_type+'-'+provider_name+'-'+host
                            # Creates a file with the .cfg extension using the output
                            with open(f"{formatted_name}.cfg", "w") as f:
                                f.write(f"Configuration for {formatted_name}")

                        export[host_type]['hosts'].sort()
    return export

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--host', action='store')
    args = parser.parse_args()

    main()
