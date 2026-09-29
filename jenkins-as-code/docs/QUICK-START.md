# Jenkins Infrastructure Quick Start Guide

This guide provides a quick reference for deploying a complete Jenkins infrastructure using the Ansible playbooks.

## Overview

The Jenkins infrastructure deployment consists of two main playbooks:

1. **`setup-jenkins-host.yml`** - Prepares the host system
2. **`install-jenkins-server.yml`** - Installs and configures Jenkins

## Prerequisites

- Ubuntu 24.04 system
- Root/sudo access
- Internet connectivity
- Ansible installed

## Complete Deployment (Two-Step Process)

### Step 1: Prepare the Host

This playbook sets up the base system with:
- Jenkins user (UID/GID 1000 if available)
- Java 25 (Temurin JDK)
- Essential packages
- Security hardening (fail2ban, SSH configuration)
- System services (NTP, unattended upgrades)

```bash
cd jenkins-as-code/ansible
ansible-playbook setup-jenkins-host.yml --connection=local
```

**Duration:** ~5-10 minutes

### Step 2: Install Jenkins Server

This playbook installs Jenkins with:
- Jenkins LTS from official repository
- Jenkins home at `/home/jenkins/.jenkins`
- Systemd service configuration
- Proper directory structure and permissions

```bash
ansible-playbook install-jenkins-server.yml --connection=local
```

**Duration:** ~3-5 minutes

### Step 3: Access Jenkins

After installation completes, the playbook displays:
- Jenkins URL (e.g., `http://192.168.1.100:8080`)
- Initial admin password

Open the URL in your browser and use the password to unlock Jenkins.

## One-Command Deployment

To run both playbooks sequentially:

```bash
ansible-playbook setup-jenkins-host.yml --connection=local && \
ansible-playbook install-jenkins-server.yml --connection=local
```

## Directory Structure

After deployment, your Jenkins installation will have:

```
/home/jenkins/
├── .jenkins/                    # Jenkins home directory (JENKINS_HOME)
│   ├── config.xml              # Jenkins configuration
│   ├── plugins/                # Installed plugins
│   ├── jobs/                   # Jenkins jobs
│   ├── workspace/              # Build workspaces
│   ├── updates/                # Update center data
│   ├── secrets/                # Secrets directory
│   │   └── initialAdminPassword
│   └── logs/                   # Jenkins logs
│
├── .ssh/                       # SSH configuration
│   ├── authorized_keys         # SSH public keys
│   └── known_hosts            # Known SSH hosts
│
/var/cache/jenkins/             # Jenkins cache
└── war/                        # Exploded WAR files

/var/log/jenkins/               # Jenkins logs
└── jenkins.log                 # Main log file
```

## Key Configuration Details

### Jenkins User
- **Username:** `jenkins`
- **UID/GID:** 1000 (if available, otherwise system-assigned)
- **Home:** `/home/jenkins`
- **Shell:** `/bin/bash`
- **Sudo:** No (security best practice)

### Jenkins Installation
- **Home Directory:** `/home/jenkins/.jenkins`
- **HTTP Port:** 8080
- **Service User:** `jenkins`
- **Java Version:** Temurin 25 JDK
- **JVM Memory:** 2GB max, 512MB min (configurable)

### Security Features
- SSH password authentication disabled
- Fail2ban protecting SSH (3 attempts, 10-minute window)
- Unattended security updates configured (disabled by default)
- NTP time synchronization
- Proper file permissions and ownership

## Post-Installation Checklist

- [ ] Access Jenkins web interface
- [ ] Complete initial setup wizard
- [ ] Install recommended plugins
- [ ] Create admin user
- [ ] Configure Jenkins URL
- [ ] Set up backup strategy
- [ ] Configure firewall rules (if needed)
- [ ] Set up reverse proxy with HTTPS (recommended for production)

## Common Commands

### Service Management
```bash
# Check Jenkins status
sudo systemctl status jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# View logs
sudo journalctl -u jenkins -f
```

### File Operations
```bash
# View initial admin password
sudo cat /home/jenkins/.jenkins/secrets/initialAdminPassword

# Check Jenkins home ownership
ls -la /home/jenkins/.jenkins/

# View Jenkins configuration
sudo cat /etc/default/jenkins
```

### Verification
```bash
# Check Jenkins is listening
sudo netstat -tlnp | grep 8080

# Test HTTP access
curl -I http://localhost:8080

# Check Java version
java -version
```

## Customization

### Change Jenkins Port

Edit `install-jenkins-server.yml`:
```yaml
vars:
  jenkins_port: 9090  # Change from 8080
  jenkins_args: "--webroot=/var/cache/jenkins/war --httpPort=9090"
```

### Adjust JVM Memory

Edit `install-jenkins-server.yml`:
```yaml
vars:
  jenkins_java_opts: "-Djava.awt.headless=true -Xmx4096m -Xms1024m"
```

### Customize SSH Key

Before running `setup-jenkins-host.yml`, set environment variable:
```bash
export JENKINS_SSH_KEY="ssh-rsa AAAAB3... your-key-here"
ansible-playbook setup-jenkins-host.yml --connection=local
```

Or edit the playbook directly:
```yaml
vars:
  jenkins_ssh_key: "ssh-rsa AAAAB3... your-key-here"
```

## Troubleshooting

### Jenkins Won't Start
```bash
# Check logs
sudo journalctl -u jenkins -n 50

# Check Java
java -version

# Fix permissions
sudo chown -R jenkins:jenkins /home/jenkins/.jenkins/
```

### Port Already in Use
```bash
# Find what's using port 8080
sudo lsof -i :8080

# Change Jenkins port in playbook or stop conflicting service
```

### Can't Access Jenkins
```bash
# Check firewall
sudo ufw status
sudo ufw allow 8080/tcp

# Check Jenkins is running
sudo systemctl status jenkins

# Check network binding
sudo netstat -tlnp | grep 8080
```

## Next Steps

After successful deployment:

1. **Complete Jenkins Setup:**
   - Install plugins
   - Configure security
   - Set up credentials
   - Create jobs

2. **Configure Backups:**
   - Set up automated backups of `/home/jenkins/.jenkins/`
   - Test restore procedures

3. **Production Hardening:**
   - Set up HTTPS with reverse proxy
   - Configure firewall rules
   - Enable unattended security updates
   - Set up monitoring

4. **Integration:**
   - Connect to version control (Git, GitHub, etc.)
   - Configure build agents
   - Set up notifications

## Documentation

- [JENKINS-INSTALL.md](JENKINS-INSTALL.md) - Detailed Jenkins installation guide
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Complete deployment documentation
- [roles/README.md](roles/README.md) - Ansible roles documentation
- [VAGRANT-DEPLOYMENT.md](VAGRANT-DEPLOYMENT.md) - Vagrant testing guide

## Support Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Community](https://community.jenkins.io/)
- [Ansible Documentation](https://docs.ansible.com/)

---

**Made with Bob**