# Vagrant Playbook Check — v2 Libvirt Changes

This document covers the changes introduced in the `vpc_v2` branch that extend
the Vagrant-based playbook test infrastructure with **KVM/libvirt** provider support
alongside the existing VirtualBox path.

---

## Background

Previously all Vagrant-based testing used VirtualBox exclusively.  Machines that do
not have VirtualBox available (e.g. bare-metal KVM hosts, certain CI agents) could
not run `vagrantPlaybookCheck.sh`.  This branch adds a parallel libvirt provider path
so the same test matrix can be executed on either hypervisor without modifying the
playbooks or Vagrantfiles for the existing provider.

---

## New Vagrantfiles

A set of `Vagrantfile.<OS>.Libvirt` files has been added to [`ansible/vagrant/`](../vagrant/),
one per supported OS.  The naming convention uses a capitalised provider suffix after
the OS name:

```
Vagrantfile.<OS>              ← VirtualBox (unchanged)
Vagrantfile.<OS>.Libvirt      ← KVM / libvirt (new)
Vagrantfile.<OS>.Adopt        ← VirtualBox Adoptium box (unchanged)
Vagrantfile.<OS>.Adopt.Libvirt ← KVM / libvirt Adoptium box (new, Win2022 & Win2025 only)
```

### Supported Libvirt OSs at merge time

| OS              | Libvirt Vagrantfile                      | Notes                                    |
|-----------------|------------------------------------------|------------------------------------------|
| CentOS 6        | `Vagrantfile.CentOS6.Libvirt`            | rsync synced_folder disabled (OpenSSH 5.x) |
| CentOS 7        | `Vagrantfile.CentOS7.Libvirt`            |                                          |
| CentOS 8        | `Vagrantfile.CentOS8.Libvirt`            |                                          |
| Debian 11       | `Vagrantfile.Debian11.Libvirt`           |                                          |
| Debian 12       | `Vagrantfile.Debian12.Libvirt`           |                                          |
| Fedora 40       | `Vagrantfile.Fedora40.Libvirt`           |                                          |
| Ubuntu 16.04    | `Vagrantfile.Ubuntu1604.Libvirt`         |                                          |
| Ubuntu 18.04    | `Vagrantfile.Ubuntu1804.Libvirt`         |                                          |
| Ubuntu 20.04    | `Vagrantfile.Ubuntu2004.Libvirt`         | `v.machine_virtual_size = 200` required  |
| Ubuntu 21.04    | `Vagrantfile.Ubuntu2104.Libvirt`         |                                          |
| Ubuntu 22.04    | `Vagrantfile.Ubuntu2204.Libvirt`         |                                          |
| Ubuntu 24.04    | `Vagrantfile.Ubuntu2404.Libvirt`         |                                          |
| Win 2022        | `Vagrantfile.Win2022.Libvirt`            | WinRM; best-effort support               |
| Win 2022 Adopt  | `Vagrantfile.Win2022.Adopt.Libvirt`      | WinRM; pre-patched Adoptium box          |
| Win 2025        | `Vagrantfile.Win2025.Libvirt`            | WinRM; best-effort support               |
| Win 2025 Adopt  | `Vagrantfile.Win2025.Adopt.Libvirt`      | WinRM; pre-patched Adoptium box          |

**VirtualBox-only OSs** (no libvirt Vagrantfile):  Win2012, Windows2022.Core.

---

## Key Differences Between VirtualBox and Libvirt Vagrantfiles

| Aspect                   | VirtualBox Vagrantfile           | Libvirt Vagrantfile                                       |
|--------------------------|----------------------------------|-----------------------------------------------------------|
| Provider block           | `config.vm.provider "virtualbox"` | `config.vm.provider "libvirt"`                           |
| Synced folder            | `type: "virtualbox"` (default)   | `type: "rsync"` (no Guest Additions)                     |
| CentOS 6 synced folder   | Default                          | `disabled: true` (OpenSSH 5.x incompatible with rsync)   |
| Disk sizing              | `vagrant-disksize` plugin        | `v.machine_virtual_size` (integer GB)                    |
| VBoxManage customisation | `v.customize [...]`              | Not used                                                  |
| Network                  | NAT + forwarded port             | Private DHCP network, real guest IP                       |
| `vagrant port`           | Returns NAT forwarded port       | Returns nothing (not applicable)                          |
| SSH/WinRM host           | `127.0.0.1`                      | Dynamic IP from `vagrant ssh-config` / `winrm-config`    |
| `vagrant-disksize` plugin | Required                        | **Must be removed** — probes VBoxManage regardless of provider |
| `vagrant-rsync-back` plugin | Required                     | **Must be removed** — same VBoxManage issue               |
| `vagrant-libvirt` plugin | Not used                         | **Required**                                              |

### Typical Libvirt Vagrantfile skeleton

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
# ... provisioning (copy from VirtualBox equivalent) ...
SCRIPT

Vagrant.configure("2") do |config|
  # Suppress vagrant-vbguest probing VBoxManage when that plugin is installed
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  config.vm.define :adoptopenjdkXXX do |adoptopenjdkXXX|
    adoptopenjdkXXX.vm.box = "<same box as VirtualBox variant>"
    adoptopenjdkXXX.vm.synced_folder ".", "/vagrant", type: "rsync"
    adoptopenjdkXXX.vm.hostname = "adoptopenjdkXXX"
    adoptopenjdkXXX.vm.network :private_network, type: "dhcp"
    adoptopenjdkXXX.vm.provision "shell", inline: $script, privileged: false
  end
  config.vm.provider "libvirt" do |v|
    v.memory = 2560   # match VirtualBox equivalent
    v.cpus = 1
    # v.machine_virtual_size = 200  # integer GB, only if disk extension is required
  end
end
```

### Ubuntu 20.04 disk-expansion detail

The `generic/ubuntu2004` box ships with a filesystem significantly smaller than
the 128 GB virtual disk.  When `apt upgrade` installs a new kernel it writes to
`/boot` and fails with `ENOSPC` (Error 24) unless the partition is extended first.
The Libvirt Vagrantfile for Ubuntu 20.04 sets `v.machine_virtual_size = 200` and
runs a provisioner that:

1. Installs `cloud-guest-utils`
2. Detects the root partition device dynamically (`/dev/vda` under KVM, not `/dev/sda`)
3. Calls `growpart` and `resize2fs`
4. Purges old kernel packages from the separate `/boot` partition before `apt upgrade`

This block is not present in the VirtualBox Vagrantfile because VirtualBox uses a
different base box (`bento/ubuntu-20.04`) that does not have the same layout.

---

## Changes to `vagrantPlaybookCheck.sh`

### New `--provider` / `-p` option

```bash
./vagrantPlaybookCheck.sh -a --provider libvirt
./vagrantPlaybookCheck.sh -v Ubuntu2004 --provider libvirt
```

Defaults to `virtualbox` if not specified, so existing invocations are unaffected.

### Plugin management

When `--provider libvirt` is set, `checkVars()` now:

- **Uninstalls** `vagrant-disksize` and `vagrant-rsync-back` if present — both
  plugins probe `VBoxManage` on every `vagrant up` regardless of provider and will
  abort libvirt runs.
- **Installs** `vagrant-libvirt` if not already present.

When `--provider virtualbox` (default), the old behaviour is preserved:
`vagrant-disksize` and `vagrant-rsync-back` are installed if missing.

### OS list filtering (`checkVagrantOS`)

`--all` now builds the OS list filtered to the active provider:

- `libvirt`: scans `Vagrantfile.*.Libvirt` files only.
- `virtualbox`: scans `Vagrantfile.*` files, excluding `.Libvirt` and `.Adopt` suffixes.

This prevents `--all` from ever mixing providers in a single run.

When `--provider libvirt` is used with a specific OS that has no `.Libvirt`
Vagrantfile, the script warns and falls back to the VirtualBox Vagrantfile rather
than aborting.

### Vagrantfile selection (`startVMPlaybook`)

The function appends `.Libvirt` to the symlink target when `provider == libvirt`:

```bash
ln -sf vagrant/Vagrantfile.$OS${vagrantfileSuffix} Vagrantfile
```

### Orphaned domain cleanup (libvirt only)

Before `vagrant up`, the script now:

1. Attempts `vagrant destroy -f` to remove any Vagrant-tracked leftover.
2. Derives the libvirt domain name (`<USER>_<machine_name>`) from the Vagrantfile.
3. Calls `virsh destroy` + `virsh undefine --remove-all-storage` for any orphaned
   domain that Vagrant no longer tracks.

This prevents `"domain name already taken"` errors on subsequent runs after a
failed or interrupted test.

### SSH host / port resolution

Under VirtualBox the guest is reached on `127.0.0.1` via a NAT-forwarded port
obtained from `vagrant port`.  Under libvirt the guest has a real private-network
IP; `vagrant port` returns nothing.

The script now calls `vagrant ssh-config` to obtain `HostName`, `Port`, and
`IdentityFile` for the libvirt path, and stores the result in `sshHost`.  All
subsequent SSH calls (`ssh-keyscan`, `ansible-playbook`, `ssh`, `scp`) use
`${sshHost}` instead of the hard-coded `127.0.0.1`.

### CentOS 6 libvirt path

CentOS 6 ships OpenSSH 5.3, which:

- Only offers `ssh-rsa` host keys — modern OpenSSH (8.8+) disabled `ssh-rsa` by
  default, so `ssh-keyscan` must be called with `-t ssh-rsa`.
- Does not support the `ControlMaster`/`ControlPersist` options that the rsync
  synced folder injects, so the Libvirt Vagrantfile disables the synced folder
  entirely.

Because `/vagrant` is unavailable under libvirt for CentOS 6, the playbook is no
longer run via `vagrant ssh --command "cd /vagrant && ..."`.  Instead:

1. The ansible workspace is copied into the VM via `scp` using the Vagrant-managed
   key (not the playbook key) with legacy algorithm flags
   (`-o HostKeyAlgorithms=ssh-rsa -o PubkeyAcceptedKeyTypes=ssh-rsa`).
2. `vagrant ssh --command` runs the playbook from `~/ansible_workspace` inside the
   VM.
3. The log is retrieved back to the host via `scp`.

### Windows libvirt path (`startVMPlaybookWin`)

The Vagrantfile suffix priority for Windows is:

| Provider  | `--use-adopt` set and `.Adopt.Libvirt` exists | `--use-adopt` set, no `.Adopt.Libvirt` | Default        |
|-----------|-----------------------------------------------|----------------------------------------|----------------|
| libvirt   | `.Adopt.Libvirt`                              | `.Libvirt` (warning)                  | `.Libvirt`     |
| virtualbox | `.Adopt`                                     | —                                     | (none)         |

When `--use-adopt` + libvirt is chosen, `Windows_Updates` is added to
`--skip-tags` automatically because the Adoptium box ships with a known patch
baseline.

Under libvirt, `vagrant port` does not return WinRM port mappings.  The script
uses `vagrant winrm-config` to obtain `HostName` and `Port` for both initial
connection and after the post-playbook `vagrant halt && vagrant up` cycle.

The WinRM port set in `adoptopenjdk_variables.yml` is updated to match the actual
port reported by `winrm-config` (`ansible_port`).

WinRM timeouts (`ansible_winrm_operation_timeout_sec`, `ansible_winrm_read_timeout_sec`)
are extended to 3600 s / 3630 s to accommodate large downloads and `win_unzip` on
slower KVM guests.

When `--build` is used under libvirt, the absence of a synced `C:\vagrant\` folder
is handled by uploading test scripts to `C:\tmp\pbTestScripts\` via WinRM
Base64-encoded PowerShell writes, avoiding any dependency on the synced folder.

### Orphaned libvirt volume cleanup (`cleanupLibvirtVolumes`)

A new function `cleanupLibvirtVolumes()` is called from `destroyVM()` when
`provider == libvirt`.  It:

1. Derives the box name from the Vagrantfile (`vm.box`).
2. Encodes `/` as `-VAGRANTSLASH-` to match the libvirt volume naming convention.
3. Lists volumes in the `default` pool matching `<boxName>_vagrant_box_image_*`.
4. Deletes matching volumes via `virsh vol-delete`.

`vagrant destroy` only removes the `~/.vagrant.d/boxes` entry; the storage pool
image is left behind and must be deleted manually without this step.

### Output filtering

Vagrant and vagrant-libvirt emit `[K`-prefixed progress lines (cursor-erase
sequences used for in-place progress bars) that clutter Jenkins logs.
`VAGRANT_NO_COLOR=1` suppresses ANSI colour codes but not these control sequences.
The `vagrant up` and `vagrant halt && vagrant up` calls are now piped through
`grep -v '^\[K'` to remove both libvirt volume-upload progress and Vagrant
box-download progress lines.

### Xtrace suppression

The script now calls `{ set +x; } 2>/dev/null` at startup.  When Jenkins or a
developer invokes the script with `bash -x`, xtrace was previously emitting
thousands of lines for every argument-parsing comparison and variable assignment.
The explicit `echo` statements already provide all meaningful progress output.

---

## Changes to `updateBoxes.sh`

### New `--provider` / `-p` option

```bash
./updateBoxes.sh -r --provider libvirt
```

When `libvirt` is specified and `--remove` (`-r`) is used:

1. The list of libvirt storage pool volumes in the `default` pool is captured
   **before** `vagrant box prune` runs.
2. After prune, `cleanupOrphanedLibvirtVolumes()` checks each captured volume:
   - Derives the box name from the volume name (reversing `-VAGRANTSLASH-` encoding).
   - If the box no longer appears in `vagrant box list`, the volume is deleted via
     `virsh vol-delete`.
3. Volumes for boxes that are still present are left untouched.

---

## New Script: `testLibvirtVagrantfiles.sh`

A standalone developer smoke-test script for Libvirt Vagrantfiles.  It does **not**
require a Jenkins workspace and does not clone any external repositories.  It is
independent of `vagrantPlaybookCheck.sh`.

### Usage

```bash
# Boot test only
./testLibvirtVagrantfiles.sh -v Ubuntu2004

# Boot + Ansible Unix playbook (skips adoptopenjdk/jenkins tags)
./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook

# Test all Libvirt OSs with playbook
./testLibvirtVagrantfiles.sh -a --playbook

# Keep the VM running after the test
./testLibvirtVagrantfiles.sh -v Ubuntu2004 --playbook --retain
```

### Prerequisites checked at startup

- `vagrant` must be on `PATH`.
- `vagrant-libvirt` plugin must be installed.
- `LIBVIRT_DEFAULT_URI` is set to `qemu:///system` (required for access to
  persistent networks); if not set the script sets it automatically and prints a
  warning.

### What it tests

For each OS:

1. Creates an isolated working directory under `$WORKSPACE/libvirtTests/<OS>/`.
2. Copies `playbooks/`, `plugins/`, and `ansible.cfg` from the local checkout into
   the working directory (preserving the original).
3. Generates a fresh SSH keypair.
4. Symlinks the `Vagrantfile.<OS>.Libvirt` into the working directory as `Vagrantfile`.
5. Runs `vagrant up --provider=libvirt`.
6. Optionally runs `ansible-playbook` against the booted VM using `vagrant ssh-config`
   for host/port discovery.
7. Tears down (halt + destroy) unless `--retain` is specified.

### CentOS 6 playbook limitation

The playbook phase is skipped for CentOS 6 when using this script.  The full
playbook path for CentOS 6 under libvirt requires SCP workspace copying (see the
`vagrantPlaybookCheck.sh` section above) which is not implemented in this lighter
smoke-test script.

### Windows limitation

Windows Libvirt OSs (`Win2022`, `Win2025`) are skipped entirely by this script.
The WinRM communicator requires the `winrm-elevated` Ruby gem, which conflicts with
`rubyzip` 3.x on Vagrant 2.3.x system packages.  The Vagrantfiles themselves are
valid — this limitation is a Vagrant gem dependency issue on the test host.

### Summary output

At the end of a run a summary table is printed:

```
OS                              Boot      Playbook     Overall
------------------------------  --------  -----------  -------
Ubuntu2004                      PASS      PASS         PASS
CentOS6                         PASS      SKIP         PASS
Win2022                         SKIP      SKIP         SKIP
```

Exit code is `0` if all tested OSs passed, `1` if any failed.

### Log files

Ansible playbook output is written to:

```
$WORKSPACE/libvirtTests/logFiles/<OS>.log
```

---

## Adding a New Libvirt OS

1. Create `ansible/vagrant/Vagrantfile.<NewOS>.Libvirt` following the skeleton above.
2. For Windows: also consider `Vagrantfile.<NewOS>.Adopt.Libvirt` if an Adoptium box
   is available.
3. No changes to `vagrantPlaybookCheck.sh` are required — the script auto-discovers
   Vagrantfiles by filename.
4. If the new OS uses WinRM (i.e. it is a Windows variant), ensure it is listed in
   the Windows guard condition in `vagrantPlaybookCheck.sh`:
   ```bash
   if [[ "$OS" == "Win2012" || "$OS" == "Win2022" || "$OS" == "Win2025" || ... ]]; then
   ```
5. Update the OS table in `README.md`.

---

## Known Limitations and Caveats

| Limitation                     | Detail                                                                                              |
|--------------------------------|-----------------------------------------------------------------------------------------------------|
| Win2012 / Win2022.Core         | No Libvirt Vagrantfile; always use VirtualBox.                                                      |
| CentOS 6 + libvirt             | Synced folder disabled; playbook must be SCP-transferred into the VM.                               |
| Windows + libvirt              | WinRM over plain HTTP (port 5985) rather than SSL (port 5986). Best-effort support.                 |
| `vagrant-disksize` plugin      | Incompatible with libvirt; automatically removed by `vagrantPlaybookCheck.sh` when `--provider libvirt` is used. |
| `testLibvirtVagrantfiles.sh`   | Windows OSs skipped due to `winrm-elevated` / `rubyzip` gem conflict on Vagrant 2.3.x.             |
| Libvirt `LIBVIRT_DEFAULT_URI`  | Must be `qemu:///system`; session context cannot access persistent networks.                        |
