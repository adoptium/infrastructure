# Packer Configuration for Virtual Machine Images

This repository contains two Packer configuration files used for building virtual machine images for MacStadium Orka environments. These configurations are specifically tailored to set up environments with necessary tools like Homebrew, Ansible, and Xcode.

## Configuration Files

1. Base Image Creation (`orka-base.pkr.hcl`): This file is used to create a base image for sonoma-arm64 VMs. It installs Homebrew, Ansible, and specific versions of Xcode.

1. Adoptium Image Creation (`orka.pkr.hcl`): This configuration builds upon the base image to create an Adoptium Sonoma ARM64 and Intel image, with a full Ansible playbook run excluding certain tags.

## Prerequisites

- [Packer](https://www.packer.io/downloads) installed on your system.
- Access to a MacStadium Orka environment (via VPN).
- Required environment variables set (`ORKA_TOKEN`, `XCode11_7_SAS_TOKEN`, `XCode15_0_1_SAS_TOKEN`).

## Setup and Usage

### Setting Environment Variables

Set the necessary environment variables:

```bash
export ORKA_TOKEN="your-orka-token"
export XCode11_7_SAS_TOKEN="your-xcode11.7-token"
export XCode15_0_1_SAS_TOKEN="your-xcode15.0.1-token"
```

### Running the Packer Builds

1. Building the Base image

```bash
packer init .
packer build orka-base.pkr.hcl
```

This will create the base image for sonoma-arm64 and somoma-intel VMs. The base step has a pause which allows users to manually make any required changes and then resume the build.

1. Building the Adoptium image

The Adoptium image depends on the base image. This generates the images that we use in Jenkins and contains the full set of dependencies.

```bash
packer init .
packer build orka.pkr.hcl
```
