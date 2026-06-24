# Infrastructure Setup Guide

## Prerequisites

This guide covers the setup requirements for the Adoptium infrastructure automation using Ansible.

## Python Requirements

The infrastructure automation requires Python 3.x and several Python packages, particularly for managing Windows hosts via WinRM.

### Installation

Install the required Python packages:

```bash
pip3 install --user -r requirements.txt
```

Or system-wide (requires sudo):

```bash
sudo pip3 install -r requirements.txt
```

### Key Dependencies

- **ansible** - Core automation framework
- **pywinrm** - Required for Windows host management via WinRM protocol
- **requests-ntlm** - NTLM authentication support for Windows
- **requests-credssp** - CredSSP authentication support

## Ansible Collections

The project uses Ansible Galaxy collections that must be installed:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

To force reinstall/update collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml --force
```

### Required Collections

- **community.general** - General purpose modules and plugins
- **community.windows** - Windows-specific modules (requires pywinrm)
- **ansible.windows** - Core Windows support

## Verification

Verify your setup:

```bash
# Check Python packages
pip3 list | grep -E "(ansible|pywinrm|requests)"

# Check Ansible collections
ansible-galaxy collection list | grep -E "(community.general|community.windows|ansible.windows)"

# Verify pywinrm is accessible
python3 -c "import winrm; print(f'pywinrm version: {winrm.__version__}')"
```

## Troubleshooting

### WinRM Dependency Error

If you see an error like:
```
Unable to resolve dependency: user requested 'winrm (= 2.3.6)'
```

This indicates the `pywinrm` Python package is not installed or not accessible. Solutions:

1. Install Python requirements: `pip3 install --user -r requirements.txt`
2. Reinstall collections: `ansible-galaxy collection install -r collections/requirements.yml --force`
3. Verify pywinrm: `python3 -c "import winrm"`

### Collection Installation Issues

If collections fail to install:

1. Check internet connectivity to galaxy.ansible.com
2. Clear Ansible cache: `rm -rf ~/.ansible/collections`
3. Reinstall with `--force` flag

## Windows Host Configuration

For managing Windows hosts, the target machines must be configured for WinRM. See the playbook comments in:
- `ansible/playbooks/AdoptOpenJDK_Windows_Playbook/windows_with_ssh.yml`
- `ansible/playbooks/AdoptOpenJDK_Windows_Playbook/windows_dockerhost.yml`

Basic Windows setup:
```powershell
# On the Windows target machine (as Administrator)
wget https://raw.githubusercontent.com/ansible/ansible-documentation/devel/examples/scripts/ConfigureRemotingForAnsible.ps1 -OutFile .\ConfigureRemotingForAnsible.ps1
.\ConfigureRemotingForAnsible.ps1 -CertValidityDays 9999
.\ConfigureRemotingForAnsible.ps1 -EnableCredSSP
.\ConfigureRemotingForAnsible.ps1 -ForceNewSSLCert
.\ConfigureRemotingForAnsible.ps1 -SkipNetworkProfileCheck
```

## Additional Resources

- [Main README](README.md) - Project overview and documentation
- [Ansible Documentation](ansible/README.md) - Detailed Ansible usage
- [FAQ](FAQ.md) - Common questions and operations
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute