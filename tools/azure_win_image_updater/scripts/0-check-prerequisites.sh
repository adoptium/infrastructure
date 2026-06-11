#!/bin/bash
#
# Step 0: Check Prerequisites
# Validates that all required tools and configurations are present
# Run this before any other scripts to ensure environment is ready
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Track overall status
ALL_CHECKS_PASSED=true

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Step 0: Prerequisites Check          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    echo -n "Checking for $name... "
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ Found${NC}"
        echo "  Version: $version"
    else
        echo -e "${RED}✗ Not found${NC}"
        echo -e "  ${YELLOW}Install hint: $install_hint${NC}"
        ALL_CHECKS_PASSED=false
    fi
    echo ""
}

# Function to check Python package
check_python_package() {
    local package=$1
    local name=$2
    local install_hint=$3
    
    echo -n "Checking for Python package $name... "
    if python3 -c "import $package" &> /dev/null; then
        echo -e "${GREEN}✓ Found${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
        echo -e "  ${YELLOW}Install hint: $install_hint${NC}"
        ALL_CHECKS_PASSED=false
    fi
    echo ""
}

# Function to check file exists
check_file() {
    local file=$1
    local name=$2
    local hint=$3
    
    echo -n "Checking for $name... "
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ Found${NC}"
        echo "  Path: $file"
    else
        echo -e "${RED}✗ Not found${NC}"
        echo -e "  ${YELLOW}$hint${NC}"
        ALL_CHECKS_PASSED=false
    fi
    echo ""
}

echo -e "${BLUE}=== System Tools ===${NC}"
echo ""

# Check Azure CLI
check_command "az" "Azure CLI" "Install: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"

# Check jq
check_command "jq" "jq (JSON processor)" "Install: sudo apt-get install jq"

# Check Python 3
check_command "python3" "Python 3" "Install: sudo apt-get install python3"

# Check pip3
check_command "pip3" "pip3 (Python package manager)" "Install: sudo apt-get install python3-pip"

echo -e "${BLUE}=== Ansible ===${NC}"
echo ""

# Check Ansible
check_command "ansible" "Ansible" "Install: sudo apt-get install ansible OR pip3 install ansible"

# Check ansible-playbook
check_command "ansible-playbook" "ansible-playbook" "Install: sudo apt-get install ansible OR pip3 install ansible"

echo -e "${BLUE}=== Python Packages for Ansible Windows ===${NC}"
echo ""

# Check pywinrm
check_python_package "winrm" "pywinrm" "Install: pip3 install pywinrm"

# Check requests
check_python_package "requests" "requests" "Install: pip3 install requests"

# Check requests-ntlm (for NTLM auth)
check_python_package "requests_ntlm" "requests-ntlm" "Install: pip3 install requests-ntlm"

# Check requests-credssp (for CredSSP auth)
check_python_package "requests_credssp" "requests-credssp" "Install: pip3 install requests-credssp"

echo -e "${BLUE}=== Configuration Files ===${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check .env file
check_file "$PROJECT_ROOT/.env" ".env configuration file" "Create from template: cp .env.template .env && nano .env"

# Check if .env has been configured (not just template values)
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -n "Checking if .env is configured... "
    if grep -q "your-subscription-id" "$PROJECT_ROOT/.env" 2>/dev/null; then
        echo -e "${RED}✗ Still contains template values${NC}"
        echo -e "  ${YELLOW}Edit .env and replace placeholder values with your Azure credentials${NC}"
        ALL_CHECKS_PASSED=false
    else
        echo -e "${GREEN}✓ Appears configured${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}=== Azure CLI Authentication ===${NC}"
echo ""

# Check if logged into Azure
echo -n "Checking Azure CLI authentication... "
if az account show &> /dev/null; then
    echo -e "${GREEN}✓ Authenticated${NC}"
    ACCOUNT_NAME=$(az account show --query name -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    echo "  Account: $ACCOUNT_NAME"
    echo "  Subscription: $SUBSCRIPTION_ID"
else
    echo -e "${RED}✗ Not authenticated${NC}"
    echo -e "  ${YELLOW}Login with: az login${NC}"
    echo -e "  ${YELLOW}Or for service principal: az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID${NC}"
    ALL_CHECKS_PASSED=false
fi
echo ""

# Summary
echo -e "${CYAN}════════════════════════════════════════${NC}"
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All Prerequisites Met${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}You're ready to run the provisioning scripts!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./scripts/1-provision-vm.sh"
    echo "  2. Then: ./scripts/3-configure-winrm.sh (after it's created)"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some Prerequisites Missing${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Please install missing components and run this check again.${NC}"
    echo ""
    echo "Quick install commands for Ubuntu/Debian:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y azure-cli jq python3 python3-pip ansible"
    echo "  pip3 install pywinrm requests requests-ntlm requests-credssp"
    echo ""
    exit 1
fi

# Made with Bob