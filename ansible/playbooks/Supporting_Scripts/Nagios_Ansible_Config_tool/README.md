# Nagios Ansible Config Tool

This is an automation tool to automatically add client systems to Nagios monitoring via Ansible.

Currently the tool only supports Unix. 

## How to use the tool

This script is executed on the Nagios Master, and assumes the following:
  - The Nagios Plugins are already installed on the client system
  - The Nagios user and it's ssh key is configured
  - The Nagios client is using an IPv4 address.

The script expects 6 command line arguments to be passed to it from Ansible, in the following order:

```bash
{{ ansible_distribution }} {{ ansible_architecture }} {{ inventory_hostname }} {{ ansible_host }} {{ provider }} {{ ansible_port }}
```

https://github.com/adoptium/infrastructure/issues/1670 is being used to track replacing the tool with a purely Ansible approach to setting up Nagios monitoring
