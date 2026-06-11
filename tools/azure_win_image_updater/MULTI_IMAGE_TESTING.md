# Multi-Image Testing Guide

This guide explains how to test multiple Windows gallery images locally using the automated workflow.

## Overview

The Azure Windows Image Updater now supports processing multiple gallery images in a single run. This is useful for:

- **Local Testing**: Validate all images work correctly before Jenkins automation
- **Batch Updates**: Apply Windows updates to multiple images at once
- **Consistency**: Ensure all images are updated with the same process

## Configuration

### 1. Update `.env` File

The `AZURE_IMAGE_DEFINITION` variable is used for single image processing, while `AZURE_IMAGE_MULTIPLE` supports multiple comma-separated image names:

```bash
# Single image (for test-full-workflow.sh)
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"

# Multiple images (for test-full-all-images.sh)
export AZURE_IMAGE_MULTIPLE="Test-Windows-2025-x64,Test-Windows-2022-x64,Test-Windows-11-x64"
```

**Important**:
- Separate image names with commas (no spaces after commas)
- Each image must exist in your Azure Compute Gallery
- The order determines processing sequence

### 2. Verify Gallery Setup

Ensure all images are created in your Azure Compute Gallery:

```bash
# List all image definitions in your gallery
az sig image-definition list \
    --resource-group adoptopenjdk \
    --gallery-name adoptium_compute_gallery \
    --output table
```

Expected output should include:
- `Test-Windows-2025-x64`
- `Test-Windows-2022-x64`
- `Test-Windows-11-x64`

## Running Multi-Image Workflow

### Local Testing (All Images)

**Option 1: Using test-full-all-images.sh (Recommended - Fully Automated)**

Process all images from `AZURE_IMAGE_MULTIPLE` with no prompts:

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env
./scripts/test-full-all-images.sh
```

**Option 2: Using run-all-images.sh (Interactive)**

Process all images from `AZURE_IMAGE_DEFINITION` with prompts between images:

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env
./scripts/run-all-images.sh
```

### What Happens

The script will:

1. **Validate Configuration**
   - Check all required environment variables
   - Verify Azure Compute Gallery exists
   - Confirm all image definitions exist

2. **Process Each Image Sequentially**
   - Provision a temporary VM from the gallery image
   - Configure WinRM for Ansible connectivity
   - Run Windows Updates via Ansible
   - Sysprep the VM to generalize it
   - Capture a new image version to the gallery
   - Clean up temporary resources

3. **Generate Reports**
   - Individual log file per image in `logs/multi-image-TIMESTAMP/`
   - Summary report showing success/failure for each image
   - Duration tracking per image

### Interactive Prompts

The script includes safety prompts:

- **Initial Confirmation**: Review configuration before starting
- **Failure Handling**: Choose to continue or stop if an image fails
- **Step Confirmation**: Each workflow step requires confirmation (inherited from `test-full-workflow.sh`)

### Example Output

```
╔════════════════════════════════════════════════════════╗
║  Azure Windows Image Updater - Multi-Image Workflow   ║
╚════════════════════════════════════════════════════════╝

Configuration:
  Gallery: adoptium_compute_gallery
  Resource Group: adoptopenjdk
  Images to Process: 3

Images:
  - Test-Windows-2025-x64
  - Test-Windows-2022-x64
  - Test-Windows-11-x64

Validating Azure Compute Gallery...
✓ Gallery exists

Validating image definitions...
  Checking Test-Windows-2025-x64... ✓
  Checking Test-Windows-2022-x64... ✓
  Checking Test-Windows-11-x64... ✓

✓ All image definitions validated

Logs will be saved to: logs/multi-image-20260605-164500

════════════════════════════════════════════════════════
Ready to process 3 image(s)
════════════════════════════════════════════════════════

This will:
  1. Provision a VM for each image
  2. Configure WinRM
  3. Run Windows Updates via Ansible
  4. Sysprep the VM
  5. Capture a new image version

Continue? (y/n):
```

## Log Files

### Location

Logs are saved in timestamped directories:
```
logs/multi-image-YYYYMMDD-HHMMSS/
├── Test-Windows-2025-x64.log
├── Test-Windows-2022-x64.log
└── Test-Windows-11-x64.log
```

### Log Contents

Each log file contains:
- Start timestamp
- Complete workflow output for that image
- Success/failure status
- Duration in minutes

### Reviewing Logs

```bash
# View logs for a specific image
cat logs/multi-image-20260605-164500/Test-Windows-2022-x64.log

# Search for errors across all logs
grep -i error logs/multi-image-20260605-164500/*.log

# Check summary at end of each log
tail -n 20 logs/multi-image-20260605-164500/*.log
```

## Troubleshooting

### Image Not Found Error

```
ERROR: Image definition 'Test-Windows-2025-x64' not found in gallery
```

**Solution**: Create the image definition in your gallery:

```bash
az sig image-definition create \
    --resource-group adoptopenjdk \
    --gallery-name adoptium_compute_gallery \
    --gallery-image-definition Test-Windows-2025-x64 \
    --publisher MicrosoftWindowsServer \
    --offer WindowsServer \
    --sku 2025-datacenter \
    --os-type Windows \
    --os-state Generalized
```

### Workflow Fails for One Image

The script will:
1. Log the failure details
2. Prompt whether to continue with remaining images
3. Mark the failed image in the summary report

**Options**:
- Continue: Process remaining images
- Stop: Review logs and fix the issue before retrying

### VM Provisioning Fails

Common causes:
- Quota limits reached
- Network configuration issues
- Image version not available

**Solution**: Check the specific image log file for detailed error messages.

## Best Practices

### 1. Test One Image First

Before running all images, test with a single image:

```bash
# Temporarily modify .env to test one image
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
./scripts/run-all-images.sh
```

### 2. Schedule During Off-Hours

Processing multiple images takes time (30-60 minutes per image). Schedule during:
- Nights
- Weekends
- Low-usage periods

### 3. Monitor Progress

Keep terminal open to monitor progress and respond to prompts. Alternatively:
- Use `screen` or `tmux` for long-running sessions
- Review logs periodically in another terminal

### 4. Verify New Versions

After successful completion, verify new image versions:

```bash
# List versions for each image
for IMAGE in Test-Windows-2025-x64 Test-Windows-2022-x64 Test-Windows-11-x64; do
    echo "=== $IMAGE ==="
    az sig image-version list \
        --resource-group adoptopenjdk \
        --gallery-name adoptium_compute_gallery \
        --gallery-image-definition "$IMAGE" \
        --query "[].{Version:name, State:provisioningState}" \
        --output table
    echo ""
done
```

## Time Estimates

Approximate duration per image:
- VM Provisioning: 5-10 minutes
- WinRM Configuration: 2-3 minutes
- Windows Updates: 15-30 minutes (varies by update count)
- Sysprep: 5-10 minutes
- Image Capture: 10-15 minutes

**Total per image**: 40-70 minutes  
**Total for 3 images**: 2-3.5 hours

## Next Steps

After successful local testing:

1. **Review Results**: Check all image versions were created
2. **Test New Images**: Deploy VMs from new versions to verify functionality
3. **Jenkins Integration**: See [JENKINS_INTEGRATION.md](JENKINS_INTEGRATION.md) for automation setup

## Summary Report Example

```
════════════════════════════════════════════════════════
Multi-Image Workflow Complete
════════════════════════════════════════════════════════

Summary:
  Total Images: 3
  Successful: 3
  Failed: 0
  Skipped: 0

Successful Images:
  ✓ Test-Windows-2025-x64
  ✓ Test-Windows-2022-x64
  ✓ Test-Windows-11-x64

Logs saved to: logs/multi-image-20260605-164500

All images processed successfully! 🎉
```

## Support

For issues or questions:
1. Check log files for detailed error messages
2. Verify Azure credentials and permissions
3. Ensure all prerequisites are installed (run `./scripts/0-check-prerequisites.sh`)
4. Review individual script documentation in `scripts/` directory

---

**Made with Bob** 🤖