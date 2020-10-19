# Setup AIX Virtual Machine (aka LPAR) for OpenJDK developement - test and build

## Minimum storage

## Recommended VP, EC and Memory

## OS levels
At the time of this document - AIX 7.1 TL05 and AIX 7.2 TL04 were the IBM supported versions of AIX.

In principle, the level of AIX is not critical, because the starting point uses a working
OpenJDK system - rather than rely solely on IBM supplied Java.

Re: IBM supplied Java - while Java7 and Java7_64 should work, the assumption is that you have
Java8_64 installed and included in the default PATH in /etc/environment.

## Open Source Software

There are two approaches: the more common is to install AIX OSS in RPM based packages 

### Working with AIXToolBox and `yum.sh`
Ensure the following AIX (DVD aka BOS) packages are installed:
- expect
- tcl
- ftp (client)
- OpenSSL-1.0.2.1601

The above is the minimum software required to execute a script named yum.sh - that will download
additional software to enable the python package yum(-v3). After this initial install you will need
to immediately use `yum update` to update all these packages to the latest levels. All in all,
approximately 50 additional RPM packages are installed to complete these steps.

Note: after running these `yum.sh` and `yum update` you may not be able to uninstall any of these packages.
Also: applying 'mixed' combinations of `AIX update_all` and `yum update` may cause issues with libraries
not being found - as both package managers (installp and RPM) claim ownership of the same file.

### Not using RPM based OSS packages
The issue is not what compiler is used (gcc is very common with the existing RPM based OSS for AIX).
The first issue is that two package managers are used - and they are not designed to work with each other.
Over time RPM.spec files have been improved - to not overwrite files owned by AIX BOS filesets - but
should it happen - the RPM fileset does not warn you that it has overwritten a file that `installp`
believes it is managing. Likewise, should a RPM package successfully insert it's extra bits into a file
already there (so nothing breaks) - and AIX `update_all` action may replace a file and now the RPM OSS
package no longer works because the file is no longer providing the `something extra` that the RPM OSS
added to a file (generally a dynamicly loaded library).

The second issue is finding, or self-packaging, OSS software using installp.
The portal http://www.aixtools.net strives to supply the OSS packages generally needed for OSS development
on AIX. These are packaged using installp (using the AIX program mkinstallp). While there is no guarantee
that there is a file needed by two packages - should this happen - the installp process says that
packageB has taken control of fileZ - previously owned by packageA.

### Summary
In short, the choice is to rely on mixed package managers - and the inherent breakage that occurs from time
to time with no warning or or rely, as all other platforms do - on a single platform supplied package manager.

## Applying the Ansible Playbook for AIX

The playbooks are applied from an Ansible Control Node. This does not have to be an AIX node - although that is
possible (Playbook v2 was developed an AIX Control Node, and tested on both AIX and Linux Control Nodes).

AIX will need some version of Python installed. The 'yum.sh' approach installs Python2 (to support the yum command).
There is a playbook to install Python3 from AIXTools. This can co-exist with the Python2 installed by 'yum.sh'.
(# There is an intent to develop a playbook that can install Python3 - without any previous Python installed - WIP
- work in progress).

## Working with Ansible
The playbooks for AIX use some additional modules. On the control node you will need to:

$ ansible-galaxy collection install community.general

The playbooks are using:
- community.general.aix_devices
- community.general.aix_filesystem
- community.general.aix_inittab
- community.general.aix_lvg
- community.general.aix_lvol
- community.general.installp
