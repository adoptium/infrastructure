# Ansible playbooks to download and install dependencies for OpenJDK build and test on various platforms

# Quickstart guide

The ansible playbooks under the `playbook` directory are used to set up all
of the adoptopenjdk machines to be able to run building and testing of the
openjdk and related projects.

The main playbooks should be run from this directory using, for example, the
following command (the skipped tags are one that aren't needed on most
user's machines, but are needed if you're setting up a machine for the
official AdoptOpenJDK infrastructure):

```
ansible-playbook -i inventory_file --skip-tags adoptopenjdk,jenkins playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```

If you are interesting in running the playbooks within a virtual machine on your
host, checkout the section on Vagrant later in this readme

## Do I need to be a superuser on the target machine to run the playbooks?

Yes, in order to access the package repositories (we will perform either `yum install` or `apt-get` commands)

## How do I run the playbooks?

1) Install Ansible 2.4 or later (

    - On RHEL 7.x
    ```bash
    yum install epel-release
    yum install ansible
    ```

    - For Ubuntu
    ```bash
    sudo apt-add-repository ppa:ansible/ansible
    sudo apt update
    sudo apt install ansible
    ```

    - On another system with `pip` available:
    ```bash
    sudo pip install ansible
    ```

2) Ensure that you have edited the `hosts` in `/etc/ansible/` or in the project root directory. For running locally `hosts` file should contain something as simple as `localhost ansible_connection=local`.

3) Run a playbook to install dependencies, e.g. for Ubuntu 14.x on x86:
    ```bash
    ansible-playbook -s playbooks/AdoptOpenJDK_Unix_Playbook/main.yml --skip-tags=adoptopenjdk,jenkins

    # Or to use a custom hosts file:
    ansible-playbook -i /path/to/hosts -s AdoptOpenJDK_Unix_Playbook/main.yml --skip-tags=adoptopenjdk,jenkins
    ```

4) The Ansible playbook will download and install any dependencies needed to build OpenJDK

## How do I run the playbooks on a remote Windows host?

Ansible can't be installed locally on a Windows machine, therefore the playbook has to be ran on a seperate system and then pointed at a Windows Machine.

This can be done by doing the following: 

1) In `playbooks/AdoptOpenJDK_Windows_Playbook/main.yml` change `- hosts: {{ groups['Vendor_groups'] ...` to `- hosts: all`
2) Alter `playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml` to add `ansible_winrm_transport: credssp`. Uncomment and set `ansible_password` to your admin user's password.
3) Create a `hosts` file containing the IP address of the Windows machine.

The playbook can then be run by executing the following, from the `openjdk-infrastructure/ansible` directory:

```bash
ansible-playbook -i hosts -u ADMIN_USER --skip-tags adoptopenjdk,jenkins playbooks/AdoptOpenJDK_Windows_Playbook/main.yml
```

Due to the time taken to execute some of the roles on the playbook, such as the cygwin and MSVS installations, a ConnectTimeout error could occur.

```bash
ConnectTimeout: HTTPSConnectionPool(host='x.xx.xxx.xxx', port=5986): Max retries exceeded with url: /wsman (Caused by ConnectTimeoutError(<urllib3.connection.HTTPSConnection object at 0x7f1f31ef2d10>, 'Connection to x.xx.xxx.xxx timed out. (connect timeout=30)'))
fatal: [x.xx.xxx.xxx]: FAILED! => {"msg": "Unexpected failure during module execution.", "stdout": ""}
```

In certain cases, this can be fixed by increasing a couple of timeout variables in `playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml`

```bash
ansible_winrm_operation_timeout_sec: 600
ansible_winrm_read_timeout_sec: 630
```

Additional information about `winrm` variables can be found [here](https://github.com/ansible/ansible/blob/devel/docs/docsite/rst/user_guide/windows_winrm.rst#inventory-options)

## Which playbook do I run?

Our playbooks are named according to the operating system they are supported for, keep in mind that package availability may differ between operating system releases.

The main ones are as follows:

- AdoptOpenJDK_Unix_Playbook/main.yml (For all *IX machines including macOS)
- AdoptOpenJDK_Windows_Playbook/main.yml (Windows systems)
- aix.yml (For AIX systems - not currently split out into individual roles)
- AdoptOpenJDK_ITW_Playbooks (CentOS or Red Hat only - IcedTea-WEB setup)

There are also various playbooks used to set up other machines in the
adoptopenjdk infrastructure - generally most end users won't need these but
I'll include them for completeness:

- vagrant.yml (Used to set up an Ubuntu machine to run Vagrant playbook testing)

## Where can I run the playbooks?

On any machine you have SSH access to: in the playbooks here we are using `hosts: local`,
our playbook will run on the hosts defined in the Ansible install directory's `hosts` file. To run on the local machine,
we will have the following text in our `/etc/ansible/hosts` file:
```
[local]
127.0.0.1
```
Running `ansible --version` will display your Ansible configuration folder that contains the `hosts` file you can modify

## Skipping one or more tags via CLI when running Ansible playbooks

In general skipping `adoptopenjdk` and `jenkins` as per all of the examples
above will be all that's needed -  those tags are in place for all roles
that will probe problematic on a non-AdoptOpenJDK owned machine. Most of the
roles have their own tags you can use to skip them if required, but one that
might be useful is `dont_remove_system`. We have one or two roles such as
`GIT_source` in the *IX playbook which can potentially remove any system
installed version of the tool after building a later one from source into
/usr/local. For maximum safety you can use that too, but you should consider
whether that's really what you want to do if you add that to your skip list.

## Passing in extra variables from the command line

The below example is appropriate to run playbook by skipping tasks by using a combination of conditionals and tags (linked and dependent tasks will not be executed):

```bash
ansible-playbook -i [/path/to/hosts] -b AdoptOpenJDK_Unix_Playbook/main.yml --extra-vars "Jenkins_Username=jenkins Jenkins_User_SSHKey=[/path/to/id_rsa.pub] Nagios_Plugins=Disabled Slack_Notification=Disabled Superuser_Account=Disabled" --skip-tags="adoptopenjdk,jenkins,dont_remove_system"
```

Note that when running from inside a `vagrant` instance:
 - the `[/path/to/hosts]` can be replace with `/vagrant/playbooks/hosts`
 - the `[/path/to/id_rsa.pub]` can be replaced with `/home/vagrant/.ssh/id_rsa.pub`

This is useful if one or more tasks are failing to execute successfully or if they need to be skipped due to not deemed to be executed in the right environment.

## Verbose mode, debugging Ansible playbooks

Below are the levels of verbosity available with using ansible scripts:

```bash
ansible-playbook -v -b playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
ansible-playbook -vv -b playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
ansible-playbook -vvv -b playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
ansible-playbook -vvvv -b playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```

A snippet from the man pages of Ansible:

>     -v, --verbose
>           verbose mode (-vvv for more, -vvvv to enable connection debugging)

## Expected output of a successful Ansible build

When the above `ansible-playbook` commands succeed, we should get something like this:

```
PLAY RECAP *********************************************************************
172.28.128.134             : ok=131  changed=96   unreachable=0    failed=0   
```

# Running via Vagrant and VirtualBox

We have some automation for running under Vagrant which we use to validate
playbook changes before they are merged. See the
[pbTestScripts](pbTestScripts/) folder for more info. The scripts from there
are run on jenkins in the
[VagrantPlaybookCheck](https://ci.adoptopenjdk.net/view/Tooling/job/VagrantPlaybookCheck/) job

Any additional help in setting up Vagrant with Virtualbox can be found [here](https://www.vagrantup.com/intro/getting-started/index.html)

## Vagrant setup guide - macOS

To test the ansible scripts, you'll need to install the following programs.

1. Install Homebrew 2.1.7 or later
  ```bash
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  ```
2. Install Vagrant 2.2.5 or later
  ```bash
  brew cask install vagrant
  ```
3. Install Virtualbox 6.0.8 or later:
  ```bash
  brew cask install virtualbox
  ```

Note: `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` is required before running the playbook on macOS.

## Vagrant setup guide - Ubuntu (other Linuxes are similar)

If you're on Ubuntu we have a playbook that can be used to set up your
machine to run vagrant in [playbooks/vagrant.yml](playbooks/vagrant.yml) but
it simply installs Vagrant from https://releases.hashicorp.com/vagrant/2.2.5/vagrant_2.2.5_x86_64.deb
and also [virtualbox from their web site](https://www.virtualbox.org/wiki/Downloads)

## Executing under vagrant

To test the ansible scripts you can set up a Virtual Machine isolated from your own host system.
Several `Vagrantfile`s have been provided and the usual `vagrant` commands should get it up and running.

The following method runs the ansible playbooks on the local connection.
Normally you will be running ansible on your development machine, and using it
to modify remote hosts.

**NOTE** The `/vagrant/` directory maps to the directory on your host that you launched the `VagrantFile` from
e.g. `~/workspace/AdoptOpenJDK/openjdk-infrastructure/ansible`

Within the `openjdk-infrastructure/ansible` directory:

```bash
ln -sf Vagrantfile.Centos6 Vagrantfile

vagrant up

vagrant ssh # Uses default ssh login, user=vagrant, password=vagrant

cd /vagrant/playbooks
```

Note when using our Vagrantfiles:
 - A `hosts` file containing `localhost ansible_connection=local` will already be present in the directory with the playbook scripts (`/vagrant/playbooks`).
 - A public key file `id_rsa.pub` will already be present in the `/home/vagrant/.ssh/` folder

1) Run a playbook to install dependencies, for Linux on x86:

`ansible-playbook -b AdoptOpenJDK_Unix_Playbook/main.yml --skip-tags=adoptopenjdk,jenkins`

In case one or more tasks fail or should not be run in the local environment, see [Skipping one or more tags via CLI when running Ansible playbooks](https://github.com/AdoptOpenJDK/openjdk-infrastructure/tree/master/ansible#skipping-one-or-more-tags-via-cli-when-running-ansible-playbooks) for further details. Ideally, the below can be run for smooth execution in the `vagrant` box:

```bash
ansible-playbook -b AdoptOpenJDK_Unix_Playbook/main.yml --skip-tags="install_zulu,jenkins_authorized_key,nagios_add_key,add_zeus_user_key"
```
## Using Ansible to modify Vagrant VM remote hosts (linux)

The following method runs the ansible playbooks against a Vagrant VM remotely.

```bash
ln -sf Vagrantfile.CentOS6 Vagrantfile

ssh-keygen -q -f id_rsa -t rsa -N '' # Generate a keypair for use between host and VM

vagrant up
```
After starting the vagrant machine, several files need to be edited to allow ansible to make the connection.

1) In `playbooks/AdoptOpenJDK_Unix_Playbook/main.yml` change `- hosts: {{ groups['Vendor_groups'] ...` to `- hosts: all`
2) Add `timeout=30` and `private_key_file=id_rsa` under the `[defaults]` section in `ansible.cfg`
3) Alter the `playbooks/AdoptOpenJDK_Unix_Playbook/hosts.tmp` file generated by the Vagrantfile to only contain the larger IP Address

To start running the playbook against the VM, from the `openjdk-infrastructure/ansible` directory:

```bash
ansible-playbook -i playbooks/AdoptOpenJDK_Unix_Playbook/hosts.tmp -u vagrant -b --skip-tags adoptopenjdk,jenkins playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```

## Using Ansible to modify Vagrant VM remote hosts (Windows)

To run the playbook against a Windows Vagrant VM remotely, the follow steps can be taken: 

```bash
vagrant plugin install vagrant-disksize

pip install pywinrm requests-credssp	# Pre-reqs for using winrm

ln -sf Vagrantfile.Win2012 Vagrantfile

vagrant up
```

Several files will also need to be edited for Windows:

1) In `playbooks/AdoptOpenJDK_Windows_Playbook/main.yml` change `- hosts: {{ groups['Vendor_groups'] ...` to `- hosts: all`
2) Alter the `playbooks/AdoptOpenJDK_Windows_Playbook/hosts.tmp` file generated by the Vagrantfile to remove the CRs and only contain the larger IP Address
3) Alter `playbooks/AdoptOpenJDK_Windows_Playbook/group_vars/all/adoptopenjdk_variables.yml` to add `ansible_winrm_transport: credssp`. Uncomment and set `ansible_password` to `vagrant`

To run the playbook against the VM, from the `openjdk-infrastructure/ansible` directory:

```bash
ansible-playbook -i playbooks/AdoptOpenJDK_Windows_playbook/hosts.tmp -u vagrant --skip-tags jenkins,adoptopenjdk playbooks/AdoptOpenJDK_Windows_Playbook/main.yml
```

Alternatively, [pbTestScripts/vagrantPlaybookCheck.sh](pbTestScripts/vagrantPlaybookCheck.sh) will do this for you when executing `./vagrantPlaybookCheck.sh -v Win2012 -u https://github.com/adoptopenjdk/openjdk-infrastructure --retainVM`

## Can I have multiple VMs on different OSs?

As vagrant uses Virtualbox to create VMs, multiple VMs on different OSs can be setup.
You can do this by following these steps:

  1. Make a copy of the existing directory you have.
  2. The `Vagrantfile` is a symlink or copy of the Vagrantfile that is labelled with the desired OS (e.g. `VagrantFile.Ubuntu1804`)
  3. Continue the vagrant functions as normal.

To access each vagrant VM, you'll need to be in the correct directory to `vagrant ssh` into, or the ID of the machine can be used:

```bash
vagrant ssh 1a2b3c4d
```
Use `vagrant-global-status --prune` to find the directory the vagrant VM is in and the ID of the machine.
