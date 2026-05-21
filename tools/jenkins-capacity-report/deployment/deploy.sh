#!/bin/bash
# Deployment script for Jenkins Capacity Analyzer
# Run with sudo: sudo ./deploy.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/var/www/jenkins-capacity-report"
APP_USER="www-data"
APP_GROUP="www-data"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins Capacity Analyzer Deployment${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if Apache2 is installed
if ! command -v apache2 &> /dev/null; then
    echo -e "${YELLOW}Apache2 not found. Installing...${NC}"
    apt update
    apt install -y apache2
fi

# Install required packages
echo -e "${GREEN}Installing required packages...${NC}"
apt install -y apache2 libapache2-mod-wsgi-py3 python3-pip python3-venv

# Enable required Apache modules
echo -e "${GREEN}Enabling Apache modules...${NC}"
a2enmod wsgi
a2enmod headers
a2enmod rewrite

# Create application directory if it doesn't exist
if [ ! -d "$APP_DIR" ]; then
    echo -e "${GREEN}Creating application directory...${NC}"
    mkdir -p "$APP_DIR"
fi

# Copy application files
echo -e "${GREEN}Copying application files...${NC}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -r "$SCRIPT_DIR"/* "$APP_DIR/"

# Set ownership
echo -e "${GREEN}Setting file ownership...${NC}"
chown -R $APP_USER:$APP_GROUP "$APP_DIR"

# Create virtual environment
echo -e "${GREEN}Creating Python virtual environment...${NC}"
cd "$APP_DIR"
if [ ! -d "venv" ]; then
    sudo -u $APP_USER python3 -m venv venv
fi

# Install Python dependencies
echo -e "${GREEN}Installing Python dependencies...${NC}"
sudo -u $APP_USER venv/bin/pip install --upgrade pip
sudo -u $APP_USER venv/bin/pip install -r requirements.txt

# Check if .env file exists
if [ ! -f "$APP_DIR/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    if [ -f "$APP_DIR/.env.example" ]; then
        echo -e "${YELLOW}Copying .env.example to .env${NC}"
        cp "$APP_DIR/.env.example" "$APP_DIR/.env"
        chown $APP_USER:$APP_GROUP "$APP_DIR/.env"
        chmod 600 "$APP_DIR/.env"
        echo -e "${RED}IMPORTANT: Edit $APP_DIR/.env with your Jenkins credentials!${NC}"
    else
        echo -e "${RED}Error: .env.example not found. Please create .env manually.${NC}"
    fi
fi

# Set proper permissions for .env
if [ -f "$APP_DIR/.env" ]; then
    chmod 600 "$APP_DIR/.env"
    chown $APP_USER:$APP_GROUP "$APP_DIR/.env"
fi

# Ask user for deployment type
echo -e "\n${YELLOW}How would you like to deploy the application?${NC}"
echo "1) Separate domain/subdomain (e.g., jenkins-capacity.example.com)"
echo "2) Subdirectory of existing site (e.g., example.com/jenkins-capacity)"
read -p "Enter choice [1 or 2]: " DEPLOY_TYPE

if [ "$DEPLOY_TYPE" = "1" ]; then
    # Separate domain deployment
    read -p "Enter server name (e.g., jenkins-capacity.example.com): " SERVER_NAME
    
    # Copy and configure Apache site
    cp "$APP_DIR/apache2-jenkins-capacity.conf" "/etc/apache2/sites-available/jenkins-capacity.conf"
    
    # Update ServerName in config
    sed -i "s/jenkins-capacity.example.com/$SERVER_NAME/g" "/etc/apache2/sites-available/jenkins-capacity.conf"
    
    # Enable site
    a2ensite jenkins-capacity.conf
    
    echo -e "${GREEN}Site configuration created: /etc/apache2/sites-available/jenkins-capacity.conf${NC}"
    echo -e "${YELLOW}Note: Edit the config file to add SSL certificates if needed${NC}"
    
elif [ "$DEPLOY_TYPE" = "2" ]; then
    # Subdirectory deployment
    read -p "Enter subdirectory path (e.g., /jenkins-capacity): " SUBDIR
    
    echo -e "${YELLOW}Please add the following to your existing Apache site configuration:${NC}"
    echo -e "${GREEN}"
    cat << EOF

# Jenkins Capacity Analyzer
WSGIDaemonProcess jenkins_capacity \\
    user=www-data \\
    group=www-data \\
    threads=5 \\
    python-home=$APP_DIR/venv \\
    python-path=$APP_DIR \\
    home=$APP_DIR

WSGIScriptAlias $SUBDIR $APP_DIR/wsgi.py

<Directory $APP_DIR>
    WSGIProcessGroup jenkins_capacity
    WSGIApplicationGroup %{GLOBAL}
    Require all granted
</Directory>
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}Add this to your site config in /etc/apache2/sites-available/${NC}"
else
    echo -e "${RED}Invalid choice. Skipping Apache configuration.${NC}"
fi

# Test Apache configuration
echo -e "\n${GREEN}Testing Apache configuration...${NC}"
if apache2ctl configtest; then
    echo -e "${GREEN}Apache configuration is valid!${NC}"
    
    # Reload Apache
    echo -e "${GREEN}Reloading Apache...${NC}"
    systemctl reload apache2
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit $APP_DIR/.env with your Jenkins credentials"
    echo "2. (Optional) Copy clouds.xml.live to $APP_DIR/data/"
    echo "3. Access your application at the configured URL"
    echo "4. Check logs: tail -f /var/log/apache2/jenkins-capacity-error.log"
    
else
    echo -e "${RED}Apache configuration test failed!${NC}"
    echo -e "${YELLOW}Please check the configuration and try again.${NC}"
    exit 1
fi

# Made with Bob
