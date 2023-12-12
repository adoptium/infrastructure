# Testing for Infrastructure Tools

This document will include all of the ways in which testing is done in the infrastructure repository. 

## Vagrant Playbook Check

The Vagrant Playbook Check (VPC) job is used to test changes made to the [Windows and Linux playbooks](https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks).

The job is built in our [Jenkins server](https://ci.adoptium.net/job/VagrantPlaybookCheck/). The job runs a user's fork of the infrastructure repository onto the supported operating systems using Vagrant virtual machines. The vagrant files for the supported operating systems can be found [here](https://github.com/adoptium/infrastructure/tree/master/ansible/vagrant).

Currently, the supported x86-64 systems are:
- Windows 2012 and 2022
- Debian 8 and 10
- Ubuntu 16.04, 18.04, 20.04 and 22.04
- CentOS 6, 7 and 8
- Solaris 10
- Fedora 35
## Qemu Playbook Check

The QEMU Playbook Check (QPC) job is similar to the VPC job except it is not limited to x86-64 virtual machines.

It is built in our [Jenkins server](https://ci.adoptium.net/job/QEMUPlaybookCheck/). The job itself runs [this script](https://github.com/adoptium/infrastructure/blob/master/ansible/pbTestScripts/qemuPlaybookCheck.sh).

Currently, the supported platorms are:
- Ubuntu 18.04 on ppc64le, aarch64 and s390x
- Debian 11 on riscv64
- Debian 10 on aarch64
- Debian 8 on arm32

## Github workflows

These jobs run automatically when a pull request is submitted. The files for these jobs can be found [here](https://github.com/adoptium/infrastructure/tree/master/.github/workflows). 

### Platforms

If a pull request contains changes to the playbooks, this workflow will be triggered automatically. It will execute the playbook changes on the supported platforms:
- [Solaris 10](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build_vagrant.yml)
- [MacOS 11](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build_mac.yml)
- [Windows 2019 and 2022](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build_wsl.yml)

### Docker Build Images

This workflow job executes playbook changes inside a [CentOS 6](https://github.com/adoptium/infrastructure/blob/master/ansible/docker/Dockerfile.CentOS6) and [Alpine 3](https://github.com/adoptium/infrastructure/blob/master/ansible/docker/Dockerfile.Alpine3) docker container which it builds during the job.

The workflow file can be found [here](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build.yml).

### QEMU Playbook Check

Similar to the [job that runs in our Jenkins server](https://github.com/adoptium/infrastructure/blob/master/docs/Testing.md#qemu-playbook-check) but this job runs in a github workflow. 

The supported platforms are:
- Ubuntu 18.04 on aarch64, ppc64le and s390x
- Ubuntu 20.04 on riscv64
- Debian 10 on aarch64

The workflow file can be found [here](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build_qemu.yml).

### Docker Static Checks

This github workflow is triggered when changes are made to the [dockerfiles](https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles) responsible for building our [Static Docker containers](https://github.com/adoptium/infrastructure/blob/master/FAQ.md#dockerstatic-test-systems).

If a pull request contains changes to any of the dockerfiles, the workflow will attempt to build the docker containers. It will pass if the containers build without error.

The file for this workflow can be found [here](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/check_dockerstatic.yml).

## AWX

Though primarily the infrastructure team uses AWX to execute the playbooks onto our [build and test machines](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) as a means of [patching](https://github.com/adoptium/infrastructure/blob/master/FAQ.md#patching), we also use AWX to test changes made to playbooks by executing the changes onto any of the infrastructure machines.

Our AWX server is hosted [here](https://awx2.adoptopenjdk.net/#/login).