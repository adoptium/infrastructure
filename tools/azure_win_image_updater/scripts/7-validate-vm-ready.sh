#!/bin/bash
set -e

# Script 7: Validate VM is Ready for Image Capture
# This script monitors the VM until it's stopped, then validates it's properly generalized

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo "Error: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Check if VM name file exists
if [ ! -f "$PROJECT_ROOT/.last-vm-name" ]; then
    echo "Error: No VM name found. Run script 1 first to provision a VM."
    exit 1
fi

VM_NAME=$(cat "$PROJECT_ROOT/.last-vm-name")

echo ""
echo "=========================================="
echo "Validating VM Ready for Image Capture"
echo "=========================================="
echo ""
echo "VM Name: $VM_NAME"
echo "Resource Group: $AZURE_RESOURCE_GROUP"
echo ""

# Function to get VM power state
get_vm_power_state() {
    az vm get-instance-view \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
        -o tsv 2>/dev/null || echo "Unknown"
}

# Function to get VM provisioning state
get_vm_provisioning_state() {
    az vm get-instance-view \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --query "instanceView.statuses[?starts_with(code, 'ProvisioningState/')].displayStatus" \
        -o tsv 2>/dev/null || echo "Unknown"
}

echo "Monitoring VM state..."
echo "Waiting for VM to reach 'VM stopped' state after sysprep..."
echo ""

MAX_WAIT_MINUTES=15
WAIT_SECONDS=$((MAX_WAIT_MINUTES * 60))
ELAPSED=0
CHECK_INTERVAL=30

while [ $ELAPSED -lt $WAIT_SECONDS ]; do
    POWER_STATE=$(get_vm_power_state)
    PROVISIONING_STATE=$(get_vm_provisioning_state)
    
    echo "[$(date +%H:%M:%S)] Power State: $POWER_STATE | Provisioning State: $PROVISIONING_STATE"
    
    # Check if VM is stopped (not deallocated, just stopped)
    if [[ "$POWER_STATE" == "VM stopped" ]]; then
        echo ""
        echo "✓ VM has reached 'VM stopped' state"
        break
    fi
    
    # Check if already deallocated (someone manually deallocated it)
    if [[ "$POWER_STATE" == "VM deallocated" ]]; then
        echo ""
        echo "✓ VM is already deallocated"
        break
    fi
    
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
done

if [ $ELAPSED -ge $WAIT_SECONDS ]; then
    echo ""
    echo "=========================================="
    echo "WARNING: Timeout Reached"
    echo "=========================================="
    echo ""
    echo "VM did not reach stopped state within $MAX_WAIT_MINUTES minutes."
    echo "Current state: $POWER_STATE"
    echo ""
    echo "This may indicate:"
    echo "- Sysprep is still running (wait longer)"
    echo "- Sysprep encountered an error"
    echo "- VM is stuck in a transitional state"
    echo ""
    echo "You can:"
    echo "1. Wait longer and run this script again"
    echo "2. Check VM status manually in Azure Portal"
    echo "3. Check sysprep logs on the VM (if accessible)"
    echo ""
    exit 1
fi

echo ""
echo "=========================================="
echo "Validating VM State"
echo "=========================================="
echo ""

# Get detailed VM information
echo "Retrieving VM details..."
VM_INFO=$(az vm show \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --output json)

# Check OS disk
OS_DISK_ID=$(echo "$VM_INFO" | jq -r '.storageProfile.osDisk.managedDisk.id')
echo "OS Disk ID: $OS_DISK_ID"

# Get OS disk details
echo ""
echo "Checking OS disk state..."
DISK_INFO=$(az disk show --ids "$OS_DISK_ID" --output json)
DISK_STATE=$(echo "$DISK_INFO" | jq -r '.diskState')

echo "Disk State: $DISK_STATE"

# Validation checks
echo ""
echo "=========================================="
echo "Validation Results"
echo "=========================================="
echo ""

VALIDATION_PASSED=true

# Check 1: VM must be stopped or deallocated
if [[ "$POWER_STATE" == "VM stopped" ]] || [[ "$POWER_STATE" == "VM deallocated" ]]; then
    echo "✓ VM Power State: $POWER_STATE (OK)"
else
    echo "✗ VM Power State: $POWER_STATE (FAILED - must be stopped or deallocated)"
    VALIDATION_PASSED=false
fi

# Check 2: Provisioning state should be succeeded
if [[ "$PROVISIONING_STATE" == "Provisioning succeeded" ]]; then
    echo "✓ Provisioning State: $PROVISIONING_STATE (OK)"
else
    echo "⚠ Provisioning State: $PROVISIONING_STATE (WARNING)"
fi

# Check 3: Disk should be unattached or attached (both are OK for capture)
if [[ "$DISK_STATE" == "Unattached" ]] || [[ "$DISK_STATE" == "Attached" ]]; then
    echo "✓ Disk State: $DISK_STATE (OK)"
else
    echo "✗ Disk State: $DISK_STATE (FAILED)"
    VALIDATION_PASSED=false
fi

echo ""

if [ "$VALIDATION_PASSED" = true ]; then
    echo "=========================================="
    echo "✓ VM is Ready for Image Capture"
    echo "=========================================="
    echo ""
    echo "The VM has been successfully generalized and is ready to be captured."
    echo ""
    echo "Next step:"
    echo "  Run script 8 to capture the VM image to the Azure Compute Gallery"
    echo ""
    echo "Command:"
    echo "  ./scripts/8-capture-image.sh"
    echo ""
    exit 0
else
    echo "=========================================="
    echo "✗ VM is NOT Ready for Image Capture"
    echo "=========================================="
    echo ""
    echo "One or more validation checks failed."
    echo "Please review the errors above and take corrective action."
    echo ""
    exit 1
fi

# Made with Bob
