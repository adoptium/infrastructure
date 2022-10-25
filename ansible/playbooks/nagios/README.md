

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

## How to add additional Jenkins Check Label Job To Nagios server group For Windows ##

*  Amend the Nagios server config file, e.g ( /usr/local/nagios/etc/objects/localhost.cfg ) to include the entry for the new label check.

```bash
	define service{
        use                             local-service
        host_name                       Nagios_Server
        check_period                    once-a-day-at-8
        service_description             Check Label- build/windows/x64
        check_command                   check_label!build&&windows&&x64!75!30
        notifications_enabled           0
	}
``
