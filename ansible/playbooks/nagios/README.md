**IMPORTANT!**

Currently the Nagios server (4.4.7) installation playbook has only been developed and tested on Ubuntu 22.04. Changes will be required if you wish to install a Nagios Server on a different host OS

Ensure to update the ansible.cfg and nagios_inventory.yml files before running this playbook.

Its also important to note, that  machines being added to to the Nagios server for monitoring, may need software installing on themselves also (the Nagios plugins, and the NSClient software in the case of Windows based machines). Any additional software required, is installed by the regular Adoptium infrastructure playbooks, found within this repository.

For hints, and examples on using these playbooks, check out the supplied USAGE_GUIDE.md found inside the documentation directory.

**Repository Contents:**

README.MD (This File)

**1) ./documentation/**

  This directory contains supplemental documentation, which may be useful when using theses Nagios playbooks.

**2) ./VagrantFiles/**

  This directory contains a vagrantfile that can be used to create a test server for running the Nagios_Server playbook on.

  **NB: For the Ubuntu 2204 Vagrantfile, its recommended to use a minimum Vagrant version of 2.2.19-1**

**3) ./roles/***

This directory houses the Ansible roles used in the creation and configuration of the Nagios server, there are two key roles with defined purposes, they can be used independently to perform their specific purpose, or alternatively run one after another. There is further documentation within each role, detailing further technical details on how they work.

 - ./roles/Nagios_Server
    This role will create a base Nagios server, with default monitoring options for the Nagios server itself.

- ./roles/Nagios_Config
- This role will create the Nagios server configuration files based on an Ansible inventory file in a defined format, and the mapping templates defined within the role.

Some more details about how this role works can be found in the documentation/USAGE_GUIDE.MD document.

**4) ansible.cfg**

This is the default configuration file for Ansible and contains some standard options, along with some commented options related to using the supplied vagrantfile for creating a development,test or demonstration environment.

**5) nagios_inventory.yml**

This file is a simple Ansible inventory file used for creating the Nagios server, it only has a single entry of the servers IP address, which can be swapped in/out when running on a vagrant(or similar) localhost.

**6)  play_setup_server.yml**

This is the playbook for installing the Nagios server from scratch, it depends on 2 additional files (vars_setup_server.yml secrets_setup_server.enc) contained within this directory

   - vars_setup_server.yml - contains a list of variable defaults for a typical installation.

   - secrets_setup_server.enc - is an Ansible vault containing the default Nagios admin password, and the slack webhook URL. It is supplied with dummy entries, which should be changed prior to running the playbook.

        nagios_admin_pass: xxxxxxxxxx
        slack_webhook: xxxxxxxxxx

Once the values in the file have been edited, the file can be encrypted to protect the values.

    ansible-vault encrypt secrets_setup_server.enc

The Encrypted File Can Be Edited Using The Following Command (With The Relevant Password)

    ansible-vault edit secrets_setup_server.enc

The Encrypted File Can Have Its Password Changed With The Following command

    ansible-vault rekey secrets_setup_server.enc

**7)  play_config_server.yml**

This is the playbook for configuring a Nagios server created using the play_setup_server playbook, it depends on a single additional file (vars_configure_server.yml) contained within this directory

**8) vars_configure_server.yml**
This file contains a list of variable defaults for a typical installation.
