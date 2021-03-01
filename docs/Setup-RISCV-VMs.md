# Creating RISC-V VMs using QEMU

This is a document outlining how to setup multiple different versions of RISC-V QEMU VMs, for Ubuntu 18.04 CLI, using prebuilt images. Whilst this guide uses prebuilt images, information on how to build your own images can be found under the 'Useful Links' section of each version of the VM.

## Install QEMU (version 5.0.0)

Install a few package pre-requisites:

```sh
sudo apt-get install git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev
```

To build the correct version of QEMU:

```sh
wget https://download.qemu.org/qemu-5.0.0.tar.xz
tar xvJf qemu-5.0.0.tar.xz
cd qemu-5.0.0
./configure
make
make install
```

Note: The version has to be `>5.0.0`, otherwise you can't `ssh` into the Fedora Rawhide VM.

## Common arguments

All of these VMs are going to be started with several common arguments passed into `qemu-system-riscv64` , so this section is to explain those:

| Argument & example                             | Explanation                                                                 |
|------------------------------------------------|-----------------------------------------------------------------------------|
| `-smp 4`                                        | Refers to the amount of CPUs passed to VM.                                   |
| `-m 3G`                                          | Refers to the amount of memory passed to VM.                                 |
| `-machine virt`                                  | The machine to be emulated- 'virt' doesn't correspond to a specific machine. |
| `-device virtio-net-device,netdev=usernet`      | Adding a network card 'device' to the VM.                                    |
| `-netdev user,id=usernet,hostfwd=tcp::XXXXX-:22` | Port forwarding port 'XXXXX' to VM's port 22 to allow for ssh.               |
| `-device virtio-blk-device,drive=ABC`            | Adding a storage 'device' to the VM, with ID "ABC".                                        |
| `-drive file=FILE,format=raw,id=ABC`         | Assigning a file to the storage device with ID "ABC".                            |
| `-object rng-random,filename=/dev/urandom,id=rng` | Pass on a source of Random-Number-Generation (RNG) from host to VM, with ID "rng". |
| `-device virtio-rng-device,rng=rng` | Add an rng 'device' to the VM, using the rng source with ID "rng".   |
| `-append "console=ttyS0 ro root=/dev/vda"` | A way of passing options to the linux kernel. |

For more information on the QEMU RNG device, see [VirtIORNG](https://wiki.qemu.org/Features/VirtIORNG)

## Fedora 'Stage4'

Retrieve the prebuilt kernel and disk image from Fedora, and extract the image:

```sh
wget https://fedorapeople.org/groups/risc-v/disk-images/bbl
wget https://fedorapeople.org/groups/risc-v/disk-images/stage4-disk.img.xz
tar xvf stage4-disk.img.xz
```

Run the following from a folder with the disk image and `bbl`:

```sh
qemu-system-riscv64 -nographic \
-machine virt \
-smp 4 \
-m 3G \
-kernel bbl \
-append "console=ttyS0 ro root=/dev/vda"  \
-device virtio-blk-device,drive=hd0 \
-drive file=stage4-disk.img,format=raw,id=hd0 \
-device virtio-net-device,netdev=usernet \
-netdev user,id=usernet,hostfwd=tcp::10000-:22
```

Alternatively, this can be ran in a `screen` session.

You're also able to `ssh` into the machine by running:

```sh
ssh -p 10000 root@localhost
```

The root user's password is `riscv` , it's suggested you change that if the machine you're running on has an IP open to the internet.

### Fedora Stage4 Useful links

- The kernel/disk image repository: [https://fedorapeople.org/groups/risc-v/disk-images/](https://fedorapeople.org/groups/risc-v/disk-images/)
- Extra information of disk images: [https://fedoraproject.org/wiki/Architectures/RISC-V/Disk_images](https://fedoraproject.org/wiki/Architectures/RISC-V/Disk_images)
- Source / extra info for building the kernel: [https://github.com/rwmjones/fedora-riscv-kernel](https://github.com/rwmjones/fedora-riscv-kernel)

## Fedora 'Rawhide'

Retrieve the prebuilt image/Kernel for Fedora-Rawhide:

```sh
wget https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/Fedora-Developer-Rawhide-20191123.n.0-fw_payload-uboot-qemu-virt-smode.elf
wget https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/Fedora-Developer-Rawhide-20191123.n.0-sda.raw.xz
tar xvf Fedora-Developer-Rawhide-20191123.n.0-sda.raw.xz
```

If preferred, you can build your own images. See 'Info on building the images manually' under the 'Useful Links' section.

Run the following, from a folder containing the disk image and kernel:

```sh
qemu-system-riscv64 -nographic \
-machine virt \
-smp 4 \
-m 3G \
-kernel Fedora-Developer-Rawhide-20191123.n.0-fw_payload-uboot-qemu-virt-smode.elf \
-object rng-random,filename=/dev/urandom,id=rng0 \
-device virtio-rng-device,rng=rng0 \
-device virtio-blk-device,drive=hd0 \
-drive file=Fedora-Developer-Rawhide-20191123.n.0-sda.raw,format=raw,id=hd0 \
-device virtio-net-device,netdev=usernet \
-netdev user,id=usernet,hostfwd=tcp::10005-:22
```

To login, use the `riscv` user, password `Fedora_Rocks!`. The root user is unavailable.

To `ssh` into the machine run the following:

```sh
ssh -p 10005 riscv@localhost
```

### Fedora Rawhide Useful links

- Info on building the images manually: [https://fedoraproject.org/wiki/Architectures/RISC-V/Installing](https://fedoraproject.org/wiki/Architectures/RISC-V/Installing)
- The prebuilt image repository: [https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/](https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/)
- List of nightly build Rawhide images: [http://fedora.riscv.rocks/koji/tasks?state=closed&view=flat&method=createAppliance&order=-id](http://fedora.riscv.rocks/koji/tasks?state=closed&view=flat&method=createAppliance&order=-id)

## Debian

To run a RISC-V Debian VM, some additional packages need to be installed on Ubuntu. This can be done by adding the following to `/etc/apt/sources.list`:

```sh
deb [trusted=yes] http://ftp.uk.debian.org/debian sid main
deb [trusted=yes] http://ftp.uk.debian.org/debian experimental main
```

The `[trusted=yes]` has to be put in as without it, a GPG error occurs stating: `The following signatures couldn't be verified because the public key is not available`

```sh
apt update
apt install opensbi u-boot-qemu
```

These packages are to provide the kernel and bootloader for QEMU. Once installed, these will be at:

```sh
/usr/lib/riscv64-linux-gnu/opensbi/qemu/virt/fw_jump.elf
/usr/lib/u-boot/qemu-riscv64_smode/u-boot.bin
```

Then retrieve a prebuilt image and `unzip` it:

```sh
wget https://gitlab.com/api/v4/projects/giomasce%2Fdqib/jobs/artifacts/master/download?job=convert_riscv64-virt -O deb_riscv.zip
unzip deb_riscv.zip
```

Within the `artifacts` directory will be `image.qcow2`. This is the Debian image that needs to be used.

Run the following, from the `artifacts` folder:

```sh
qemu-system-riscv64 -nographic \
-machine virt \
-cpu rv64 \
-smp 4 \
-m 3G \
-kernel /usr/lib/riscv64-linux-gnu/opensbi/qemu/virt/fw_jump.elf \
-device loader,file=/usr/lib/u-boot/qemu-riscv64_smode/u-boot.bin,addr=0x80200000 \
-append "root=LABEL=rootfs console=ttyS0" \
-object rng-random,filename=/dev/urandom,id=rng \
-device virtio-rng-device,rng=rng \
-device virtio-blk-device,drive=hd0 \
-drive file=image.qcow2,if=none,id=hd0 \
-device virtio-net-device,netdev=net \
-netdev user,id=net,hostfwd=tcp::10010-:22
```

The `-cpu` option refers to which CPU QEMU is to emulate. The `-device loader...` option is to pass the bootloader to the VM.

You're able to ssh to the machine by running:

```sh
ssh -p 10010 root@localhost
```

The `root` user's password is set by default to `Debian`

### Useful Links

- Extra information about Debian on RISC-V: [https://wiki.debian.org/RISC-V](https://wiki.debian.org/RISC-V)
- Prebuilt image repository: [https://people.debian.org/~gio/dqib/](https://people.debian.org/~gio/dqib/)

### Adding Additional Storage to the VM

With all of these VMs, the only secondary storage they have are the virtual disks that the boot image is on. Often these don't don't suffice and additional storage is required.

`fallocate` can be used to create a suitably large file to mount to the VM. In this example, a 10GB file is made.

```sh
fallocate -l 10GB second_disk.img
```

Once the file is made, it needs to be added to the VM on booting. To do this, take the `qemu-system-riscv64` command above, and add the following lines:

```sh
-device virtio-blk-device,drive=hd1 \
-drive file=second_disk.img,format=raw,if=none,id=hd1
```

**Note:** The `id` field in the `-drive` option must be unique.

Once the machine has booted, the unmounted disk can be found by using `fdisk -l`. If this is the only extra disk being added to the VM, it will be `/dev/vdb`.

From here, a partition will need to be made using `fdisk /dev/vdb`, and a filesystem made on that partition: `mkfs.ext4 /dev/vdb1`.

The partition can then be mounted: `mount -t auto /dev/vdb1 /mount/point`. If you want this disk to be mounted automatically on booting the VM, add the following to `/etc/fstab` :

```sh
/dev/vdb1  /home/jenkins  ext4  defaults 0 1
```
