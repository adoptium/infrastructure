# Recreating QEMU images
This is a document how to rebuild the images used in the [QEMUPlaybookCheck](https://ci.adoptopenjdk.net/job/QEMUPlaybookCheck/) (QPC) Jenkins job, in the event of having to migrate the machine that runs QPC. In this document, the **host machine** refers to the machine running QPC and the **guest machine** refers to the QEMU VM.

## Standarised rules:
Regardless of the architecture that QEMU is emulating, all of the disk images mentioned here will follow rules to ensure the QPC script still works on the machines.

| Rule | Explanation |
|--|--|
| 15GB Image size | This is to allow enough space for the Unix Playbook to fully run and build a JDK.
User: `linux`, Password: `password`  | This is allow for `sshpass` to add the generated ssh key to the QEMU machine, allowing for automatic sign in.
| Password-less `sudo` | This is to allow for the `-b` option to be used in the `ansible-playbook` command automatically.
| `sudo`, `python2` / `python3` are installed | The playbooks aren't setup to install any of these, but they are required to run the Ansible commands.

In addition to these guest machine rules, all images must be stored in _/qemu_base_images/_ on the host machine, compressed using `xz` , under the name `$ARCHITECTURE.dsk.xz`.

### Extending the disk image:
Irrespective of the file used for the the disk image- i.e. `qcow2` or `DOS/MBR boot sector` , the disk images can be resized using:
```bash
# Making $ARCHITECTURE.dsk 5Gb larger
$ qemu-img resize $ARCHITECTURE.dsk +5G
```
This is executed on the host machine. The QEMU VM using this disk image must not be running when you do this.

**Note:** Once you've done this, you'll need to extend the partition within the VM. Alternatively creating a new partition and mount it at `/home/linux` for extra space to build the JDK.
### Password-less `sudo`:
This is only applicable once `sudo` is installed. This is required to allow for the `linux` user to use `sudo` without requiring a password to be input, so [qemuPlaybookCheck.sh](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/pbTestScripts/qemuPlaybookCheck.sh) can use the `-b` option in `ansible-playbook` without user interaction. 
```bash
sudo sh -c "echo 'linux ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers"
```
This can also be done with whichever file editor you tend to use. This is executed on the guest machine.

## Disk Images

### Ubuntu18.04 PPC64LE:
The Ubuntu18.04 disk was created manually, as opposed to getting a pre-made one from a guide. The first step is to find a PPC64LE ISO. At the time of creating the image, Ubuntu 18.04 could be found on the [Ubuntu website](https://ubuntu.com/download/server/power), however this has been updated with the newest LTS. Alternatively Ubuntu18.04 PPC64LE ISOs can be found at [cloud-images.ubuntu](https://cloud-images.ubuntu.com/releases/bionic/release/)

After this we need to create a large file to put the disk image on. The current U18 PPC64le disk image uses a `raw` format, created by doing the following: 
```bash
fallocate -l 15GB PPC64LE.dsk
```
However, this could be created in QEMU's `qcow2` format
```bash
qemu-img create -f qcow2 PPC64LE.dsk 15G
```
The iso then needs to be installed on the created disk. To do this, a QEMU VM needs to be created that boots from the iso, to install on the disk:
```bash
qemu-system-ppc64 -M pseries -m 1024 -cdrom U18-ppc64el.iso -boot d -hda PPC64LE.dsk
```
Run through the installation as normal, and the disk image should be ready. To then run the machine to add the `linux` user and other config, run the following: 
```bash
qemu-system-ppc64 -M pseries -m 1024 -hda PPC64LE.dsk
```
### Ubuntu18.04 S390x:
This was setup very much like the above Ubuntu18.04 PPC64LE disk- i.e, an Iso found [here](https://cloud-images.ubuntu.com/releases/bionic/release/) was used to install Ubuntu18.04 on a 15GB `qcow` image. 
Run this to start the installation: 
```bash
qemu-system-s390x -M s390-ccw-virtio -m 1024 -cdrom U18-S390x.iso -drive file=S390X.dsk,if=none,format=raw,id=hd0 -device virtio-blk-ccw,drive=hd0,id=virtio-disk0 -boot d
```
And to run the QEMU machine as normal: 
```bash
qemu-system-s390x -M s390-ccw-virtio -m 1024 -drive file=S390X.dsk,if=none,format=raw,id=hd0 -device virtio-blk-ccw,drive=hd0,id=virtio-disk0
```
If for whatever reason these don't work, there is another process that can produce a working `s390x` QEMU VM, which would be to use the separate `-kernel` and `-init` options in the `qemu-system-s390x` command. These aren't currently supported in the `qemuPlaybookCheck.sh` script, but wouldn't be too difficult to alter if required.

A link to a guide to build a **Debian** S390x image can be found [here](https://wiki.qemu.org/Documentation/Platforms/S390X#Minimal_command-line), with a link to where the `kernel` and `initrd` can be downloaded. Alternatively, these can be extracted from an iso.

A link to a guide to build an **Ubuntu19.04 Server** S390x image, as well as how to extract `kernel` and `initrd` files from an iso, can be found [here](https://astr0baby.wordpress.com/2019/05/09/testing-bleeding-edge-ubuntu-server-19-10-s390x-in-qemu/). 
### Debian Buster ARM64:
This architecture was setup using the instructions [here](https://wiki.debian.org/Arm64Qemu), with the disk image found [here](https://cdimage.debian.org/cdimage/openstack/current/). When setting up the images for QPC, the `debian-10.4.3-*-arm64.qcow2` image was used, however new images are being released fairly frequently.

With this architecture, an extra QEMU package has to be installed to provide the file used for `-bios` option in the `qemu-system-aarch64` command:
```bash
$ apt install qemu-efi-aarch64
```
The setup instructions also suggests installing `qemu-system-arm` and `qemu-utils`, however `qemu-system-arm` isn't required if `QEMU 5.0.0` has been built on the system, and `qemu-utils` just wasn't used.

### RISC-V Images:
For information on how to setup several different kind of RISC-V VMs, see [https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/docs/Setup-RISCV-VMs.md](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/docs/Setup-RISCV-VMs.md)

Of the three that are listed in that document, only the Debian Bullseye RISC-V VM is used in QPC. 
The document also gives a broader overview of QEMU, for instance; how to build `QEMU 5.0.0` on an Ubuntu Host machine, explanation for the `qemu-system-$arch` command options and how to add additional disks to a QEMU VM.

## Useful Links:
QEMU Documentation: [https://wiki.qemu.org/Documentation](https://wiki.qemu.org/Documentation)

Overview of QEMU emulating different architectures on different OSs: [https://gmplib.org/~tege/qemu.html](https://gmplib.org/~tege/qemu.html)
