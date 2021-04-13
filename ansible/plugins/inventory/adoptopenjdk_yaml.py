#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright Node.js contributors. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#

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

valid = {
  # taken from nodejs/node.git: ./configure
  'arch': ('armv7', 'armv8', 'ppc64le', 'ppc64', 'x64', 's390x', 'arm64', 'sparcv9' , 'riscv64'),

  # valid roles - add as necessary
  'type': ('build', 'test', 'infrastructure', 'docker'),

  # providers - validated for consistency
  'provider': ('alibaba', 'azure', 'marist', 'osuosl', 'scaleway',
        'macstadium', 'macincloud', 'ibmcloud', 'spearhead',
        'packet', 'linaro','digitalocean', 'ibm', 'godaddy',
        'aws', 'inspira', 'packet_esxi', 'nine', 'gdams')
}

def main():

    # load config file for special cases
    config = configparser.RawConfigParser()
    config.read('ansible.cfg')

    # load public inventory
    basepath = path.dirname(__file__)
    inventory_path = path.abspath(path.join(basepath, "..", "..", "inventory.yml"))
    export = parse_yaml(load_yaml_file(inventory_path), config)

    # export in JSON for Ansible
    print(json.dumps(export, sort_keys=True, indent=2))


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
                for provider_name, hosts in provider.items():
                    for host, metadata in hosts.items():

                        # some hosts have metadata appended to provider
                        # which requires underscore
                        delimiter = "_" if host.count('-') == 3 else "-"
                        hostname = '{}-{}{}{}'.format(host_type, provider_name,
                                                      delimiter, host)

                        export[host_type]['hosts'].append(hostname)

                        hostvars = {}

                        try:
                            parsed_host = parse_host(hostname)
                            for k, v in parsed_host.items():
                                hostvars.update({k: v[0] if type(v) is dict else v})
                        except Exception as e:
                            raise Exception('Failed to parse host: %s' % e)

                        if 'ip' in metadata:
                            hostvars.update({'ansible_host': metadata['ip']})
                            del metadata['ip']

                        if 'port' in metadata:
                            hostvars.update({'ansible_port': str(metadata['port'])})
                            del metadata['port']

                        if 'user' in metadata:
                            hostvars.update({'ansible_user': metadata['user']})
                            if 'win' not in hostname:
                                hostvars.update({'ansible_become': True})
                            del metadata['user']

                        if 'password' in metadata:
                            hostvars.update({'ansible_password': str(metadata['password'])})
                            del metadata['password']

                        hostvars.update(metadata)

                        # add specific options from config
                        for option in filter(lambda s: s.startswith('hosts:'),
                                             config.sections()):
                            # remove `hosts:`
                            if option[6:] in hostname:
                                for o in config.items(option):
                                    # configparser returns tuples of key, value
                                    hostvars.update({o[0]: o[1]})

                        export['_meta']['hostvars'][hostname] = {}
                        export['_meta']['hostvars'][hostname].update(hostvars)

            export[host_type]['hosts'].sort()

    return export

def parse_host(host):
    """Parses a host and validates it against our naming conventions"""

    hostinfo = dict()
    info = host.split('-')

    expected = ['type', 'provider', 'os', 'arch', 'uid']

    if len(info) != 5:
        raise Exception('Host format is invalid: %s,' % host)

    for key, item in enumerate(expected):
        hostinfo[item] = has_metadata(info[key])

    for item in ['type', 'provider', 'arch']:
        if hostinfo[item] not in valid[item]:
            raise Exception('Invalid %s: %s' % (item, hostinfo[item]))

    return hostinfo


def has_metadata(info):
    """
    Checks for metadata in variables. These are separated from the "key"
    metadata by underscore. Not used anywhere at the moment for anything
    other than descriptiveness
    """

    metadata = info.split('_', 1)

    try:
        key = metadata[0]
        metadata = metadata[1]
    except IndexError:
        metadata = False
        key = info

    return key if metadata else info


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--host', action='store')
    args = parser.parse_args()

    main()
