# Quick Deployment Guide

**Jenkins Capacity Analyzer - Simplified Deployment**

This guide provides a streamlined process for deploying updates to your production server at `https://nagios.adoptopenjdk.net/jenkins-capacity/`.

---

## 📋 Prerequisites

- SSH access to `nagios.adoptopenjdk.net`
- sudo privileges on the server
- Application already installed at `/var/www/jenkins-capacity-report`

---

## 🚀 Deployment Process (3 Steps)

### Step 1: Create Deployment Package (Local Machine)

```bash
cd /home/scfryer/Development/Bob-Github-Repos/general-utils.jenkins_capacity/jenkins-capacity-report

# Run the packaging script
./deployment/package-for-deployment.sh

# This creates: jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz
```

**What it does:**
- ✅ Includes all source code, templates, and configuration
- ❌ Excludes sensitive files (.env, users.json, clouds.xml.live)
- ❌ Excludes generated data (logs, CSV, JSON reports)
- ✅ Runs automated verification tests
- ✅ Creates checksums and file manifest

**Expected output:**
```
✓ Tarball integrity check passed
✓ Found: web_app.py
✓ Found: main.py
✓ Excluded: .env
✓ Excluded: data/users.json
✓ All verification tests passed!
```

---

### Step 2: Transfer Package to Server

```bash
# Copy the tarball to the server
scp jenkins-capacity-*.tar.gz user@nagios.adoptopenjdk.net:/tmp/
```

Replace `user` with your actual username.

---

### Step 3: Update on Server

```bash
# SSH to the server
ssh user@nagios.adoptopenjdk.net

# Navigate to application directory
cd /var/www/jenkins-capacity-report

# Run the update script
sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-*.tar.gz
```

**What it does:**
- ✅ Creates automatic backup
- ✅ Preserves .env, users.json, clouds.xml.live
- ✅ Extracts new version
- ✅ Updates Python dependencies (if needed)
- ✅ Reloads Apache gracefully (no downtime)
- ✅ Verifies deployment

**Expected output:**
```
✓ Backup created successfully
✓ Preserved .env
✓ Preserved data/users.json
✓ New version extracted
✓ Apache reloaded successfully
✓ Application is responding
Deployment complete!
```

---

## ✅ Verification

After deployment, verify the application:

```bash
# Check application in browser
https://nagios.adoptopenjdk.net/jenkins-capacity/

# Monitor logs (on server)
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log

# Check Apache status
sudo systemctl status apache2
```

---

## 🔄 Rollback (If Needed)

If something goes wrong, rollback to the previous version:

```bash
# On the server
cd /var/www/jenkins-capacity-report

# Find the backup
ls -lh /var/backups/jenkins-capacity/

# Restore from backup
sudo tar -xzf /var/backups/jenkins-capacity/jenkins-capacity-backup-YYYYMMDD-HHMMSS.tar.gz -C /var/www/jenkins-capacity-report

# Reload Apache
sudo systemctl reload apache2
```

Backups are automatically created before each update and kept for the last 10 deployments.

---

## 🛠️ Troubleshooting

### Issue: Package creation fails

**Check:**
```bash
# Verify you're in the correct directory
pwd
# Should show: .../jenkins-capacity-report

# Check if critical files exist
ls -la main.py web_app.py requirements.txt
```

### Issue: Transfer fails

**Check:**
```bash
# Verify SSH access
ssh user@nagios.adoptopenjdk.net "echo 'Connection OK'"

# Check disk space on server
ssh user@nagios.adoptopenjdk.net "df -h /tmp"
```

### Issue: Update script fails

**Check:**
```bash
# Verify you're running as root
sudo whoami  # Should output: root

# Check if tarball exists
ls -lh /tmp/jenkins-capacity-*.tar.gz

# Verify tarball integrity
tar -tzf /tmp/jenkins-capacity-*.tar.gz | head
```

### Issue: Application not responding after update

**Check logs:**
```bash
# Apache error log
sudo tail -100 /var/log/apache2/error.log

# Application log
sudo tail -100 /var/www/jenkins-capacity-report/logs/web_app.log

# Check Python dependencies
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip list
```

**Quick fix:**
```bash
# Restart Apache (brief downtime)
sudo systemctl restart apache2

# Or reload (no downtime)
sudo systemctl reload apache2
```

---

## 📊 What Gets Deployed

### ✅ Included in Package

- **Source Code**: `main.py`, `web_app.py`, `src/`
- **Templates**: `templates/`
- **Deployment Config**: `deployment/wsgi.py`, Apache configs
- **Scripts**: `scripts/`, `tools/`
- **Documentation**: `docs/`, `README.md`
- **Requirements**: `requirements.txt`
- **Examples**: `.env.example`, `tools/*.example`
- **Tests**: `tests/`

### ❌ Excluded from Package (Preserved on Server)

- **Sensitive Config**: `.env`, `Credentials.txt`
- **User Data**: `data/users.json`
- **Cloud Config**: `data/clouds.xml.live`
- **Metrics History**: `data/metrics_history.json`
- **Excluded Nodes**: `data/excluded_nodes.json`
- **Generated Data**: `*.csv`, `*.json` reports
- **Logs**: `logs/*.log`
- **Virtual Environment**: `venv/`
- **Python Cache**: `__pycache__/`

---

## 📝 Complete Workflow Example

```bash
# === ON LOCAL MACHINE ===

# 1. Navigate to project
cd ~/Development/Bob-Github-Repos/general-utils.jenkins_capacity/jenkins-capacity-report

# 2. Create package
./deployment/package-for-deployment.sh
# Output: jenkins-capacity-20260415-110000.tar.gz created

# 3. Transfer to server
scp jenkins-capacity-20260415-110000.tar.gz scfryer@nagios.adoptopenjdk.net:/tmp/

# === ON SERVER ===

# 4. SSH to server
ssh scfryer@nagios.adoptopenjdk.net

# 5. Update application
cd /var/www/jenkins-capacity-report
sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-20260415-110000.tar.gz

# 6. Verify
curl -I https://nagios.adoptopenjdk.net/jenkins-capacity/

# 7. Check logs
sudo tail -f /var/log/apache2/error.log

# === DONE! ===
```

---

## 🔒 Security Notes

1. **Sensitive files are never included in packages**
   - `.env` with Jenkins credentials
   - `users.json` with user accounts
   - `clouds.xml.live` with cloud configuration
   - `Credentials.txt`

2. **Files are automatically preserved during updates**
   - The update script backs up and restores all sensitive files
   - No manual intervention needed

3. **Backups are created automatically**
   - Before each update
   - Stored in `/var/backups/jenkins-capacity/`
   - Last 10 backups are retained

---

## 📞 Support

**Documentation:**
- Full deployment guide: `docs/DEPLOYMENT.md`
- Server-specific guide: `docs/DEPLOYMENT-GUIDE-nagios-adoptopenjdk.md`
- Main README: `README.md`

**Logs:**
- Apache error: `/var/log/apache2/error.log`
- Apache access: `/var/log/apache2/access.log`
- Application: `/var/www/jenkins-capacity-report/logs/web_app.log`

**Application:**
- URL: https://nagios.adoptopenjdk.net/jenkins-capacity/
- Path: `/var/www/jenkins-capacity-report`
- User: `www-data`

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Create package | `./deployment/package-for-deployment.sh` |
| Transfer to server | `scp jenkins-capacity-*.tar.gz user@server:/tmp/` |
| Update on server | `sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-*.tar.gz` |
| Check logs | `sudo tail -f /var/log/apache2/error.log` |
| Reload Apache | `sudo systemctl reload apache2` |
| Rollback | `sudo tar -xzf /var/backups/jenkins-capacity/backup.tar.gz -C /var/www/jenkins-capacity-report` |

---

**Last Updated:** 2026-04-15  
**Created by:** Bob