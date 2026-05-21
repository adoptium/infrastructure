# Complete Deployment Guide for nagios.adoptopenjdk.net

**Server**: nagios.adoptopenjdk.net  
**Date**: 2026-02-17  
**Purpose**: Deploy Jenkins Capacity Analyzer alongside existing Nagios installation

---

## Pre-Deployment Summary

✅ All prerequisites verified:
- Apache2 running with SSL
- WSGI module installed and enabled
- Headers module enabled
- Python 3.10.12 installed
- python3-venv installed
- 44GB free space available
- No WSGI conflicts
- Nagios using `/nagios` path

---

## Deployment Plan

**Application URL**: `https://nagios.adoptopenjdk.net/jenkins-capacity`  
**Installation Path**: `/var/www/jenkins-capacity-report`  
**Method**: Subdirectory deployment (integrates with existing Apache)

---

## Step-by-Step Deployment

### Step 1: Backup Current Configuration

```bash
# Create backup directory
mkdir -p ~/backups/$(date +%Y%m%d)

# Backup Apache configuration
sudo tar -czf ~/backups/$(date +%Y%m%d)/apache2-config-backup.tar.gz /etc/apache2/

# Backup current site configs
sudo cp /etc/apache2/sites-enabled/000-default-le-ssl.conf ~/backups/$(date +%Y%m%d)/

# Verify backup
ls -lh ~/backups/$(date +%Y%m%d)/
```

**Expected output**: You should see the backup files created

---

### Step 2: Create Application Directory

```bash
# Create directory
sudo mkdir -p /var/www/jenkins-capacity-report

# Verify creation
ls -ld /var/www/jenkins-capacity-report
```

**Expected output**: `drwxr-xr-x 2 root root 4096 ...`

---

### Step 3: Copy Application Files

```bash
# Navigate to your local repository
cd /home/scfryer/Development/Bob-Jenkins-Capacity/jenkins-capacity-report

# Copy all files to the server
# If on the same machine:
sudo cp -r * /var/www/jenkins-capacity-report/

# If copying from remote machine, use scp:
# scp -r /path/to/jenkins-capacity-report/* root@nagios.adoptopenjdk.net:/var/www/jenkins-capacity-report/

# Verify files copied
ls -la /var/www/jenkins-capacity-report/
```

**Expected output**: You should see all application files including:
- main.py
- web_app.py
- deployment/wsgi.py
- requirements.txt
- src/ directory
- templates/ directory
- tools/ directory
- .env.example

---

### Step 4: Set Proper Ownership and Permissions

```bash
# Set ownership to www-data
sudo chown -R www-data:www-data /var/www/jenkins-capacity-report

# Set directory permissions
sudo find /var/www/jenkins-capacity-report -type d -exec chmod 755 {} \;

# Set file permissions
sudo find /var/www/jenkins-capacity-report -type f -exec chmod 644 {} \;

# Make scripts executable
sudo chmod +x /var/www/jenkins-capacity-report/deployment/wsgi.py
sudo chmod +x /var/www/jenkins-capacity-report/main.py
sudo chmod +x /var/www/jenkins-capacity-report/web_app.py
sudo chmod +x /var/www/jenkins-capacity-report/tools/*.sh

# Verify permissions
ls -la /var/www/jenkins-capacity-report/
```

**Expected output**: All files owned by www-data:www-data

---

### Step 5: Create Python Virtual Environment

```bash
# Navigate to application directory
cd /var/www/jenkins-capacity-report

# Create virtual environment as www-data user
sudo -u www-data python3 -m venv venv

# Verify venv created
ls -la venv/
```

**Expected output**: venv directory with bin/, lib/, etc.

---

### Step 6: Install Python Dependencies

```bash
# Still in /var/www/jenkins-capacity-report

# Upgrade pip
sudo -u www-data venv/bin/pip install --upgrade pip

# Install requirements
sudo -u www-data venv/bin/pip install -r requirements.txt

# Verify installations
sudo -u www-data venv/bin/pip list
```

**Expected output**: Should show:
- Flask (3.0.0 or higher)
- requests (2.31.0 or higher)
- python-dotenv (1.0.0 or higher)
- pydantic (2.5.0 or higher)

---

### Step 7: Configure Environment Variables

```bash
# Copy example env file
sudo cp /var/www/jenkins-capacity-report/.env.example /var/www/jenkins-capacity-report/.env

# Edit the .env file
sudo nano /var/www/jenkins-capacity-report/.env
```

**Edit the following values**:
```bash
JENKINS_URL=https://ci.adoptium.net
JENKINS_USERNAME=your_jenkins_username
JENKINS_API_TOKEN=your_jenkins_api_token
CLOUD_CONFIG_FILE=/var/www/jenkins-capacity-report/data/clouds.xml.live
```

**Save and exit**: Press `Ctrl+X`, then `Y`, then `Enter`

```bash
# Set proper permissions on .env
sudo chown www-data:www-data /var/www/jenkins-capacity-report/.env
sudo chmod 600 /var/www/jenkins-capacity-report/.env

# Verify permissions
ls -la /var/www/jenkins-capacity-report/.env
```

**Expected output**: `-rw------- 1 www-data www-data ... .env`

---

### Step 8: (Optional) Copy Cloud Configuration File

If you have a clouds.xml file:

```bash
# Copy clouds.xml to application directory
sudo cp /path/to/clouds.xml.live /var/www/jenkins-capacity-report/data/

# Set permissions
sudo chown www-data:www-data /var/www/jenkins-capacity-report/data/clouds.xml.live
sudo chmod 644 /var/www/jenkins-capacity-report/data/clouds.xml.live

# Verify
ls -la /var/www/jenkins-capacity-report/data/clouds.xml.live
```

**If you don't have this file yet**: The application will work without it, but cloud capacity features will be disabled. You can add it later.

---

### Step 9: Test Application Locally (Before Apache Integration)

```bash
# Test Jenkins connectivity
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/python3 -c "
from src.config import Config
from src.jenkins_client import JenkinsClient

config = Config.from_env()
print(f'Jenkins URL: {config.jenkins_url}')
print(f'Username: {config.username}')
print('Testing connection...')

try:
    client = JenkinsClient(config.jenkins_url, config.username, config.api_token)
    nodes = client.get_all_nodes()
    print(f'✅ Success! Found {len(nodes)} nodes')
except Exception as e:
    print(f'❌ Error: {e}')
"
```

**Expected output**: Should show successful connection and node count

---

### Step 10: Configure Apache2

```bash
# Backup the SSL site config first
sudo cp /etc/apache2/sites-enabled/000-default-le-ssl.conf /etc/apache2/sites-enabled/000-default-le-ssl.conf.backup

# Edit the SSL site configuration
sudo nano /etc/apache2/sites-enabled/000-default-le-ssl.conf
```

**Scroll to the bottom of the file, BEFORE the closing `</VirtualHost>` tag, and add**:

```apache
    # Jenkins Capacity Analyzer
    WSGIDaemonProcess jenkins_capacity \
        user=www-data \
        group=www-data \
        threads=5 \
        python-home=/var/www/jenkins-capacity-report/venv \
        python-path=/var/www/jenkins-capacity-report \
        home=/var/www/jenkins-capacity-report

    WSGIScriptAlias /jenkins-capacity /var/www/jenkins-capacity-report/deployment/wsgi.py

    <Directory /var/www/jenkins-capacity-report>
        WSGIProcessGroup jenkins_capacity
        WSGIApplicationGroup %{GLOBAL}
        Require all granted
    </Directory>
```

**Save and exit**: Press `Ctrl+X`, then `Y`, then `Enter`

---

### Step 11: Test Apache Configuration

```bash
# Test configuration syntax
sudo apache2ctl configtest
```

**Expected output**: `Syntax OK`

**If you see errors**:
- Check for typos in the configuration
- Ensure all paths are correct
- Verify the closing `</VirtualHost>` tag is still present

---

### Step 12: Reload Apache

```bash
# Reload Apache (graceful, no downtime)
sudo systemctl reload apache2

# Check Apache status
sudo systemctl status apache2
```

**Expected output**: Apache should show as `active (running)`

---

### Step 13: Monitor Logs During First Access

Open a new terminal and monitor logs:

```bash
# Terminal 1: Watch error log
sudo tail -f /var/log/apache2/error.log
```

Open another terminal:

```bash
# Terminal 2: Watch access log
sudo tail -f /var/log/apache2/access.log
```

---

### Step 14: Test the Application

```bash
# Test from command line
curl -I https://nagios.adoptopenjdk.net/jenkins-capacity

# Or test with full response
curl https://nagios.adoptopenjdk.net/jenkins-capacity
```

**Expected output**: Should see HTML content or HTTP 200 response

---

### Step 15: Access from Browser

Open your web browser and navigate to:

```
https://nagios.adoptopenjdk.net/jenkins-capacity
```

**Expected result**: You should see the Jenkins Capacity Dashboard

---

## Verification Checklist

After deployment, verify:

- [ ] Application loads in browser
- [ ] Dashboard shows Jenkins node data
- [ ] Navigation works (click through different sections)
- [ ] No errors in Apache error log
- [ ] Nagios still works at `/nagios`
- [ ] SSL certificate is valid

---

## Troubleshooting

### Issue 1: 500 Internal Server Error

**Check error log**:
```bash
sudo tail -100 /var/log/apache2/error.log
```

**Common causes**:
1. **Python module not found**: Reinstall dependencies
   ```bash
   cd /var/www/jenkins-capacity-report
   sudo -u www-data venv/bin/pip install -r requirements.txt
   ```

2. **Permission denied**: Fix permissions
   ```bash
   sudo chown -R www-data:www-data /var/www/jenkins-capacity-report
   sudo chmod 600 /var/www/jenkins-capacity-report/.env
   ```

3. **WSGI import error**: Check deployment/wsgi.py path in Apache config

---

### Issue 2: 404 Not Found

**Verify Apache configuration**:
```bash
# Check if WSGIScriptAlias is correct
grep -A 5 "jenkins-capacity" /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Reload Apache
sudo systemctl reload apache2
```

---

### Issue 3: Application Shows But No Data

**Test Jenkins connection**:
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/python3 main.py
```

**Check .env file**:
```bash
sudo cat /var/www/jenkins-capacity-report/.env
```

Verify credentials are correct.

---

### Issue 4: Cloud Statistics Not Working

This is expected if you haven't copied the clouds.xml file. The application will show a warning message with instructions.

**To enable cloud statistics**:
1. Extract clouds.xml from Jenkins server
2. Copy to `/var/www/jenkins-capacity-report/data/clouds.xml.live`
3. Set permissions: `sudo chown www-data:www-data /var/www/jenkins-capacity-report/data/clouds.xml.live`

---

## Post-Deployment Tasks

### 1. Set Up Log Rotation

```bash
# Create logrotate config
sudo nano /etc/logrotate.d/jenkins-capacity
```

Add:
```
/var/www/jenkins-capacity-report/jenkins_capacity.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
}
```

### 2. (Optional) Add Authentication

If you want to use Nagios authentication:

```bash
sudo nano /etc/apache2/sites-enabled/000-default-le-ssl.conf
```

Modify the Directory block:
```apache
<Directory /var/www/jenkins-capacity-report>
    WSGIProcessGroup jenkins_capacity
    WSGIApplicationGroup %{GLOBAL}
    
    AuthName "Jenkins Capacity Access"
    AuthType Basic
    AuthUserFile /usr/local/nagios/etc/htpasswd.users
    Require valid-user
</Directory>
```

Reload Apache:
```bash
sudo systemctl reload apache2
```

### 3. Set Up Automatic Updates (Optional)

Create update script:
```bash
sudo nano /var/www/jenkins-capacity-report/update.sh
```

Add:
```bash
#!/bin/bash
cd /var/www/jenkins-capacity-report
sudo -u www-data git pull origin main
sudo -u www-data venv/bin/pip install -r requirements.txt
sudo systemctl reload apache2
```

Make executable:
```bash
sudo chmod +x /var/www/jenkins-capacity-report/update.sh
```

---

## Maintenance

### Update Application

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data git pull origin main
sudo -u www-data venv/bin/pip install -r requirements.txt
sudo systemctl reload apache2
```

### View Logs

```bash
# Apache error log
sudo tail -f /var/log/apache2/error.log

# Apache access log
sudo tail -f /var/log/apache2/access.log

# Application log (if configured)
sudo tail -f /var/www/jenkins-capacity-report/jenkins_capacity.log
```

### Restart Services

```bash
# Reload Apache (graceful, no downtime)
sudo systemctl reload apache2

# Restart Apache (brief downtime)
sudo systemctl restart apache2

# Check status
sudo systemctl status apache2
```

---

## Rollback Procedure

If something goes wrong:

```bash
# Stop Apache
sudo systemctl stop apache2

# Restore backup
sudo cp ~/backups/YYYYMMDD/000-default-le-ssl.conf.backup /etc/apache2/sites-enabled/000-default-le-ssl.conf

# Test configuration
sudo apache2ctl configtest

# Start Apache
sudo systemctl start apache2

# Verify Nagios still works
curl -I https://nagios.adoptopenjdk.net/nagios
```

---

## Success Criteria

✅ Application accessible at `https://nagios.adoptopenjdk.net/jenkins-capacity`  
✅ Dashboard displays Jenkins node data  
✅ All navigation links work  
✅ No errors in Apache logs  
✅ Nagios continues to work normally  
✅ SSL certificate valid  

---

## Support Information

**Application Repository**: https://github.com/steelhead31/general-utils  
**Branch**: add_jenkins_cap_tool  
**Documentation**: See DEPLOYMENT.md in repository  

**Key Files**:
- Application: `/var/www/jenkins-capacity-report/`
- Config: `/var/www/jenkins-capacity-report/.env`
- Apache Config: `/etc/apache2/sites-enabled/000-default-le-ssl.conf`
- Logs: `/var/log/apache2/error.log`

---

## Deployment Completed

**Date**: _______________  
**Deployed By**: _______________  
**Application URL**: https://nagios.adoptopenjdk.net/jenkins-capacity  
**Status**: _______________  

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

**End of Deployment Guide**