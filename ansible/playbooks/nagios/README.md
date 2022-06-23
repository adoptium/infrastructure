**IMPORTANT!**

Currently the Nagios server installation playbook has only been developed and tested on Ubuntu 22.04. Changes will be required if you wish to install a Nagios Server on a different host O/S/

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

This is the playbook for installing the nagios server from scratch, it depends on the other 2 files contained within this directory

    - vars_setup_server.yml - contains a list of variable defaults for a typical installation.
    - secrets_setup_server.yml - is an ansible vault containing the default nagios admin password

    This was created by encrypting a plain text file, as per the example below :

    ansible-vault encrypt secrets_setup_server.yml, where the contents of the unencrypted file look like below (password is an example)

    ```nagios_admin_pass: password123```

Usage Guide :

1) Either directly on the nagios server host (ansible must be installed), or alternatively from an ansible machine with connection to the nagios server to be.

    ansible-playbook -b play_setup_server.yml --ask-vault-pass

Based off the [installation guide](https://support.nagios.com/kb/article/nagios-core-installing-nagios-core-from-source-96.html): 
And Off This [GitRepo](https://github.com/Willsparker/AnsibleBoilerPlates/tree/main/Nagios) : 
