#!/bin/bash
################################################################################
# Jenkins Capacity Analyzer - Package Testing Script
# 
# This script performs comprehensive testing of a deployment package to ensure
# it contains all required files and excludes sensitive data.
#
# Usage: ./test-package.sh <path-to-tarball>
#
# Example: ./test-package.sh jenkins-capacity-20260415-110000.tar.gz
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

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${YELLOW}$message${NC}"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Package Testing Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if tarball path provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide path to tarball${NC}"
    echo -e "${YELLOW}Usage: $0 <path-to-tarball>${NC}"
    echo -e "${YELLOW}Example: $0 jenkins-capacity-20260415-110000.tar.gz${NC}"
    exit 1
fi

TARBALL_PATH="$1"

# Verify tarball exists
if [ ! -f "$TARBALL_PATH" ]; then
    echo -e "${RED}Error: Tarball not found: $TARBALL_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}Testing package: $(basename "$TARBALL_PATH")${NC}"
echo -e "${BLUE}Size: $(du -h "$TARBALL_PATH" | cut -f1)${NC}\n"

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${YELLOW}Extracting package for testing...${NC}\n"

# Test 1: Tarball integrity
if tar -tzf "$TARBALL_PATH" > /dev/null 2>&1; then
    test_result "Tarball integrity" "pass"
else
    test_result "Tarball integrity" "fail" "Tarball is corrupted or invalid"
    exit 1
fi

# Extract tarball
tar -xzf "$TARBALL_PATH" -C "$TEMP_DIR"
PACKAGE_NAME=$(ls "$TEMP_DIR")
EXTRACT_DIR="$TEMP_DIR/$PACKAGE_NAME"

echo -e "\n${YELLOW}Running file presence tests...${NC}\n"

# Test 2-10: Critical files must exist
CRITICAL_FILES=(
    "main.py:Main application entry point"
    "web_app.py:Flask web application"
    "requirements.txt:Python dependencies"
    "README.md:Documentation"
    ".env.example:Environment configuration example"
    "deployment/wsgi.py:WSGI entry point"
    "deployment/apache2-jenkins-capacity.conf:Apache configuration"
    "src/__init__.py:Source package marker"
    "templates/dashboard.html:Main dashboard template"
)

for entry in "${CRITICAL_FILES[@]}"; do
    IFS=':' read -r file description <<< "$entry"
    if [ -f "$EXTRACT_DIR/$file" ]; then
        test_result "Critical file: $file" "pass"
    else
        test_result "Critical file: $file" "fail" "$description is missing"
    fi
done

echo -e "\n${YELLOW}Running directory structure tests...${NC}\n"

# Test 11-16: Required directories
REQUIRED_DIRS=(
    "src:Source code directory"
    "templates:HTML templates"
    "deployment:Deployment configuration"
    "scripts:Utility scripts"
    "tools:Development tools"
    "docs:Documentation"
)

for entry in "${REQUIRED_DIRS[@]}"; do
    IFS=':' read -r dir description <<< "$entry"
    if [ -d "$EXTRACT_DIR/$dir" ]; then
        test_result "Directory: $dir/" "pass"
    else
        test_result "Directory: $dir/" "fail" "$description is missing"
    fi
done

echo -e "\n${YELLOW}Running security tests (sensitive files must be excluded)...${NC}\n"

# Test 17-21: Sensitive files must NOT exist
SENSITIVE_FILES=(
    ".env:Environment configuration with credentials"
    "Credentials.txt:Stored credentials"
    "data/users.json:User database"
    "data/clouds.xml.live:Live cloud configuration"
    "data/metrics_history.json:Historical metrics data"
)

for entry in "${SENSITIVE_FILES[@]}"; do
    IFS=':' read -r file description <<< "$entry"
    if [ ! -f "$EXTRACT_DIR/$file" ]; then
        test_result "Excluded: $file" "pass"
    else
        test_result "Excluded: $file" "fail" "SECURITY: $description should not be in package"
    fi
done

echo -e "\n${YELLOW}Running data exclusion tests...${NC}\n"

# Test 22: No log files
LOG_COUNT=$(find "$EXTRACT_DIR" -name "*.log" 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -eq 0 ]; then
    test_result "No log files" "pass"
else
    test_result "No log files" "fail" "Found $LOG_COUNT log files"
fi

# Test 23: No CSV files (except examples)
CSV_COUNT=$(find "$EXTRACT_DIR" -name "*.csv" ! -name "example_*.csv" 2>/dev/null | wc -l)
if [ "$CSV_COUNT" -eq 0 ]; then
    test_result "No generated CSV files" "pass"
else
    test_result "No generated CSV files" "fail" "Found $CSV_COUNT CSV files"
fi

# Test 24: No JSON data files (except examples and required configs)
JSON_COUNT=$(find "$EXTRACT_DIR/data" -name "*.json" ! -name "example_*.json" 2>/dev/null | wc -l)
if [ "$JSON_COUNT" -eq 0 ]; then
    test_result "No generated JSON data files" "pass"
else
    test_result "No generated JSON data files" "fail" "Found $JSON_COUNT JSON files in data/"
fi

echo -e "\n${YELLOW}Running artifact exclusion tests...${NC}\n"

# Test 25: No Python cache
PYCACHE_COUNT=$(find "$EXTRACT_DIR" -type d -name "__pycache__" 2>/dev/null | wc -l)
if [ "$PYCACHE_COUNT" -eq 0 ]; then
    test_result "No Python cache" "pass"
else
    test_result "No Python cache" "fail" "Found $PYCACHE_COUNT __pycache__ directories"
fi

# Test 26: No .pyc files
PYC_COUNT=$(find "$EXTRACT_DIR" -name "*.pyc" 2>/dev/null | wc -l)
if [ "$PYC_COUNT" -eq 0 ]; then
    test_result "No .pyc files" "pass"
else
    test_result "No .pyc files" "fail" "Found $PYC_COUNT .pyc files"
fi

# Test 27: No virtual environment
if [ ! -d "$EXTRACT_DIR/venv" ]; then
    test_result "No virtual environment" "pass"
else
    test_result "No virtual environment" "fail" "venv/ directory should not be in package"
fi

# Test 28: No .git directory
if [ ! -d "$EXTRACT_DIR/.git" ]; then
    test_result "No .git directory" "pass"
else
    test_result "No .git directory" "fail" ".git/ directory should not be in package"
fi

# Test 29: No .vscode directory
if [ ! -d "$EXTRACT_DIR/.vscode" ]; then
    test_result "No .vscode directory" "pass"
else
    test_result "No .vscode directory" "fail" ".vscode/ directory should not be in package"
fi

echo -e "\n${YELLOW}Running package metadata tests...${NC}\n"

# Test 30: Package info file exists
if [ -f "$EXTRACT_DIR/PACKAGE-INFO.txt" ]; then
    test_result "Package info file" "pass"
else
    test_result "Package info file" "fail" "PACKAGE-INFO.txt is missing"
fi

# Test 31: File list exists
if [ -f "$EXTRACT_DIR/FILE-LIST.txt" ]; then
    test_result "File list" "pass"
    FILE_COUNT=$(wc -l < "$EXTRACT_DIR/FILE-LIST.txt")
else
    test_result "File list" "fail" "FILE-LIST.txt is missing"
    FILE_COUNT=0
fi

# Test 32: Checksums file exists
if [ -f "$EXTRACT_DIR/CHECKSUMS.txt" ]; then
    test_result "Checksums file" "pass"
else
    test_result "Checksums file" "fail" "CHECKSUMS.txt is missing"
fi

echo -e "\n${YELLOW}Running content validation tests...${NC}\n"

# Test 33: Verify checksums
if [ -f "$EXTRACT_DIR/CHECKSUMS.txt" ]; then
    cd "$EXTRACT_DIR"
    if sha256sum -c CHECKSUMS.txt > /dev/null 2>&1; then
        test_result "Checksum verification" "pass"
    else
        test_result "Checksum verification" "fail" "Some files failed checksum verification"
    fi
    cd - > /dev/null
else
    test_result "Checksum verification" "fail" "Cannot verify - CHECKSUMS.txt missing"
fi

# Test 34: Python syntax check on main files
SYNTAX_ERRORS=0
for pyfile in "$EXTRACT_DIR/main.py" "$EXTRACT_DIR/web_app.py"; do
    if [ -f "$pyfile" ]; then
        if python3 -m py_compile "$pyfile" 2>/dev/null; then
            : # Syntax OK
        else
            SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
        fi
    fi
done

if [ "$SYNTAX_ERRORS" -eq 0 ]; then
    test_result "Python syntax check" "pass"
else
    test_result "Python syntax check" "fail" "Found $SYNTAX_ERRORS files with syntax errors"
fi

# Test 35: Requirements.txt is valid
if [ -f "$EXTRACT_DIR/requirements.txt" ]; then
    if grep -q "flask" "$EXTRACT_DIR/requirements.txt" && \
       grep -q "requests" "$EXTRACT_DIR/requirements.txt"; then
        test_result "Requirements.txt validity" "pass"
    else
        test_result "Requirements.txt validity" "fail" "Missing critical dependencies"
    fi
else
    test_result "Requirements.txt validity" "fail" "requirements.txt not found"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${BLUE}Package: $(basename "$TARBALL_PATH")${NC}"
echo -e "${BLUE}Files in package: $FILE_COUNT${NC}"
echo -e "${BLUE}Tests run: $TESTS_TOTAL${NC}"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests failed: $TESTS_FAILED${NC}\n"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    echo -e "${GREEN}Package is ready for deployment!${NC}\n"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}========================================${NC}\n"
    echo -e "${YELLOW}Please review the failures above before deploying.${NC}\n"
    exit 1
fi

# Made with Bob
