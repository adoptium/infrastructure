# Ubuntu 24.04 Jenkins User Setup - Ansible Playbook

This playbook configures an Ubuntu 24.04 system with a Jenkins user account, SSH access, and proper permissions for Jenkins automation.

## Overview

The playbook performs the following tasks:
- Verifies the target system is running Ubuntu 24.04
- Updates the apt package cache
- Installs essential packages (openssh-server, sudo, python3, python3-pip)
- Creates a Jenkins user with home directory (no sudo access for security)
- Configures SSH access with authorized keys
- Configures system limits for the Jenkins user
- Adds GitHub to known_hosts

## Prerequisites

- Ansible installed on the Ubuntu 24.04 host
- Root or sudo access on the host
- SSH key for Jenkins user (set via environment variable or update in playbook)

## Files

- `ubuntu24-jenkins-setup.yml` - Main Ansible playbook (runs locally on the host)

## Usage

### 1. Install Ansible on the host

```bash
sudo apt update
sudo apt install -y ansible
```

### 2. Set up your SSH key

Export your Jenkins SSH public key as an environment variable:

```bash
export JENKINS_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... jenkins@adoptopenjdk"
```

Or edit the playbook directly to set the `jenkins_ssh_key` variable.

### 3. Run the playbook locally

Execute the playbook on the host itself:

```bash
sudo ansible-playbook ubuntu24-jenkins-setup.yml --connection=local
```

Or without sudo if you're already root:

```bash
ansible-playbook ubuntu24-jenkins-setup.yml --connection=local
```

### 4. Run specific tags (optional)

You can run specific parts of the playbook using tags:

```bash
# Only setup system packages
sudo ansible-playbook ubuntu24-jenkins-setup.yml --connection=local --tags setup

# Only configure Jenkins user
sudo ansible-playbook ubuntu24-jenkins-setup.yml --connection=local --tags jenkins_user
```

## Configuration Variables

The playbook uses the following variables (defined in the playbook):

- `jenkins_username`: Username for the Jenkins user (default: `jenkins`)
- `jenkins_home`: Home directory path (default: `/home/jenkins`)
- `jenkins_ssh_key`: SSH public key for authentication

## Security Considerations

- **Production-Ready Security**: The Jenkins user has NO sudo access (runs with minimal privileges)
- SSH key authentication is required (no password authentication)
- Password expiry is disabled for the Jenkins user to prevent service interruption
- System limits are set to allow Jenkins to handle many processes and open files
- If elevated privileges are needed for specific tasks, use a separate admin account

## Verification

After running the playbook, you can verify the setup:

```bash
# SSH into the VM as Jenkins user
ssh -i /path/to/jenkins/private/key jenkins@<vm-ip>

# Verify user has no sudo access (should show "not allowed")
sudo -l

# Verify limits
ulimit -a

# Check user groups (should NOT include sudo)
groups jenkins
```

## Troubleshooting

### Playbook Fails on Ubuntu Version Check

If the playbook fails on the Ubuntu version assertion:
- Verify you're running Ubuntu 24.04: `lsb_release -a`
- If using a different version, update the assertion in the playbook

### SSH Key Not Working

If SSH key authentication fails:
1. Verify the public key is correctly set in the playbook or environment variable
2. Check the key format (should start with `ssh-rsa`, `ssh-ed25519`, etc.)
3. Ensure the private key has correct permissions: `chmod 600 /path/to/private/key`

## Tags Reference

- `always` - Tasks that always run (verification, display info)
- `setup` - System setup tasks (packages, SSH service)
- `jenkins_user` - Jenkins user creation and configuration

## Related Files

This playbook is part of the Jenkins-as-Code infrastructure setup located in `jenkins-as-code/ansible/playbooks/`.

## License

This playbook is part of the AdoptOpenJDK infrastructure project.

---
*Made with Bob*