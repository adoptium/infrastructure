# Packer Configuration for Virtual Machine Images

This repository contains two Packer configuration files used for building virtual machine images for MacStadium Orka environments. These configurations are specifically tailored to set up environments with necessary tools like Homebrew, Ansible, and Xcode.

## Configuration Files

1. Base Image Creation (`orka-base.pkr.hcl`): This file is used to create a base image for sonoma and sequoia arm64 and intel VMs. It installs Homebrew, Ansible, and specific versions of Xcode (only on arm64).

2. Adoptium Image Creation (`orka.pkr.hcl`): This configuration builds upon the base image to create an Adoptium Sonoma and Sequoia ARM64 and Intel images, with a full Ansible playbook run excluding certain tags.

## Prerequisites

- [Packer](https://www.packer.io/downloads) installed on your system.
- Access to a MacStadium Orka environment (via VPN).
- Required environment variables set (`ORKA_TOKEN`, `XCode11_7_SAS_TOKEN`, `XCode15_2_SAS_TOKEN`).

## Setup and Usage

### Setting Environment Variables

Set the necessary environment variables:

```bash
export ORKA_TOKEN="your-orka-token"
export XCode11_7_SAS_TOKEN="your-xcode11.7-token"
export XCode15_2_SAS_TOKEN="your-xcode15.2-token"
```

### Running the Packer Builds

Below are instructions to build adoptium orka macos images. We first build a base image, which has only xcode installed, and then we build upon this base image by building a final image, which includes the rest of the ansible playbook. At the end of the build the produced image is automatically pushed to our orka cluster. 

Use `sonoma` or `sequoia` in place of `MACOS` and `intel` or `arm64` in place of `ARCH`. All commands must be run from the `ansible/packer` directory.

1. Building the Base image

```bash
packer init orka-base.pkr.hcl
packer build --only=macstadium-orka.MACOS-ARCH orka-base.pkr.hcl
```

The base step has a pause which allows users to manually make any required changes and then resume the build.

2. Building the Adoptium image

The Adoptium image depends on the base image. This generates the images that we use in Jenkins and contains the full set of dependencies.

```bash
packer init orka.pkr.hcl
packer build --only=macstadium-orka.MACOS-ARCH orka.pkr.hcl
```
