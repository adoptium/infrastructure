#!/bin/bash
set -e

# Script 8: Capture VM Image to Azure Compute Gallery
# This script shows current gallery state and captures the generalized VM as a new image version
# Usage: ./8-capture-image.sh [version]
#   If version is not provided, it will auto-increment from the latest version

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

# Optional version override parameter
VERSION_OVERRIDE="$1"

echo ""
echo "=========================================="
echo "Capture VM Image to Gallery"
echo "=========================================="
echo ""
echo "VM Name: $VM_NAME"
echo "Resource Group: $AZURE_RESOURCE_GROUP"
echo "Gallery: $AZURE_GALLERY_NAME"
echo "Image Definition: $AZURE_IMAGE_DEFINITION"
echo ""

# Get gallery resource group (defaults to VM resource group if not specified)
GALLERY_RG="${AZURE_GALLERY_RESOURCE_GROUP:-$AZURE_RESOURCE_GROUP}"

echo "=========================================="
echo "Current Gallery State"
echo "=========================================="
echo ""

# Check if gallery exists
echo "Checking gallery: $AZURE_GALLERY_NAME..."
if ! az sig show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --output none 2>/dev/null; then
    echo "ERROR: Gallery '$AZURE_GALLERY_NAME' not found in resource group '$GALLERY_RG'"
    echo ""
    echo "Please create the gallery first:"
    echo "  az sig create --resource-group $GALLERY_RG --gallery-name $AZURE_GALLERY_NAME"
    exit 1
fi

echo "✓ Gallery exists"
echo ""

# Check if image definition exists
echo "Checking image definition: $AZURE_IMAGE_DEFINITION..."
if ! az sig image-definition show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --output none 2>/dev/null; then
    echo "ERROR: Image definition '$AZURE_IMAGE_DEFINITION' not found"
    echo ""
    echo "Please create the image definition first:"
    echo "  az sig image-definition create \\"
    echo "    --resource-group $GALLERY_RG \\"
    echo "    --gallery-name $AZURE_GALLERY_NAME \\"
    echo "    --gallery-image-definition $AZURE_IMAGE_DEFINITION \\"
    echo "    --publisher MicrosoftWindowsServer \\"
    echo "    --offer WindowsServer \\"
    echo "    --sku 2022-datacenter \\"
    echo "    --os-type Windows \\"
    echo "    --os-state Generalized"
    exit 1
fi

echo "✓ Image definition exists"
echo ""

# List existing versions
echo "Existing image versions:"
VERSIONS=$(az sig image-version list \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --query "[].{Version:name, State:provisioningState, Published:publishingProfile.publishedDate}" \
    --output table 2>/dev/null)

if [ -z "$VERSIONS" ] || [ "$VERSIONS" = "[]" ]; then
    echo "  No existing versions found"
    LATEST_VERSION="none"
else
    echo "$VERSIONS"
    echo ""
    LATEST_VERSION=$(az sig image-version list \
        --resource-group "$GALLERY_RG" \
        --gallery-name "$AZURE_GALLERY_NAME" \
        --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
        --query "max_by([], &name).name" \
        --output tsv 2>/dev/null)
    echo "Latest version: $LATEST_VERSION"
fi

echo ""
echo "=========================================="
echo "VM Information"
echo "=========================================="
echo ""

# Get VM details
VM_INFO=$(az vm show \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --output json)

VM_ID=$(echo "$VM_INFO" | jq -r '.id')
VM_LOCATION=$(echo "$VM_INFO" | jq -r '.location')
OS_DISK_ID=$(echo "$VM_INFO" | jq -r '.storageProfile.osDisk.managedDisk.id')
IMAGE_DEFINITION_LOCATION=$(az sig image-definition show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --query location \
    --output tsv)
LATEST_VERSION_LOCATION=$(az sig image-version show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --gallery-image-version "$LATEST_VERSION" \
    --query location \
    --output tsv 2>/dev/null || true)
LATEST_TARGET_REGION=$(az sig image-version show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --gallery-image-version "$LATEST_VERSION" \
    --query "publishingProfile.targetRegions[0].name" \
    --output tsv 2>/dev/null || true)

if [ -n "${AZURE_GALLERY_TARGET_REGION:-}" ]; then
    TARGET_REGION="$AZURE_GALLERY_TARGET_REGION"
elif [ -n "$LATEST_TARGET_REGION" ] && [ "$LATEST_TARGET_REGION" != "null" ]; then
    TARGET_REGION="$LATEST_TARGET_REGION"
else
    TARGET_REGION="$IMAGE_DEFINITION_LOCATION"
fi

echo "VM ID: $VM_ID"
echo "VM Location: $VM_LOCATION"
echo "Image Definition Location: $IMAGE_DEFINITION_LOCATION"
echo "Latest Version Location: $LATEST_VERSION_LOCATION"
echo "Latest Version Target Region: $LATEST_TARGET_REGION"
echo "Configured Gallery Target Region: ${AZURE_GALLERY_TARGET_REGION:-<not set>}"
echo "Resolved Target Region: $TARGET_REGION"
echo "OS Disk: $OS_DISK_ID"
echo ""

# Get VM power state
POWER_STATE=$(az vm get-instance-view \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
    --output tsv)

echo "Power State: $POWER_STATE"
echo ""

# Verify VM is stopped
if [[ "$POWER_STATE" != "VM stopped" && "$POWER_STATE" != "VM deallocated" ]]; then
    echo "ERROR: VM must be stopped before capture"
    echo "Current state: $POWER_STATE"
    echo ""
    echo "Please run script 7 to validate the VM is ready"
    exit 1
fi

echo "=========================================="
echo "New Image Version"
echo "=========================================="
echo ""

# Calculate new version
if [ -n "$VERSION_OVERRIDE" ]; then
    # Use provided version
    NEW_VERSION="$VERSION_OVERRIDE"
    echo "Using provided version: $NEW_VERSION"
elif [ "$LATEST_VERSION" = "none" ]; then
    # No existing versions, start with 1.0.0
    NEW_VERSION="1.0.0"
    echo "No existing versions found, starting with: $NEW_VERSION"
else
    # Auto-increment from latest version
    # Parse version (assumes format: major.minor.patch)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_VERSION"
    
    # Increment patch version
    PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    echo "Auto-incremented from $LATEST_VERSION to: $NEW_VERSION"
fi

echo ""

# Show comparison
echo "=========================================="
echo "Version Comparison"
echo "=========================================="
echo ""
echo "Current (Latest): $LATEST_VERSION"
echo "New (Proposed):   $NEW_VERSION"
echo ""

echo "=========================================="
echo "Image Capture Plan"
echo "=========================================="
echo ""
echo "The following actions will be performed:"
echo "  1. Generalize the VM (mark as generalized in Azure)"
echo "  2. Create new image version: $NEW_VERSION"
echo "  3. Replicate to region: $TARGET_REGION"
echo "  4. Set replica count: 1"
echo "  5. Leave existing gallery versions intact"
echo ""
echo "Note: Image creation takes 10-30 minutes"
echo ""

# Save the proposed version for reference
echo "$NEW_VERSION" > "$PROJECT_ROOT/.proposed-version"
echo "Proposed version saved to: $PROJECT_ROOT/.proposed-version"
echo ""

# Ensure the target version does not already exist
if az sig image-version show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --gallery-image-version "$NEW_VERSION" \
    --output none 2>/dev/null; then
    echo "ERROR: Image version '$NEW_VERSION' already exists"
    echo "Provide a different version argument or remove the conflicting version first"
    exit 1
fi

echo "Proceeding with image capture for version $NEW_VERSION..."
echo ""

echo "Generalizing VM..."
az vm generalize \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --output none

echo "✓ VM generalized"
echo ""

echo "Creating image version in Azure Compute Gallery..."
echo "This may take 10-30 minutes..."
echo ""

TARGET_REGION_CODE=$(az account list-locations \
    --query "[?displayName=='$TARGET_REGION'].name | [0]" \
    --output tsv 2>/dev/null || true)

if [ -z "$TARGET_REGION_CODE" ] || [ "$TARGET_REGION_CODE" = "null" ]; then
    TARGET_REGION_CODE=$(echo "$TARGET_REGION" | tr '[:upper:] ' '[:lower:]')
fi

if [ "$VM_LOCATION" != "$TARGET_REGION_CODE" ]; then
    echo "ERROR: Azure Compute Gallery image versions created from a VM require the source VM to be in the same region as the target region."
    echo "Source VM region: $VM_LOCATION"
    echo "Target region: $TARGET_REGION"
    echo "Target region code: $TARGET_REGION_CODE"
    echo ""
    echo "Your current VM cannot be captured directly into this gallery image version because the regions do not match."
    echo "You need one of the following:"
    echo "  1. Provision/update the VM in $TARGET_REGION and capture from there"
    echo "  2. Use/create a gallery image definition whose target region matches $VM_LOCATION"
    echo ""
    exit 1
fi

DEPLOYMENT_NAME="sig-image-version-${AZURE_IMAGE_DEFINITION}-${NEW_VERSION//./-}"
TARGET_REGIONS_JSON=$(jq -cn --arg region "$TARGET_REGION" '[{name:$region,regionalReplicaCount:1}]')

echo "Deployment Name: $DEPLOYMENT_NAME"
echo "Target Regions JSON: $TARGET_REGIONS_JSON"
echo ""

az deployment group create \
    --resource-group "$GALLERY_RG" \
    --name "$DEPLOYMENT_NAME" \
    --mode Incremental \
    --template-file /dev/stdin \
    --parameters galleryName="$AZURE_GALLERY_NAME" \
                 imageDefinitionName="$AZURE_IMAGE_DEFINITION" \
                 versionName="$NEW_VERSION" \
                 sourceVmId="$VM_ID" \
                 defaultReplicaCount=1 \
                 excludedFromLatest=false \
                 regionReplications="$TARGET_REGIONS_JSON" \
                 location="$IMAGE_DEFINITION_LOCATION" \
                 allowDeletionOfReplicatedLocations=false \
                 blockDeletionBeforeEndOfLife=false \
                 replicationMode="Full" <<'EOF'
{
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "galleryName": { "type": "string" },
    "imageDefinitionName": { "type": "string" },
    "versionName": { "type": "string" },
    "sourceVmId": { "type": "string" },
    "defaultReplicaCount": { "type": "int" },
    "excludedFromLatest": { "type": "bool" },
    "regionReplications": { "type": "array" },
    "location": { "type": "string" },
    "allowDeletionOfReplicatedLocations": { "type": "bool" },
    "blockDeletionBeforeEndOfLife": { "type": "bool" },
    "replicationMode": { "type": "string" }
  },
  "resources": [
    {
      "apiVersion": "2024-03-03",
      "type": "Microsoft.Compute/galleries/images/versions",
      "name": "[concat(parameters('galleryName'), '/', parameters('imageDefinitionName'), '/', parameters('versionName'))]",
      "location": "[parameters('location')]",
      "properties": {
        "publishingProfile": {
          "replicaCount": "[parameters('defaultReplicaCount')]",
          "targetRegions": "[parameters('regionReplications')]",
          "excludeFromLatest": "[parameters('excludedFromLatest')]",
          "replicationMode": "[parameters('replicationMode')]"
        },
        "storageProfile": {
          "source": {
            "virtualMachineId": "[parameters('sourceVmId')]"
          }
        },
        "safetyProfile": {
          "allowDeletionOfReplicatedLocations": "[parameters('allowDeletionOfReplicatedLocations')]",
          "blockDeletionBeforeEndOfLife": "[parameters('blockDeletionBeforeEndOfLife')]"
        }
      },
      "tags": {}
    }
  ],
  "outputs": {}
}
EOF

echo ""
echo "✓ Image version created successfully"
echo ""

echo "Verifying created image version..."
IMAGE_VERSION_STATE=$(az sig image-version show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --gallery-image-definition "$AZURE_IMAGE_DEFINITION" \
    --gallery-image-version "$NEW_VERSION" \
    --query "provisioningState" \
    --output tsv)

echo "Provisioning State: $IMAGE_VERSION_STATE"
echo ""

echo "=========================================="
echo "Image Capture Complete"
echo "=========================================="
echo ""
echo "Gallery: $AZURE_GALLERY_NAME"
echo "Image Definition: $AZURE_IMAGE_DEFINITION"
echo "Previous Version: $LATEST_VERSION"
echo "New Version: $NEW_VERSION"
echo "Target Region: $TARGET_REGION"
echo ""
echo "Existing versions were left intact."
echo ""

# Made with Bob
