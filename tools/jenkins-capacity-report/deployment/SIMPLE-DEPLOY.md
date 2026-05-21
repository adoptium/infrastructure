# Simple Deployment Guide

This guide describes the simplified deployment process using manual SFTP transfer.

## Overview

The simplified deployment process:
1. Create a deployment tarball locally
2. Transfer it to the server via SFTP
3. Extract it over the existing installation
4. Reload Apache

## Prerequisites

- SSH/SFTP access to the server
- Sudo privileges on the server
- Existing installation at `/var/www/jenkins-capacity-report`

## Step-by-Step Instructions

### 1. Create Deployment Package

On your local machine, run:

```bash
cd jenkins-capacity-report
./deployment/create-deployment-package.sh
```

This creates a tarball named `jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz` in the project root.

**What's included:**
- Application code (main.py, web_app.py, src/)
- Templates (templates/)
- Configuration (config/)
- Deployment files (deployment/)
- Scripts and tools
- Documentation
- Tests

**What's excluded (preserved on server):**
- `.env` (your environment configuration)
- `data/users.json` (user database)
- `data/clouds.xml.live` (cloud configuration)
- `data/*.json` (generated data files)
- `logs/*.log` (log files)
- `venv/` (virtual environment)

### 2. Transfer to Server

Use SFTP, SCP, or your preferred file transfer method:

```bash
# Using SCP
scp jenkins-capacity-20260505-085021.tar.gz user@nagios.adoptopenjdk.net:/tmp/

# Or using SFTP
sftp user@nagios.adoptopenjdk.net
put jenkins-capacity-20260505-085021.tar.gz /tmp/
quit
```

### 3. Backup Current Installation (Recommended)

SSH to the server and create a backup:

```bash
ssh user@nagios.adoptopenjdk.net
cd /var/www/jenkins-capacity-report
sudo tar -czf ~/jenkins-capacity-backup-$(date +%Y%m%d-%H%M%S).tar.gz .
```

### 4. Extract New Version

Extract the tarball over the existing installation:

```bash
cd /var/www/jenkins-capacity-report
sudo tar -xzf /tmp/jenkins-capacity-20260505-085021.tar.gz
```

**Important:** The tarball extracts files directly into the current directory, updating only the application code and templates. Your `.env`, `data/users.json`, and other configuration files remain untouched.

### 5. Set Permissions

Ensure proper ownership and permissions:

```bash
sudo chown -R www-data:www-data /var/www/jenkins-capacity-report
sudo chmod 600 /var/www/jenkins-capacity-report/.env
```

### 6. Update Dependencies (If Needed)

If `requirements.txt` changed, update Python dependencies:

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install -r requirements.txt
```

### 7. Reload Apache

Apply the changes:

```bash
sudo systemctl reload apache2
```

### 8. Verify Deployment

Check that the application is working:

```bash
# Check Apache status
sudo systemctl status apache2

# Check application logs
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log

# Test the application
curl -I https://nagios.adoptopenjdk.net/jenkins-capacity/
```

## Rollback Procedure

If something goes wrong, restore from backup:

```bash
cd /var/www/jenkins-capacity-report
sudo tar -xzf ~/jenkins-capacity-backup-YYYYMMDD-HHMMSS.tar.gz
sudo systemctl reload apache2
```

## Troubleshooting

### Application Not Responding

Check Apache error log:
```bash
sudo tail -f /var/log/apache2/error.log
```

Check application log:
```bash
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log
```

### Permission Issues

Reset permissions:
```bash
cd /var/www/jenkins-capacity-report
sudo chown -R www-data:www-data .
sudo chmod 600 .env
sudo chmod 755 deployment/*.sh
```

### Python Dependencies Issues

Reinstall dependencies:
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install --upgrade pip
sudo -u www-data venv/bin/pip install -r requirements.txt --force-reinstall
```

## Quick Reference

### One-Line Deployment (After Transfer)

```bash
cd /var/www/jenkins-capacity-report && \
sudo tar -xzf /tmp/jenkins-capacity-*.tar.gz && \
sudo chown -R www-data:www-data . && \
sudo chmod 600 .env && \
sudo systemctl reload apache2
```

### Check What's in the Tarball

```bash
tar -tzf jenkins-capacity-20260505-085021.tar.gz | less
```

### Compare Files Before Extracting

```bash
# Extract to temporary location first
mkdir /tmp/jenkins-capacity-preview
tar -xzf /tmp/jenkins-capacity-*.tar.gz -C /tmp/jenkins-capacity-preview
diff -r /var/www/jenkins-capacity-report /tmp/jenkins-capacity-preview
```

## Notes

- The tarball is designed to be extracted directly over an existing installation
- Sensitive files (`.env`, `users.json`, etc.) are never included in the tarball
- Always backup before deploying
- The deployment preserves all your data and configuration
- You can safely extract multiple times - it only updates code files

## Made with Bob