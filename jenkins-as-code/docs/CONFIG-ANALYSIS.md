# Jenkins Master Configuration Analysis

## Overview
Analysis of extracted configuration from production Jenkins master (jenkins-hetzner-ubuntu2004) running Ubuntu 24.04.4 LTS.

---

## ✅ IMPLEMENT NOW - Generic/Portable Configurations

These configurations are environment-independent and should be implemented immediately in the Ansible playbook:

### 1. **SSH Security Configuration** ✅ ALREADY IMPLEMENTED
- PasswordAuthentication: no
- KbdInteractiveAuthentication: no
- PermitRootLogin: prohibit-password (key-based only)
- **Status**: Already in playbook

### 2. **System Limits** ⚠️ PARTIALLY IMPLEMENTED
Current production has default limits.conf (no custom limits).
- **Action**: Keep current playbook implementation with jenkins user limits
- **Status**: Already configured in playbook for jenkins user

### 3. **Unattended Upgrades** 🔧 NEEDS IMPLEMENTATION
Production config shows security-only updates enabled.
```
Allowed-Origins:
- ${distro_id}:${distro_codename}
- ${distro_id}:${distro_codename}-security
- ${distro_id}ESMApps:${distro_codename}-apps-security
- ${distro_id}ESM:${distro_codename}-infra-security
```
- **Action**: Add unattended-upgrades configuration to playbook
- **Priority**: HIGH (security)

### 4. **NTP Configuration** 🔧 NEEDS IMPLEMENTATION
Production uses standard Ubuntu NTP pool servers.
```
pool 0.ubuntu.pool.ntp.org iburst
pool 1.ubuntu.pool.ntp.org iburst
pool 2.ubuntu.pool.ntp.org iburst
pool 3.ubuntu.pool.ntp.org iburst
pool ntp.ubuntu.com
```
- **Action**: Add NTP configuration task
- **Priority**: MEDIUM (time sync important for builds)

### 5. **Additional JDK Versions** 🔧 NEEDS IMPLEMENTATION
Production has multiple JDK versions:
- temurin-11-jdk
- temurin-17-jdk
- temurin-21-jdk
- temurin-25-jdk ✅ (already in playbook)
- **Action**: Add tasks to install JDK 11, 17, 21
- **Priority**: HIGH (needed for multi-version builds)

### 6. **Wazuh Agent** 🔧 OPTIONAL
Production has wazuh-agent installed (security monitoring).
- **Action**: Add wazuh-agent installation if monitoring is required
- **Priority**: LOW (can be added later)

### 7. **Environment PATH** 🔧 NEEDS REVIEW
Production has custom PATH with InstallBuilder:
```
PATH="/opt/installbuilder-17.7.0/bin:..."
```
- **Action**: Review if InstallBuilder or other custom tools needed
- **Priority**: MEDIUM (depends on build requirements)

---

## ⏳ IMPLEMENT LATER - Environment-Specific Configurations

These configurations contain server-specific details and should be configured AFTER the new server has its domain/IP:

### 1. **Hosts File** 🚫 DO NOT COPY
Production hosts file contains:
- Hostname: jenkins-hetzner-ubuntu2004
- IPv4: 172.31.1.100, 78.47.239.97
- IPv6: 2a01:4f8:c0c:1804::2
- **Action**: Configure with new server's hostname and IPs
- **When**: After server provisioning

### 2. **Network Configuration** 🚫 DO NOT COPY
Production network shows:
- eth0 with specific MAC and IPs
- Hetzner-specific network setup
- **Action**: Let new server use its own network config
- **When**: Automatic during provisioning

### 3. **Nginx Configuration** 🚫 EXTRACT & REVIEW LATER
Needs analysis of:
- Virtual hosts
- SSL certificates
- Proxy configurations
- Domain names
- **Action**: Extract nginx configs, update domains/certs for new server
- **When**: After DNS and SSL certificates are ready

### 4. **Fail2ban Configuration** 🚫 EXTRACT & REVIEW LATER
May contain IP whitelists or server-specific rules.
- **Action**: Extract and review, update IP whitelists
- **When**: After new server is accessible

### 5. **Backup Mounts** 🚫 DO NOT COPY
Production has:
- //u158991.your-backup.de/backup mounted at /mnt/backup-server
- Additional disks: /dev/sdb, /dev/sdc for Jenkins workspace/jobs
- **Action**: Configure new backup solution with new credentials
- **When**: After backup infrastructure is ready

### 6. **Cron Jobs** 🚫 REVIEW & ADAPT
**Jenkins user crontab:**
```
08 08 * * * /home/jenkins/diskspace/rundiskspace
0,15,30,45 * * * * bash -c "date; grep label queue.xml..." >> /home/jenkins/queuedepth.log
```

**Root crontab:**
```
0 5 * * 6 /root/apt-security.sh
```
- **Action**: Review scripts, adapt paths for new server
- **When**: After Jenkins is installed and scripts are available

---

## 📋 IMPLEMENTATION PRIORITY

### Phase 1: Initial Server Setup (NOW)
1. ✅ Base packages installation (already in playbook)
2. ✅ SSH hardening (already in playbook)
3. ✅ Jenkins user creation with UID/GID handling (already in playbook)
4. ✅ Temurin 25 JDK (already in playbook)
5. 🔧 Add Temurin 11, 17, 21 JDKs
6. 🔧 Configure unattended-upgrades
7. 🔧 Configure NTP
8. ✅ System limits (already in playbook)

### Phase 2: Post-Provisioning (AFTER new server has domain/IP)
1. Configure hostname and hosts file
2. Extract and configure nginx with new domains
3. Extract and configure fail2ban with new IPs
4. Set up backup mounts with new credentials
5. Configure monitoring (wazuh-agent if needed)

### Phase 3: Jenkins-Specific (AFTER Jenkins installation)
1. Review and adapt cron jobs
2. Set up disk space monitoring
3. Configure queue depth monitoring
4. Set up Jenkins-specific scripts

---

## 🔍 ADDITIONAL FINDINGS

### Disk Usage Concerns
Production server shows:
- Root partition: 93% full (494G/564G used)
- Jobs partition: 76% full (1.5T/2.0T used)
- **Recommendation**: Plan for adequate storage on new server

### Memory
- 30GB RAM, 15GB swap
- **Recommendation**: Match or exceed for new server

### Multiple JDK Versions Required
Production uses 4 different JDK versions (11, 17, 21, 25).
- **Recommendation**: Install all versions in playbook

### Custom Tools
- InstallBuilder 17.7.0 in PATH
- **Action**: Determine if needed for new server

---

## 📝 NEXT STEPS

1. **Immediate**: Update playbook with Phase 1 items
2. **Document**: Create separate configs for Phase 2 (domain-specific)
3. **Review**: Nginx and fail2ban configs in detail
4. **Plan**: Storage requirements for new server
5. **Identify**: All custom scripts and tools needed

---

## 🚨 WARNINGS

- **DO NOT** copy hosts file directly
- **DO NOT** copy network configurations
- **DO NOT** copy backup mount credentials
- **DO NOT** copy nginx configs without updating domains
- **DO NOT** copy fail2ban configs without reviewing IP whitelists
- **REVIEW** all cron jobs before implementing
