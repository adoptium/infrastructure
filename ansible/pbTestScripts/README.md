# Scripts to test Unix playbooks on Vagrant VMs

Most people will not need to run this directly, but if you can it will
reduce the likelihood of breaking things when you adjust the playbooks.
These scripts can be invoked via the
[VagrantPlaybookCheck](https://ci.adoptopenjdk.net/view/work%20in%20progress/job/VagrantPlaybookCheck/)
job if you have access to our jenkins, and they take 60-90 minutes to run
on the UNIX/Linux-based platforms, but closer to three hours for Windows.

This folder contains the scripts necessary to start separate vagrant machines with the following OSs:

* Ubuntu 16.04
* Ubuntu 18.04
* CentOS6
* CentOS7
* Debian8
* Windows Server 2012 R2

These machines will then have the playbooks ran on them, with additional options to build JDK8 and test it.

The top level script `vagrantPlayBookCheck.sh` takes a number of options:

| Option                   | Description                                           | Example                                                                                             |
|--------------------------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| --vagrantfile / -v OS    | Run against the specified operating system            | `./vagrantPlaybookCheck.sh -v Ubuntu1804`                                                           |
| --all / -a               | Runs for all OSs                                      | `./vagrantPlaybookCheck.sh -a`                                                                      |
| --retainVM / -r          | Retains the VM after running the Playbook             | `./vagrantPlaybookCheck.sh -a --retainVM`                                                           |
| --build / -b             | Build JDK8 on the VM after the playbook               | `./vagrantPlaybookCheck.sh -a --build`                                                              |
| --URL / -u Git URL       | Specify the URL of the infrastructure repo to clone * | `./vagrantPlaybookCheck.sh -a --URL https://github.com/sxa555/openjdk-infrastructure/tree/mybranch` |
| --test / -t              | Run a small test on the built JDK within the VM **    | `./vagrantPlaybookCheck.sh -a --build --test`                                                       |
| --new-vagrant-file / -nv | Use the vagrant files from the new URL                | `./vagrantPlaybookCheck.sh -a -nv --URL https://...`                                                |
| --skip-more / -sm        | For speed/testing skip tags not needed for build test | `./vagrantPlaybookCheck.sh -a -sm`
| --help                   | Displays usage                                        | `./vagrantPlaybookCheck.sh --help`                                                                  |

Notes:
 - If not specified, the URL will default to `https://github.com/adoptopenjdk/openjdk-infrastructure`
 - `--test` requires `--build` be enabled, otherwise the script will error.

The script is able to test specific branches of repositories, as well as the master branch, for example:
* "https://github.com/adoptopenjdk/openjdk-infrastructure" will git clone and test the master branch of adoptopenjdk/openjdk-infrastructure.
* "https://github.com/adoptopenjdk/openjdk-infrastructure/tree/branch_name" will git clone and test the "branch_name" branch of adoptopenjdk/openjdk-infrastructure

This can also be done on other people's forks of the repository, for example:
* "https://github.com/username/openjdk-infrastructure/tree/branch_name" will git clone the "branch_name" branch of "username"s fork of the repository 

The script will then make a directory in the `$WORKSPACE` location called _adoptopenjdkPBTests_, in which another directory containing the log files, and the Git repository is stored. Following that, the script will run each ansible playbook on their respective VMs, writing the output to the aforementioned log files. If not defined prior to running, `$WORKSPACE` will default to `$HOME`. 

After each playbook is ran through, a summary is given, containing which OS playbooks succeeded, failed, or were cancelled. The logs can also be perused to get more in-depth error messages.

If specified, the VMs will then be tested by building JDK8 - if all dependencies are filled by the playbook as they should be, the JDK will be successfully built. If the `--test` option is then specified, the JDK will then have a simple test ran against it that will ensure it was built properly.

If the VMs were chosen *not* to be destroyed, they can be later by running the _vmDestroy.sh_ script, which takes the `Vagrant OS` as an argument. If found, every Vagrant VM with this OS will be destroyed, therefore the user will be asked to confirm they want this. The `--force` option will skip this prompt.

The additional scripts in the _pbTestScripts_ folder are called from `testScript.sh`
