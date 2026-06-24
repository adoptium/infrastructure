# Ansible Roles for Jenkins Infrastructure

This directory contains Ansible roles for configuring Jenkins infrastructure based on the existing production Jenkins master configuration.

## Available Roles

### 1. unattended_upgrades
**Purpose:** Configure security-only automatic updates for Ubuntu systems.

**What it does:**
- Installs the `unattended-upgrades` package
- Configures `/etc/apt/apt.conf.d/50unattended-upgrades` with security-only updates
- Sets up `/etc/apt/apt.conf.d/20auto-upgrades` (disabled by default)

**Configuration:**
The role is configured to only install security updates from:
- `${distro_id}:${distro_codename}-security`
- Extended Security Maintenance (ESM) updates if available

**Note:** Automatic updates are disabled by default in `20auto-upgrades`. To enable:
```bash
# Edit /etc/apt/apt.conf.d/20auto-upgrades and change:
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

**Tags:** `security`

---

### 2. ntp_config
**Purpose:** Configure time synchronization with Ubuntu NTP pools.

**What it does:**
- Installs NTP package (ntpsec for Ubuntu 20.04+, ntp for older versions)
- Configures `/etc/ntp.conf` with Ubuntu pool servers
- Enables and starts the NTP service

**NTP Servers configured:**
- `0.ubuntu.pool.ntp.org`
- `1.ubuntu.pool.ntp.org`
- `2.ubuntu.pool.ntp.org`
- `3.ubuntu.pool.ntp.org`
- `ntp.ubuntu.com` (fallback)

**Variables:**
- `ntp_service`: Service name (default: `ntpsec`)
- `ntp_package`: Package name (default: `ntpsec`)

**Tags:** `system`

---

### 3. fail2ban
**Purpose:** Configure fail2ban for SSH protection with IP whitelisting.

**What it does:**
- Installs fail2ban package
- Configures `/etc/fail2ban/jail.local` with SSH protection
- Sets up repeat offender detection (recidive jail)
- Enables and starts the fail2ban service

**Features:**
- **SSH Protection:** Bans IPs after 3 failed login attempts within 10 minutes
- **Progressive Banning:** Ban time doubles for repeat offenders (1h → 2h → 4h, max 1 week)
- **Repeat Offender Jail:** IPs banned 5+ times in 24 hours get a 7-day ban
- **IP Whitelisting:** Trusted IPs/networks are never banned

**Default Configuration:**
- `findtime`: 10 minutes
- `maxretry`: 3 attempts
- `bantime`: 1 hour (escalates for repeat offenders)
- `backend`: systemd (for modern Ubuntu)

**Variables:**
- `fail2ban_ignoreip`: Space-separated list of IPs/networks to whitelist
  - Default: `127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16`

**IMPORTANT:** Update the `fail2ban_ignoreip` variable with your trusted IPs before deployment!

**Example - Setting custom whitelist:**
```yaml
# In your playbook or inventory
vars:
  fail2ban_ignoreip: "127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 203.0.113.0/24 198.51.100.50"
```

**Tags:** `security`

---

## Usage

### In Playbook
```yaml
- name: Configure Jenkins Host
  hosts: jenkins_servers
  become: yes
  roles:
    - role: unattended_upgrades
      tags: security
    - role: ntp_config
      tags: system
    - role: fail2ban
      tags: security
      vars:
        fail2ban_ignoreip: "127.0.0.1/8 ::1 10.0.0.0/8 YOUR_OFFICE_IP"
```

### Run Specific Roles
```bash
# Run only security roles
ansible-playbook setup-jenkins-host.yml --tags security

# Run only NTP configuration
ansible-playbook setup-jenkins-host.yml --tags system

# Run all roles
ansible-playbook setup-jenkins-host.yml
```

---

## Configuration Source

These roles are based on the configuration extracted from the existing Jenkins master server:
- **Extracted on:** 2026-06-24
- **Source:** `jenkins-as-code/data/jenkins-master-configs-20260624-180156/`

The configurations match the production Jenkins master to ensure consistency across the infrastructure.

---

## Verification

### Check unattended-upgrades status
```bash
sudo systemctl status unattended-upgrades
sudo cat /etc/apt/apt.conf.d/50unattended-upgrades
sudo cat /etc/apt/apt.conf.d/20auto-upgrades
```

### Check NTP status
```bash
sudo systemctl status ntpsec  # or ntp on older systems
ntpq -p  # Show NTP peers
timedatectl status  # Show time sync status
```

### Check fail2ban status
```bash
sudo systemctl status fail2ban
sudo fail2ban-client status  # Show all jails
sudo fail2ban-client status sshd  # Show SSH jail details
sudo fail2ban-client status recidive  # Show repeat offender jail
```

---

## Security Notes

1. **Unattended Upgrades:** Disabled by default. Enable only after testing in your environment.
2. **Fail2ban Whitelist:** Always include your management IPs to avoid locking yourself out.
3. **NTP:** Proper time synchronization is critical for security (SSL/TLS, Kerberos, logs).

---

## Troubleshooting

### Fail2ban not banning
- Check logs: `sudo tail -f /var/log/fail2ban.log`
- Verify backend: `sudo fail2ban-client get sshd backend`
- Test regex: `sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf`

### NTP not syncing
- Check peers: `ntpq -p`
- Check system time: `timedatectl`
- Verify network connectivity to NTP servers

### Unattended upgrades not running
- Check timer: `sudo systemctl status apt-daily-upgrade.timer`
- Check logs: `sudo cat /var/log/unattended-upgrades/unattended-upgrades.log`
- Verify configuration: `sudo unattended-upgrade --dry-run --debug`

---

## Related Documentation

- [CONFIG-ANALYSIS.md](../../CONFIG-ANALYSIS.md) - Analysis of extracted Jenkins master configuration
- [setup-jenkins-host.yml](../setup-jenkins-host.yml) - Main playbook using these roles