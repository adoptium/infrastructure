# Deployment Guide - Jenkins Capacity Analyzer

This guide covers deploying the Jenkins Capacity Analyzer web application to a production Apache2 server.

## Prerequisites

- Ubuntu/Debian Linux server with Apache2 installed
- Python 3.8 or higher
- sudo/root access
- Existing Apache2 web server running

## Deployment Steps

### 1. Install Required System Packages

```bash
sudo apt update
sudo apt install -y apache2 libapache2-mod-wsgi-py3 python3-pip python3-venv
```

### 2. Enable Required Apache Modules

```bash
sudo a2enmod wsgi
sudo a2enmod headers
sudo a2enmod rewrite
sudo a2enmod ssl  # If using HTTPS
```

### 3. Create Application Directory

```bash
# Create application directory
sudo mkdir -p /var/www/jenkins-capacity-report

# Copy application files
sudo cp -r /path/to/jenkins-capacity-report/* /var/www/jenkins-capacity-report/

# Set ownership
sudo chown -R www-data:www-data /var/www/jenkins-capacity-report
```

### 4. Create Python Virtual Environment

```bash
cd /var/www/jenkins-capacity-report

# Create virtual environment
sudo -u www-data python3 -m venv venv

# Activate virtual environment
sudo -u www-data venv/bin/pip install --upgrade pip

# Install dependencies
sudo -u www-data venv/bin/pip install -r requirements.txt
```

### 5. Configure Environment Variables

```bash
# Copy and edit the .env file
sudo cp .env.example /var/www/jenkins-capacity-report/.env
sudo nano /var/www/jenkins-capacity-report/.env
```

Edit the `.env` file with your Jenkins credentials:
```bash
JENKINS_URL=https://your-jenkins-server.com
JENKINS_USERNAME=your_username
JENKINS_API_TOKEN=your_api_token
CLOUD_CONFIG_FILE=/var/www/jenkins-capacity-report/data/clouds.xml.live
```

Set proper permissions:
```bash
sudo chown www-data:www-data /var/www/jenkins-capacity-report/.env
sudo chmod 600 /var/www/jenkins-capacity-report/.env
```

### 6. Copy Cloud Configuration (Optional)

If you have a clouds.xml file:
```bash
sudo cp clouds.xml.live /var/www/jenkins-capacity-report/data/
sudo chown www-data:www-data /var/www/jenkins-capacity-report/data/clouds.xml.live
sudo chmod 644 /var/www/jenkins-capacity-report/data/clouds.xml.live
```

### 7. Configure Apache2

#### Option A: Separate Domain/Subdomain

```bash
# Copy Apache configuration
sudo cp deployment/apache2-jenkins-capacity.conf /etc/apache2/sites-available/jenkins-capacity.conf

# Edit the configuration
sudo nano /etc/apache2/sites-available/jenkins-capacity.conf
```

Update the following in the configuration:
- `ServerName` - Your domain or subdomain
- `ServerAdmin` - Your email address
- SSL certificate paths (if using HTTPS)

```bash
# Enable the site
sudo a2ensite jenkins-capacity.conf

# Test configuration
sudo apache2ctl configtest

# Reload Apache
sudo systemctl reload apache2
```

#### Option B: Serve from Subdirectory

If you want to serve from `https://your-server.com/jenkins-capacity`:

1. Edit your existing Apache site configuration:
```bash
sudo nano /etc/apache2/sites-available/000-default.conf
# or your custom site config
```

2. Add the following inside your existing `<VirtualHost>` block:
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

3. Reload Apache:
```bash
sudo systemctl reload apache2
```

### 8. Set Up Log Rotation (Optional but Recommended)

Create a logrotate configuration:
```bash
sudo nano /etc/logrotate.d/jenkins-capacity
```

Add the following:
```
/var/log/apache2/jenkins-capacity-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        if /etc/init.d/apache2 status > /dev/null ; then \
            /etc/init.d/apache2 reload > /dev/null; \
        fi;
    endscript
}
```

### 9. Set Up Automatic Cloud Config Updates (Optional)

If you want to automatically update the clouds.xml file:

```bash
# Create update script
sudo nano /var/www/jenkins-capacity-report/update-clouds.sh
```

Add the following:
```bash
#!/bin/bash
# Update clouds.xml from Jenkins server

JENKINS_SERVER="your-jenkins-server"
JENKINS_HOME="/home/jenkins/.jenkins"
DEST_DIR="/var/www/jenkins-capacity-report"

# Extract clouds config on Jenkins server
ssh jenkins@${JENKINS_SERVER} "cd ${JENKINS_HOME} && /path/to/tools/extract_clouds_config.sh -o /tmp/clouds.xml.live"

# Copy to web server
scp jenkins@${JENKINS_SERVER}:/tmp/clouds.xml.live ${DEST_DIR}/data/

# Set permissions
chown www-data:www-data ${DEST_DIR}/data/clouds.xml.live
chmod 644 ${DEST_DIR}/data/clouds.xml.live

# Clean up on Jenkins server
ssh jenkins@${JENKINS_SERVER} "rm /tmp/clouds.xml.live"
```

Make it executable:
```bash
sudo chmod +x /var/www/jenkins-capacity-report/update-clouds.sh
```

Add to crontab for daily updates:
```bash
sudo crontab -e
```

Add:
```
0 2 * * * /var/www/jenkins-capacity-report/update-clouds.sh >> /var/log/jenkins-capacity-update.log 2>&1
```

## Verification

### 1. Check Apache Status
```bash
sudo systemctl status apache2
```

### 2. Check Apache Error Logs
```bash
sudo tail -f /var/log/apache2/jenkins-capacity-error.log
```

### 3. Test the Application

Visit your configured URL:
- Separate domain: `https://jenkins-capacity.example.com`
- Subdirectory: `https://your-server.com/jenkins-capacity`

## Troubleshooting

### Permission Issues

If you see permission errors:
```bash
sudo chown -R www-data:www-data /var/www/jenkins-capacity-report
sudo chmod -R 755 /var/www/jenkins-capacity-report
sudo chmod 600 /var/www/jenkins-capacity-report/.env
```

### Python Module Not Found

If you see "ModuleNotFoundError":
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install -r requirements.txt
sudo systemctl restart apache2
```

### WSGI Import Error

Check the WSGI error log:
```bash
sudo tail -100 /var/log/apache2/jenkins-capacity-error.log
```

Verify Python path in Apache config matches your installation.

### Application Not Loading

1. Check Apache configuration syntax:
```bash
sudo apache2ctl configtest
```

2. Verify WSGI module is loaded:
```bash
apache2ctl -M | grep wsgi
```

3. Check file permissions:
```bash
ls -la /var/www/jenkins-capacity-report/
```

### Jenkins Connection Issues

Test Jenkins connectivity:
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/python3 -c "
from src.config import Config
from src.jenkins_client import JenkinsClient
config = Config.from_env()
client = JenkinsClient(config.jenkins_url, config.username, config.api_token)
nodes = client.get_all_nodes()
print(f'Successfully connected! Found {len(nodes)} nodes')
"
```

## Security Considerations

1. **Restrict Access**: Consider adding authentication to the Apache configuration
2. **Use HTTPS**: Always use SSL/TLS in production
3. **Firewall**: Ensure only necessary ports are open
4. **Credentials**: Keep `.env` file secure with proper permissions (600)
5. **Updates**: Regularly update dependencies and system packages

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
sudo tail -f /var/log/apache2/jenkins-capacity-error.log

# Apache access log
sudo tail -f /var/log/apache2/jenkins-capacity-access.log

# Application log (if configured)
sudo tail -f /var/www/jenkins-capacity-report/jenkins_capacity.log
```

### Restart Services

```bash
# Reload Apache (graceful, no downtime)
sudo systemctl reload apache2

# Restart Apache (brief downtime)
sudo systemctl restart apache2
```

## Performance Tuning

For high-traffic deployments, consider:

1. **Increase WSGI threads**:
   ```apache
   WSGIDaemonProcess jenkins_capacity threads=10
   ```

2. **Enable caching** (add to Apache config):
   ```apache
   <IfModule mod_expires.c>
       ExpiresActive On
       ExpiresByType text/css "access plus 1 month"
       ExpiresByType application/javascript "access plus 1 month"
   </IfModule>
   ```

3. **Use a reverse proxy cache** like Varnish for frequently accessed pages

## Support

For issues or questions:
- Check the main README.md
- Review Apache error logs
- Verify all prerequisites are met
- Ensure proper file permissions

## Made with Bob