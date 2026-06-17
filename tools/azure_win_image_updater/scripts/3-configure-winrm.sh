#!/bin/bash
set -e

# Step 3: Configure WinRM for Ansible
# Downloads and runs Ansible's ConfigureRemotingForAnsible.ps1 script via CSE

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
echo -e "${CYAN}║  Step 3: Configure WinRM for Ansible  ║${NC}"
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

echo -e "${BLUE}Configuration:${NC}"
echo "  VM Name: $VM_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo ""

# Check if VM exists and is running
echo -e "${BLUE}Checking VM status...${NC}"
if ! az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
    echo -e "${RED}ERROR: VM '$VM_NAME' not found in resource group '$RESOURCE_GROUP'${NC}"
    exit 1
fi

POWER_STATE=$(az vm get-instance-view \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
    --output tsv)

echo "  Power State: $POWER_STATE"

if [[ "$POWER_STATE" != "VM running" ]]; then
    echo -e "${YELLOW}VM is not running. Starting VM...${NC}"
    az vm start \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --no-wait
    
    echo "Waiting for VM to start..."
    sleep 30
fi

echo -e "${GREEN}✓ VM is ready${NC}"
echo ""

# Remove any existing Custom Script Extension
echo -e "${BLUE}Checking for existing Custom Script Extension...${NC}"
if az vm extension show \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension &>/dev/null; then
    
    echo -e "${YELLOW}Removing existing Custom Script Extension...${NC}"
    az vm extension delete \
        --resource-group "$RESOURCE_GROUP" \
        --vm-name "$VM_NAME" \
        --name CustomScriptExtension \
        --output none
    
    echo "Waiting 10 seconds..."
    sleep 10
    echo -e "${GREEN}✓ Existing extension removed${NC}"
fi

echo ""

# Deploy WinRM configuration using VM Run Command
echo -e "${BLUE}Deploying WinRM configuration using VM Run Command...${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "  1. Download Ansible's ConfigureRemotingForAnsible.ps1"
echo "  2. Run with parameters:"
echo "     - CertValidityDays: 9999"
echo "     - EnableCredSSP: Yes"
echo "     - ForceNewSSLCert: Yes"
echo "     - SkipNetworkProfileCheck: Yes"
echo "  3. Configure WinRM HTTPS listener"
echo "  4. Configure firewall rules"
echo "  5. Log all output to C:\winrm-config.log"
echo ""

# Read the PowerShell script
PS_SCRIPT=$(cat "$SCRIPT_DIR/configure-winrm.ps1")

# Use VM Run Command (avoids JSON escaping issues)
echo -e "${BLUE}Executing WinRM configuration...${NC}"
echo "This may take 2-3 minutes..."
echo ""

set +e
RUN_COMMAND_OUTPUT=$(az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts "$PS_SCRIPT" \
    --output json 2>&1)

RUN_COMMAND_STATUS=$?
set -e

echo ""

# Parse and display output
if [ $RUN_COMMAND_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ WinRM configuration command executed${NC}"
    echo ""
    
    # Extract stdout and stderr
    STDOUT=$(echo "$RUN_COMMAND_OUTPUT" | jq -r '.value[0].message' 2>/dev/null || echo "")
    
    if [ -n "$STDOUT" ]; then
        echo -e "${BLUE}Command Output:${NC}"
        echo "$STDOUT"
        echo ""
    fi
    
    # Check if configuration was successful
    if echo "$STDOUT" | grep -q "SUCCESS: WinRM configured for Ansible"; then
        EXTENSION_STATUS="Succeeded"
    else
        EXTENSION_STATUS="Failed"
    fi
else
    echo -e "${RED}✗ WinRM configuration command failed${NC}"
    echo ""
    echo -e "${YELLOW}Error Output:${NC}"
    echo "$RUN_COMMAND_OUTPUT"
    echo ""
    EXTENSION_STATUS="Failed"
fi

# Check final status
if [[ "$EXTENSION_STATUS" == "Succeeded" ]]; then
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}WinRM Configuration Complete${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo "  VM Name: $VM_NAME"
    echo "  WinRM HTTPS: Enabled (port 5986)"
    echo "  CredSSP: Enabled"
    echo "  Certificate Validity: 9999 days"
    echo "  Log File: C:\\winrm-config.log (on VM)"
    echo ""
    echo -e "${GREEN}VM is ready for Ansible connectivity testing${NC}"
    echo -e "${BLUE}Next step: Run ./scripts/4-test-ansible.sh${NC}"
    echo ""
else
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${RED}WinRM Configuration Failed${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check extension output above for errors"
    echo "  2. RDP to VM and check C:\\winrm-config.log"
    echo "  3. Verify internet connectivity from VM"
    echo "  4. Try running script again"
    echo ""
    exit 1
fi

# Made with Bob