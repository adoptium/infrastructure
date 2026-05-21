#!/bin/bash
################################################################################
# Jenkins Capacity Analyzer - Deployment Package Creator
# 
# This script creates a deployment-ready tarball containing only the necessary
# files for production deployment, excluding sensitive data and development
# artifacts.
#
# Usage: ./package-for-deployment.sh [output-directory]
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
OUTPUT_DIR="${1:-$PROJECT_ROOT}"
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Jenkins Capacity Deployment Packager${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verify we're in the correct directory
if [ ! -f "$PROJECT_ROOT/web_app.py" ]; then
    echo -e "${RED}Error: Cannot find web_app.py. Are you in the correct directory?${NC}"
    exit 1
fi

echo -e "${GREEN}Project root: ${PROJECT_ROOT}${NC}"
echo -e "${GREEN}Package name: ${PACKAGE_NAME}.tar.gz${NC}"
echo -e "${GREEN}Output directory: ${OUTPUT_DIR}${NC}\n"

# Create package directory structure
echo -e "${YELLOW}Creating package directory structure...${NC}"
mkdir -p "$PACKAGE_DIR"

# Copy files and directories, excluding sensitive and generated content
echo -e "${YELLOW}Copying application files...${NC}"

# Copy main Python files
cp "$PROJECT_ROOT/main.py" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/web_app.py" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/requirements.txt" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/README.md" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/.env.example" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/.gitignore" "$PACKAGE_DIR/" 2>/dev/null || true

# Copy directories (excluding sensitive and generated files)
echo -e "${YELLOW}Copying source code...${NC}"
if [ -d "$PROJECT_ROOT/src" ]; then
    mkdir -p "$PACKAGE_DIR/src"
    cp -r "$PROJECT_ROOT/src"/* "$PACKAGE_DIR/src/" 2>/dev/null || true
    # Remove Python cache
    find "$PACKAGE_DIR/src" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$PACKAGE_DIR/src" -type f -name "*.pyc" -delete 2>/dev/null || true
fi

echo -e "${YELLOW}Copying templates...${NC}"
if [ -d "$PROJECT_ROOT/templates" ]; then
    cp -r "$PROJECT_ROOT/templates" "$PACKAGE_DIR/" 2>/dev/null || true
fi

echo -e "${YELLOW}Copying deployment configuration...${NC}"
if [ -d "$PROJECT_ROOT/deployment" ]; then
    mkdir -p "$PACKAGE_DIR/deployment"
    cp "$PROJECT_ROOT/deployment/wsgi.py" "$PACKAGE_DIR/deployment/" 2>/dev/null || true
    cp "$PROJECT_ROOT/deployment/apache2-jenkins-capacity.conf" "$PACKAGE_DIR/deployment/" 2>/dev/null || true
    # Don't copy deploy.sh as it's for initial setup, not updates
fi

echo -e "${YELLOW}Copying scripts...${NC}"
if [ -d "$PROJECT_ROOT/scripts" ]; then
    cp -r "$PROJECT_ROOT/scripts" "$PACKAGE_DIR/" 2>/dev/null || true
    find "$PACKAGE_DIR/scripts" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
fi

echo -e "${YELLOW}Copying tools...${NC}"
if [ -d "$PROJECT_ROOT/tools" ]; then
    mkdir -p "$PACKAGE_DIR/tools"
    # Copy all files except actual clouds.xml files (keep examples)
    for file in "$PROJECT_ROOT/tools"/*; do
        filename=$(basename "$file")
        if [[ ! "$filename" =~ ^clouds\.xml$ ]] && [[ ! "$filename" =~ \.xml$ ]] || [[ "$filename" =~ \.example\. ]]; then
            cp "$file" "$PACKAGE_DIR/tools/" 2>/dev/null || true
        fi
    done
fi

echo -e "${YELLOW}Copying configuration files...${NC}"
if [ -d "$PROJECT_ROOT/config" ]; then
    cp -r "$PROJECT_ROOT/config" "$PACKAGE_DIR/" 2>/dev/null || true
fi

echo -e "${YELLOW}Copying documentation...${NC}"
if [ -d "$PROJECT_ROOT/docs" ]; then
    cp -r "$PROJECT_ROOT/docs" "$PACKAGE_DIR/" 2>/dev/null || true
fi

echo -e "${YELLOW}Copying tests...${NC}"
if [ -d "$PROJECT_ROOT/tests" ]; then
    cp -r "$PROJECT_ROOT/tests" "$PACKAGE_DIR/" 2>/dev/null || true
    find "$PACKAGE_DIR/tests" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
fi

# Create empty directories with .gitkeep files
echo -e "${YELLOW}Creating empty directories...${NC}"
mkdir -p "$PACKAGE_DIR/data"
mkdir -p "$PACKAGE_DIR/logs"
touch "$PACKAGE_DIR/data/.gitkeep"
touch "$PACKAGE_DIR/logs/.gitkeep"

# Create a manifest file
echo -e "${YELLOW}Creating package manifest...${NC}"
cat > "$PACKAGE_DIR/PACKAGE-INFO.txt" << EOF
Jenkins Capacity Analyzer - Deployment Package
================================================

Package: ${PACKAGE_NAME}
Created: $(date)
Created by: $(whoami)@$(hostname)

CONTENTS:
---------
This package contains all necessary files for deploying or updating
the Jenkins Capacity Analyzer application.

INCLUDED:
- Application source code (main.py, web_app.py, src/)
- Web templates (templates/)
- Configuration files (config/)
- Deployment configuration (deployment/)
- Scripts and tools (scripts/, tools/)
- Documentation (docs/, README.md)
- Requirements (requirements.txt)
- Example configuration (.env.example)
- Tests (tests/)

EXCLUDED (must be configured on server):
- Environment configuration (.env)
- User database (data/users.json)
- Cloud configuration (data/clouds.xml.live)
- Credentials (Credentials.txt)
- Generated data files (*.json, *.csv)
- Log files (logs/*.log)
- Virtual environment (venv/)
- Python cache (__pycache__/)

DEPLOYMENT INSTRUCTIONS:
------------------------
1. Transfer this tarball to your server
2. Extract to /var/www/jenkins-capacity-report/
3. Preserve existing .env and data/users.json files
4. Update Python dependencies if requirements.txt changed
5. Reload Apache: sudo systemctl reload apache2

For detailed instructions, see deployment/QUICK-DEPLOY.md

EOF

# Generate file list
echo -e "${YELLOW}Generating file list...${NC}"
cd "$PACKAGE_DIR"
find . -type f | sort > FILE-LIST.txt
FILE_COUNT=$(wc -l < FILE-LIST.txt)
cd - > /dev/null

# Create checksum file
echo -e "${YELLOW}Generating checksums...${NC}"
cd "$PACKAGE_DIR"
find . -type f -not -name "CHECKSUMS.txt" -exec sha256sum {} \; | sort > CHECKSUMS.txt
cd - > /dev/null

# Create the tarball
echo -e "${YELLOW}Creating tarball...${NC}"
cd "$TEMP_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
cd - > /dev/null

# Move to output directory
mv "$TEMP_DIR/${PACKAGE_NAME}.tar.gz" "$OUTPUT_DIR/"

# Get file size
PACKAGE_SIZE=$(du -h "$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz" | cut -f1)

# Verification
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Package Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Package Details:${NC}"
echo -e "  Location: ${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz"
echo -e "  Size: ${PACKAGE_SIZE}"
echo -e "  Files: ${FILE_COUNT}"
echo -e ""

# Run verification tests
echo -e "${YELLOW}Running verification tests...${NC}"

# Test 1: Verify tarball can be extracted
TEST_DIR=$(mktemp -d)
if tar -tzf "$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Tarball integrity check passed"
else
    echo -e "${RED}✗${NC} Tarball integrity check failed"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Test 2: Extract and verify critical files exist
tar -xzf "$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz" -C "$TEST_DIR"
CRITICAL_FILES=(
    "web_app.py"
    "main.py"
    "requirements.txt"
    "deployment/wsgi.py"
    "src/__init__.py"
    "src/node_pattern_matcher.py"
    "templates/dashboard.html"
    "config/node_patterns.json"
    ".env.example"
)

ALL_CRITICAL_FOUND=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$TEST_DIR/$PACKAGE_NAME/$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
        ALL_CRITICAL_FOUND=false
    fi
done

# Test 3: Verify sensitive files are NOT included
SENSITIVE_FILES=(
    ".env"
    "Credentials.txt"
    "data/users.json"
    "data/clouds.xml.live"
)

ALL_SENSITIVE_EXCLUDED=true
for file in "${SENSITIVE_FILES[@]}"; do
    if [ -f "$TEST_DIR/$PACKAGE_NAME/$file" ]; then
        echo -e "${RED}✗${NC} SECURITY WARNING: Sensitive file included: $file"
        ALL_SENSITIVE_EXCLUDED=false
    else
        echo -e "${GREEN}✓${NC} Excluded: $file"
    fi
done

# Test 4: Verify no log files included
if find "$TEST_DIR/$PACKAGE_NAME" -name "*.log" | grep -q .; then
    echo -e "${RED}✗${NC} WARNING: Log files found in package"
else
    echo -e "${GREEN}✓${NC} No log files in package"
fi

# Test 5: Verify no Python cache
if find "$TEST_DIR/$PACKAGE_NAME" -name "__pycache__" | grep -q .; then
    echo -e "${RED}✗${NC} WARNING: Python cache found in package"
else
    echo -e "${GREEN}✓${NC} No Python cache in package"
fi

# Cleanup test directory
rm -rf "$TEST_DIR"

# Final status
echo -e "\n${GREEN}========================================${NC}"
if [ "$ALL_CRITICAL_FOUND" = true ] && [ "$ALL_SENSITIVE_EXCLUDED" = true ]; then
    echo -e "${GREEN}✓ All verification tests passed!${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "1. Transfer to server:"
    echo -e "   ${YELLOW}scp ${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz user@nagios.adoptopenjdk.net:/tmp/${NC}"
    echo -e ""
    echo -e "2. SSH to server and run update script:"
    echo -e "   ${YELLOW}ssh user@nagios.adoptopenjdk.net${NC}"
    echo -e "   ${YELLOW}cd /var/www/jenkins-capacity-report${NC}"
    echo -e "   ${YELLOW}sudo ./deployment/update-on-server.sh /tmp/${PACKAGE_NAME}.tar.gz${NC}"
    echo -e ""
else
    echo -e "${RED}✗ Some verification tests failed!${NC}"
    echo -e "${RED}========================================${NC}\n"
    echo -e "${YELLOW}Please review the errors above before deploying.${NC}"
    exit 1
fi

# Made with Bob
