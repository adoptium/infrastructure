
**Usage Guide :**

This document will cover a number of installation scenarios, firstly a standard installation on a typical Linux (Ubuntu) server, and secondly a set of instructions to cover creating a development or test server using vagrant.

Installing On A Linux Server
---------------------------------------

Ansible is required to run the playbooks, either directly on the Nagios server host, or alternatively from an Ansible machine with the ability to connect to the Nagios server. The playbooks will need to run as the root user, as it will need to install a number of packages, and create a "nagios" user, for the server to run as.

1) Prior to running the Nagios server installation playbook, ensure the ansible.cfg, nagios_inventory and the secrets_setup_server.enc vault file have been updated as necessary. This is detailed in the main README.MD file.

2) To run the first playbook (which will create a base nagios server installation)

    ansible-playbook -b play_setup_server.yml --ask-vault-pass  

3) Once this is completed, the Nagios server will be accessible via the Web UI, (access via http://nagios.server.id/nagios), replacing the nagios.server.id with the IP address or hostname for the server Nagios has been installed on.

4) The next step in the installation process is to run they play_config_server.yml playbook, however prior to that, there are a few important details, that should be checked/amended as required to suit. The configuration playbook, requires a few key elements to be configured (these are currently configured to work within the context of the Adoptium infrastructure, but can be amended).

Firstly within the vars_configure_server.yml file, there is a path to an Ansible inventory file, by default it is configured to use a link to a RAW yml file stored within Github.

  `inventory_path: https://raw.githubusercontent.com/adoptium/infrastructure/master/ansible/inventory.yml`

This inventory file is created using the following system of tiered stanzas, e.g

test-osuosl-aix72-ppc64-4 (Function - Provider - O/S - Architecture - Counter)

More details can be found within the (public inventory file)[https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml] and within the documentation contained within the (infrastructure repository)[https://github.com/adoptium/infrastructure/]



Additional Notes For Installing Using Vagrant
---------------------------------------

3) For Windows users getting this error when trying to run the playbook
```bash
	[WARNING]: Ansible is being run in a world writable directory (/vagrant), ignoring it as an ansible.cfg source
```
edit your Vagrantfile and add  
`, id: "vagrant-root", disabled: false, mount_options: ["dmode=775"]`
to the `nagios_server.vm.synced_folder ".", "/vagrant"` line



Notes
----------------------------------------
This guide (and the automation of nagios server installation and configuration) has been based off the [official Nagios installation guide](https://support.nagios.com/kb/article/nagios-core-installing-nagios-core-from-source-96.html): and this [GitRepo](https://github.com/Willsparker/AnsibleBoilerPlates/tree/main/Nagios) :

For additional documentation regarding Nagios see this link [Nagios HTML Docs](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/index.html)

For some useful tips for working with vault files see [here](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
