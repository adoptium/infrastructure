```bash
Installing AWX aka Ansible Tower 
Based on: Ubuntu 14.04 From the Packet.net
Setup:

# Set Hostname
hostnamectl set-hostname ansible.adoptopenjdk.net --static

# Check /etc/hosts
127.0.0.1 ansible.adoptopenjdk.net ansible-tower

# Install prerequisites apps
apt-get update && apt-get -y install ansible binutils dkms gcc git make patch python-pip vim
apt-get -y install python3-pip
pip install --upgrade pip
pip install django

# Docker-CE Installation
apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update && apt-get -y install docker-ce
pip install docker-py

# Test docker
service docker start
docker run hello-world

# Upgrade Ansible
apt-get -y install software-properties-common python-software-properties 
add-apt-repository ppa:ansible/ansible -y
apt-get update && apt-get -y install ansible 

# Create a folder to store ansible tower
mkdir /opt/awx_install_files && cd /opt/awx_install_files
git clone  https://github.com/ansible/awx.git
cd awx/installer/
ansible-playbook -i inventory install.yml

# This install.yml will install ansiable-tower using an ansible playbook
# Once complete, it can take ~20 mins for ansible tower finish upgrading and come on-line
# You can watch the output running this command:
docker logs -f awx_task

# At this point you can open the website and test
https://ansible.adoptopenjdk.net

# Viewing the website will show
AWX is Upgrading
AWX is currently upgrading or installing, this page will refresh when done.

# The default administrator username is admin, and the password is password.
# Testing Ansible Tower
# Complete the Hello World test
https://docs.ansible.com/ansible-tower/2.3.0/html/quickstart/create_project.html

# Now we need to secure the server???
login to website
click "users"
select "admin"
enter the new password and confirm
Other Stuff:

# Ubuntu will delete its /tmp folder on reboot. We need to disable this.
# As AWX saves its information in postgress in /tmp
echo > /etc/init/mounted-tmp.conf

# Configuring MOTD
# Ubuntu has this thing were it will display the motd twice to workaround it, do the following:
echo "" > /etc/motd

# uncomment "Banner /etc/issue.net" in /etc/ssh/sshd_config 
vi /etc/ssh/sshd_config 
service ssh restart

# Paste the following into /etc/issue.net
MMMMMMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNMMMMMMMMM
MMMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNs`  +NNNNNNNNNNNNNNNNNNNNNNNNNNMMMMMM
MMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNh     +NNNNNNNNNNNNNNNNNNNNNNNNNNMMMMM
MMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNd`      sNNNNNNNNNNNNNNNNNNNNNNNNNNMMMM
MMMNNNNNNNNNNNNNNNNNNNNNNNNNNNm.   `    hNNNNNNNNNNNNNNNNNNNNNNNNNNMMM
MMNNNNNNNNNNNNNNNNNNNNNNNNNNNm:   `d:   `dNNNNNNNNNNNNNNNNNNNNNNNNNNMM
MNNNNNNNNNNNNNNNNNNNNNNNNNNNN+    hNm.   -mNNNNNNNNNNNNNNNNNNNNNNNNNNM
MNNNNNNNNNNNNNNNNNNNNNNNNNNNs    oNNNd`   :NNNNNNNNNNNNNNNNNNNNNNNNNNM
MNNNNNNNNNNNNNNNNNNNNNNNNNNh    /NNNNNy    +NNNNNNNNNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNNNNNNNd`   -mNNNNNNo    sNNNNNNNNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNNNNNNm.    +mNNNNNNN/    hNNNNNNNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNNNNNm:      `/hNNNNNm-   `dNNNNNNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNNNNN+    /.    .omNNNd`   -mNNNNNNNNNNNNNNNNNNNNNN
NNNNNNNNNNNNNNNNNNNNNNNs    /NNy:     /hNNh    :NNNNNNNNNNNNNNNNNNNNNN
MNNNNNNNNNNNNNNNNNNNNNh    -mNNNNmo.    .oms    +NNNNNNNNNNNNNNNNNNNNN
MNNNNNNNNNNNNNNNNNNNNd`   `dNNNNNNNNy:     :-    sNNNNNNNNNNNNNNNNNNNM
MMNNNNNNNNNNNNNNNNNNm.    hNNNNNNNNNNNdo.        `hNNNNNNNNNNNNNNNNNNM
MMNNNNNNNNNNNNNNNNNm:    oNNNNNNNNNNNNNNNy:       `dNNNNNNNNNNNNNNNNMM
MMMNNNNNNNNNNNNNNNN+    /NNNNNNNNNNNNNNNNNNd+`     -NNNNNNNNNNNNNNNMMM
MMMMNNNNNNNNNNNNNNs    -mNNNNNNNNNNNNNNNNNNNNmy:   +NNNNNNNNNNNNNNMMMM
MMMMMNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNmdmNNNNNNNNNNNNNNMMMMM
                   Welcome to AWX aka Ansible Tower
                https://ansible.adoptopenjdk.net
AWX is run from docker containers, you can watch the start up activity for the containers by running: docker logs -f awx_task

# auto update 
crontab -e

# Patch Ubuntu weekly at 5/5:15 Sundays
0 5 * * 1 apt-get update
15 5 * * 1 apt-get -y upgrade

# Setup Backups for AWX docker containers
mkdir /backup
vi ~/backup_docker_AWX.sh 
// code
DATE=`date +%m-%d-%Y`

# Create Tar backups from the containers
docker save -o /backup/awx_test_backup_$DATE.tar ansible/awx_task
docker save -o /backup/awx_web_backup_$DATE.tar ansible/awx_web 
docker save -o /backup/rabbitmq_backup_$DATE.tar rabbitmq
docker save -o /backup/postgres_backup_$DATE.tar postgres
docker save -o /backup/memcached_backup_$DATE.tar memcached
tar -cvf /backup/postgres_tmp_backup_$DATE.tar /tmp/pgdocker
// code
chmod +x backup_docker_AWX.sh 
crontab -e

# Backup AWX's docker containers weekly at 5am on Mondays
0 5 * * 2 /root/backup_docker_AWX.sh 
chattr +i /etc/resolv.conf 

# Working with local files
# Files on rt-ansible-tower
docker ps

# Find the CONTAINER_ID for ansible/awx_task
# Enter the containter 
docker exec -it CONTAINER_ID bash

# Create a folder to work out of
mkdir /Vendor_Files

# You can place any files we need for Playbooks here
```