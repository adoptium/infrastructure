# Azure Windows Image Updater

Automated workflow for updating Windows gallery images in Azure Compute Gallery with the latest Windows updates using Ansible.

## 🎯 Overview

This tool automates the complete process of updating Windows images:

1. **Provision** - Creates temporary VM from gallery image
2. **Configure** - Sets up WinRM for Ansible connectivity
3. **Update** - Installs Windows Updates via Ansible
4. **Generalize** - Runs Sysprep to prepare for imaging
5. **Capture** - Creates new versioned image in gallery
6. **Cleanup** - Removes all temporary resources

## 🚀 Quick Start

### Prerequisites

- Ubuntu/Debian Linux system
- Azure CLI installed
- Ansible with WinRM support
- Azure Service Principal with appropriate permissions
- Azure Compute Gallery with image definitions

### Installation

1. **Install system packages** (as root):
   ```bash
   sudo ./setup-ubuntu-node.sh
   ```

2. **Create dedicated user** (optional, for Jenkins):
   ```bash
   sudo ./setup-dedicated-user.sh
   ```

3. **Configure environment**:
   ```bash
   cp .env.template .env
   nano .env  # Add your Azure credentials
   ```

4. **Test prerequisites**:
   ```bash
   source .env
   ./scripts/0-check-prerequisites.sh
   ```

## 📋 Supported Images

Configure images in `.env`:

```bash
# Single image for test-full-workflow.sh
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"

# Multiple images for test-full-all-images.sh (comma-separated)
export AZURE_IMAGE_MULTIPLE="Test-Windows-2022-x64,Test-Windows-2025-x64,Test-Windows-11-x64"
```

## 🔧 Usage

### Single Image (Automated)

Process one image with full automation:

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
./scripts/test-full-workflow.sh
```

**Features:**
- ✅ No user prompts
- ✅ Automatic version increment
- ✅ Automatic cleanup on exit
- ✅ Complete in 40-70 minutes

### Multiple Images (Fully Automated)

Process all images from `AZURE_IMAGE_MULTIPLE`:

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env
./scripts/test-full-all-images.sh
```

**Features:**
- ✅ Processes all images sequentially
- ✅ No user prompts
- ✅ Continues on failure
- ✅ Individual log files per image
- ✅ Summary report at completion
- ✅ Complete in 2-3.5 hours for 3 images

### Multiple Images (Interactive)

Process images with prompts for control:

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env
./scripts/run-all-images.sh
```

**Features:**
- ⚠️ Prompts before starting
- ⚠️ Prompts after failures
- ✅ Uses `AZURE_IMAGE_DEFINITION` variable
- ✅ Good for testing/debugging

## 📁 Project Structure

```
azure-image-updater/
├── .env                          # Azure credentials (not in git)
├── .env.template                 # Template for credentials
├── .gitignore                    # Git ignore rules
├── README.md                     # This file
├── AUTOMATED_WORKFLOW.md         # Automation details
├── MULTI_IMAGE_TESTING.md        # Multi-image guide
├── JENKINS_INTEGRATION.md        # Jenkins setup guide
├── setup-ubuntu-node.sh          # System package installer
├── setup-dedicated-user.sh       # User creation script
├── complete-setup.sh             # User-level setup
├── scripts/
│   ├── 0-check-prerequisites.sh  # Validate environment
│   ├── 1-provision-vm.sh         # Create VM from image
│   ├── 2-test-custom-script-extension.sh
│   ├── 3-configure-winrm.sh      # Enable WinRM
│   ├── 4-test-ansible.sh         # Test connectivity
│   ├── 5-run-updates.sh          # Install Windows updates
│   ├── 6-run-sysprep.sh          # Generalize VM
│   ├── 7-validate-vm-ready.sh    # Verify VM stopped
│   ├── 8-capture-image.sh        # Create new version
│   ├── test-full-workflow.sh     # Single image automation
│   ├── test-full-all-images.sh   # Multi-image automation
│   ├── run-all-images.sh         # Multi-image interactive
│   └── cleanup-all-test-resources.sh
├── ansible/
│   └── playbooks/                # Ansible playbooks
│       ├── windows-updates.yml   # Windows Update playbook
│       └── run-sysprep.yml       # Sysprep playbook
└── logs/                         # Execution logs (not in git)
```

## 🔐 Security

### Credentials Management

- **Never commit `.env` file** - Contains sensitive credentials
- Store Azure credentials in Jenkins for CI/CD
- Use Azure Key Vault for production secrets
- Rotate service principal credentials regularly

### Network Security

- NSG rules created for RDP (3389), WinRM (5986), Nagios (12489)
- Temporary VMs are deleted after image capture
- Consider using Azure Bastion for enhanced security

### Access Control

- Dedicated user (`azureupdater`) with SSH key authentication only
- Service principal with least-privilege permissions
- Jenkins RBAC for build triggers

## 📊 Workflow Steps

### Automated Workflow (test-full-workflow.sh)

1. **Prerequisites Check** - Validates all required tools and configurations
2. **Provision VM** - Creates temporary VM with NSG and networking
3. **Test Custom Script Extension** - Validates Azure extensions
4. **Configure WinRM** - Enables WinRM over HTTPS for Ansible
5. **Test Ansible** - Verifies Ansible connectivity via WinRM
6. **Run Windows Updates** - Installs all available updates via Ansible
7. **Prepare for Jenkins** - Installs Java 8, Java 21, and OpenSSH Server
8. **Run Sysprep** - Generalizes the VM for imaging
9. **Validate VM Ready** - Confirms VM is stopped/deallocated
10. **Capture Image** - Creates new versioned image in gallery
11. **Cleanup** - Removes all temporary resources (automatic)

### Multi-Image Workflow (test-full-all-images.sh)

- Validates all images exist in gallery
- Processes each image using test-full-workflow.sh
- Creates separate log files per image
- Continues processing even if one image fails
- Provides comprehensive summary report

## 📝 Configuration

### Environment Variables (.env)

```bash
# Azure Service Principal Credentials
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"

# Azure Resources
export AZURE_RESOURCE_GROUP="adoptopenjdk"
export AZURE_LOCATION="uksouth"
export AZURE_VNET_NAME="adoptopenjdkvnet803"
export AZURE_SUBNET_NAME="default"

# Gallery Configuration
export AZURE_GALLERY_NAME="adoptium_compute_gallery"
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
export AZURE_IMAGE_MULTIPLE="Test-Windows-2022-x64,Test-Windows-2025-x64,Test-Windows-11-x64"

# VM Configuration
export AZURE_VM_SIZE="Standard_D2s_v3"
export AZURE_ADMIN_USERNAME="adoptopenjdk"
export AZURE_ADMIN_PASSWORD="your-secure-password"
```

### Adding New Images

1. **Create image definition in Azure**:
   ```bash
   az sig image-definition create \
       --resource-group adoptopenjdk \
       --gallery-name adoptium_compute_gallery \
       --gallery-image-definition Test-Windows-2019-x64 \
       --publisher MicrosoftWindowsServer \
       --offer WindowsServer \
       --sku 2019-datacenter \
       --os-type Windows \
       --os-state Generalized
   ```

2. **Add to .env file**:
   ```bash
   export AZURE_IMAGE_MULTIPLE="Test-Windows-2022-x64,Test-Windows-2025-x64,Test-Windows-11-x64,Test-Windows-2019-x64"
   ```

3. **Update Jenkins parameter** (if using Jenkins):
   Add new choice to IMAGE_NAME parameter in Jenkinsfile

## 🐛 Troubleshooting

### Common Issues

**Azure CLI not authenticated**
```bash
az login --service-principal \
    -u $AZURE_CLIENT_ID \
    -p $AZURE_CLIENT_SECRET \
    --tenant $AZURE_TENANT_ID
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

**WinRM connection fails**
- Check NSG rules allow port 5986
- Verify VM has public IP
- Check Windows Firewall on VM
- Review WinRM configuration script logs

**Windows Updates take too long**
- Normal for first update (15-30 minutes)
- Check VM has internet connectivity
- Review Ansible playbook logs in `logs/` directory
- Consider increasing VM size for faster updates

**Image capture fails**
- Ensure VM is stopped/deallocated
- Verify VM was sysprepped successfully
- Check gallery permissions
- Review Azure activity logs

**Resources not cleaned up**
```bash
# Manual cleanup
./scripts/cleanup-all-test-resources.sh
```

### Log Files

Logs are saved in timestamped directories:

```
logs/
├── multi-image-20260608-103000/
│   ├── Test-Windows-2025-x64.log
│   ├── Test-Windows-2022-x64.log
│   └── Test-Windows-11-x64.log
└── single-image-20260608-110000/
    └── workflow.log
```

## 🔄 Jenkins Integration

### Basic Pipeline

```groovy
pipeline {
    agent { label 'azure-updater-node' }
    
    parameters {
        choice(
            name: 'IMAGE_NAME',
            choices: ['Test-Windows-2025-x64', 'Test-Windows-2022-x64', 'Test-Windows-11-x64'],
            description: 'Select image to update'
        )
    }
    
    stages {
        stage('Update Image') {
            steps {
                sh '''
                    cd /home/azureupdater/azure-image-updater
                    export AZURE_IMAGE_DEFINITION="${params.IMAGE_NAME}"
                    source .env
                    ./scripts/test-full-workflow.sh
                '''
            }
        }
    }
}
```

See [JENKINS_INTEGRATION.md](JENKINS_INTEGRATION.md) for complete setup guide.

## 📚 Documentation

- **[AUTOMATED_WORKFLOW.md](AUTOMATED_WORKFLOW.md)** - Detailed automation guide
- **[MULTI_IMAGE_TESTING.md](MULTI_IMAGE_TESTING.md)** - Multi-image testing guide
- **[JENKINS_INTEGRATION.md](JENKINS_INTEGRATION.md)** - Jenkins setup and examples

## 🔄 Maintenance

### Regular Tasks

- **Monthly**: Run image updates to apply latest Windows patches
- **Quarterly**: Review and update Ansible playbooks
- **Annually**: Rotate Azure service principal credentials

### Cleanup Old Versions

Remove old image versions to save storage costs:

```bash
# List all versions
az sig image-version list \
    --resource-group adoptopenjdk \
    --gallery-name adoptium_compute_gallery \
    --gallery-image-definition Test-Windows-2022-x64 \
    --output table

# Delete old version
az sig image-version delete \
    --resource-group adoptopenjdk \
    --gallery-name adoptium_compute_gallery \
    --gallery-image-definition Test-Windows-2022-x64 \
    --gallery-image-version 1.0.0
```

## ⏱️ Time Estimates

### Single Image
- VM Provisioning: 5-10 minutes
- WinRM Configuration: 2-3 minutes
- Windows Updates: 15-30 minutes (varies by update count)
- Sysprep: 5-10 minutes
- Image Capture: 10-15 minutes
- **Total**: 40-70 minutes

### Multiple Images (3 images)
- **Total**: 2-3.5 hours

## 🤝 Contributing

When making changes:
1. Test locally with single image first
2. Verify all images work correctly
3. Update documentation
4. Test Jenkins integration if applicable

## 📄 License

See [LICENSE](../../LICENSE) file in repository root.

## 🙏 Acknowledgments

Built with automation best practices for Azure infrastructure management.

---

**Made with Bob** 🤖