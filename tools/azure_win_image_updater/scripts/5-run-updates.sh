#!/bin/bash
set -e

# Step 5: Run Windows Updates via Ansible
# Executes the windows-updates.yml playbook to install all available updates

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
echo -e "${CYAN}║  Step 5: Run Windows Updates          ║${NC}"
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
echo "  Playbook: ansible/playbooks/windows-updates.yml"
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

echo -e "${BLUE}Created temporary inventory${NC}"
echo ""

echo -e "${YELLOW}⚠ NOTE: Windows Updates can take 30-90 minutes${NC}"
echo -e "${YELLOW}The VM may reboot multiple times during this process${NC}"
echo ""

# Run the playbook
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Starting Windows Updates${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "  1. Search for available updates"
echo "  2. Download and install updates"
echo "  3. Reboot if required"
echo "  4. Check for additional updates"
echo ""
echo -e "${BLUE}Starting playbook execution...${NC}"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run ansible playbook with verbose output and unbuffered output
# PYTHONUNBUFFERED=1 ensures Python output is not buffered
# This is critical when output is piped through tee in wrapper scripts
if PYTHONUNBUFFERED=1 ansible-playbook \
    -i "$TEMP_INVENTORY" \
    "$PROJECT_ROOT/ansible/playbooks/windows-updates.yml" \
    -v; then
    
    PLAYBOOK_SUCCESS=true
    echo ""
    echo -e "${GREEN}✓ Playbook execution completed${NC}"
else
    PLAYBOOK_SUCCESS=false
    echo ""
    echo -e "${RED}✗ Playbook execution failed${NC}"
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Cleanup
rm -f "$TEMP_INVENTORY"

echo ""
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${CYAN}Windows Updates Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""
echo "  VM Name: $VM_NAME"
echo "  Duration: ${MINUTES}m ${SECONDS}s"
echo ""

if [ "$PLAYBOOK_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Windows Updates completed successfully${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Verify VM is accessible"
    echo "  2. Check for any additional updates (optional)"
    echo "  3. Run sysprep: ./scripts/6-run-sysprep.sh"
    echo "  4. Capture image: ./scripts/2-capture-image.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Windows Updates failed${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check if VM is still accessible"
    echo "  2. RDP to VM and check Windows Update status"
    echo "  3. Review Ansible output above for errors"
    echo "  4. Try running the playbook again"
    echo ""
    echo -e "${YELLOW}To retry:${NC}"
    echo "  ./scripts/5-run-updates.sh $VM_NAME"
    echo ""
    exit 1
fi

# Made with Bob