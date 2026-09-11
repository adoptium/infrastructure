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
* Ubuntu 22.04
* Ubuntu 24.04
* CentOS 6
* CentOS 7
* CentOS 8
* Debian 11
* Debian 12
* Fedora 40
* FreeBSD 12
* Windows Server 2012 R2 (VirtualBox only)
* Windows Server 2022
* Windows Server 2022 Core (VirtualBox only)
* Windows Server 2025

> **Note:** Windows Server 2012 R2 and Windows Server 2022 Core have no Libvirt Vagrantfile and
> always use VirtualBox. Windows Server 2022 and 2025 have best-effort Libvirt support (see
> `--provider` below). The `--use-adopt` flag applies only to VirtualBox Windows variants.

These machines will then have the playbooks ran on them, with additional options to build JDKXX and test it.

The top level script `vagrantPlayBookCheck.sh` takes a number of options:

| Option                                | Description                                           | Example                                                        |
|---------------------------------------|-------------------------------------------------------|----------------------------------------------------------------|
| `--vagrantfile` / `-v` OS             | Run against the specified operating system            | `./vagrantPlaybookCheck.sh -v Ubuntu1804`                      |
| `--all` / `-a`                        | Runs for all OSs supported by the active provider     | `./vagrantPlaybookCheck.sh -a`                                 |
|                                       |                                                       |                                                                |
| `--provider` / `-p` name              | Select the virtualisation provider: `virtualbox` (default) or `libvirt` | `./vagrantPlaybookCheck.sh -a --provider libvirt` |
|                                       |                                                       |                                                                |
| `--fork` / `-f` Git fork              | Specify the fork of the infrastructure repo to clone  | `./vagrantPlaybookCheck.sh -a --fork willsparker`              |
| `--branch` / `-br` Git branch         | Specify the branch of the fork to clone               | `./vagrantPlaybookCheck.sh -a --fork willsparker --branch 1941`|
| `--new-vagrant-file` / `-nv`          | Use the vagrant files from the new URL                | `./vagrantPlaybookCheck.sh -a -nv`                             |
| `--skip-more` / `-sm`                 | For speed/testing skip tags not needed for build test | `./vagrantPlaybookCheck.sh -a -sm`                             |
| `--clean-workspace` / `-c`            | Delete the old workspace                              | `./vagrantPlaybookCheck.sh -a -c`                              |
| `--retainVM` / `-r`                   | Retains the VM after running the Playbook             | `./vagrantPlaybookCheck.sh -a --retainVM`                      |
| `--no-halt` / `-nh`                   | Don't halt the Vagrant VMs at the end of the script   | `./vagrantPlaybookCheck.sh -a --retainVM -nh`                  |
| `--help`                              | Displays usage                                        | `./vagrantPlaybookCheck.sh --help`                             |
|                                       |                                                       |                                                                |
| `--build` / `-b`                      | Build JDK8 on the VM after the playbook               | `./vagrantPlaybookCheck.sh -a --build`                         |
| `--build-fork` / `-bf` build fork     | Specify the fork of the openjdk-build repo to clone   | `./vagrantPlaybookCheck.sh -a --build --build-fork sxa`        |
| `--build-branch` / `-bb` build branch | Specify the branch of the build fork to clone         | `./vagrantPlaybookCheck.sh -a --build --build-branch master`   |
| `--build-hotspot`                     | Specify to build the JDK with the Hotspot JVM *       | `./vagrantPlaybookCheck.sh -a --build --build-hotspot`         |
| `--JDK-Version` / `-jdk` jdk          | Specify which JDK to build, if applicable             | `./vagrantPlaybookCheck.sh -a --build --JDK-version jdk11`     |
| `--test` / `-t`                       | Run a small test on the built JDK within the VM *     | `./vagrantPlaybookCheck.sh -a --build --test`                  |
|                                       |                                                       |                                                                |
| `-V`,`-VV`,`-VVV`,`-VVVV`             | Add various verbosity levels to ansible-playbook cmd  | `./vagrantPlaybookCheck.sh -a --build -VVV`                    |

Notes:
 - The `--fork` and `--branch` arguments default to `adoptopenjdk` and `master`, respectively.
 - The `--build-fork` and `--build-branch` arguments also default to `adoptopenjdk` and `master`, respectively.
 - By default, the JDK will be built with the OpenJ9 JVM, as it has more dependencies which is a better test for the playbooks.
 - `--test` requires `--build` be enabled, otherwise the script will error.
 - When `--provider libvirt` is used with `--all`, only OSs that have a `Vagrantfile.<OS>.Libvirt` are included. VirtualBox-only OSs are excluded automatically.
 - When `--provider libvirt` is used with a specific OS that has no `.Libvirt` Vagrantfile, the script warns and falls back to VirtualBox.

The script will first clone the repository specified by the `--fork` and `--branch` options. For example, if `--fork` is 'willsparker' and `--branch` is '1941', the repository being cloned is https://github.com/willsparker/openjdk-infrastructure/tree/1941.

The script will then make a directory in the `$WORKSPACE` location called _adoptopenjdkPBTests_, in which another directory containing the log files, and the Git repository is stored. Following that, the script will run each ansible playbook on their respective VMs, writing the output to the aforementioned log files. If not defined prior to running, `$WORKSPACE` will default to `$HOME`.

After each playbook is ran through, a summary is given, containing which OS playbooks succeeded, failed, or were cancelled. The logs can also be perused to get more in-depth error messages.

If specified, the VMs will then be tested by building JDK8 - if all dependencies are filled by the playbook as they should be, the JDK will be successfully built. If the `--test` option is then specified, the JDK will then have a simple test ran against it that will ensure it was built properly.

If the VMs were chosen *not* to be destroyed, they can be later by running the _vmDestroy.sh_ script, which takes the `Vagrant OS` as an argument. If found, every Vagrant VM with this OS will be destroyed, therefore the user will be asked to confirm they want this. The `--force` option will skip this prompt.

Vagrant boxes can be updated by their provider from time to time, and using outdated versions can occasionally [cause issues](https://github.com/adoptium/infrastructure/issues/2375#issue-1043540735). To ensure the current vagrant boxes used on the system are up to date, _updateBoxes.sh_ can be used. This will check and update all current vagrant boxes for the user. Outdated box versions will be removed if the `-r` option, is used. A prompt will ask the user to confirm the removal of a box, and option `-rf` will skip this prompt.

The additional scripts in the _pbTestScripts_ folder are called from `vagrantPlaybookCheck.sh`

---

## Adding a new OS distribution

1. Create `ansible/vagrant/Vagrantfile.<NewOS>` following the structure of an existing VirtualBox Vagrantfile.
2. Optionally create `ansible/vagrant/Vagrantfile.<NewOS>.Libvirt` for Libvirt support (see pattern below).
3. For Windows OSs, add the short name to the Windows guard condition in the main loop of
   `vagrantPlaybookCheck.sh` (search for the `Win2012 || Win2022 || Win2025` condition).
4. Update this README's OS list above.

The script auto-discovers both Vagrantfiles from their filenames — no other code changes are needed.

---

## Adding support for a new provider

The Vagrantfile naming convention uses a suffix to identify the provider: `Vagrantfile.<OS>.<Provider>`.
VirtualBox Vagrantfiles use no suffix (e.g. `Vagrantfile.Ubuntu2004`). All others use a capitalised
provider name (e.g. `Vagrantfile.Ubuntu2004.Libvirt`).

To add a new provider (e.g. `Hyperv`):

1. Create `ansible/vagrant/Vagrantfile.<OS>.Hyperv` files for each OS to support.
2. In `checkVagrantOS()` in `vagrantPlaybookCheck.sh`, add a filter branch for the new provider suffix
   alongside the existing `libvirt` branch.
3. In `startVMPlaybook()`, add a branch to the `vagrantfileSuffix` logic for the new provider name.
4. In `startVMPlaybookWin()`, add a branch to the `winVagrantfileSuffix` logic for the new provider.
5. In `checkVars()`, add a plugin check if the new provider requires a Vagrant plugin.

### Libvirt Vagrantfile pattern

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
# ... (copy verbatim from VirtualBox equivalent) ...
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.define :adoptopenjdkXXX do |adoptopenjdkXXX|
    adoptopenjdkXXX.vm.box = "<same box as VirtualBox variant>"
    adoptopenjdkXXX.vm.synced_folder ".", "/vagrant", type: "rsync"
    adoptopenjdkXXX.vm.hostname = "adoptopenjdkXXX"
    adoptopenjdkXXX.vm.network :private_network, type: "dhcp"
    adoptopenjdkXXX.vm.provision "shell", inline: $script, privileged: false
  end
  config.vm.provider "libvirt" do |v|
    v.memory = 2560   # match VirtualBox equivalent
    v.cpus = 1        # match VirtualBox equivalent
    # v.machine_virtual_size = 75  # integer GB, only if disk sizing is required
  end
end
```

Key differences from VirtualBox Vagrantfiles:
- `synced_folder` uses `type: "rsync"` (no VirtualBox Guest Additions)
- Provider block is `"libvirt"` with `v.memory` / `v.cpus` / optionally `v.machine_virtual_size`
- No `v.customize ["modifyvm", ...]` (VirtualBox-specific API)
- No `vagrant-disksize` plugin (`disksize.size`) — use `v.machine_virtual_size` instead

---

## Local Libvirt smoke testing

For developer machines with Vagrant and libvirt already installed, use `testLibvirtVagrantfiles.sh`
to validate the Libvirt Vagrantfiles without triggering a full CI run:

```bash
# Boot test only (confirms VM starts and provisions correctly)
./testLibvirtVagrantfiles.sh -v Ubuntu2004

# Boot + full playbook run (skips JDK build/test)
./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook

# Test all Libvirt OSs
./testLibvirtVagrantfiles.sh -a --playbook

# Keep the VM running after the test for manual inspection
./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook --retain
```

Logs are written to `$WORKSPACE/libvirtTests/logFiles/<OS>.log`. A summary table is printed at the end.
