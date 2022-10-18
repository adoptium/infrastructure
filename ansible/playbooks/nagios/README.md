**IMPORTANT!**

Currently the Nagios server (4.4.7) installation playbook has only been developed and tested on Ubuntu 22.04. Changes will be required if you wish to install a Nagios Server on a different host OS

Ensure to update the ansible.cfg and nagios_inventory.yml files before running this playbook.

**Repository Contents:**

README.MD (This File)

1) ./VagrantFiles/

  This directory contains a vagrantfile that can be used to create a test server for running the Nagios_Server playbook on.

  **NB: For the Ubuntu 2204 Vagrantfile, its recommended to use a minimum Vagrant version of 2.2.19-1**

2) ./roles/*

This directory houses the ansible roles used in the creation of the nagios server.

3) ansible.cfg

This is the default configuration file for ansible

4) nagios_inventory.yml

This file is a simple ansible inventory file used for creating the nagios server, it only has a single entry which can be swapped in/out for running on a vagrant localhost

5)  play_setup_server.yml

This is the playbook for installing the nagios server from scratch, it depends on the other 2 files (vars_setup_server.yml secrets_setup_server.enc) and contained within this directory

    - vars_setup_server.yml - contains a list of variable defaults for a typical installation.
    - secrets_setup_server.enc - is an ansible vault containing the default nagios admin password, and the slack webhook URL.

This was created by encrypting a plain text file, as per the example below :

    ansible-vault encrypt secrets_setup_server.enc

The Encrypted File Contains 2 Sensitive Pieces Of Information.

    nagios_admin_pass: xxxxxxxxxx
    slack_webhook: xxxxxxxxxx

The Encrypted File Can Be Edited Using The Following Command (With The Relevant Password)

    ansible-vault edit secrets_setup_server.enc

The Encrypted File Can Have Its Password Changed With The Following command

    ansible-vault rekey secrets_setup_server.enc


**Usage Guide :**

1) Prior to running the nagios server installation playbook, ensure the ansible.cfg, nagios_inventory and the secrets_setup_server.enc vault file have been updated as necessary.

2) Either directly on the nagios server host (ansible must be installed), or alternatively from an ansible machine with connection to the nagios server to be.

    ansible-playbook -b play_setup_server.yml --ask-vault-pass

Based off the [installation guide](https://support.nagios.com/kb/article/nagios-core-installing-nagios-core-from-source-96.html):
And Off This [GitRepo](https://github.com/Willsparker/AnsibleBoilerPlates/tree/main/Nagios) :
For some useful tips for working with vault files see [here](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

### How to update a host group name to the nagios core configurations

* The hostgroups.cfg can be located at

```bash
/usr/local/nagios/etc/objects/hostgroups.cfg
```

* Navigate to

```bash
cd /usr/local/nagios/etc/objects
```

* Open hostgroups.cfg in a text editor

```bash
vi hostgroups.cfg
```

* After opening the `hostgroups.cfg` update the host group name in the code related to the following block of code.

```bash
define hostgroup {
    hostgroup_name  linuxubuntu
    alias           linux-ubuntu
}
```

* Move a directory up and then edit the nagios.cfg file:

```bash
cd ..
vi nagios.cfg
```

* Check whether the config file is declared in nagios.cfg. It should look like this

```bash
cfg_file=/usr/local/nagios/etc/objects/hostgroups.cfg
```

and can be added if there is non

* For each of the hosts we want to be part of the group, find their definitions and update a hostgroups directive to put them into the updated hostgroup. In this case, our definitions for sparta.example.net and athens.example.net ends up looking like this: The hostgroups name can be updated to the corresponding name `linuxubuntu`

```bash
define host {
    use         linux-server
    host_name   khan.example.net
    alias       khan
    address     192.0.2.21
    hostgroups  linuxubuntu
}
define host {
    use         linux-server
    host_name   khu.example.net
    alias       khu
    address     192.0.2.22
    hostgroups  linuxubuntu
}
```

* Restart Nagios:

```bash
/etc/init.d/nagios reload
```
