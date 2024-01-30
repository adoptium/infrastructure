# Recreating QEMU images

This is a document how to rebuild the images used in the [QEMUPlaybookCheck](https://ci.adoptium.net/job/QEMUPlaybookCheck/) (QPC) Jenkins job, in the event of having to migrate the machine that runs QPC. In this document, the **host machine** refers to the machine running QPC and the **guest machine** refers to the QEMU VM.

## Standardized rules

Regardless of the architecture that QEMU is emulating, all of the disk images mentioned here will follow rules to ensure the QPC script still works on the machines.

| Rule | Explanation |
|--|--|
| 15GB Image size | This is to allow enough space for the Unix Playbook to fully run and build a JDK.
User: `linux`, Password: `password`  | This is allow for `sshpass` to add the generated ssh key to the QEMU machine, allowing for automatic sign in.
| Password-less `sudo` | This is to allow for the `-b` option to be used in the `ansible-playbook` command automatically.
| `sudo`, `python2` / `python3` are installed | The playbooks aren't setup to install any of these, but they are required to run the Ansible commands.

In addition to these guest machine rules, all images must be stored in _/qemu_base_images/_ on the host machine, compressed using `xz` , under the name `$ARCHITECTURE.dsk.xz`.

### Extending the disk image

Irrespective of the file used for the the disk image- i.e. `qcow2` or `DOS/MBR boot sector` , the disk images can be resized using:

```bash
# Making $ARCHITECTURE.dsk 5Gb larger
$ qemu-img resize $ARCHITECTURE.dsk +5G
```

This is executed on the host machine. The QEMU VM using this disk image must not be running when you do this.

**Note:** Once you've done this, you'll need to extend the partition within the VM. Alternatively creating a new partition and mount it at `/home/linux` for extra space to build the JDK.

### Password-less `sudo`

This is only applicable once `sudo` is installed. This is required to allow for the `linux` user to use `sudo` without requiring a password to be input, so [qemuPlaybookCheck.sh](https://github.com/adoptium/infrastructure/blob/master/ansible/pbTestScripts/qemuPlaybookCheck.sh) can use the `-b` option in `ansible-playbook` without user interaction.

```bash
sudo sh -c "echo 'linux ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers"
```

This can also be done with whichever file editor you tend to use. This is executed on the guest machine.

## Disk Images

### Ubuntu18.04 PPC64LE

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

### Ubuntu18.04 S390x

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

### Debian Buster ARM64

This architecture was setup using the instructions [here](https://wiki.debian.org/Arm64Qemu), with the disk image found [here](https://cdimage.debian.org/cdimage/openstack/current/). When setting up the images for QPC, the `debian-10.4.3-*-arm64.qcow2` image was used, however new images are being released fairly frequently.

With this architecture, an extra QEMU package has to be installed to provide the file used for `-bios` option in the `qemu-system-aarch64` command:

```bash
apt install qemu-efi-aarch64
```

The setup instructions also suggests installing `qemu-system-arm` and `qemu-utils`, however `qemu-system-arm` isn't required if `QEMU 5.0.0` has been built on the system, and `qemu-utils` just wasn't used.

### Ubuntu 18 ARM64

This disk image was setup using the instructions [here](https://futurewei-cloud.github.io/ARM-Datacenter/qemu/how-to-launch-aarch64-vm/)

To summarize the instructions in the link:

The packages `qemu-system-arm`, `qemu-efi-aarch64` and `qemu-utils` are installed.
Two flash images are created using the commands

```bash
dd if=/dev/zero of=flash1.img bs=1M count=64
dd if=/dev/zero of=flash0.img bs=1M count=64
dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=flash0.img conv=notrunc
```

An empty disk image is created, using the command

```bash
qemu-img create ubuntu-image.img 20G
```

Then the disk image can be booted up using an installer. The instructions use a [Ubuntu 18 installer](http://ports.ubuntu.com/ubuntu-ports/dists/bionic-updates/main/installer-arm64/current/images/netboot/mini.iso).

The image is booted up the first time using:

```bash
qemu-system-aarch64 -nographic -machine virt,gic-version=max -m 512M -cpu max -smp 4 \
-netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 -device virtio-net-pci,netdev=vnet \
-drive file=ubuntu-image.img,if=none,id=drive0,cache=writeback -device virtio-blk,drive=drive0,bootindex=0 \
-drive file=mini.iso,if=none,id=drive1,cache=writeback -device virtio-blk,drive=drive1,bootindex=1 \
-drive file=flash0.img,format=raw,if=pflash -drive file=flash1.img,format=raw,if=pflash
```

Once the OS is installed, the disk image can be booted on subsequent use without the installer

```bash
qemu-system-aarch64 -nographic -machine virt,gic-version=max -m 512M -cpu max -smp 4 \
-netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 -device virtio-net-pci,netdev=vnet \
-drive file=ubuntu-image.img,if=none,id=drive0,cache=writeback -device virtio-blk,drive=drive0,bootindex=0 \
-drive file=flash0.img,format=raw,if=pflash -drive file=flash1.img,format=raw,if=pflash
```

### Debian / ARM32

This disk image was setup using the instructions [here](https://translatedcode.wordpress.com/2016/11/03/installing-debian-on-qemus-32-bit-arm-virt-board/)

** NB ** Debian 8 Has been deprecated so the instructions have been updated for the current stable Debian build based on the instructions [here:](https://www.willhaley.com/blog/debian-arm-qemu/)

To summarize the instructions in the link:

The packages `qemu-system-arm, libguestfs-tools` and `qemu-utils` are installed.
`libguestfs-tools` is a tool package used for reading and writing to the disk image.

Create an empty disk image

```bash
qemu-img create -f qcow2 debian11.arm32 80G
```

`qcow2` is the format of the image.

The instructions recommend using an initrd and a kernel from the Debian website

The initrd and kernel should be downloaded from the following links in a secure fashion, the links below are sample links for the current stable version ( Debian 11 ), but can be updated appropriately for the version being installed.

```
ftp.us.debian.org/debian/dists/stable/main/installer-armhf/current/images/cdrom/initrd.gz
ftp.us.debian.org/debian/dists/stable/main/installer-armhf/current/images/cdrom/vmlinuz
```  

The ISO to be used for installing Debian 11 can be downloaded using:

```
curl -O -L https://cdimage.debian.org/debian-cd/current/armhf/iso-dvd/debian-11.1.0-armhf-DVD-1.iso
```

Then boot up the disk image for the first time and install the OS

```bash
qemu-system-arm \
  -m 4G \
  -machine type=virt \
  -cpu cortex-a7 \
  -smp 4 \
  -initrd "./initrd.gz" \
  -kernel "./vmlinuz" \
  -append "console=ttyAMA0" \
  -drive file="./debian-11.1.0-armhf-DVD-1.iso",id=cdrom,if=none,media=cdrom \
    -device virtio-scsi-device \
    -device scsi-cd,drive=cdrom \
  -drive file="./debian-arm.sda.qcow2",id=hd,if=none,media=disk \
    -device virtio-scsi-device \
    -device scsi-hd,drive=hd \
  -netdev user,id=net0,hostfwd=tcp::5555-:22 \
    -device virtio-net-device,netdev=net0 \
  -nographic
```

During the installation, you will receive a message complaining about no bootloader installed. Disregard this and continue the installation.
After the installation, the VM should exit since we have used the `-no-reboot` option.

The installer places the initrd and kernel files onto the disk image in the `/boot` directory. These need to be copied out of the disk image and passed as command line parameters to the VM.

Using `libguestfs-tools` installed earlier (the VM MUST not be running when using `libguestfs-tools`), we can see inside the `/boot` directory of the disk image.

```bash
virt-ls -a debian11.arm32 /boot/

## Note The Names Of These Files May Differ

System.map-x.x.x-x-armmp-lpae
configx.x.x-x-armmp-lpae
initrd.img
initrd.img-x.x.x-x-armmp-lpae
lost+found
vmlinuz
vmlinuz-x.x.x-x-armmp-lpae
```

Copy out the appropriate files

```bash
## Start SSHD On The VM
chroot /target/ sh -c "mkdir -p /var/run/sshd && /sbin/sshd -D"
## Use SCP To Copy The Appropriate Files
scp -P 5555 <your username in the VM>@localhost:/boot/vmlinuz ./vmlinuz-from-guest \
scp -P 5555 <your username in the VM>@localhost:/boot/initrd.img ./initrd.img-from-guest
##
exit
```

Finally, boot up the VM

```bash
qemu-system-arm \
  -m 4G \
  -machine type=virt \
  -cpu cortex-a7 \
  -smp 4 \
  -initrd "./initrd.img-from-guest" \
  -kernel "./vmlinuz-from-guest" \
  -append "console=ttyAMA0 root=/dev/sda2" \
  -drive file="./debian-arm.sda.qcow2",id=hd,if=none,media=disk \
    -device virtio-scsi-device \
    -device scsi-hd,drive=hd \
  -netdev user,id=net0,hostfwd=tcp::5555-:22 \
    -device virtio-net-device,netdev=net0 \
  -nographic
```

### RISC-V Images

For information on how to setup several different kind of RISC-V VMs, see [https://github.com/adoptium/infrastructure/blob/master/docs/Setup-RISCV-VMs.md](https://github.com/adoptium/infrastructure/blob/master/docs/Setup-RISCV-VMs.md)

Of the three that are listed in that document, only the Debian Bullseye RISC-V VM is used in QPC.
The document also gives a broader overview of QEMU, for instance; how to build `QEMU 5.0.0` on an Ubuntu Host machine, explanation for the `qemu-system-$arch` command options and how to add additional disks to a QEMU VM.

## Useful Links

QEMU Documentation: [https://wiki.qemu.org/Documentation](https://wiki.qemu.org/Documentation)

Overview of QEMU emulating different architectures on different OSs: [https://gmplib.org/~tege/qemu.html](https://gmplib.org/~tege/qemu.html)
