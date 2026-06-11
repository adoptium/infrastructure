# Quick Start Guide

Get up and running with Azure Windows Image Updater in 10 minutes.

## Prerequisites

- Ubuntu/Debian Linux system
- Azure subscription with permissions to create resources
- Azure Compute Gallery with image definitions already created

## 1. Install System Packages (5 minutes)

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
sudo ./setup-ubuntu-node.sh
```

This installs:
- Azure CLI
- Ansible
- Python packages (pywinrm, requests)
- jq, yq utilities

## 2. Configure Credentials (2 minutes)

```bash
# Copy template
cp .env.template .env

# Edit with your credentials
nano .env
```

**Required values:**
```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_RESOURCE_GROUP="your-resource-group"
export AZURE_GALLERY_NAME="your-gallery-name"
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
export AZURE_IMAGE_MULTIPLE="Test-Windows-2022-x64,Test-Windows-2025-x64,Test-Windows-11-x64"
export AZURE_ADMIN_PASSWORD="YourSecurePassword123!"
```

## 3. Verify Setup (1 minute)

```bash
source .env
./scripts/0-check-prerequisites.sh
```

Should show: ✓ All Prerequisites Met

## 4. Run Your First Update (40-70 minutes)

### Single Image

```bash
source .env
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
./scripts/test-full-workflow.sh
```

### Multiple Images

```bash
source .env
./scripts/test-full-all-images.sh
```

## What Happens?

1. ✅ Creates temporary VM from your gallery image
2. ✅ Configures WinRM for remote management
3. ✅ Installs all Windows Updates via Ansible
4. ✅ Runs Sysprep to generalize the VM
5. ✅ Captures new image version to gallery
6. ✅ Cleans up all temporary resources

## Next Steps

- **Automation**: See [JENKINS_INTEGRATION.md](JENKINS_INTEGRATION.md)
- **Multiple Images**: See [MULTI_IMAGE_TESTING.md](MULTI_IMAGE_TESTING.md)
- **Details**: See [README.md](README.md)

## Troubleshooting

### "Azure CLI not authenticated"

```bash
az login --service-principal \
    -u $AZURE_CLIENT_ID \
    -p $AZURE_CLIENT_SECRET \
    --tenant $AZURE_TENANT_ID
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

### "Image definition not found"

Create it first:

```bash
az sig image-definition create \
    --resource-group your-resource-group \
    --gallery-name your-gallery-name \
    --gallery-image-definition Test-Windows-2022-x64 \
    --publisher MicrosoftWindowsServer \
    --offer WindowsServer \
    --sku 2022-datacenter \
    --os-type Windows \
    --os-state Generalized
```

### "Prerequisites check failed"

Install missing packages:

```bash
sudo apt-get update
sudo apt-get install -y azure-cli jq python3 python3-pip ansible
pip3 install pywinrm requests requests-ntlm requests-credssp
```

## Support

- Check logs in `logs/` directory
- Review [README.md](README.md) for detailed documentation
- See [AUTOMATED_WORKFLOW.md](AUTOMATED_WORKFLOW.md) for automation details

---

**Made with Bob** 🤖