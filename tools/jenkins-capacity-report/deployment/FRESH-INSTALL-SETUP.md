# Fresh Installation Setup Guide

This guide covers setting up Jenkins Capacity Analyzer from a deployment tarball in a fresh directory.

## Prerequisites

You should have:
- Extracted the deployment tarball to `/var/www/jenkins-capacity-report`
- Created and configured the `.env` file with your Jenkins credentials

## Setup Steps

### 1. Install System Dependencies

```bash
sudo apt update
sudo apt install -y apache2 libapache2-mod-wsgi-py3 python3-pip python3-venv
```

### 2. Enable Required Apache Modules

```bash
sudo a2enmod wsgi
sudo a2enmod headers
sudo a2enmod rewrite
```

### 3. Create Python Virtual Environment

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data python3 -m venv venv
```

### 4. Install Python Dependencies

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install --upgrade pip
sudo -u www-data venv/bin/pip install -r requirements.txt
```

### 5. Set Proper Permissions

```bash
cd /var/www/jenkins-capacity-report
sudo chown -R www-data:www-data .
sudo chmod 600 .env
sudo chmod 755 deployment/*.sh
```

### 6. Create Required Directories

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data mkdir -p data logs
```

### 7. Configure Apache

You have two options:

#### Option A: Subdirectory Deployment (Recommended)

Add this to your existing Apache site configuration (e.g., `/etc/apache2/sites-available/000-default.conf` or your SSL site config):

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

#### Option B: Separate Domain/Subdomain

Copy and configure the Apache site config:

```bash
sudo cp /var/www/jenkins-capacity-report/deployment/apache2-jenkins-capacity.conf \
    /etc/apache2/sites-available/jenkins-capacity.conf

# Edit the config file to set your ServerName
sudo nano /etc/apache2/sites-available/jenkins-capacity.conf

# Enable the site
sudo a2ensite jenkins-capacity.conf
```

### 8. Test Apache Configuration

```bash
sudo apache2ctl configtest
```

You should see "Syntax OK".

### 9. Reload Apache

```bash
sudo systemctl reload apache2
```

### 10. Verify Installation

Check that the application is running:

```bash
# Check Apache status
sudo systemctl status apache2

# Test the application (adjust URL as needed)
curl -I http://localhost/jenkins-capacity/

# Check application logs
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log
```

## Post-Installation Configuration

### Create Admin User

```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/python scripts/create_admin_user.py
```

Follow the prompts to create your admin user.

### Optional: Add Cloud Configuration

If you have a `clouds.xml` file from Jenkins:

```bash
sudo cp /path/to/clouds.xml /var/www/jenkins-capacity-report/data/clouds.xml.live
sudo chown www-data:www-data /var/www/jenkins-capacity-report/data/clouds.xml.live
```

## Verification Checklist

- [ ] Apache is running: `sudo systemctl status apache2`
- [ ] Application responds: `curl -I http://localhost/jenkins-capacity/`
- [ ] No errors in Apache log: `sudo tail /var/log/apache2/error.log`
- [ ] No errors in app log: `sudo tail /var/www/jenkins-capacity-report/logs/web_app.log`
- [ ] Can access web interface in browser
- [ ] Can log in with admin user
- [ ] Dashboard loads and shows data

## Troubleshooting

### Application Not Loading

Check Apache error log:
```bash
sudo tail -f /var/log/apache2/error.log
```

Check application log:
```bash
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log
```

### Permission Denied Errors

Reset permissions:
```bash
cd /var/www/jenkins-capacity-report
sudo chown -R www-data:www-data .
sudo chmod 600 .env
sudo chmod 755 deployment/*.sh
```

### Python Module Not Found

Reinstall dependencies:
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install -r requirements.txt --force-reinstall
```

### WSGI Module Not Loading

Ensure mod_wsgi is installed and enabled:
```bash
sudo apt install libapache2-mod-wsgi-py3
sudo a2enmod wsgi
sudo systemctl restart apache2
```

## Quick Reference Commands

### View Logs
```bash
# Apache error log
sudo tail -f /var/log/apache2/error.log

# Application log
sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log

# Apache access log
sudo tail -f /var/log/apache2/access.log
```

### Restart Services
```bash
# Reload Apache (preferred - no downtime)
sudo systemctl reload apache2

# Restart Apache (if reload doesn't work)
sudo systemctl restart apache2
```

### Check Status
```bash
# Apache status
sudo systemctl status apache2

# Test Apache config
sudo apache2ctl configtest

# Check if application is responding
curl -I http://localhost/jenkins-capacity/
```

## Environment Variables (.env)

Your `.env` file should contain:

```bash
# Jenkins Configuration
JENKINS_URL=https://your-jenkins-server.com
JENKINS_USERNAME=your-username
JENKINS_API_TOKEN=your-api-token

# Application Configuration
SECRET_KEY=your-secret-key-here
FLASK_ENV=production

# Optional: Cloud Configuration
CLOUDS_XML_PATH=./data/clouds.xml.live
```

## Next Steps

1. Access the application: `https://your-server/jenkins-capacity/`
2. Log in with your admin credentials
3. Verify that Jenkins data is being fetched correctly
4. Configure any additional settings as needed
5. Set up monitoring/alerting if desired

## Made with Bob