# Instructions for creating Solaris machines in ESXi

## Creating the new machine template

1. Login to https://esxi.adoptopenjdk.net. @gdams and @sxa have credentials if needed.
1. Click `Create / Register VM`.
1. Click `Create a new virtual machine`.
1. Select a name and guest OS:
    - Name: Provide a hostname
    - Compatibility: `ESXi 6.5 virtual machine`.
    - Guest OS family: `Other`.
    - Guest OS version: `Oracle Solaris 10 (64-bit)`
1. Leave the storage as `datastore1`.
1. Customize settings:
    - CPU: Select `4` unless more is needed.
    - Memory: Select `8GB` unless more is needed.
    - Hard disk 1: Select a minimum of 120GB.
    - Network Adapter 1: Ensure that `VM Network` is selected and the `Connect` box is ticked.
    - CD/DVD Drive 1: Select `Datastore ISO file`, then select `sol-10-u11-ga-x86-dvd.iso`.
1. Click `Finish`


## First boot and Solaris Installation

### System Identification

1. Once the machine has been created, click on it and select the `Power on` option.
1. You should then be able to click the console screen in the left corner which should display the `GNU GRUB` loader.
1. `Oracle Solaris` should boot by default or you can hit the enter button.
1. Type `1` and then enter (Oracle Solaris Interactive default)
1. Select the keyboard layout (in my case `UK-English`) and then hit `F2` (Or `Escape` then `2` as an alternative.
1. Press Enter in the screen test shell.
1. Select a language (in my case `0`), then hit Enter.
1. Click `F2` for the next few screen using the default settings until you get to the hostname.
1. Set the hostname to match what you set the machine name is ESXi to be and then hit `F2`.
1. Set the IP address. The current block of IP's that we have is `147.75.85.208/29` (8 addresses) See the [inventory.yml](https://github.com/temurin-compliance/infrastructure/blob/master/ansible/inventory.yml) and the [temurin-compliance inventory](https://github.com/temurin-compliance/infrastructure/blob/master/ansible/inventory.yml) to find out which of those are already in use.
1. The system is part of a subnet so select `Yes` at the next screen.
1. Set the subnet mask as `255.255.255.248`.
1. Select `No` to IPv6 support.
1. For the default route, use the `Specify one` option and set it to be `147.75.85.209`.
1. Check the summary and hit `F2` to confirm the network settings.
1. Select `No` to Kerberos security.
1. For the name service, select `DNS`.
1. For the Domain name, type `adoptium.net`.
1. For the DNS Server Addresses, add the following IPs:
    - 147.75.207.207 
    - 147.75.207.208
1. For the Search domain, you can enter nothing and hit `F2`.
1. The next screen will say there is a name service error. Ignore this and select `No` to entering new name service information.
1. Use the default options for NFSv4.
1. At the Time Zone screen, select the timezone as Europe (or wherever the machine is hosted). The select the country on the next page.
1. At the Root Password prompt, add a suitable root password (remember to write this down and ensure that someone changes it if they take ownership of the machine).
1. Select `Yes` for Enabling Remote services.
1. Unselect the option that asks about registering using My Oracle Support.

### Solaris Interactive Installation

1. Hit `F2` to do a Standard install.
1. Select `Install on a non-iSCSI target`.
1. Select `Automatically eject CD/DVD`.
1. Select `Auto Reboot`.
1. Select `CD/DVD` as the media source.
1. Accept the license and then set the Geographic Region. 
1. Leave the locale as `POSIX C ( C )`.
1. Select `None` when it asks if you want to install Additional Products.
1. Select `ZFS` as the filesystem to use.
1. Select `Entire Disribution` as the software choice and select the only available disk device (which you created in ESXi).
1. Hit F2 to progress through the next couple of screens until you reach the summary page. Check the options and then hit `F2` to begin installation.
1. The Solaris Initial Install will run for a few minutes (now is the time to get a coffee).
1. Once the install has completed, you will see a sceen saying that the install is paused for 90 seconds. You need to eject the virtual disk in ESXi. If you still have the console window open you can click the `Actions` button in the top right corner, click `Edit settings` and change `CD/DVD Drive 1` back to be `Host Device`. Then click Save. You'll likely see a warning about the machine using the device, Click `Yes` and then `Answer`.
1. You can then type `c` to continue. The VM will now reboot and all being well, you should end up at a Solaris Login prompt.
1. Enter the root credentials that you created earlier and you'll be logged in.
1. You may see a prompt about `Starting a Desktop Login`. You want to cancel this by hitting `Enter`. (The Desktop doesn't work well until the VMWare Tools are installed.)

### Enable root SSH login

1. Before you can SSH into the machine, you'll need to change the SSH config file. Open `/etc/ssh/sshd_config` with `vi` and change the line `PermitRootLogin` to `yes`. Once changed, you need to restart the ssh service with `svcadm restart svc:/network/ssh:default`.

### Install VMware Tools

At this point the machine is essentially setup but, it's highly recommended to install the VMware Tools for monitoring.

1. With the console window open you can click the `Actions` button in the top right corner. The hover over `Guest OS` in the dropdown and select `Install VMware Tools`. This will mount a disk drive on the machine which contains the executable.
1. Whilst in the home directory run the following command to extract the VMware Tools: `gunzip -c /cdrom/vmwaretools/vmware-solaris-tools.tar.gz | tar xf -`.
1. Start the installation process by running: `./vmware-tools-distrib/vmware-install.pl`.
1. Click enter several times accepting all the default options.
1. Enable Autostart on the machine by clicking `Actions` button in the top right corner. Hover over `Autostart` and select `Enable`.
1. Finally, reboot the machine and the installation is complete!
