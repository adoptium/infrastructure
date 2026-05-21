#!/bin/bash
################################################################################
# Jenkins Capacity Analyzer - Simple Deployment Package Creator
# 
# This script creates a deployment-ready tarball for manual SFTP transfer.
# After transfer, simply extract over the existing installation directory.
#
# Usage: ./create-deployment-package.sh
#
# The tarball will be created in the project root directory.
# Transfer it to the server and extract with:
#   tar -xzf jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="jenkins-capacity-${TIMESTAMP}"
OUTPUT_FILE="${PROJECT_ROOT}/${PACKAGE_NAME}.tar.gz"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Jenkins Capacity Deployment Packager${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verify we're in the correct directory
if [ ! -f "$PROJECT_ROOT/web_app.py" ]; then
    echo -e "${RED}Error: Cannot find web_app.py. Are you in the correct directory?${NC}"
    exit 1
fi

echo -e "${GREEN}Project root: ${PROJECT_ROOT}${NC}"
echo -e "${GREEN}Package name: ${PACKAGE_NAME}.tar.gz${NC}\n"

# Create tarball with only necessary files
echo -e "${YELLOW}Creating deployment package...${NC}"

cd "$PROJECT_ROOT"

tar -czf "$OUTPUT_FILE" \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.git' \
    --exclude='.gitignore' \
    --exclude='*.log' \
    --exclude='.env' \
    --exclude='Credentials.txt' \
    --exclude='data/users.json' \
    --exclude='data/clouds.xml.live' \
    --exclude='data/clouds.xml.live.backup' \
    --exclude='data/*.json' \
    --exclude='data/*.csv' \
    --exclude='data/archive/*' \
    --exclude='*.tar.gz' \
    --exclude='.DS_Store' \
    --exclude='*.swp' \
    --exclude='*~' \
    main.py \
    web_app.py \
    requirements.txt \
    README.md \
    .env.example \
    src/ \
    templates/ \
    config/ \
    deployment/wsgi.py \
    deployment/apache2-jenkins-capacity.conf \
    scripts/ \
    tools/ \
    docs/ \
    tests/ \
    data/.gitkeep \
    logs/.gitkeep \
    2>/dev/null || true

# Verify tarball was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo -e "${RED}Error: Failed to create tarball${NC}"
    exit 1
fi

# Get file size
PACKAGE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

# Verify tarball integrity
echo -e "${YELLOW}Verifying package integrity...${NC}"
if tar -tzf "$OUTPUT_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Package integrity verified${NC}"
else
    echo -e "${RED}✗ Package integrity check failed${NC}"
    exit 1
fi

# Count files in package
FILE_COUNT=$(tar -tzf "$OUTPUT_FILE" | wc -l)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Package Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Package Details:${NC}"
echo -e "  Location: ${OUTPUT_FILE}"
echo -e "  Size: ${PACKAGE_SIZE}"
echo -e "  Files: ${FILE_COUNT}"
echo -e ""

echo -e "${BLUE}Deployment Instructions:${NC}"
echo -e "${YELLOW}1. Transfer to server:${NC}"
echo -e "   scp ${PACKAGE_NAME}.tar.gz user@server:/tmp/"
echo -e ""
echo -e "${YELLOW}2. SSH to server:${NC}"
echo -e "   ssh user@server"
echo -e ""
echo -e "${YELLOW}3. Backup current installation (recommended):${NC}"
echo -e "   cd /var/www/jenkins-capacity-report"
echo -e "   sudo tar -czf ~/jenkins-capacity-backup-\$(date +%Y%m%d-%H%M%S).tar.gz ."
echo -e ""
echo -e "${YELLOW}4. Extract new version:${NC}"
echo -e "   cd /var/www/jenkins-capacity-report"
echo -e "   sudo tar -xzf /tmp/${PACKAGE_NAME}.tar.gz"
echo -e ""
echo -e "${YELLOW}5. Set permissions:${NC}"
echo -e "   sudo chown -R www-data:www-data /var/www/jenkins-capacity-report"
echo -e "   sudo chmod 600 /var/www/jenkins-capacity-report/.env"
echo -e ""
echo -e "${YELLOW}6. Update dependencies (if requirements.txt changed):${NC}"
echo -e "   cd /var/www/jenkins-capacity-report"
echo -e "   sudo -u www-data venv/bin/pip install -r requirements.txt"
echo -e ""
echo -e "${YELLOW}7. Reload Apache:${NC}"
echo -e "   sudo systemctl reload apache2"
echo -e ""

echo -e "${GREEN}Notes:${NC}"
echo -e "  • The tarball preserves your .env, users.json, and data files"
echo -e "  • Extracting will only update application code and templates"
echo -e "  • Your configuration and data remain untouched"
echo -e "  • Always backup before deploying!"
echo -e ""

# Made with Bob