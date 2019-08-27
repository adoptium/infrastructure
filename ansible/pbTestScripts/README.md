# Scripts to test Unix playbooks on Vagrant VMs

This folder contains the scripts necessary to start separate vagrant machines with the following OSs:

* Ubuntu 16.04
* Ubuntu 18.04
* CentOS6
* CentOS7

And subsequently test those machine’s playbooks, and build jdk8 on them.

Start by executing _testScript.sh_ with 2 arguments; the `GitHub URL` to be tested, and a `y/n` to specify keeping the VMs alive or not. The Github URL can be in two forms:

* "https://github.com/adoptopenjdk/openjdk-infrastructure" will git clone and test the master branch of adoptopenjdk/openjdk-infrastructure.
* "https://github.com/adoptopenjdk/openjdk-infrastructure/tree/branch_name" will git clone and test the "branch_name" branch of adoptopenjdk/openjdk-infrastructure

This can also be done on other people's forks of the repository, for example:

* "https://github.com/username/openjdk-infrastructure/tree/branch_name" will git clone the "branch_name" branch of "username"s fork of the repository 

The script will then make a directory in the User’s home called _adoptopenjdkPBTests_, in which another directory containing the log files, and the Git repository is stored. Following that, the script will run each ansible playbook on their respective VMs, writing the output to the aforementioned log files.

After each playbook is ran through, a summary is given, containing which OS playbooks succeeded, failed, or were cancelled. The logs can also be perused to get more in-depth error messages.

If the VMs were chosen *not* to be destroyed, they can be later by running the _vmDestroy.sh_ script, which takes the `project folder` as an argument. If that folder is found, it will run through and destroy the VMs.
