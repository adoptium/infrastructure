# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
sudo apt-get install tree -y
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible -y
sudo mkdir /ansible
sudo cp /etc/ansible/ansible.cfg /ansible
sudo touch /ansible/hosts
sudo sed -i 's?#inventory      = /etc/ansible/hosts?inventory = /ansible/hosts?g' /ansible/ansible.cfg
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.define :adoptopenjdk do |adoptopenjdk|
    adoptopenjdk.vm.box = "ubuntu/trusty64"
    adoptopenjdk.vm.hostname = "adoptopenjdk"
    adoptopenjdk.vm.network :private_network, type: "dhcp"
    adoptopenjdk.vm.provision "shell", inline: $script
  end
end