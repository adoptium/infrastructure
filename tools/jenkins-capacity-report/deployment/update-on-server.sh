#!/bin/bash
################################################################################
# Jenkins Capacity Analyzer - Server Update Script
# 
# This script safely updates the Jenkins Capacity Analyzer application on the
# production server while preserving sensitive configuration and data files.
#
# Usage: sudo ./update-on-server.sh <path-to-tarball>
#
# Example: sudo ./update-on-server.sh /tmp/jenkins-capacity-20260415-105900.tar.gz
#
# Created by: Bob
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/var/www/jenkins-capacity-report"
APP_USER="www-data"
APP_GROUP="www-data"
BACKUP_DIR="/var/backups/jenkins-capacity"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Jenkins Capacity Server Update${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if tarball path provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide path to deployment tarball${NC}"
    echo -e "${YELLOW}Usage: sudo $0 <path-to-tarball>${NC}"
    echo -e "${YELLOW}Example: sudo $0 /tmp/jenkins-capacity-20260415-105900.tar.gz${NC}"
    exit 1
fi

TARBALL_PATH="$1"

# Verify tarball exists
if [ ! -f "$TARBALL_PATH" ]; then
    echo -e "${RED}Error: Tarball not found: $TARBALL_PATH${NC}"
    exit 1
fi

# Verify tarball is valid
echo -e "${YELLOW}Verifying tarball integrity...${NC}"
if ! tar -tzf "$TARBALL_PATH" > /dev/null 2>&1; then
    echo -e "${RED}Error: Invalid or corrupted tarball${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Tarball integrity verified${NC}\n"

# Verify application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: Application directory not found: $APP_DIR${NC}"
    echo -e "${YELLOW}This script is for updating existing installations.${NC}"
    echo -e "${YELLOW}For initial deployment, use deployment/deploy.sh${NC}"
    exit 1
fi

# Pre-flight checks
echo -e "${YELLOW}Running pre-flight checks...${NC}"

# Check if Apache is running
if ! systemctl is-active --quiet apache2; then
    echo -e "${RED}Warning: Apache2 is not running${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if .env file exists
if [ ! -f "$APP_DIR/.env" ]; then
    echo -e "${RED}Warning: .env file not found in $APP_DIR${NC}"
    echo -e "${YELLOW}You will need to configure it after update${NC}"
fi

# Check disk space (need at least 500MB free)
AVAILABLE_SPACE=$(df "$APP_DIR" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 512000 ]; then
    echo -e "${RED}Warning: Low disk space (less than 500MB available)${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✓ Pre-flight checks passed${NC}\n"

# Create backup directory
echo -e "${YELLOW}Creating backup directory...${NC}"
mkdir -p "$BACKUP_DIR"

# Backup current installation
BACKUP_FILE="$BACKUP_DIR/jenkins-capacity-backup-${TIMESTAMP}.tar.gz"
echo -e "${YELLOW}Backing up current installation...${NC}"
echo -e "${BLUE}Backup location: $BACKUP_FILE${NC}"

cd "$APP_DIR"
tar -czf "$BACKUP_FILE" \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.log' \
    . 2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✓ Backup created successfully (${BACKUP_SIZE})${NC}\n"
else
    echo -e "${RED}Error: Failed to create backup${NC}"
    exit 1
fi

# Save sensitive files to temporary location
echo -e "${YELLOW}Preserving sensitive configuration files...${NC}"
TEMP_PRESERVE=$(mktemp -d)

# Preserve .env file
if [ -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/.env" "$TEMP_PRESERVE/"
    echo -e "${GREEN}✓ Preserved .env${NC}"
fi

# Preserve users.json
if [ -f "$APP_DIR/data/users.json" ]; then
    mkdir -p "$TEMP_PRESERVE/data"
    cp "$APP_DIR/data/users.json" "$TEMP_PRESERVE/data/"
    echo -e "${GREEN}✓ Preserved data/users.json${NC}"
fi

# Preserve clouds.xml.live
if [ -f "$APP_DIR/data/clouds.xml.live" ]; then
    mkdir -p "$TEMP_PRESERVE/data"
    cp "$APP_DIR/data/clouds.xml.live" "$TEMP_PRESERVE/data/"
    echo -e "${GREEN}✓ Preserved data/clouds.xml.live${NC}"
fi

# Preserve excluded_nodes.json
if [ -f "$APP_DIR/data/excluded_nodes.json" ]; then
    mkdir -p "$TEMP_PRESERVE/data"
    cp "$APP_DIR/data/excluded_nodes.json" "$TEMP_PRESERVE/data/"
    echo -e "${GREEN}✓ Preserved data/excluded_nodes.json${NC}"
fi

# Preserve metrics_history.json
if [ -f "$APP_DIR/data/metrics_history.json" ]; then
    mkdir -p "$TEMP_PRESERVE/data"
    cp "$APP_DIR/data/metrics_history.json" "$TEMP_PRESERVE/data/"
    echo -e "${GREEN}✓ Preserved data/metrics_history.json${NC}"
fi

# Preserve Credentials.txt if it exists
if [ -f "$APP_DIR/Credentials.txt" ]; then
    cp "$APP_DIR/Credentials.txt" "$TEMP_PRESERVE/"
    echo -e "${GREEN}✓ Preserved Credentials.txt${NC}"
fi

echo ""

# Check if requirements.txt will change
REQUIREMENTS_CHANGED=false
TEMP_EXTRACT=$(mktemp -d)
tar -xzf "$TARBALL_PATH" -C "$TEMP_EXTRACT"
PACKAGE_NAME=$(ls "$TEMP_EXTRACT")

if [ -f "$APP_DIR/requirements.txt" ] && [ -f "$TEMP_EXTRACT/$PACKAGE_NAME/requirements.txt" ]; then
    if ! diff -q "$APP_DIR/requirements.txt" "$TEMP_EXTRACT/$PACKAGE_NAME/requirements.txt" > /dev/null 2>&1; then
        REQUIREMENTS_CHANGED=true
        echo -e "${YELLOW}Note: requirements.txt has changed - will update dependencies${NC}\n"
    fi
fi

# Extract new version
echo -e "${YELLOW}Extracting new version...${NC}"
cd "$APP_DIR"

# Remove old files (except venv, data, logs, and preserved files)
find . -maxdepth 1 -type f ! -name '.env' ! -name 'Credentials.txt' -delete 2>/dev/null || true
rm -rf src templates deployment scripts tools tests docs 2>/dev/null || true

# Extract tarball
tar -xzf "$TARBALL_PATH" -C "$APP_DIR" --strip-components=1

echo -e "${GREEN}✓ New version extracted${NC}\n"

# Restore preserved files
echo -e "${YELLOW}Restoring preserved configuration files...${NC}"

if [ -f "$TEMP_PRESERVE/.env" ]; then
    cp "$TEMP_PRESERVE/.env" "$APP_DIR/"
    echo -e "${GREEN}✓ Restored .env${NC}"
fi

if [ -f "$TEMP_PRESERVE/data/users.json" ]; then
    cp "$TEMP_PRESERVE/data/users.json" "$APP_DIR/data/"
    echo -e "${GREEN}✓ Restored data/users.json${NC}"
fi

if [ -f "$TEMP_PRESERVE/data/clouds.xml.live" ]; then
    cp "$TEMP_PRESERVE/data/clouds.xml.live" "$APP_DIR/data/"
    echo -e "${GREEN}✓ Restored data/clouds.xml.live${NC}"
fi

if [ -f "$TEMP_PRESERVE/data/excluded_nodes.json" ]; then
    cp "$TEMP_PRESERVE/data/excluded_nodes.json" "$APP_DIR/data/"
    echo -e "${GREEN}✓ Restored data/excluded_nodes.json${NC}"
fi

if [ -f "$TEMP_PRESERVE/data/metrics_history.json" ]; then
    cp "$TEMP_PRESERVE/data/metrics_history.json" "$APP_DIR/data/"
    echo -e "${GREEN}✓ Restored data/metrics_history.json${NC}"
fi

if [ -f "$TEMP_PRESERVE/Credentials.txt" ]; then
    cp "$TEMP_PRESERVE/Credentials.txt" "$APP_DIR/"
    echo -e "${GREEN}✓ Restored Credentials.txt${NC}"
fi

# Cleanup temporary preserve directory
rm -rf "$TEMP_PRESERVE"
rm -rf "$TEMP_EXTRACT"

echo ""

# Set proper ownership and permissions
echo -e "${YELLOW}Setting file permissions...${NC}"
chown -R $APP_USER:$APP_GROUP "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;

# Make scripts executable
chmod +x "$APP_DIR/deployment"/*.sh 2>/dev/null || true
chmod +x "$APP_DIR/main.py" 2>/dev/null || true
chmod +x "$APP_DIR/web_app.py" 2>/dev/null || true
chmod +x "$APP_DIR/tools"/*.sh 2>/dev/null || true
chmod +x "$APP_DIR/scripts"/*.py 2>/dev/null || true

# Secure sensitive files
if [ -f "$APP_DIR/.env" ]; then
    chmod 600 "$APP_DIR/.env"
fi
if [ -f "$APP_DIR/Credentials.txt" ]; then
    chmod 600 "$APP_DIR/Credentials.txt"
fi

echo -e "${GREEN}✓ Permissions set${NC}\n"

# Update Python dependencies if requirements changed
if [ "$REQUIREMENTS_CHANGED" = true ]; then
    echo -e "${YELLOW}Updating Python dependencies...${NC}"
    
    if [ -d "$APP_DIR/venv" ]; then
        sudo -u $APP_USER "$APP_DIR/venv/bin/pip" install --upgrade pip
        sudo -u $APP_USER "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"
        echo -e "${GREEN}✓ Dependencies updated${NC}\n"
    else
        echo -e "${YELLOW}Warning: Virtual environment not found${NC}"
        echo -e "${YELLOW}You may need to create it manually:${NC}"
        echo -e "${YELLOW}  cd $APP_DIR${NC}"
        echo -e "${YELLOW}  sudo -u $APP_USER python3 -m venv venv${NC}"
        echo -e "${YELLOW}  sudo -u $APP_USER venv/bin/pip install -r requirements.txt${NC}\n"
    fi
fi

# Test Apache configuration
echo -e "${YELLOW}Testing Apache configuration...${NC}"
if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    echo -e "${GREEN}✓ Apache configuration is valid${NC}\n"
else
    echo -e "${RED}Warning: Apache configuration test failed${NC}"
    echo -e "${YELLOW}You may need to check the configuration manually${NC}\n"
fi

# Reload Apache
echo -e "${YELLOW}Reloading Apache...${NC}"
if systemctl reload apache2; then
    echo -e "${GREEN}✓ Apache reloaded successfully${NC}\n"
else
    echo -e "${RED}Error: Failed to reload Apache${NC}"
    echo -e "${YELLOW}You may need to restart it manually: sudo systemctl restart apache2${NC}\n"
fi

# Verification
echo -e "${YELLOW}Running post-deployment verification...${NC}"

# Check if application responds
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost/jenkins-capacity/ | grep -q "200\|302"; then
    echo -e "${GREEN}✓ Application is responding${NC}"
else
    echo -e "${YELLOW}Warning: Application may not be responding correctly${NC}"
    echo -e "${YELLOW}Check Apache error log: tail -f /var/log/apache2/error.log${NC}"
fi

# Final summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Update Completed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Summary:${NC}"
echo -e "  Backup: $BACKUP_FILE"
echo -e "  Backup size: $BACKUP_SIZE"
echo -e "  Application: $APP_DIR"
echo -e "  Dependencies updated: $([ "$REQUIREMENTS_CHANGED" = true ] && echo "Yes" || echo "No")"
echo -e ""

echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Verify application: https://nagios.adoptopenjdk.net/jenkins-capacity/"
echo -e "2. Check logs: sudo tail -f /var/log/apache2/error.log"
echo -e "3. Monitor application: sudo tail -f $APP_DIR/logs/web_app.log"
echo -e ""

echo -e "${BLUE}Rollback (if needed):${NC}"
echo -e "  cd $APP_DIR"
echo -e "  sudo tar -xzf $BACKUP_FILE"
echo -e "  sudo systemctl reload apache2"
echo -e ""

# Cleanup old backups (keep last 10)
echo -e "${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"
cd "$BACKUP_DIR"
ls -t jenkins-capacity-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
BACKUP_COUNT=$(ls -1 jenkins-capacity-backup-*.tar.gz 2>/dev/null | wc -l)
echo -e "${GREEN}✓ Backup cleanup complete (${BACKUP_COUNT} backups retained)${NC}\n"

echo -e "${GREEN}Deployment complete!${NC}"

# Made with Bob
