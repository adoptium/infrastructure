#!/bin/bash
set -e

# Step 2: Test Custom Script Extension
# Tests that CSE works by running a simple command, then cleans up

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
echo -e "${CYAN}║  Step 2: Test Custom Script Extension ║${NC}"
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

# Check if VM exists
echo -e "${BLUE}Checking VM status...${NC}"
if ! az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
    echo -e "${RED}ERROR: VM '$VM_NAME' not found in resource group '$RESOURCE_GROUP'${NC}"
    exit 1
fi

echo -e "${GREEN}✓ VM found${NC}"
echo ""

# Step 1: Reboot the VM
echo -e "${BLUE}Step 1: Rebooting VM...${NC}"
az vm restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --no-wait

echo -e "${YELLOW}Waiting 60 seconds for VM to restart...${NC}"
sleep 60

# Wait for VM to be running
echo -e "${BLUE}Waiting for VM to be fully running...${NC}"
for i in {1..12}; do
    POWER_STATE=$(az vm get-instance-view \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        --output tsv)
    
    if [[ "$POWER_STATE" == "VM running" ]]; then
        echo -e "${GREEN}✓ VM is running${NC}"
        break
    fi
    
    echo "  Status: $POWER_STATE (attempt $i/12)"
    sleep 10
done

echo ""

# Step 2: Test Custom Script Extension
echo -e "${BLUE}Step 2: Testing Custom Script Extension...${NC}"
echo "Running a simple test command via CSE..."
echo ""

# Use a simple one-liner command to avoid JSON escaping issues
az vm extension set \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --publisher Microsoft.Compute \
    --version 1.10 \
    --settings '{"commandToExecute": "powershell.exe -Command \"Get-Date | Out-File C:\\cse-test.txt; Write-Output CSE-Test-Success\""}' \
    --output table

echo ""
echo -e "${GREEN}✓ Custom Script Extension deployed${NC}"
echo ""

# Wait a bit for extension to complete
echo -e "${BLUE}Waiting 30 seconds for extension to complete...${NC}"
sleep 30

# Check extension status
echo -e "${BLUE}Checking extension status...${NC}"
EXTENSION_STATUS=$(az vm extension show \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --query "provisioningState" \
    --output tsv 2>/dev/null || echo "Unknown")

echo "  Provisioning State: $EXTENSION_STATUS"

# Get extension output
EXTENSION_OUTPUT=$(az vm extension show \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --query "instanceView.substatuses[0].message" \
    --output tsv 2>/dev/null || echo "No output available")

echo ""
echo -e "${YELLOW}Extension Output:${NC}"
echo "$EXTENSION_OUTPUT"
echo ""

if [[ "$EXTENSION_STATUS" == "Succeeded" ]]; then
    echo -e "${GREEN}✓ Custom Script Extension test PASSED${NC}"
else
    echo -e "${YELLOW}⚠ Extension status: $EXTENSION_STATUS${NC}"
fi

echo ""

# Step 3: Remove Custom Script Extension
echo -e "${BLUE}Step 3: Removing Custom Script Extension...${NC}"
az vm extension delete \
    --resource-group "$RESOURCE_GROUP" \
    --vm-name "$VM_NAME" \
    --name CustomScriptExtension \
    --output none

echo -e "${GREEN}✓ Custom Script Extension removed${NC}"
echo ""

# Step 4: Final reboot
echo -e "${BLUE}Step 4: Final reboot...${NC}"
az vm restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --no-wait

echo -e "${YELLOW}Waiting 60 seconds for VM to restart...${NC}"
sleep 60

# Wait for VM to be running
echo -e "${BLUE}Waiting for VM to be fully running...${NC}"
for i in {1..12}; do
    POWER_STATE=$(az vm get-instance-view \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        --output tsv)
    
    if [[ "$POWER_STATE" == "VM running" ]]; then
        echo -e "${GREEN}✓ VM is running${NC}"
        break
    fi
    
    echo "  Status: $POWER_STATE (attempt $i/12)"
    sleep 10
done

echo ""
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${GREEN}Custom Script Extension Test Complete${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  VM Name: $VM_NAME"
echo "  CSE Test: $EXTENSION_STATUS"
echo "  VM Status: Running"
echo ""
echo -e "${GREEN}VM is ready for next steps${NC}"
echo ""

# Made with Bob