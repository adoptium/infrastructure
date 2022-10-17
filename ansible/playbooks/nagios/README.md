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
3) For Windows users getting this error when trying to run the playbook
```bash
	[WARNING]: Ansible is being run in a world writable directory (/vagrant), ignoring it as an ansible.cfg source
```
edit your Vagrantfile and add  
`, id: "vagrant-root", disabled: false, mount_options: ["dmode=775"]`
to the `nagios_server.vm.synced_folder ".", "/vagrant"` line

Based off the [installation guide](https://support.nagios.com/kb/article/nagios-core-installing-nagios-core-from-source-96.html):
And Off This [GitRepo](https://github.com/Willsparker/AnsibleBoilerPlates/tree/main/Nagios) :
For some useful tips for working with vault files see [here](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

**Nagios Automation :**
Task: Add additional disk space check for /home/jenkins on AIX hosts
  
The following files were edited  
1) /usr/local/nagios/etc/objects/commands.cfg :  
```bash
	# 'check_jenkins_disk' command definition
	define command{
	command_name	check_jenkins_disk
	command_line	$USER1$/check_disk -w $ARG1$ -c $ARG2$ -p $ARG3$
	}
```
2) /usr/local/nagios/etc/servers/build-osuosl-aix71-ppc64-1  :
```bash
	define service{
		use				generic-service
		host_name			build-osuosl-aix71-ppc64-1
		service_description		Disk Space check for Jenkins
		check_command			check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /home/jenkins
		check_interval			60
	}
```  
3) /usr/local/nagios/etc/servers/build-osuosl-aix71-ppc64-2  :
```bash
        define service{
                use                             generic-service
                host_name                       build-osuosl-aix71-ppc64-2
                service_description             Disk Space check for Jenkins
                check_command                   check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /home/jenkins
                check_interval                  60
        }
```
4) /usr/local/nagios/etc/servers/build-osuosl-aix72-ppc64-1  :
```bash
        define service{
                use                             generic-service
                host_name                       build-osuosl-aix72-ppc64-1
                service_description             Disk Space check for Jenkins
                check_command                   check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /home/jenkins
                check_interval                  60
        }
```
