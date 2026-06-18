# Adding New Machines to the Build/Test Farm

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Types of Machines](#types-of-machines)
4. [Step-by-Step Process](#step-by-step-process)
5. [Testing and Verification](#testing-and-verification)
6. [Troubleshooting](#troubleshooting)
7. [Related Documentation](#related-documentation)

## Overview

This guide covers the complete process for adding physical machines, virtual machines, or cloud instances to the Adoptium build and test infrastructure.

### When to Use This Guide

Use this guide when you need to:
- Add a new physical machine to the infrastructure
- Provision a new VM or cloud instance
- Set up a dockerhost for running test containers
- Add infrastructure machines (Jenkins, AWX, etc.)

### Note on OS Distributions

This guide assumes you're adding a machine with an already-supported operating system. If you need to add support for a completely new OS distribution or version, additional work may be required to update ansible playbooks and create appropriate Dockerfiles/Vagrantfiles.

### What This Guide Covers

- Provisioning machines from infrastructure providers
- Initial access and security setup
- Adding machines to the ansible inventory
- Running ansible playbooks to configure machines
- Configuring machines in Jenkins
- Setting up monitoring and backups
- Verification and testing procedures

## Prerequisites

### Required Access

Before you begin, ensure you have:

- [ ] **Infrastructure team membership** or sponsorship from a team member
- [ ] **Access to infrastructure providers** (Azure, Equinix, MacStadium, etc.)
- [ ] **Bastillion access** for SSH key management
- [ ] **AWX access** (https://awx2.adoptopenjdk.net) for ansible deployment
- [ ] **Jenkins admin access** (https://ci.adoptium.net) for agent configuration
- [ ] **GitHub repository write access** for inventory updates

### Required Knowledge

You should be familiar with:

- Basic Linux/Windows/macOS administration
- SSH key management and authentication
- Ansible basics (playbooks, inventory, roles)
- Jenkins agent configuration
- Git and GitHub pull request workflow

### Tools Needed

- SSH client (OpenSSH, PuTTY, etc.)
- Git for repository operations
- Web browser for AWX and Jenkins access
- Text editor for inventory file updates

## Types of Machines

### Build Machines

**Purpose**: Compile OpenJDK binaries from source

**Jenkins Labels**: 
- `build` (for static build machines like AIX)
- `dockerBuild` (for machines that host build containers)
- Architecture: `x64`, `aarch64`, `ppc64le`, `s390x`, `riscv64`, `arm32`
- OS: `linux`, `windows`, `macos`, `aix`

**Requirements**:
- Sufficient CPU (8+ cores recommended)
- Sufficient RAM (16GB+ recommended)
- Appropriate compilers installed via ansible
- Build dependencies installed via ansible

**Examples**:
- AIX build machines (static, labeled `build`)
- Linux dockerBuild hosts (run build containers)
- Windows build machines

### Test Machines

**Purpose**: Run AQA test suites against built JDK binaries

**Jenkins Labels**:
- `ci.role.test` (mandatory for all test machines)
- `sw.os.<os>` (e.g., `sw.os.linux`, `sw.os.windows`, `sw.os.mac`)
- `hw.arch.<arch>` (e.g., `hw.arch.x64`, `hw.arch.aarch64`)
- Version-specific if needed: `sw.os.aix.7_2`, `sw.tool.glibc.2_12`

**Requirements**:
- Test prerequisites installed via ansible
- Sufficient resources for test execution
- Network access for downloading test materials
- Appropriate locales configured

**Examples**:
- Physical test machines
- VM test machines
- Static docker test containers (on dockerhosts)

### Dockerhost Machines

**Purpose**: Host multiple docker containers for testing

**Jenkins Labels**:
- `dockerBuild` (primary label)
- `qemustatic` (if QEMU installed for emulation)
- Architecture and OS labels as appropriate

**Requirements**:
- Large CPU allocation (16+ cores recommended)
- Large RAM allocation (32GB+ recommended)
- Docker installed and configured
- Ability to run multiple containers simultaneously

**Examples**:
- dockerhost-azure-ubuntu2204-x64-1
- dockerhost-equinix-ubuntu2204-armv8-1

### Infrastructure Machines

**Purpose**: Run infrastructure services (Jenkins, AWX, Nagios, etc.)

**Requirements**:
- High availability considerations
- Backup procedures configured
- Monitoring setup
- Security hardening

**Examples**:
- Jenkins controller
- AWX server
- Nagios monitoring server
- Bastillion SSH gateway

## Step-by-Step Process

### Important Note on Process Order

This guide follows a **test-first approach**: machines are configured, tested, and verified BEFORE being added to the inventory. This ensures that only working, properly configured machines are added to production infrastructure.

### Step 1: Create Tracking Issue

Create an issue using the [newmachine.md template](../../.github/ISSUE_TEMPLATE/newmachine.md):

- [ ] Navigate to https://github.com/adoptium/infrastructure/issues/new/choose
- [ ] Select "🖥️ Request for additional machines"
- [ ] Fill in all required information:
  - Operating system (linux/windows/macos/aix)
  - Architecture (x64/aarch64/arm32/ppc64/ppc64le/s390x/riscv64)
  - Provider (or leave blank)
  - Desired usage (build/test/dockerhost/infrastructure)
  - Special requirements
  - Quantity needed
  - Justification for the request
- [ ] Submit the issue

**Example Issue Title**: "New Machine requirement: Ubuntu 22.04 x64 test machine"

### Step 2: Obtain Machine from Provider

Provision the machine from your infrastructure provider:

#### Azure
```bash
# Example using Azure CLI
az vm create \
  --resource-group adoptium-rg \
  --name test-azure-ubuntu2204-x64-1 \
  --image Ubuntu2204 \
  --size Standard_D4s_v3 \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub
```

#### Equinix Metal
- Use the Equinix Metal portal or API
- Select appropriate instance type
- Choose operating system
- Configure SSH keys
- Note the assigned IP address

#### MacStadium (for macOS)
- Use Orka portal for macOS VMs
- Configure via Orka CLI or API
- See [packer scripts](../../ansible/packer/) for automation

#### Other Providers
- Follow provider-specific provisioning procedures
- Ensure SSH access is configured
- Note hostname, IP address, and credentials

**Document in the tracking issue**:
- [ ] Hostname
- [ ] IP address
- [ ] Provider
- [ ] Instance type/size
- [ ] Operating system and version
- [ ] Architecture
- [ ] Any special configuration

### Step 3: Initial Access Setup

#### Verify Access

Test connectivity to the machine:

**For Linux/Unix/macOS**:
```bash
ssh root@<IP_ADDRESS>
```

**For Windows**:
- **RDP Access**: Use Remote Desktop to connect to the machine
  ```
  mstsc /v:<IP_ADDRESS>
  Username: Administrator
  ```
- **WinRM Access**: Verify WinRM is configured for ansible
  ```powershell
  # Test WinRM from a Windows machine
  Test-WSMan -ComputerName <IP_ADDRESS>
  
  # Or from Linux/macOS with pywinrm
  python -c "import winrm; s = winrm.Session('<IP_ADDRESS>', auth=('Administrator', 'password')); print(s.run_cmd('ipconfig'))"
  ```

If password authentication is required initially, use it to set up key-based auth (Linux/Unix/macOS) or ensure WinRM is properly configured (Windows).

#### Add to Bastillion (Recommended)

Bastillion distributes SSH keys to all infrastructure machines:

1. Login to Bastillion (requires infrastructure-core team access)
2. Navigate to the appropriate profile:
   - `root-test` - for test machines
   - `root-build` - for build machines
   - `root-dockerhost` - for dockerhost machines
   - `root-infrastructure` - for infrastructure machines
3. Add the new machine to the profile
4. Verify keys are distributed

#### Alternative: Manual Key Setup

If Bastillion access is not immediately available:

```bash
# On your local machine, copy AWX public key
# Get the key from an infrastructure team member or AWX

# On the target machine
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "<AWX_PUBLIC_KEY>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Step 4: Run Ansible Playbooks

Configure the machine with ansible. **Note**: This happens BEFORE adding to inventory to ensure the machine is properly configured.

#### Important: Playbook Changes

If you need to make changes to ansible playbooks to support this machine (e.g., new package names, OS-specific configurations):

1. **Create a separate PR first** for playbook changes
2. Test the playbook changes using the normal playbook testing process (VagrantPlaybookCheck/QEMUPlaybookCheck)
3. Get the playbook PR reviewed and merged
4. Then proceed with adding the machine using the updated playbooks

**Do not combine playbook changes with machine additions in the same PR.**

#### Run Playbooks Directly (Not via AWX)

Since the machine is not yet in the inventory, you'll run ansible playbooks directly against the machine's IP address:

```bash
cd ansible

# For Linux/Unix/macOS - use IP address directly
ansible-playbook -i "<IP_ADDRESS>," -u root \
  playbooks/AdoptOpenJDK_Unix_Playbook/main.yml

# For Windows - use IP address directly
ansible-playbook -i "<IP_ADDRESS>," -u Administrator \
  playbooks/AdoptOpenJDK_Windows_Playbook/main.yml

# For AIX - use IP address directly
ansible-playbook -i "<IP_ADDRESS>," -u root \
  playbooks/AdoptOpenJDK_AIX_Playbook/main.yml

# Note the comma after the IP address - this tells ansible to treat it as an inventory
# Add -vvv for verbose output if troubleshooting
```

**Important**: The machine must be accessible via SSH with the appropriate credentials before running the playbook.

#### Handle Failures

If the playbook fails:

1. Review the error message carefully
2. Check the specific role that failed
3. Verify network connectivity and package repositories
4. Check disk space and permissions
5. Consult [Troubleshooting](#troubleshooting) section
6. Document any manual steps required in the tracking issue

### Step 5: Configure in Jenkins

Add the machine as a Jenkins agent. Configure with **minimal labels initially** - full labels will be added after testing.

#### Create New Node

1. **Login to Jenkins**: https://ci.adoptium.net
2. **Navigate to Node Management**:
   - Click "Manage Jenkins"
   - Click "Manage Nodes and Clouds"
3. **Create New Node**:
   - Click "New Node"
   - Enter node name (should match hostname)
   - Select "Permanent Agent"
   - Click "Create"

#### Configure Node Settings

**Basic Settings**:
- **Name**: `<hostname>` (e.g., `test-azure-ubuntu2204-x64-1`)
- **Description**: Brief description including provider and purpose
- **Number of executors**: 
  - Build machines: 1-2
  - Test machines: 1
  - Dockerhosts: 1 (containers have their own agents)
- **Remote root directory**: 
  - Unix/Linux/macOS: `/home/jenkins`
  - Windows: `C:\Users\jenkins`
- **Labels**: Use minimal labels initially (e.g., just the hostname). Full labels will be added after successful testing in Step 6.
- **Usage**: "Only build jobs with label expressions matching this node"
- **Launch method**:
  - Unix/Linux/macOS: "Launch agents via SSH"
  - Windows: "Launch agent by connecting it to the controller"

**SSH Launch Settings** (Unix/Linux/macOS):
- **Host**: IP address or hostname
- **Credentials**: Select jenkins SSH key
- **Host Key Verification Strategy**: "Known hosts file Verification Strategy"
- **JavaPath**: Leave empty (will use system java)

**Save the configuration**

### Step 6: Run Tests and Verify Functionality

**Critical**: Tests must pass before adding the machine to inventory and applying full labels.

#### For Build Machines

Run a test build:

1. Navigate to a build job (e.g., `build-scripts/jobs/jdk17u/jdk17u-linux-x64-temurin`)
2. Click "Build with Parameters"
3. Set `NODE_LABEL` to your machine's label or hostname
4. Click "Build"
5. Monitor the build:
   - [ ] Build starts successfully
   - [ ] Compilation completes
   - [ ] Artifacts are created
   - [ ] Build time is reasonable
6. Document results in tracking issue

#### For Test Machines

Run the full AQA test pipeline:

1. Navigate to [AQA_Test_Pipeline](https://ci.adoptium.net/job/AQA_Test_Pipeline/)
2. Click "Build with Parameters"
3. Configure parameters:
   - **LABEL**: Set to your machine hostname
   - **JDK_VERSION**: Select version to test (e.g., 17)
   - **JDK_IMPL**: hotspot
   - **BUILD_LIST**: openjdk,functional,system,perf
4. Click "Build"
5. Monitor all test suites:
   - [ ] sanity.functional
   - [ ] extended.functional
   - [ ] special.functional
   - [ ] sanity.openjdk
   - [ ] extended.openjdk
   - [ ] sanity.system
   - [ ] extended.system
   - [ ] sanity.perf
   - [ ] extended.perf
6. Document results in tracking issue
7. Investigate any failures
8. **Once all tests pass**, proceed to Step 7 to add full labels and add to inventory

#### For Dockerhost Machines

Verify docker functionality and deploy test containers:

1. **Verify Docker**:
   ```bash
   ssh root@<hostname>
   docker ps
   docker info
   ```

2. **Deploy Test Containers**:
   ```bash
   cd ansible
   ansible-playbook -i inventory.yml -u root --limit <hostname> \
     -e "docker_images=u2204,alp319,deb12" \
     playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml -t deploy
   ```

3. **Verify Containers**:
   - [ ] Containers start successfully
   - [ ] SSH access works to containers
   - [ ] Containers appear in Jenkins
   - [ ] Test job runs in container

### Step 7: Add Full Labels and Add to Inventory

**Only proceed with this step after successful testing in Step 6.**

#### Update Jenkins Labels

Now that testing is complete, add the full production labels to the Jenkins node:

1. Navigate to the node in Jenkins
2. Click "Configure"
3. Update the Labels field with full production labels

**Label Guidelines**:

**For Build Machines**:
```
build                    # For static build machines (AIX)
dockerBuild             # For machines hosting build containers
x64                     # Architecture
linux                   # Operating system
xlc16                   # Compiler version (if applicable)
```

**For Test Machines**:
```
ci.role.test            # Mandatory for all test machines
sw.os.linux             # Operating system
hw.arch.x64             # Architecture
sw.os.ubuntu22          # Specific OS version (if needed)
sw.tool.glibc.2_12      # Specific library version (if needed)
```

**For Dockerhost Machines**:
```
dockerBuild             # Primary label
qemustatic              # If QEMU installed
linux                   # Operating system
aarch64                 # Architecture
```

**Examples**:
- Build machine: `build linux ppc64 aix73 xlc16`
- Test machine: `ci.role.test sw.os.linux hw.arch.x64`
- Dockerhost: `dockerBuild linux aarch64`

4. Save the configuration

#### Add to Inventory

Create a pull request to add the machine to the ansible inventory:

**Edit inventory.yml**

File location: [`ansible/inventory.yml`](../../ansible/inventory.yml)

Add your machine to the appropriate group:

```yaml
# Example: Adding a test machine
test:
  hosts:
    test-azure-ubuntu2204-x64-1:
      ansible_host: 10.0.1.100
      group: azure
      arch: x64
      os: ubuntu22

# Example: Adding a build machine
build:
  hosts:
    build-osuosl-aix73-ppc64-1:
      ansible_host: 10.0.2.50
      group: osuosl
      arch: ppc64
      os: aix73

# Example: Adding a dockerhost
dockerhost:
  hosts:
    dockerhost-equinix-ubuntu2204-armv8-1:
      ansible_host: 10.0.3.75
      group: equinix
      arch: aarch64
      os: ubuntu22
```

**Update Plugin (if adding new machine type)**

If you're adding a completely new type of machine (not build/test/dockerhost/infrastructure), update:

File: [`ansible/plugins/inventory/adoptopenjdk_yaml.py`](../../ansible/plugins/inventory/adoptopenjdk_yaml.py)

Add the new type to the `MACHINE_TYPES` list around line 45.

**Update Playbook Hosts (if needed)**

If the new machine type needs playbook configuration, update the host lists:

**For Unix/Linux/macOS**: [`ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml`](../../ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml)

```yaml
- hosts: "{{ groups['build'] | default([]) + groups['test'] | default([]) + groups['dockerhost'] | default([]) + groups['YOUR_NEW_TYPE'] | default([]) }}"
```

**For Windows**: [`ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml`](../../ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml)

```yaml
- hosts: "{{ groups['build'] | default([]) + groups['test'] | default([]) + groups['YOUR_NEW_TYPE'] | default([]) }}"
```

**Create Pull Request**

```bash
cd ansible
git checkout -b add-machine-<hostname>
git add inventory.yml
# Add other files if modified
git commit -m "inventory: Add <hostname> to <group>"
git push origin add-machine-<hostname>
# Create PR on GitHub
```

**PR Description should include**:
- Link to tracking issue
- Confirmation that ansible playbooks ran successfully
- Confirmation that all tests passed
- Jenkins node URL
- Any special notes or deviations

### Step 8: Setup Monitoring

#### Nagios Monitoring

Once the machine is added to inventory.yml (Step 7), Nagios monitoring can be configured:

1. Run the nagios playbook:
   ```bash
   ansible-playbook -i inventory.yml \
     playbooks/nagios/play_config_server.yml
   ```
2. Verify in Nagios UI: https://nagios.adoptopenjdk.net
3. Check that alerts are configured

#### Wazuh (if applicable)

For infrastructure machines, configure Wazuh intrusion detection:

1. Follow Wazuh agent installation procedures
2. Configure agent to report to Wazuh server
3. Verify agent appears in Wazuh dashboard

### Step 9: Setup Backups

#### For Infrastructure Machines

Configure backup procedures:

- [ ] Identify critical data to backup
- [ ] Configure backup script/tool
- [ ] Test backup and restore
- [ ] Document backup procedures
- [ ] Schedule regular backups

#### For Build/Test Machines

Build and test machines typically follow immutable infrastructure principles:

- Configuration is in ansible playbooks (version controlled)
- No critical data stored on machines
- Machines can be rebuilt from playbooks
- Generally **not backed up**

### Step 9: Documentation and Closure

Finalize the machine addition:

- [ ] Update tracking issue with final configuration
- [ ] Document any special procedures or manual steps
- [ ] Add notes about any deviations from standard setup
- [ ] Update relevant documentation if needed
- [ ] Close tracking issue with summary

**Example closing comment**:
```
Machine successfully added and verified:
- Hostname: test-azure-ubuntu2204-x64-1
- IP: 10.0.1.100
- Jenkins: https://ci.adoptium.net/computer/test-azure-ubuntu2204-x64-1/
- Ansible playbook: Completed successfully
- AQA tests: All passing
- Monitoring: Configured in Nagios
- Labels: ci.role.test sw.os.linux hw.arch.x64

Ready for production use.
```

## Testing and Verification

### Pre-Production Checklist

Before adding a machine to inventory (Step 7), ensure:

- [ ] Machine provisioned and accessible
- [ ] SSH access configured (Bastillion or manual keys)
- [ ] Ansible playbooks run successfully against IP address
- [ ] Jenkins agent created and connects successfully
- [ ] Test jobs run successfully (build or test verification)
- [ ] All test suites pass (for test machines)
- [ ] No unexpected errors in logs

After adding to inventory (Step 7+):

- [ ] Machine added to inventory.yml
- [ ] Full production labels applied in Jenkins
- [ ] Monitoring configured (Nagios)
- [ ] Backup procedures in place (if applicable)
- [ ] Documentation updated
- [ ] Tracking issue updated

### Production Readiness

A machine is production-ready when:

- [ ] Machine has been running stably for 24+ hours
- [ ] No unexpected errors in logs
- [ ] Monitoring shows healthy status
- [ ] Multiple successful jobs have run
- [ ] Team has been notified of availability
- [ ] Machine is added to relevant documentation

## Troubleshooting

### SSH Connection Issues

**Problem**: Cannot SSH to machine

**Possible Causes and Solutions**:

1. **Incorrect IP address**
   - Verify IP in provider console
   - Check DNS if using hostname
   - Try ping to verify connectivity

2. **Firewall blocking connection**
   - Check provider firewall rules
   - Verify security groups (AWS/Azure)
   - Check local firewall
   - Ensure port 22 is open

3. **SSH service not running**
   - Contact provider support
   - Check if machine is fully booted
   - Verify SSH is installed and enabled

4. **Key authentication failing**
   - Verify correct private key is being used
   - Check key permissions (should be 600)
   - Try password authentication if available
   - Verify public key is in authorized_keys

5. **Wrong username**
   - Try `root`, `ubuntu`, `admin`, `Administrator`
   - Check provider documentation for default user

### Ansible Playbook Failures

**Problem**: Playbook fails during execution

**Common Issues**:

1. **Package repository unreachable**
   ```
   Solution: Check network connectivity
   - Verify DNS resolution
   - Check proxy settings if applicable
   - Verify repository URLs are accessible
   ```

2. **Insufficient disk space**
   ```
   Solution: Free up space or provision larger disk
   - Check with: df -h
   - Clean up: apt-get clean (Ubuntu/Debian)
   - Clean up: yum clean all (RHEL/CentOS)
   ```

3. **Package not found**
   ```
   Solution: Check package name for OS version
   - Package may have different name
   - May need to enable additional repositories
   - May need to build from source
   ```

4. **Permission denied**
   ```
   Solution: Verify ansible is running as root
   - Use -u root flag
   - Or use -b flag for sudo
   - Check sudo permissions
   ```

5. **Timeout errors**
   ```
   Solution: Increase timeout or check connectivity
   - Some operations take time (compiler builds)
   - Check network speed
   - May need to run role separately
   ```

**Debugging Steps**:
```bash
# Run with verbose output
ansible-playbook -vvv -i inventory.yml --limit <hostname> playbooks/...

# Run in check mode first
ansible-playbook --check -i inventory.yml --limit <hostname> playbooks/...

# Run specific role only
ansible-playbook -i inventory.yml --limit <hostname> --tags <role_name> playbooks/...

# Skip problematic role temporarily
ansible-playbook -i inventory.yml --limit <hostname> --skip-tags <role_name> playbooks/...
```

### Jenkins Agent Connection Issues

**Problem**: Jenkins agent won't connect

**Possible Causes and Solutions**:

1. **SSH credentials incorrect**
   - Verify correct credentials selected in Jenkins
   - Test SSH manually: `ssh -i <key> jenkins@<host>`
   - Check jenkins user exists on machine
   - Verify jenkins user's authorized_keys

2. **Firewall blocking connection**
   - Ensure port 22 is open from Jenkins server
   - Check security groups/firewall rules
   - Verify no iptables rules blocking

3. **Java not found**
   - Verify Java is installed: `which java`
   - Check Java version: `java -version`
   - Ensure Java is in PATH
   - May need to specify JavaPath in Jenkins config

4. **Home directory issues**
   - Verify /home/jenkins exists
   - Check permissions: `ls -ld /home/jenkins`
   - Should be owned by jenkins user
   - Should be writable by jenkins user

5. **Host key verification**
   - Add host to known_hosts on Jenkins server
   - Or use "Non verifying" strategy (less secure)

**Debugging Steps**:
```bash
# On Jenkins server, test SSH as jenkins user
sudo -u jenkins ssh -i /var/lib/jenkins/.ssh/id_rsa jenkins@<target-host>

# Check Jenkins agent logs
# In Jenkins UI: Node → Log

# Check system logs on target machine
tail -f /var/log/auth.log  # Ubuntu/Debian
tail -f /var/log/secure    # RHEL/CentOS
```

### Test Failures

**Problem**: Tests fail on new machine but pass elsewhere

**Investigation Steps**:

1. **Check prerequisites**
   - Verify all test prerequisites installed
   - Compare with working machine
   - Check ansible playbook completed successfully

2. **Verify locale settings**
   - Tests often require en_US.UTF-8
   - Check: `locale`
   - Set if needed: `export LANG=en_US.UTF-8`

3. **Check available resources**
   - Disk space: `df -h`
   - Memory: `free -h`
   - CPU: `top` or `htop`

4. **Compare configurations**
   - Compare with known working machine
   - Check library versions
   - Check kernel version
   - Check system settings

5. **Review test logs**
   - Download test artifacts from Jenkins
   - Look for specific error messages
   - Check for timeout issues
   - Look for missing dependencies

6. **Run tests manually**
   - SSH to machine
   - Run test outside Jenkins
   - See [FAQ.md](../../FAQ.md#how-do-i-replicate-a-test-failure) for details

### Performance Issues

**Problem**: Machine is slow or unresponsive

**Investigation Steps**:

1. **Check CPU usage**
   ```bash
   top
   # Look for processes using high CPU
   ```

2. **Check memory usage**
   ```bash
   free -h
   # Check if swap is being used heavily
   ```

3. **Check disk I/O**
   ```bash
   iostat -x 1
   # Look for high %util
   ```

4. **Check network**
   ```bash
   iftop  # If installed
   # Or check with provider monitoring
   ```

5. **Review system logs**
   ```bash
   dmesg | tail
   journalctl -xe
   ```

## Related Documentation

- **[FAQ.md](../../FAQ.md)** - Infrastructure FAQ with common procedures
- **[CONTRIBUTING.md](../../CONTRIBUTING.md)** - General contribution guidelines
- **[Testing.md](../../docs/Testing.md)** - Testing infrastructure overview
- **[Ansible README](../../ansible/README.md)** - Ansible usage and playbook information
- **[DockerStatic README](../../ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/README.md)** - Docker container setup
- **[Infrastructure Providers](../../docs/InfrastructureProviders.md)** - Information about our providers
- **[Access Control](../../docs/AccessControl.md)** - Access control and security
- **[Backups](../../docs/Backups.md)** - Backup procedures

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [FAQ](../../FAQ.md) for common questions
2. Search existing [GitHub issues](https://github.com/adoptium/infrastructure/issues)
3. Ask in the `#infrastructure` [Slack channel](https://adoptium.net/slack)
4. Create a new issue with details of your problem

## Feedback

This documentation can always be improved. If you find:
- Missing steps
- Unclear instructions
- Outdated information
- Errors or typos

Please open an issue or submit a pull request to help improve this guide.