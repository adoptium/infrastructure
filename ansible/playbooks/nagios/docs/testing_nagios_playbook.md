## Testing The Nagios Server Playbooks - A Guide

This is a brief step by step guide on how I tested the above PR... this is to prove working in a clean new vagrant environment

#### 1) Identify fork & branch of code..

		https://github.com/lumuchris256/infrastructure/tree/2865

#### 2) Create Working Area Of Code

	2.1) Clone fork

		git clone https://github.com/lumuchris256/infrastructure

	2.2) Switch To PR Branch

		git fetch
		git switch 2865 << This Is The Branch From The Chosen Fork >>

#### 3) Create Blank Vagrant Machine To Test Server

	3.1) Create a copy of the nagios vagrant file ( either cp or ln )
	
		cd infrastructure/ansible/playbooks/nagios
		cp VagrantFiles/Vagrantfile.Nagios.Server.Ubuntu2204 ./Vagrantfile
		vi Vagrantfile

		N.B 
		If you want to force the static IP do this, otherwise you can skip this step
		( you may need to tweak the static IP / and create relevant configuration in virtual box et al )
		
		<< Swap This Line >>
		nagios_server.vm.network :private_network, type: "dhcp"
		<< For This One , Dont Forget To Substitute The IP for the one on your virtual / guest network. >>
		nagios_server.vm.network :private_network, ip: '192.168.50.66'

	3.2) Start The Vagrant VM

		vagrant up << takes a few mins >>

#### 4) Run The Nagios Server Install Playbook

	4.1) Log In To The Running Vagrant VM

		vagrant ssh << from the same directory as the vagrantfile created in step 3.1 >>

	4.2) Run The Server Install Playbook (dont forget to set the nagios admin and ansible vault passwords detailed in the readme)

		cd /vagrant
		ansible-playbook -b play_setup_server.yml --ask-vault-pass

	4.3) Stop The Nagios Service, And Disable Slack Notifications ( dont want these going to production! )

		sudo systemctl stop nagios
		sudo mv /usr/local/nagios/bin/slack_nagios.pl /usr/local/nagios/bin/slack_nagios.old
		sudo systemctl status nagios << ensure nagios service is stopped >>

	4.4) Exit & Snapshot The Vagrant Machine ( This will allow a quick restore to this point! )

		exit
		vagrant snapshot save nagios_server << snapshot name >>
		( e.g. vagrant snapshot save nagios_server INITIAL )

	4.5) Restart The Nagios Service & Check The Nagios Server Is Up & Running

		vagrant ssh
		sudo systemctl start nagios
		sudo systemctl status nagios << should show running >>

	Access the nagios server in the browser http://http://192.168.50.66/nagios/

At this point we have a base install of a nagios server, and can use this to test changes.

#### 5) Testing The Configuration Playbooks..

Its important to note that whilst development, testing the individual playbooks will almost certainly cause the nagios server to fail to start, this is because the configuration files are interdependent , and thus until all of the new automatically configured configuration files are in place, some manual workarounds ( using template configuration files ) will need to be used.

There is a sample set of config files contained in the testconfig.zip file found in this directory , these can and should be extracted into the nagios server directory to provide a base for additional configuration.

5.1) Run the nagios automated configuration playbooks

	ansible-playbook -b play_config_server.yml

  5.2) Stop, Restart & Check The Status Of The Nagios Server

	sudo systemctl stop nagios
	sudo systemctl start nagios
	sudo systemctl status nagios << should show running >>

At this point in time it may be necessary to amend some of the nagios configuration files to allow the server to start, this is required because all of the work to automate the nagios configuration process is not completed. To find out which configuration files require amendment, you can use the nagios configuration validation command :

	/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

#### 6) Useful Commands

To Restore A Vagrant Snapshot ( From The Vagrantfile Directory : )

	vagrant snapshot restore nagios_server << snapshot name >>

To Remove A Vagrant Snapshot ( From The Vagrantfile Directory : )

	vagrant snapshot delete nagios_server << snapshot name >>
