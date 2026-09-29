# Deployment Guide - Security & System Configuration

This guide covers deploying the security and system configuration roles (unattended-upgrades, NTP, fail2ban) to Jenkins infrastructure.

## Prerequisites

- Ansible 2.9 or higher installed
- SSH access to target servers
- Root or sudo privileges on target servers
- Python 3 installed on target servers

## Quick Start

### 1. Configure Inventory

Copy the example inventory and customize it:

```bash
cd jenkins-as-code/ansible
cp inventory-example.yml inventory.yml
```

Edit `inventory.yml` and update:
- Server IP addresses
- SSH keys
- **IMPORTANT:** Fail2ban IP whitelist with your trusted IPs

### 2. Test Connectivity

```bash
ansible all -i inventory.yml -m ping
```

### 3. Run the Playbook

**Dry run (check mode):**
```bash
ansible-playbook -i inventory.yml setup-jenkins-host.yml --check --diff
```

**Full deployment:**
```bash
ansible-playbook -i inventory.yml setup-jenkins-host.yml
```

**Deploy only security roles:**
```bash
ansible-playbook -i inventory.yml setup-jenkins-host.yml --tags security
```

**Deploy only NTP:**
```bash
ansible-playbook -i inventory.yml setup-jenkins-host.yml --tags system
```

## Configuration Details

### Unattended Upgrades

**Default State:** Installed but disabled

**To Enable Automatic Updates:**
```bash
# On the target server
sudo nano /etc/apt/apt.conf.d/20auto-upgrades

# Change these values from 0 to 1:
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

**What Gets Updated:**
- Security updates only (`${distro_id}:${distro_codename}-security`)
- Extended Security Maintenance (ESM) updates if available
- NO regular updates, proposed, or backports

**Verify Configuration:**
```bash
sudo unattended-upgrade --dry-run --debug
```

### NTP Configuration

**Configured Servers:**
- 0.ubuntu.pool.ntp.org
- 1.ubuntu.pool.ntp.org
- 2.ubuntu.pool.ntp.org
- 3.ubuntu.pool.ntp.org
- ntp.ubuntu.com (fallback)

**Verify Time Sync:**
```bash
# Check NTP service
sudo systemctl status ntpsec

# Check NTP peers
ntpq -p

# Check system time
timedatectl status
```

### Fail2ban Configuration

**Default Protection:**
- SSH brute force protection enabled
- 3 failed attempts within 10 minutes = 1 hour ban
- Progressive banning (doubles each time, max 1 week)
- Repeat offender jail (5+ bans in 24h = 7 day ban)

**CRITICAL: IP Whitelist**

Before deployment, update your inventory with trusted IPs:

```yaml
fail2ban_ignoreip: >-
  127.0.0.1/8
  ::1
  10.0.0.0/8
  192.168.0.0/16
  YOUR_OFFICE_IP/32
  YOUR_VPN_NETWORK/24
```

**Verify Configuration:**
```bash
# Check fail2ban status
sudo systemctl status fail2ban

# List all jails
sudo fail2ban-client status

# Check SSH jail
sudo fail2ban-client status sshd

# Check repeat offender jail
sudo fail2ban-client status recidive

# View banned IPs
sudo fail2ban-client get sshd banned

# Unban an IP (if needed)
sudo fail2ban-client set sshd unbanip 203.0.113.50
```

## Post-Deployment Verification

### 1. Check All Services

```bash
# Run on target server
sudo systemctl status ntpsec
sudo systemctl status fail2ban
sudo systemctl status unattended-upgrades
```

### 2. Verify Configurations

```bash
# Check unattended-upgrades config
cat /etc/apt/apt.conf.d/50unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades

# Check NTP config
cat /etc/ntp.conf
ntpq -p

# Check fail2ban config
cat /etc/fail2ban/jail.local
sudo fail2ban-client status
```

### 3. Test Fail2ban (Optional)

From a non-whitelisted IP, attempt multiple failed SSH logins to verify banning works:

```bash
# From test machine (will get banned!)
ssh wronguser@jenkins-server  # Try 3+ times with wrong password

# On Jenkins server, check if IP was banned
sudo fail2ban-client status sshd
```

## Troubleshooting

### Fail2ban Not Starting

```bash
# Check configuration syntax
sudo fail2ban-client -t

# Check logs
sudo tail -f /var/log/fail2ban.log

# Restart service
sudo systemctl restart fail2ban
```

### NTP Not Syncing

```bash
# Check if NTP can reach servers
sudo ntpdate -q 0.ubuntu.pool.ntp.org

# Restart NTP service
sudo systemctl restart ntpsec

# Check system time settings
timedatectl
```

### Locked Out by Fail2ban

If you accidentally get banned:

1. Access server via console (not SSH)
2. Unban your IP:
   ```bash
   sudo fail2ban-client set sshd unbanip YOUR_IP
   ```
3. Add your IP to whitelist in inventory
4. Re-run playbook

## Rollback

To remove configurations:

```bash
# Stop services
sudo systemctl stop fail2ban
sudo systemctl stop ntpsec

# Remove packages (optional)
sudo apt remove fail2ban ntpsec unattended-upgrades

# Restore original configs from backups
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
```

## Maintenance

### Update Fail2ban Whitelist

1. Edit inventory.yml
2. Update `fail2ban_ignoreip` variable
3. Re-run playbook:
   ```bash
   ansible-playbook -i inventory.yml setup-jenkins-host.yml --tags security
   ```

### Monitor Fail2ban Activity

```bash
# View recent bans
sudo tail -100 /var/log/fail2ban.log | grep Ban

# View all currently banned IPs
sudo fail2ban-client status sshd | grep "Banned IP"

# Statistics
sudo fail2ban-client status sshd
```

### Check for Security Updates

```bash
# List available security updates
sudo apt list --upgradable | grep -i security

# Run unattended-upgrades manually
sudo unattended-upgrade --dry-run
```

## Security Best Practices

1. **Always whitelist your management IPs** before enabling fail2ban
2. **Test in staging** before deploying to production
3. **Monitor fail2ban logs** regularly for suspicious activity
4. **Keep NTP synchronized** for accurate security logs
5. **Enable unattended-upgrades** only after testing in your environment
6. **Document all whitelisted IPs** and review regularly

## Support

For issues or questions:
- Check role documentation: `jenkins-as-code/ansible/roles/README.md`
- Review extracted configs: `jenkins-as-code/data/jenkins-master-configs-*/`
- See configuration analysis: `jenkins-as-code/CONFIG-ANALYSIS.md`

---

**Last Updated:** 2026-06-24  
**Based on:** Production Jenkins master configuration