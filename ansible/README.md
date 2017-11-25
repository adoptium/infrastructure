# Ansible playbooks to download and install dependencies for OpenJDK on various platforms

# Running via Vagrant and VirtualBox 

You are better off running it inside a Virtual Machine isolate from your own local system. 
A `Vagrantfile` has been provided and the usual `vagrant` commands should get it up and running.
```
   $ vagrant up
   $ vagrant ssh
   
   (ssh login: vagrant   password: vagrant)
   
   cd /vagrant/ansible/playbooks   
```

1) Run a playbook to install dependencies, for Ubuntu 14.x on x86:
`ansible-playbook -s ubuntu_14_x86.yml`

or  

`ansible-playbook -s playbooks/ubuntu.yml`

Ensure that you have created `host` file in the root directory of the repo or in `/etc/ansible/`. For running locally `hosts` file should contain something as simple as `localhost ansible_connection=local`.

# Running Manually

## Do I need to be a superuser to run the playbooks?

Yes, in order to access the package repositories (we will perform either `yum install` or `apt-get` commands)

## How do I run the playbooks?

1) Install Ansible

On Ubuntu 16.x
`apt install ansible`

On RHEL 7.x
`yum install epel-release` then `yum install ansible`

For Ubuntu 14.x
`sudo apt-add-repository ppa:ansible/ansible`
`sudo apt update`
`sudo apt install ansible`

2) Run a playbook to install dependencies, for Ubuntu 14.x on x86:
`ansible-playbook -s ubuntu_14_x86.yml`

or

`ansible-playbook -s playbooks/ubuntu.yml`

Ensure that you have created `host` file in the root directory of the repo or in `/etc/ansible/`. For running locally `hosts` file should contain something as simple as `localhost ansible_connection=local`.

3) The Ansible playbook will download and install any dependencies needed to build OpenJDK

## Which playbook do I run?

Our playbooks are named according to the operating system they are supported for, keep in mind that package availability may differ between operating system releases

## Where can I run the playbooks?

On any machine you have SSH access to: in the playbooks here we are using `hosts: local`, 
our playbook will run on the hosts defined in the Ansible install directory's `hosts` file. To run on the local machine, 
we will have the following text in our `/etc/ansible/hosts` file:
```
[local]
127.0.0.1
```
Running `ansible --version` will display your Ansible configuration folder that contains the `hosts` file you can modify
