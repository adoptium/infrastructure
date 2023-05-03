This document details a few examples of the manual processes involved in adding additional checks on the Nagios server, and amending the configuration files for individual hosts. This process has been automated by the Nagios_Config role in ansible, but this provides useful context.

### Important Notes On Amending Nagios Configuration Files Manually

Firstly before amending any Nagios config files, it is important to back up the files PRIOR to editing, the configuration files are sensitive to interrelated changes, so backups of any files being edited must be made.

Secondly, the Nagios server provides the ability to validate any config files, prior to restarting the Nagios server service

    /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

The output of this command, will show any errors in the configuration files , which must be reverted or corrected prior to restarting the Nagios service to pick up changes.

Sample Output

    Nagios Core 4.4.6
    Copyright (c) 2009-present Nagios Core Development Team and Community Contributors
    Copyright (c) 1999-2009 Ethan Galstad
    Last Modified: 2020-04-28
    License: GPL

    Website: https://www.nagios.org
    Reading configuration data...
       Read main config file okay...
       Read object config files okay...

    Running pre-flight check on configuration data...

    Checking objects...
    	Checked 478 services.
    	Checked 74 hosts.
    	Checked 14 host groups.
    	Checked 3 service groups.
    	Checked 1 contacts.
    	Checked 1 contact groups.
    	Checked 49 commands.
    	Checked 6 time periods.
    	Checked 0 host escalations.
    	Checked 0 service escalations.
    Checking for circular paths...
    	Checked 74 hosts
    	Checked 0 service dependencies
    	Checked 0 host dependencies
    	Checked 6 timeperiods
    Checking global event handlers...
    Checking obsessive compulsive processor commands...
    Checking misc settings...

    Total Warnings: 0
    Total Errors:   0

Finally after changes are made and validated the Nagios service must be restarted to make any changes effective.

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

### Example Of How to Add Additional Disk Space Check For /tmp on AIX hosts

Firstly, in order to add a new command, the Nagios list of master command templates needs to be updated. The  `commands.cfg` file which contains all the default command templates for a default Nagios installation can be located at `/usr/local/nagios/etc/objects/commands.cfg`

An entry similar to the below should be added into the commands.cfg file



Once this is done, then the server specific config file should be edited to include the new command to be run, so for this example the server specific config file, e.g ( `/usr/local/nagios/etc/servers/build-osuosl-aix71-ppc64-1.cfg` ) should have a section as shown in the example below added :

```bash
	define service {
		use				generic-service
		host_name			AIX host name goes here
		service_description		Disk Space check for Jenkins
		check_command			check_by_ssh!/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /home/jenkins
		check_interval			60
	}
```  
The second step above is repeated could then be repeated for any/all AIX hosts in the /usr/local/nagios/etc/servers directory.  

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
