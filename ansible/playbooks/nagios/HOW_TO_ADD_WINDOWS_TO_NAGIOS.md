**Prerequisite**

Create  a test server for running the Nagios_Server playbook on and a windows server VM using [this instruction.](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md#can-i-have-multiple-vms-on-different-oss) 

**Adding windows machine to nagios monitoring**

To add a Windows host to a Nagios Server, we require NSClient++ plugin.

The plugin acts as an intermediate between Nagios and Windows server.

Thus, to add Windows host,  install NSClient++ plugin in the Windows machine first and then make changes in the Nagios configuration file.

 Steps you need to follow in order to monitor a new Windows machine:

1). Perform first-time prerequisites

2). Install a monitoring agent on the Windows machine

3). Create new host and service definitions for monitoring the Windows machine

4). Restart the Nagios daemon

**Changes in Windows server**

1). Login as an administrator to the Windows server.

2). Download and install the [NSclient package](https://www.nsclient.org/download/0.5.1/#0.5.1.45) based on the architecture.

3). After downloading the file, double-click on the .msi file, to begin with, the installation and click on run.

4). A Welcome screen appears, click on Next. Now  check "I accept the terms in the License Agreement".

5). Choose Setup type as Typical and click on Next. In the next window, leave the default settings and click Next.

6). Enter the Nagios Server IP in Allowed hosts and check all the modules and click Next then complete the install.

 7). From the start Menu, Start NSClient++

**Changes In Nagios server**

1). Login to the server where Nagios is installed.

Edit the file windows.cfg using the command.
```bash
nano /usr/local/nagios/etc/objects/windows.cfg
```
In the configuration file, enter the details of the Windows server. In host_name, enter the hostname of the Windows server. In the address,specify the IP address of the Windows server. 

2). open the Nagios configuration file using the command ,
```bash
nano /usr/local/nagios/etc/nagios.cfg
```
 uncomment the changes below and save.

```bash
cfg_file=/usr/local/nagios/etc/objects/windows.cfg
```

Run a sanity check on the configuration files by running Nagios with the -v command line option: 
```bash
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```
Restart nagios  

Now browse the Nagios GUI.  Windows host is present on the dashboard.
