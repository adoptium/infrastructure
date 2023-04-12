
**Usage Guide :**

1) Prior to running the Nagios server installation playbook, ensure the ansible.cfg, nagios_inventory and the secrets_setup_server.enc vault file have been updated as necessary. You will also need to uncomment the line from the play_setup_server.yml file to include the new Ansible vault file.
```
  vars_files:
    **# - secrets_setup_server.enc**
    - vars_setup_server.yml
```

2) Either directly on the Nagios server host (Ansible must be installed), or alternatively from an Ansible machine with connection to the Nagios server to be.

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
```

### How to Add Additional Disk Space Check For /tmp on AIX hosts

* The commands configuration file `commands.cfg` can be located at

```bash
/usr/local/nagios/etc/objects/commands.cfg

add_disk_space_check
## How to add additional disk space check for /home/jenkins on AIX hosts.

Additional checks are defined and added to host specific config files (located in the /usr/local/nagios/etc/servers directory) in the Nagios monitoring server. The steps include :

1) Define the command in the commands.cfg file located at /usr/local/nagios/etc/objects/commands.cfg :  
```bash
	# 'check_jenkins_disk' command definition
	define command{
	command_name	check_jenkins_disk
	command_line	$USER1$/check_disk -w $ARG1$ -c $ARG2$ -p $ARG3$
	}
```
2) Amend the machine specific config file, e.g ( /usr/local/nagios/etc/servers/build-osuosl-aix71-ppc64-1.cfg ) to include the entry for the new check.  

```bash
	define service {
		use				generic-service
		host_name			AIX host name goes here
		service_description		Disk Space check for Jenkins
		check_command			check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /home/jenkins
		check_interval			60
	}
```  
The second step above is repeated for all AIX hosts in the /usr/local/nagios/etc/servers directory.  

### How to update a host group name to the Nagios core configurations

* The hostgroups.cfg can be located at

```bash
/usr/local/nagios/etc/objects/hostgroups.cfg
```

* Navigate to

```bash
cd /usr/local/nagios/etc/objects
```

* Open commands.cfg in a text editor

```bash
nano commands.cfg
```

* `check_tmp_disk` command definition

```bash
define command{
	    command_name	check_tmp_disk
	    command_line	$USER1$/check_disk -w $ARG1$ -c $ARG2$ -p $ARG3$
	}

```
* Point the machine to a specific configuration(`.cfg`) file where to spin from for the tmp disk check. These configuration files can be found in this directory

```bash
/usr/local/nagios/etc/servers/example.cfg
```

* Open example.cfg in a text editor

```bash
nano example.cfg
```

* The configuration file should look like this

```bash
define service{
    use                      generic-service
    host_name                machine host name goes here
    service_description      Disk Space check for tmp
    check_command            check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /tmp
    check_interval           40
}
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
