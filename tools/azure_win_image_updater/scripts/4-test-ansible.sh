#!/bin/bash
set -e

# Step 4: Test Ansible Connectivity
# Tests that Ansible can connect to the Windows VM via WinRM

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

source "$PROJECT_ROOT/.env"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Step 4: Test Ansible Connectivity    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Get VM name from argument or .last-vm-name file
if [ -n "$1" ]; then
    VM_NAME="$1"
elif [ -f "$PROJECT_ROOT/.last-vm-name" ]; then
    VM_NAME=$(cat "$PROJECT_ROOT/.last-vm-name")
    echo -e "${BLUE}Using VM from .last-vm-name: $VM_NAME${NC}"
else
    echo -e "${RED}ERROR: No VM name provided${NC}"
    echo "Usage: $0 <vm-name>"
    echo "   or: Run after 1-provision-vm.sh (saves VM name automatically)"
    exit 1
fi

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
ADMIN_USERNAME="${AZURE_ADMIN_USERNAME}"
ADMIN_PASSWORD="${AZURE_ADMIN_PASSWORD}"

# Get VM IP
echo -e "${BLUE}Getting VM IP address...${NC}"
VM_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

if [ -z "$VM_IP" ]; then
    echo -e "${RED}ERROR: Could not get VM IP address${NC}"
    exit 1
fi

echo -e "${GREEN}✓ VM IP: $VM_IP${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo "  VM Name: $VM_NAME"
echo "  VM IP: $VM_IP"
echo "  Username: $ADMIN_USERNAME"
echo "  WinRM Port: 5986 (HTTPS)"
echo "  Transport: CredSSP"
echo ""

# Create temporary inventory file
TEMP_INVENTORY=$(mktemp)
cat > "$TEMP_INVENTORY" << EOF
[windows]
$VM_IP

[windows:vars]
ansible_user=$ADMIN_USERNAME
ansible_password=$ADMIN_PASSWORD
ansible_connection=winrm
ansible_winrm_transport=credssp
ansible_winrm_server_cert_validation=ignore
ansible_port=5986
EOF

echo -e "${BLUE}Created temporary inventory file${NC}"
echo ""

# Test 1: Ping test
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Test 1: Ansible Ping${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""

if ansible windows -i "$TEMP_INVENTORY" -m win_ping; then
    echo ""
    echo -e "${GREEN}✓ Ping test PASSED${NC}"
    PING_SUCCESS=true
else
    echo ""
    echo -e "${RED}✗ Ping test FAILED${NC}"
    PING_SUCCESS=false
fi

echo ""

# Test 2: Gather facts
if [ "$PING_SUCCESS" = true ]; then
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}Test 2: Gather Windows Facts${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    if ansible windows -i "$TEMP_INVENTORY" -m setup -a "filter=ansible_os_family,ansible_distribution,ansible_distribution_version,ansible_hostname"; then
        echo ""
        echo -e "${GREEN}✓ Facts gathering PASSED${NC}"
        FACTS_SUCCESS=true
    else
        echo ""
        echo -e "${RED}✗ Facts gathering FAILED${NC}"
        FACTS_SUCCESS=false
    fi
    echo ""
fi

# Test 3: Run simple command
if [ "$PING_SUCCESS" = true ]; then
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}Test 3: Execute PowerShell Command${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    
    if ansible windows -i "$TEMP_INVENTORY" -m win_shell -a "Get-Date; Write-Output 'Ansible test successful'"; then
        echo ""
        echo -e "${GREEN}✓ Command execution PASSED${NC}"
        COMMAND_SUCCESS=true
    else
        echo ""
        echo -e "${RED}✗ Command execution FAILED${NC}"
        COMMAND_SUCCESS=false
    fi
    echo ""
fi

# Cleanup
rm -f "$TEMP_INVENTORY"

# Summary
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Test Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""

if [ "$PING_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Ansible Ping: PASSED${NC}"
else
    echo -e "${RED}✗ Ansible Ping: FAILED${NC}"
fi

if [ "$FACTS_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Facts Gathering: PASSED${NC}"
elif [ "$PING_SUCCESS" = true ]; then
    echo -e "${RED}✗ Facts Gathering: FAILED${NC}"
else
    echo -e "${YELLOW}⊘ Facts Gathering: SKIPPED${NC}"
fi

if [ "$COMMAND_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Command Execution: PASSED${NC}"
elif [ "$PING_SUCCESS" = true ]; then
    echo -e "${RED}✗ Command Execution: FAILED${NC}"
else
    echo -e "${YELLOW}⊘ Command Execution: SKIPPED${NC}"
fi

echo ""

if [ "$PING_SUCCESS" = true ] && [ "$FACTS_SUCCESS" = true ] && [ "$COMMAND_SUCCESS" = true ]; then
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}All Tests PASSED${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Ansible is successfully configured!${NC}"
    echo -e "${BLUE}Next step: Run ./scripts/5-run-updates.sh${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}Some Tests FAILED${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Verify WinRM is configured: ./scripts/3-configure-winrm.sh"
    echo "  2. Check NSG allows port 5986"
    echo "  3. Verify credentials in .env file"
    echo "  4. Check VM firewall allows WinRM"
    echo "  5. RDP to VM and check C:\\winrm-config.log"
    echo ""
    echo -e "${YELLOW}Test connection manually:${NC}"
    echo "  ansible windows -i <inventory> -m win_ping"
    echo ""
    exit 1
fi

# Made with Bob