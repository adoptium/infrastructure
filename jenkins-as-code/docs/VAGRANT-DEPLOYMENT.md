# Vagrant Dev Server Deployment Guide

Quick guide for deploying security and system configuration to your Vagrant dev server running on localhost.

## Your Configuration

Your `hosts` file is already configured with:
- **Connection:** localhost via local connection
- **Fail2ban Whitelist:** Production Jenkins master IPs included
- **Group:** `local` group for localhost

## Quick Commands

### 1. Check Configuration
```bash
cd jenkins-as-code/ansible

# Verify inventory
ansible-inventory -i hosts --list

# Check connectivity
ansible -i hosts local -m ping
```

### 2. Deploy Everything (Dry Run)
```bash
ansible-playbook -i hosts setup-jenkins-host.yml --check --diff
```

### 3. Deploy Everything (For Real)
```bash
ansible-playbook -i hosts setup-jenkins-host.yml
```

### 4. Deploy Only Security Roles
```bash
# Unattended-upgrades + Fail2ban
ansible-playbook -i hosts setup-jenkins-host.yml --tags security
```

### 5. Deploy Only NTP
```bash
ansible-playbook -i hosts setup-jenkins-host.yml --tags system
```

### 6. Deploy Specific Role
```bash
# Just fail2ban
ansible-playbook -i hosts setup-jenkins-host.yml --tags security --skip-tags unattended_upgrades

# Just NTP
ansible-playbook -i hosts setup-jenkins-host.yml --tags system

# Just unattended-upgrades
ansible-playbook -i hosts setup-jenkins-host.yml --tags security --skip-tags fail2ban
```

## Post-Deployment Verification

### Check Services
```bash
# On your Vagrant server
sudo systemctl status fail2ban
sudo systemctl status ntpsec
sudo systemctl status unattended-upgrades
```

### Verify Fail2ban Configuration
```bash
# Check fail2ban status
sudo fail2ban-client status

# Check SSH jail
sudo fail2ban-client status sshd

# Verify your IP whitelist is loaded
sudo cat /etc/fail2ban/jail.local | grep ignoreip
```

### Verify NTP
```bash
# Check NTP peers
ntpq -p

# Check time sync status
timedatectl status
```

### Verify Unattended Upgrades
```bash
# Check configuration
cat /etc/apt/apt.conf.d/50unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades

# Test (dry run)
sudo unattended-upgrade --dry-run --debug
```

## Your Fail2ban Whitelist

Your `hosts` file includes the production whitelist:
```
127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 78.47.239.96 46.224.123.39 178.62.115.224 20.90.182.165
```

This means these IPs will NEVER be banned:
- **127.0.0.1/8, ::1** - Loopback (localhost)
- **10.0.0.0/8, 192.168.0.0/16** - Private networks (your Vagrant network)
- **78.47.239.96, 46.224.123.39, 178.62.115.224, 20.90.182.165** - Production trusted IPs

## Troubleshooting

### Playbook Fails with Permission Denied
The playbook uses `become: yes` for privilege escalation. Make sure your user can sudo:
```bash
# Test sudo access
sudo -v
```

### Fail2ban Not Starting
```bash
# Check logs
sudo journalctl -u fail2ban -n 50

# Test configuration
sudo fail2ban-client -t

# Restart service
sudo systemctl restart fail2ban
```

### NTP Not Syncing
```bash
# Check if service is running
sudo systemctl status ntpsec

# Check network connectivity to NTP servers
ping -c 3 0.ubuntu.pool.ntp.org

# Restart service
sudo systemctl restart ntpsec
```

## Modifying Configuration

### Change Fail2ban Whitelist
Edit `hosts` file and update the `fail2ban_ignoreip` line:
```ini
[local:vars]
fail2ban_ignoreip=127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 YOUR_NEW_IP
```

Then re-run:
```bash
ansible-playbook -i hosts setup-jenkins-host.yml --tags security
```

### Enable Unattended Upgrades
After testing, enable automatic updates:
```bash
# On Vagrant server
sudo nano /etc/apt/apt.conf.d/20auto-upgrades

# Change both values to "1":
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

## Complete Deployment Example

```bash
# Navigate to ansible directory
cd jenkins-as-code/ansible

# 1. Verify configuration
ansible-inventory -i hosts --list

# 2. Test connectivity
ansible -i hosts local -m ping

# 3. Dry run to see what will change
ansible-playbook -i hosts setup-jenkins-host.yml --check --diff

# 4. Deploy everything
ansible-playbook -i hosts setup-jenkins-host.yml

# 5. Verify services are running
ansible -i hosts local -m shell -a "systemctl status fail2ban ntpsec" --become

# 6. Check fail2ban status
ansible -i hosts local -m shell -a "fail2ban-client status" --become
```

## Notes

- Your Vagrant server is accessed via `localhost` with local connection (no SSH)
- All roles use `become: yes` for privilege escalation
- The playbook is idempotent - safe to run multiple times
- Configuration matches production Jenkins master exactly

---

**Quick Reference:**
- Inventory file: `hosts`
- Playbook: `setup-jenkins-host.yml`
- Roles: `unattended_upgrades`, `ntp_config`, `fail2ban`
- Tags: `security`, `system`