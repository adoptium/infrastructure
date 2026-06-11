#!/bin/bash
set -e

# Script 6: Run Sysprep via Ansible
# This script runs sysprep to generalize the Windows VM, preparing it for image capture

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
echo "Using VM: $VM_NAME"

# Get VM public IP
echo "Getting VM public IP address..."
PUBLIC_IP=$(az vm show -d \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query publicIps -o tsv)

if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not get public IP for VM $VM_NAME"
    exit 1
fi

echo "VM Public IP: $PUBLIC_IP"

# Create temporary inventory file
TEMP_INVENTORY=$(mktemp)
trap "rm -f $TEMP_INVENTORY" EXIT

cat > "$TEMP_INVENTORY" << EOF
[windows]
$PUBLIC_IP

[windows:vars]
ansible_user=$AZURE_ADMIN_USERNAME
ansible_password=$AZURE_ADMIN_PASSWORD
ansible_connection=winrm
ansible_winrm_transport=credssp
ansible_winrm_server_cert_validation=ignore
ansible_port=5986
ansible_winrm_scheme=https
EOF

echo ""
echo "=========================================="
echo "Running Sysprep via Ansible"
echo "=========================================="
echo ""
echo "WARNING: This will generalize and shutdown the VM!"
echo "After sysprep completes, the VM will be in a stopped (deallocated) state."
echo ""

# Run the sysprep playbook
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
    -i "$TEMP_INVENTORY" \
    "$PROJECT_ROOT/ansible/playbooks/run-sysprep.yml" \
    -v

PLAYBOOK_EXIT_CODE=$?

if [ $PLAYBOOK_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Sysprep Initiated Successfully"
    echo "=========================================="
    echo ""
    echo "The VM is now running sysprep and will shutdown automatically."
    echo "This process typically takes 5-10 minutes."
    echo ""
    echo "Next steps:"
    echo "1. Wait for the VM to reach 'Stopped' state (not just 'Stopping')"
    echo "2. Run script 7 to validate the VM is ready for image capture"
    echo "3. Run script 8 to capture the generalized VM to the gallery"
    echo ""
    echo "To check VM power state:"
    echo "  az vm get-instance-view --resource-group $AZURE_RESOURCE_GROUP --name $VM_NAME --query instanceView.statuses[1].displayStatus -o tsv"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "Sysprep Failed"
    echo "=========================================="
    echo ""
    echo "The sysprep playbook failed with exit code: $PLAYBOOK_EXIT_CODE"
    echo ""
    echo "Common issues:"
    echo "- VM may have already been sysprepped"
    echo "- Ansible connection may have been lost"
    echo "- Sysprep may have encountered an error"
    echo ""
    echo "Check the VM state:"
    echo "  az vm get-instance-view --resource-group $AZURE_RESOURCE_GROUP --name $VM_NAME --query instanceView.statuses[1].displayStatus -o tsv"
    echo ""
    exit 1
fi

# Made with Bob
