# Jenkins Server Installation Guide

This guide covers the installation of Jenkins server using the `install-jenkins-server.yml` playbook.

## Overview

The `install-jenkins-server.yml` playbook installs Jenkins LTS on Ubuntu 24.04 with the Jenkins home directory configured at `/home/jenkins/.jenkins` to mirror the production Jenkins master setup.

## Prerequisites

Before running this playbook, you must:

1. **Run the host setup playbook first:**
   ```bash
   ansible-playbook setup-jenkins-host.yml --connection=local
   ```
   This creates the Jenkins user, installs Java, and configures the base system.

2. **Ensure you have:**
   - Ubuntu 24.04 system
   - Root/sudo access
   - Internet connectivity for package downloads

## Installation

### Quick Start

```bash
# 1. First, set up the Jenkins host (if not already done)
ansible-playbook setup-jenkins-host.yml --connection=local

# 2. Install Jenkins server
ansible-playbook install-jenkins-server.yml --connection=local
```

### What Gets Installed

The playbook performs the following:

1. **Pre-flight Checks:**
   - Verifies Ubuntu 24.04
   - Confirms Jenkins user exists
   - Confirms Java is installed

2. **Jenkins Installation:**
   - Adds Jenkins official repository
   - Installs Jenkins LTS package
   - Installs required dependencies

3. **Directory Structure:**
   ```
   /home/jenkins/.jenkins/          # Jenkins home (JENKINS_HOME)
   ├── plugins/                     # Jenkins plugins
   ├── jobs/                        # Jenkins jobs
   ├── workspace/                   # Build workspaces
   ├── updates/                     # Update center data
   └── secrets/                     # Secrets (created by Jenkins)
       └── initialAdminPassword     # Initial admin password
   
   /var/cache/jenkins/              # Jenkins cache
   └── war/                         # Exploded WAR files
   
   /var/log/jenkins/                # Jenkins logs
   └── jenkins.log                  # Main log file
   ```

4. **Service Configuration:**
   - Configures Jenkins to run as the `jenkins` user
   - Sets `JENKINS_HOME=/home/jenkins/.jenkins`
   - Configures systemd service with proper security settings
   - Sets resource limits (file descriptors, processes)

5. **Startup:**
   - Enables Jenkins service to start on boot
   - Starts Jenkins and waits for it to be ready
   - Retrieves the initial admin password

## Configuration Variables

You can customize the installation by modifying variables in the playbook:

```yaml
vars:
  jenkins_username: jenkins              # Jenkins system user
  jenkins_home: /home/jenkins            # User home directory
  jenkins_data_dir: /home/jenkins/.jenkins  # Jenkins home directory
  jenkins_version: "lts"                 # Jenkins version (lts or specific version)
  jenkins_port: 8080                     # HTTP port
  jenkins_java_opts: "-Djava.awt.headless=true -Xmx2048m -Xms512m"  # JVM options
  jenkins_args: "--webroot=/var/cache/jenkins/war --httpPort=8080"  # Jenkins args
```

### Customizing JVM Memory

To adjust Jenkins memory allocation, modify `jenkins_java_opts`:

```yaml
# For a system with 8GB RAM, allocate 4GB to Jenkins
jenkins_java_opts: "-Djava.awt.headless=true -Xmx4096m -Xms1024m"
```

### Changing the Port

To run Jenkins on a different port:

```yaml
jenkins_port: 9090
jenkins_args: "--webroot=/var/cache/jenkins/war --httpPort=9090"
```

## Post-Installation

### 1. Access Jenkins

After installation completes, the playbook displays:
- Jenkins URL (e.g., `http://192.168.1.100:8080`)
- Initial admin password

Access Jenkins in your web browser using the provided URL.

### 2. Unlock Jenkins

Use the initial admin password displayed by the playbook, or retrieve it manually:

```bash
sudo cat /home/jenkins/.jenkins/secrets/initialAdminPassword
```

### 3. Install Plugins

Choose one of:
- **Install suggested plugins** (recommended for most users)
- **Select plugins to install** (for custom setups)

### 4. Create Admin User

Create your first administrator account with:
- Username
- Password
- Full name
- Email address

### 5. Configure Jenkins URL

Confirm or update the Jenkins URL for your environment.

## Service Management

### Check Jenkins Status

```bash
sudo systemctl status jenkins
```

### Start/Stop/Restart Jenkins

```bash
sudo systemctl start jenkins
sudo systemctl stop jenkins
sudo systemctl restart jenkins
```

### View Jenkins Logs

```bash
# Real-time log viewing
sudo journalctl -u jenkins -f

# View recent logs
sudo journalctl -u jenkins -n 100

# View logs in file
sudo tail -f /var/log/jenkins/jenkins.log
```

### Check Jenkins Configuration

```bash
# View systemd service configuration
sudo systemctl cat jenkins

# View environment variables
sudo cat /etc/default/jenkins

# View systemd override
sudo cat /etc/systemd/system/jenkins.service.d/override.conf
```

## Verification

### Verify Installation

```bash
# Check Jenkins is running
sudo systemctl is-active jenkins

# Check Jenkins is listening on port 8080
sudo netstat -tlnp | grep 8080
# or
sudo ss -tlnp | grep 8080

# Test HTTP access
curl -I http://localhost:8080
```

### Verify Directory Structure

```bash
# Check Jenkins home directory
ls -la /home/jenkins/.jenkins/

# Check ownership
ls -ld /home/jenkins/.jenkins/
# Should show: drwxr-xr-x jenkins jenkins

# Check Jenkins is using correct home
sudo systemctl show jenkins | grep JENKINS_HOME
```

## Troubleshooting

### Jenkins Won't Start

1. **Check logs:**
   ```bash
   sudo journalctl -u jenkins -n 50
   ```

2. **Check Java:**
   ```bash
   java -version
   ```

3. **Check permissions:**
   ```bash
   ls -la /home/jenkins/.jenkins/
   sudo chown -R jenkins:jenkins /home/jenkins/.jenkins/
   ```

4. **Check port availability:**
   ```bash
   sudo netstat -tlnp | grep 8080
   ```

### Port Already in Use

If port 8080 is already in use:

1. Find what's using it:
   ```bash
   sudo lsof -i :8080
   ```

2. Either stop that service or change Jenkins port in the playbook.

### Permission Denied Errors

```bash
# Fix ownership of Jenkins directories
sudo chown -R jenkins:jenkins /home/jenkins/.jenkins/
sudo chown -R jenkins:jenkins /var/cache/jenkins/
sudo chown -R jenkins:jenkins /var/log/jenkins/
```

### Jenkins Slow to Start

Jenkins can take 1-2 minutes to fully start, especially on first run. Be patient and check logs:

```bash
sudo journalctl -u jenkins -f
```

## Security Considerations

### Initial Setup

1. **Change admin password immediately** after first login
2. **Enable security realm** (Jenkins' own user database or LDAP)
3. **Configure authorization strategy** (Matrix-based security recommended)
4. **Install security plugins:**
   - OWASP Markup Formatter
   - Matrix Authorization Strategy
   - Role-based Authorization Strategy

### Firewall Configuration

If using a firewall, allow Jenkins port:

```bash
# UFW
sudo ufw allow 8080/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

### Reverse Proxy (Recommended for Production)

For production, use Nginx or Apache as a reverse proxy with HTTPS:

```nginx
# Nginx example
server {
    listen 80;
    server_name jenkins.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name jenkins.example.com;
    
    ssl_certificate /etc/ssl/certs/jenkins.crt;
    ssl_certificate_key /etc/ssl/private/jenkins.key;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Backup and Restore

### Backup Jenkins Home

```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Backup Jenkins home directory
sudo tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz -C /home/jenkins .jenkins/

# Start Jenkins
sudo systemctl start jenkins
```

### Restore Jenkins Home

```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Restore backup
sudo tar -xzf jenkins-backup-20260625.tar.gz -C /home/jenkins/

# Fix permissions
sudo chown -R jenkins:jenkins /home/jenkins/.jenkins/

# Start Jenkins
sudo systemctl start jenkins
```

## Upgrading Jenkins

### Via Package Manager (Recommended)

```bash
# Update package list
sudo apt update

# Upgrade Jenkins
sudo apt upgrade jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### Manual Upgrade

1. Download new jenkins.war
2. Stop Jenkins
3. Replace /usr/share/java/jenkins.war
4. Start Jenkins

## Uninstallation

To completely remove Jenkins:

```bash
# Stop Jenkins
sudo systemctl stop jenkins
sudo systemctl disable jenkins

# Remove package
sudo apt remove --purge jenkins

# Remove directories (CAUTION: This deletes all Jenkins data!)
sudo rm -rf /home/jenkins/.jenkins/
sudo rm -rf /var/cache/jenkins/
sudo rm -rf /var/log/jenkins/

# Remove repository
sudo rm /etc/apt/sources.list.d/jenkins.list
sudo apt-key del $(apt-key list | grep -B 1 "Jenkins" | head -n 1 | awk '{print $2}')
```

## Related Documentation

- [setup-jenkins-host.yml](setup-jenkins-host.yml) - Host preparation playbook
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Overall deployment guide
- [roles/README.md](roles/README.md) - Ansible roles documentation
- [Official Jenkins Documentation](https://www.jenkins.io/doc/)

## Support

For issues or questions:
1. Check Jenkins logs: `sudo journalctl -u jenkins -f`
2. Review this documentation
3. Consult [Jenkins Documentation](https://www.jenkins.io/doc/)
4. Check [Jenkins Community Forums](https://community.jenkins.io/)

---

**Made with Bob**