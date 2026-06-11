#!/bin/bash
set -e

# Step 1: Provision VM from Image
# Simple script to create a VM from a gallery image for manual Windows updates

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    echo "Please create it from .env.template"
    exit 1
fi

source "$PROJECT_ROOT/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Step 1: Provision VM from Image      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Configuration
# Windows computer name limit is 15 characters
# Format: upd-MMDD-HHMM (13 chars, leaves room for variations)
TIMESTAMP=$(date +%m%d-%H%M)
VM_NAME="upd-${TIMESTAMP}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
LOCATION="${AZURE_LOCATION}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_D4s_v3}"
ADMIN_USERNAME="${AZURE_ADMIN_USERNAME}"
ADMIN_PASSWORD="${AZURE_ADMIN_PASSWORD}"

# Auto-discover latest image version from gallery
echo -e "${BLUE}Querying gallery for latest image version...${NC}"
GALLERY_RG="${AZURE_GALLERY_RESOURCE_GROUP:-$RESOURCE_GROUP}"
LATEST_VERSION=$(az sig image-version list \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --query "sort_by(@, &publishingProfile.publishedDate)[-1].name" \
    --output tsv)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}ERROR: Could not find any versions for image: $AZURE_IMAGE_DEFINITION${NC}"
    echo "Gallery: $AZURE_GALLERY_NAME"
    echo "Resource Group: $GALLERY_RG"
    exit 1
fi

IMAGE="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${GALLERY_RG}/providers/Microsoft.Compute/galleries/${AZURE_GALLERY_NAME}/images/${AZURE_IMAGE_DEFINITION}/versions/${LATEST_VERSION}"

echo -e "${GREEN}✓ Found latest version: $LATEST_VERSION${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo "  VM Name: $VM_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  VM Size: $VM_SIZE"
echo "  Gallery: $AZURE_GALLERY_NAME"
echo "  Image Definition: $AZURE_IMAGE_DEFINITION"
echo "  Image Version: $LATEST_VERSION"
echo "  Full Image ID: $IMAGE"
echo "  Admin User: $ADMIN_USERNAME"
echo ""

# Create Network Security Group
echo -e "${BLUE}Creating Network Security Group...${NC}"
NSG_NAME="${VM_NAME}-nsg"

az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --location "$LOCATION" \
    --output none

echo -e "${GREEN}✓ NSG created${NC}"

# Add RDP rule (Priority 300)
echo -e "${BLUE}Adding RDP rule to NSG...${NC}"
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name RDP \
    --priority 300 \
    --source-address-prefixes '*' \
    --destination-port-ranges 3389 \
    --protocol Tcp \
    --access Allow \
    --direction Inbound \
    --output none

echo -e "${GREEN}✓ RDP rule added${NC}"

# Add WinRM HTTPS rule (Priority 310)
echo -e "${BLUE}Adding WinRM HTTPS rule to NSG...${NC}"
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name WinRMInbound \
    --priority 310 \
    --source-address-prefixes '*' \
    --destination-port-ranges 5986 \
    --protocol Tcp \
    --access Allow \
    --direction Inbound \
    --output none

echo -e "${GREEN}✓ WinRM rule added${NC}"

# Add Nagios NSClient rule (Priority 320)
echo -e "${BLUE}Adding Nagios NSClient rule to NSG...${NC}"
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name Nagios-NSClient-Allow12489 \
    --priority 320 \
    --source-address-prefixes '*' \
    --destination-port-ranges 12489 \
    --protocol Tcp \
    --access Allow \
    --direction Inbound \
    --output none

echo -e "${GREEN}✓ Nagios rule added${NC}"

# Add SSH rule (Priority 330)
echo -e "${BLUE}Adding SSH rule to NSG...${NC}"
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name SSH \
    --priority 330 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow \
    --direction Inbound \
    --output none

echo -e "${GREEN}✓ SSH rule added${NC}"

# Create VM with the NSG
echo ""
echo -e "${BLUE}Creating VM with configured NSG...${NC}"

IMAGE_ACCELERATED_NETWORKING=$(az sig image-definition show \
    --resource-group "${AZURE_GALLERY_RESOURCE_GROUP:-$RESOURCE_GROUP}" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --query "features[?name=='IsAcceleratedNetworkSupported'].value | [0]" \
    --output tsv 2>/dev/null || true)

if [ "$IMAGE_ACCELERATED_NETWORKING" = "True" ]; then
    echo -e "${BLUE}Image definition requires accelerated networking - enabling it on the VM NIC${NC}"
    ACCELERATED_NETWORKING_ARG="--accelerated-networking true"
else
    ACCELERATED_NETWORKING_ARG=""
fi

az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --location "$LOCATION" \
    --nsg "$NSG_NAME" \
    --public-ip-sku Standard \
    --security-type TrustedLaunch \
    $ACCELERATED_NETWORKING_ARG --output table

echo ""
echo -e "${GREEN}✓ VM Created Successfully${NC}"
echo ""

# Get VM details
VM_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${GREEN}VM Provisioned Successfully${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}VM Details:${NC}"
echo "  Name: $VM_NAME"
echo "  IP Address: $VM_IP"
echo "  Username: $ADMIN_USERNAME"
echo "  Password: [from .env]"
echo ""

# Save VM name for next step
echo "$VM_NAME" > "$PROJECT_ROOT/.last-vm-name"
echo -e "${BLUE}VM name saved to .last-vm-name${NC}"
echo ""

# Made with Bob
