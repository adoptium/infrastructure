# QEMU Playbook Check — v2 Changes

This document covers the changes made to [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh)
as part of [infrastructure#4494](https://github.com/adoptium/infrastructure/issues/4494).
The QEMU path is independent of the Vagrant/libvirt work described in [`VAGRANT_V2.MD`](VAGRANT_V2.MD).

---

## Background

`qemuPlaybookCheck.sh` runs the Adoptium Unix Ansible playbook against OS disk images
booted under QEMU.  It is used for architectures that cannot be tested with Vagrant
(e.g. `aarch64`, `s390x`, `ppc64le`, `arm32`, `riscv`) because no suitable Vagrant
box exists for those targets.

These changes were driven by the need to support hosts running QEMU 8.x
(Ubuntu 24.04), whereas the script was previously only tested against QEMU 4.x/5.x.
This exposed several bugs: a false-positive boot detection that broke PPC64LE, an
incompatibility between QEMU 8.x and the 2021 RISC-V Debian 11 base image, and a
stale repository URL.

---

## Changes

### 1. Ubuntu 18.04 aarch64 — CPU type changed from `max` to `cortex-a57`

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `runImage()`, `AARCH64 / UBUNTU18` case.

**Before:**
```bash
export EXTRA_ARGS="... -cpu max"
```

**After:**
```bash
export EXTRA_ARGS="... -cpu cortex-a57"
```

**Reason:** `-cpu max` exposes all QEMU-emulated CPU features to the guest, which
caused boot failures for the Ubuntu 18.04 aarch64 image.  `cortex-a57` is the same
fixed-feature model used for the `DEBIAN10` + `aarch64` combination and is the correct
target for these older images.

---

### 2. Boot timeout increased (300 s → 600 s)

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `runImage()`, boot polling loop.

**Reason:** AARCH64/Ubuntu18 images on slower CI hosts were hitting the 300 s limit
before reaching a login prompt.  The disk decompression alone can take over 90 seconds
on the target host, leaving insufficient time for the full boot sequence.  600 seconds
aligns with the observed worst-case boot time across the supported image set.

---

### 3. Infrastructure repository URL corrected

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `runPlaybook()`.

**Before:**
```bash
local gitURL="https://github.com/$gitFork/openjdk-infrastructure"
```

**After:**
```bash
local gitURL="https://github.com/$gitFork/infrastructure"
```

**Reason:** The Adoptium infrastructure repository was renamed from
`openjdk-infrastructure` to `infrastructure`.  The old URL redirects for the canonical
`adoptopenjdk` fork but not for personal or organisation forks, causing `git clone` to
fail with `repository not found` when `--infra-fork` is set to anything other than
`adoptopenjdk`.

---

### 4. VM readiness probe replaced

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `runImage()`, boot polling loop.

The original readiness check used `tail … | grep -q login` on the QEMU console log.
This had two failure modes discovered in order:

1. **False positive (PPC64LE)** — The PPC64LE bootloader writes text containing `login`
   to the console before the kernel has finished booting.  The script broke out of the
   wait loop after ~30 seconds and attempted SSH while sshd was not yet listening,
   resulting in `kex_exchange_identification: read: Connection reset by peer`.

2. **QEMU usermode NAT (intermediate `nc -z` fix)** — `nc -z` was tried as a
   replacement but also failed: QEMU's `-net user` stack answers the TCP handshake at
   the *host* level before guest sshd is up, making the port appear open while the
   connection is immediately reset by the guest.

**Fix:** The probe is now a full `sshpass ssh … uname -a` with `ConnectTimeout=10`.
This only exits 0 when sshd has completed its handshake and accepted authentication —
the only reliable indicator that the VM is ready.

Additionally, `StrictHostKeyChecking` was changed from `no` to `accept-new` to satisfy
the `trailofbits.generic.ssh-disable-host-key-checking` semgrep rule.  `accept-new`
accepts the host key on first connection (required for freshly created VMs) but will
reject if the key changes unexpectedly, unlike `no` which silently accepts any key on
every connection.

---

### 5. SSH key generated before the boot loop

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `runImage()`.

The `ssh-keygen` and `ssh-keygen -R` calls were moved to before the readiness loop so
the key is available from the first probe attempt.  The separate post-loop
`sshpass ssh uname -a` (which existed only to accept the host key) was removed — the
loop's successful probe already performs that function.

---

### 6. `destroyVM` empty-PID guard

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `destroyVM()`.

When QEMU fails to start (e.g. missing firmware files), `ps | grep $PORTNO` returns
nothing and `$PID` is empty.  The original code called `kill $PID` unconditionally,
producing:

```
kill: usage: kill [-s sigspec | -n signum | -sigspec] pid | jobspec ...
```

`destroyVM` now checks `[[ -z "$PID" ]]` before calling `kill` and returns 0
gracefully when no process is found.

---

### 7. RISC-V: direct kernel boot for QEMU 8.x compatibility

**File:** [`qemuPlaybookCheck.sh`](qemuPlaybookCheck.sh) — `setupWorkspace()` and `runImage()`.

**Background:** The Debian 11 RISC-V base image was built in 2021.  QEMU 8.x on
Ubuntu 24.04 ships U-Boot 2025.10, which hits `FDT creation failed! hanging...` when
loading the old image's Device Tree blob.  Additionally, QEMU 8.x automatically loads
`opensbi-riscv64-generic-fw_dynamic.bin` as the default BIOS for the `virt` machine,
so explicitly passing an OpenSBI `.elf` via `-kernel` produces a ROM overlap error:

```
qemu-system-riscv64: Some ROM regions are overlapping
```

**Fix:** Bypass U-Boot and OpenSBI entirely — QEMU 8.x handles OpenSBI automatically.
Boot the guest kernel directly.  The boot flow is:

1. **`setupWorkspace`** mounts the QCOW2 disk image via `qemu-nbd`, extracts
   `vmlinux-*` and `initrd.img-*` from the first partition into the workFolder as
   `vmlinux` and `initrd.img`, then disconnects.  Extraction is skipped on subsequent
   runs if the files already exist.

2. **`runImage`** sets:
   ```bash
   export EXTRA_ARGS="-kernel $workFolder/vmlinux -initrd $workFolder/initrd.img"
   export APPEND_ARGS="root=LABEL=rootfs rw console=ttyS0"
   ```

3. The QEMU launch command uses `${APPEND_ARGS:+-append "$APPEND_ARGS"}` as a separate
   expansion.  Embedding `-append '...'` inside an unquoted variable causes
   word-splitting, which QEMU interprets as multiple separate arguments and fails with
   `drive with bus=0, unit=0 (index=0) exists`.

**Sudoers requirement:** The jenkins user requires the following entries in
`/etc/sudoers.d/jenkins-qemu` on the CI host:

```
jenkins ALL=(root) NOPASSWD: /sbin/modprobe nbd *
jenkins ALL=(root) NOPASSWD: /usr/bin/qemu-nbd *
jenkins ALL=(root) NOPASSWD: /bin/mount *
jenkins ALL=(root) NOPASSWD: /bin/umount *
jenkins ALL=(root) NOPASSWD: /bin/cp *
jenkins ALL=(root) NOPASSWD: /bin/chown *
```

---

## How `qemuPlaybookCheck.sh` Works (Overview)

For reference, the end-to-end flow is:

```
processArgs → defaultVars → setupWorkspace → runImage → runPlaybook
```

| Step             | Function           | What it does                                                                                     |
|------------------|--------------------|--------------------------------------------------------------------------------------------------|
| Parse arguments  | `processArgs()`    | Reads CLI options: architecture, OS, fork, branch, build/test flags.                            |
| Normalise vars   | `defaultVars()`    | Canonicalises architecture/OS names; validates combinations; sets `WORKSPACE`.                   |
| Prepare workspace | `setupWorkspace()` | Copies the compressed disk image from `/home/jenkins/qemu_base_images/<OS>.<ARCH>/` to `$WORKSPACE/qemu_pbCheck/` and decompresses with `xz -d`.  For RISC-V, also extracts the kernel and initrd via `qemu-nbd`. |
| Boot VM          | `runImage()`       | Starts `qemu-system-<arch>` with architecture-specific arguments.  Generates an SSH keypair, then polls with `sshpass ssh … uname -a` until sshd accepts connections.  Injects the public key via `ssh-copy-id`. |
| Run playbook     | `runPlaybook()`    | Clones the infrastructure repo; patches `ansible.cfg`; runs `ansible-playbook` over the QEMU SSH port.  Optionally builds and tests a JDK inside the guest. |
| Teardown         | `destroyVM()`      | Kills the QEMU process by PID (no-op if already gone); optionally removes the disk image.       |

### Supported architecture / OS combinations

```
aarch64
  └── Debian 10
  └── Ubuntu 18.04   ← -cpu cortex-a57
arm32
  └── Debian 8
ppc64le
  └── Ubuntu 18.04
riscv
  └── Debian 11      ← direct kernel boot (no U-Boot)
s390x
  └── Ubuntu 18.04
```

### Disk image location

Images are expected at:

```
/home/jenkins/qemu_base_images/<OS>.<ARCH>/<OS>.<ARCH>.dsk.xz
```

The script copies and decompresses the image to:

```
$WORKSPACE/qemu_pbCheck/<OS>.<ARCH>.dsk
```

If the decompressed image already exists from a previous run it is reused (no
re-copy), unless `--clean-workspace` / `-cw` is specified.

### Port collision avoidance

The default SSH port is `10022`.  When running under Jenkins, `EXECUTOR_NUMBER` is
used to derive a unique port (`1002$EXECUTOR_NUMBER`).  If the derived port is already
in use, the script increments it until a free port is found.

---

## Usage Reference

```bash
./qemuPlaybookCheck.sh -a <arch> -o <os> [options]

Required:
  --architecture | -a <arch>   Target architecture (aarch64, arm32, ppc64le, riscv, s390x)
  --operating-system | -o <os> Target OS (debian8, debian10, debian11, ubuntu18)

Optional:
  --build | -b                 Build a JDK after the playbook
  --build-fork | -bf <fork>    Fork of openjdk-build to use (default: adoptopenjdk)
  --build-branch | -bb <br>    Branch of the build fork (default: master)
  --build-hotspot | -hs        Build with Hotspot instead of OpenJ9
  --clean-workspace | -cw      Remove old work folder before starting
  --currentDir | -c            Set WORKSPACE to the script directory
  --infra-fork | -if <fork>    Fork of the infrastructure repo (default: adoptopenjdk)
  --infra-branch | -ib <br>    Branch of the infrastructure fork (default: master)
  --jdk-version | -v <ver>     JDK version to build (default: jdk8u)
  --retainVM | -r              Keep the QEMU process running after the playbook
  --skip-more | -sm            Skip non-essential roles to speed up the playbook
  --test | -t                  Test the built JDK (requires --build)
  -V / -VV / -VVV / -VVVV     Ansible playbook verbosity
```

### Examples

```bash
# Run the aarch64 Ubuntu 18.04 playbook check
./qemuPlaybookCheck.sh -a aarch64 -o ubuntu18

# Run and also build JDK 11 with Hotspot on RISC-V / Debian 11
./qemuPlaybookCheck.sh -a riscv -o debian11 --build --jdk-version jdk11 --build-hotspot

# Use a fork/branch of the infrastructure repo
./qemuPlaybookCheck.sh -a s390x -o ubuntu18 --infra-fork myuser --infra-branch my-fix

# Retain the VM for manual inspection after the playbook
./qemuPlaybookCheck.sh -a aarch64 -o debian10 --retainVM
```

---

## Notes for Maintainers

- **Adding a new architecture/OS combination** requires adding entries to both
  `defaultVars()` (OS/arch normalisation) and `runImage()` (QEMU command arguments).
  The `showArchList()` function should also be updated for the help output.

- **The `--build` flag is a no-op for RISC-V** — native JDK builds on RISC-V are not
  currently supported.  The script detects this combination and silently skips the
  build/test phase.

- **`sshpass`** must be installed on the host.  It is used both for the boot readiness
  probe and to inject the SSH public key into the guest's `authorized_keys` using the
  image's default password (`password`).

- **RISC-V hosts** require `sudo` access for `modprobe`, `qemu-nbd`, `mount`, `umount`,
  `cp`, and `chown`.  See the sudoers entry in the RISC-V change section above.

- **Log files** are written to `$WORKSPACE/qemu_pbCheck/logFiles/<OS>.<ARCH>.log`.
  Build and test logs use the suffixes `.build_log` and `.test_log` respectively.

---

## Known Limitations and Caveats

| Limitation                  | Detail                                                                                                    |
|-----------------------------|-----------------------------------------------------------------------------------------------------------|
| RISC-V Debian 11 base image | Too old for QEMU 8.x U-Boot (2025.10); requires direct kernel boot via `qemu-nbd` extraction.            |
| RISC-V jenkins sudoers      | `qemu-nbd`, `modprobe`, `mount`, `umount`, `cp`, `chown` must be in jenkins sudoers on the CI host.      |
| RISC-V build/test           | Native JDK builds on RISC-V are not supported; `--build` and `--test` are silently ignored.              |
| Boot timeout                | Fixed at 600 s.  Very slow hosts or large images may still time out; increase `$SECONDS -gt 600` if needed. |
