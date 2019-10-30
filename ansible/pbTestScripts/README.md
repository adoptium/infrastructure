# Scripts to test Unix playbooks on Vagrant VMs

This folder contains the scripts necessary to start separate vagrant machines with the following OSs:

* Ubuntu 16.04
* Ubuntu 18.04
* CentOS6
* CentOS7
* Windows Server 2012 R2

And subsequently test those machine’s playbooks, and optionally build jdk8u and test the jdk built

The script takes a number of options:

| Option               | Description                                           | Example                                                                           |
|----------------------|-------------------------------------------------------|-----------------------------------------------------------------------------------|
| --all / -a           | Runs for all OSs                                      | `./testScript.sh -a`                                                              |
| --retainVM / -r      | Retains the VM after running the Playbook             | `./testScript.sh -a --retainVM`                                                   |
| --build / -b         | Build JDK8 on the VM after the playbook               | `./testScript.sh -a --build`                                                      |
| --URL / -u <Git URL> | Specify the URL of the infrastructure repo to clone * | `./testScript.sh -a --URL https://github.com/adoptopenjdk/openjdk-infrastructure` |
| --test / -t          | Run a small test on the built JDK within the VM **    | `./testScript.sh -a --build --test`                                               |
| --help               | Displays usage                                        | `./testScript.sh --help`                                                          |

Notes:
 - If not specified, the URL will default to `https://github.com/adoptopenjdk/openjdk-infrastructure`
 - `--test` requires `--build` be enabled, otherwise the script will error.

The script is able to test specific branches of repositories, as well as the master branch, for example:
* "https://github.com/adoptopenjdk/openjdk-infrastructure" will git clone and test the master branch of adoptopenjdk/openjdk-infrastructure.
* "https://github.com/adoptopenjdk/openjdk-infrastructure/tree/branch_name" will git clone and test the "branch_name" branch of adoptopenjdk/openjdk-infrastructure

This can also be done on other people's forks of the repository, for example:
* "https://github.com/username/openjdk-infrastructure/tree/branch_name" will git clone the "branch_name" branch of "username"s fork of the repository 

The script will then make a directory in the User’s home called _adoptopenjdkPBTests_, in which another directory containing the log files, and the Git repository is stored. Following that, the script will run each ansible playbook on their respective VMs, writing the output to the aforementioned log files.
After each playbook is ran through, a summary is given, containing which OS playbooks succeeded, failed, or were cancelled. The logs can also be perused to get more in-depth error messages.

If specified, the VMs will then be tested by building JDK8 - if all dependencies are filled by the playbook as they should be, the JDK will be successfully built. If the `--test` option is then specified, the JDK will then have a simple test ran against it that will ensure it was built properly. 

If the VMs were chosen *not* to be destroyed, they can be later by running the _vmDestroy.sh_ script, which takes the `project folder` as an argument. If that folder is found, it will run through and destroy the VMs.
