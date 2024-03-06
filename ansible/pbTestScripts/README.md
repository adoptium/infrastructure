# Scripts to test Unix playbooks on Vagrant VMs

Most people will not need to run this directly, but if you can it will
reduce the likelihood of breaking things when you adjust the playbooks.
These scripts can be invoked via the
[VagrantPlaybookCheck](https://ci.adoptium.net/view/Tooling/job/VagrantPlaybookCheck/)
job if you have access to our jenkins, and they take 60-90 minutes to run
on the UNIX/Linux-based platforms, but closer to three hours for Windows.

This folder contains the scripts necessary to start separate vagrant machines with the following OSs:

* Ubuntu 16.04
* Ubuntu 18.04
* Ubuntu 20.04
* CentOS6
* CentOS7
* CentOS8
* Debian8
* Debian10
* FreeBSD12
* Solaris10
* Windows Server 2012 R2

These machines will then have the playbooks ran on them, with additional options to build JDK8 and test it.

The top level script `vagrantPlayBookCheck.sh` takes a number of options:

| Option                                | Description                                           | Example                                                        |
|---------------------------------------|-------------------------------------------------------|----------------------------------------------------------------|
| `--vagrantfile` / `-v` OS             | Run against the specified operating system            | `./vagrantPlaybookCheck.sh -v Ubuntu1804`                      |
| `--all` / `-a`                        | Runs for all OSs                                      | `./vagrantPlaybookCheck.sh -a`                                 |
|                                       |                                                       |                                                                |
| `--fork` / `-f` Git fork              | Specify the fork of the infrastructure repo to clone  | `./vagrantPlaybookCheck.sh -a --fork willsparker               |
| `--branch` / `-br` Git branch         | Specify the branch of the fork to clone               | `./vagrantPlaybookCheck.sh -a --fork willsparker --branch 1941 |
| `--new-vagrant-file` / `-nv`          | Use the vagrant files from the new URL                | `./vagrantPlaybookCheck.sh -a -nv --URL https://...`           |
| `--skip-more` / `-sm`                 | For speed/testing skip tags not needed for build test | `./vagrantPlaybookCheck.sh -a -sm`                             |
| `--clean-workspace` / `-c`            | Delete the old workspace                              | `./vagrantPlaybookCheck.sh -a -c`                              |
| `--retainVM` / `-r`                   | Retains the VM after running the Playbook             | `./vagrantPlaybookCheck.sh -a --retainVM`                      |
| `--no-halt` / `-nh`                   | Don't halt the Vagrant VMs at the end of the script   | `./vagrantPlaybookCheck.sh -a --retainVM -nh`                  |
| `--help`                              | Displays usage                                        | `./vagrantPlaybookCheck.sh --help`                             |
|                                       |                                                       |                                                                |
| `--build` / `-b`                      | Build JDK8 on the VM after the playbook               | `./vagrantPlaybookCheck.sh -a --build`                         |
| `--build-fork` / `-bf` build fork     | Specify the fork of the openjdk-build repo to clone   | `./vagrantPlaybookCheck.sh -a --build --build-fork sxa         |
| `--build-branch` / `-bb` build branch | Specify the branch of the build fork to clone         | `./vagrantPlaybookCheck.sh -a --build --build-branch master    |
| `--build-hotspot`                     | Specify to build the JDK with the Hotspot JVM *       | `./vagrantPlaybookCheck.sh -a --build --build-hotspot          |
| `--JDK-Version` / `-jdk` jdk          | Specify which JDK to build, if applicable             | `./vagrantPlaybookCheck.sh -a --build --JDK-version jdk11      |
| `--test` / `-t`                       | Run a small test on the built JDK within the VM *     | `./vagrantPlaybookCheck.sh -a --build --test`                  |
|                                       |                                                       |                                                                |
| `-V`,`-VV`,`-VVV`,`-VVVV`             | Add various verbosity levels to ansible-playbook cmd  | `./vagrantPlaybookCheck.sh -a --build -VVV`                    |

Notes:
 - The `--fork` and `--branch` arguments default to `adoptopenjdk` and `master`, respectively.
 - The `--build-fork` and `--build-branch` arguments also default to `adoptopenjdk` and `master`, respectively.
 - By default, the JDK will be built with the OpenJ9 JVM, as it has more dependencies which is a better test for the playbooks.
 - `--test` requires `--build` be enabled, otherwise the script will error.

The script will first clone the repository specified by the `--fork` and `--branch` options. For example, if `--fork` is 'willsparker' and `--branch` is '1941', the repository being cloned is https://github.com/willsparker/openjdk-infrastructure/tree/1941.

The script will then make a directory in the `$WORKSPACE` location called _adoptopenjdkPBTests_, in which another directory containing the log files, and the Git repository is stored. Following that, the script will run each ansible playbook on their respective VMs, writing the output to the aforementioned log files. If not defined prior to running, `$WORKSPACE` will default to `$HOME`. 

After each playbook is ran through, a summary is given, containing which OS playbooks succeeded, failed, or were cancelled. The logs can also be perused to get more in-depth error messages.

If specified, the VMs will then be tested by building JDK8 - if all dependencies are filled by the playbook as they should be, the JDK will be successfully built. If the `--test` option is then specified, the JDK will then have a simple test ran against it that will ensure it was built properly.

If the VMs were chosen *not* to be destroyed, they can be later by running the _vmDestroy.sh_ script, which takes the `Vagrant OS` as an argument. If found, every Vagrant VM with this OS will be destroyed, therefore the user will be asked to confirm they want this. The `--force` option will skip this prompt.

Vagrant boxes can be updated by their provider from time to time, and using outdated versions can occasionally [cause issues](https://github.com/adoptium/infrastructure/issues/2375#issue-1043540735). To ensure the current vagrant boxes used on the system are up to date, _updateBoxes.sh_ can be used. This will check and update all current vagrant boxes for the user. Outdated box versions will be removed if the `-r` option, is used. A prompt will ask the user to confirm the removal of a box, and option `-rf` will skip this prompt. 

The additional scripts in the _pbTestScripts_ folder are called from `vagrantPlaybookCheck.sh`
