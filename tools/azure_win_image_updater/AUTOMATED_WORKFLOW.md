# Automated Workflow Guide

This document explains the fully automated workflow for updating Windows gallery images without user prompts.

## Overview

The `test-full-workflow.sh` script has been redesigned for complete automation:

✅ **No user prompts** - Runs all steps automatically  
✅ **Automatic validation** - Each step validates before proceeding  
✅ **Automatic cleanup** - All resources cleaned up on exit  
✅ **Error handling** - Stops immediately on failure  
✅ **Resource verification** - Confirms all resources are removed  

## Key Changes

### 1. Removed User Prompts

**Before:**
- Script prompted after each step to continue
- Image capture required version confirmation

**After:**
- All steps run automatically in sequence
- Version auto-incremented without confirmation
- Only stops on errors

### 2. Automatic Cleanup

The script now includes comprehensive cleanup that:

- Runs automatically on exit (success or failure)
- Uses bash `trap` to ensure cleanup always executes
- Deletes all temporary resources:
  - Virtual Machine
  - Network Interface Card (NIC)
  - Public IP Address
  - Network Security Group (NSG)
  - OS Disk
- Waits for Azure to release resource locks
- Verifies all resources are removed
- Reports any remaining resources

### 3. Enhanced Logging

Every action is logged with:
- Timestamp
- Log level (INFO, SUCCESS, WARNING, ERROR)
- Step duration
- Total workflow duration

### 4. Exit Codes

- `0` - Success (all steps completed, cleanup successful)
- `1` - Failure (step failed or cleanup issues)

## Usage

### Single Image (Direct)

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env

# Set the image to process
export AZURE_IMAGE_DEFINITION="Test-Windows-2022-x64"
export AZURE_SOURCE_IMAGE="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Compute/galleries/$AZURE_GALLERY_NAME/images/Test-Windows-2022-x64"

# Run automated workflow
./scripts/test-full-workflow.sh
```

### Multiple Images (Wrapper)

```bash
cd infrastructure.azureauto/tools/azure_win_image_updater
source .env

# Process all images defined in AZURE_IMAGE_DEFINITION
./scripts/run-all-images.sh
```

**Note:** The wrapper script (`run-all-images.sh`) still has prompts for:
- Initial confirmation before starting
- Continuation after failures

This is intentional for local testing control.

## Workflow Steps

The automated workflow executes these steps in sequence:

1. **Check Prerequisites** (0-check-prerequisites.sh)
   - Validates Azure CLI, Ansible, Python packages
   - Checks .env configuration
   - Verifies Azure authentication

2. **Provision VM** (1-provision-vm.sh)
   - Creates temporary VM from gallery image
   - Sets up Network Security Group
   - Configures public IP and networking
   - **Triggers cleanup registration**

3. **Test Custom Script Extension** (2-test-custom-script-extension.sh)
   - Validates Azure Custom Script Extension

4. **Configure WinRM** (3-configure-winrm.sh)
   - Enables WinRM over HTTPS
   - Creates self-signed certificate
   - Opens firewall port 5986

5. **Test Ansible** (4-test-ansible.sh)
   - Verifies Ansible can connect via WinRM
   - Tests basic connectivity

6. **Run Windows Updates** (5-run-updates.sh)
   - Searches for available updates
   - Downloads and installs updates
   - Handles reboots automatically
   - Continues until no more updates

7. **Run Sysprep** (6-run-sysprep.sh)
   - Generalizes the VM
   - Shuts down the VM
   - Prepares for image capture

8. **Validate VM Ready** (7-validate-vm-ready.sh)
   - Confirms VM is stopped/deallocated
   - Waits for VM to reach proper state

9. **Capture Image** (8-capture-image.sh)
   - Auto-increments version number
   - Generalizes VM in Azure
   - Creates new image version
   - Publishes to gallery
   - **No confirmation prompt**

10. **Cleanup** (automatic via trap)
    - Deletes VM
    - Removes NIC, Public IP, NSG, Disk
    - Verifies all resources removed
    - Reports final status

## Cleanup Details

### What Gets Cleaned Up

All resources with the VM name prefix (e.g., `upd-0608-1030`):

```
upd-0608-1030              (VM)
upd-0608-1030VMNic         (Network Interface)
upd-0608-1030PublicIP      (Public IP)
upd-0608-1030-nsg          (Network Security Group)
upd-0608-1030_OsDisk_*     (OS Disk)
```

### Cleanup Process

1. **VM Deletion** - Deletes the virtual machine
2. **Wait Period** - 30 seconds for Azure to release locks
3. **Resource Cleanup** - Deletes NIC, Public IP, NSG, Disk
4. **Verification** - Counts remaining resources
5. **Reporting** - Reports success or remaining resources

### Cleanup Timing

- Runs automatically on script exit
- Triggered by:
  - Normal completion
  - Script failure
  - User interrupt (Ctrl+C)
  - System termination

### Verification

After cleanup, the script verifies:

```bash
# Check for remaining resources
REMAINING=$(az network nic list --query "[?starts_with(name, 'upd-')]" -o tsv | wc -l)
REMAINING=$((REMAINING + $(az network public-ip list --query "[?starts_with(name, 'upd-')]" -o tsv | wc -l)))
REMAINING=$((REMAINING + $(az network nsg list --query "[?starts_with(name, 'upd-')]" -o tsv | wc -l)))
REMAINING=$((REMAINING + $(az disk list --query "[?starts_with(name, 'upd-')]" -o tsv | wc -l)))

if [ $REMAINING -eq 0 ]; then
    echo "✓ All resources cleaned successfully"
else
    echo "⚠ $REMAINING resources still remain"
fi
```

## Jenkins Integration

The automated workflow is perfect for Jenkins:

```groovy
stage('Update Image') {
    steps {
        script {
            sh '''
                cd /home/azureupdater/azure-image-updater
                export AZURE_IMAGE_DEFINITION="${params.IMAGE_NAME}"
                source .env
                ./scripts/test-full-workflow.sh
            '''
        }
    }
}
```

**Benefits:**
- No manual intervention required
- Automatic cleanup on success or failure
- Proper exit codes for Jenkins status
- Complete logs in Jenkins console

## Error Handling

### Step Failure

If any step fails:
1. Script stops immediately
2. Error is logged with timestamp
3. Cleanup runs automatically
4. Exit code 1 returned

### Cleanup Failure

If cleanup encounters issues:
1. Retries after waiting for lock release
2. Reports remaining resources
3. Provides resource names for manual cleanup
4. Exit code reflects cleanup status

## Monitoring

### During Execution

Watch for these log patterns:

```
[INFO] 2026-06-08 10:00:00 - Starting automated workflow
[SUCCESS] 2026-06-08 10:05:00 - Step 1 completed in 300s
[ERROR] 2026-06-08 10:10:00 - Step 2 failed after 120s
```

### After Completion

Check the summary:

```
╔════════════════════════════════════════════════════════╗
║  Workflow Complete                                     ║
╚════════════════════════════════════════════════════════╝

[INFO] 2026-06-08 11:00:00 - Total Duration: 60m 0s
[SUCCESS] 2026-06-08 11:00:00 - Workflow completed successfully
[SUCCESS] 2026-06-08 11:00:00 - All resources cleaned up successfully
```

## Troubleshooting

### Resources Not Cleaned Up

If resources remain after cleanup:

```bash
# List remaining resources
az network nic list --resource-group adoptopenjdk --query "[?starts_with(name, 'upd-')]" -o table
az network public-ip list --resource-group adoptopenjdk --query "[?starts_with(name, 'upd-')]" -o table
az network nsg list --resource-group adoptopenjdk --query "[?starts_with(name, 'upd-')]" -o table
az disk list --resource-group adoptopenjdk --query "[?starts_with(name, 'upd-')]" -o table

# Manual cleanup
./scripts/cleanup-all-test-resources.sh
```

### Workflow Hangs

If the workflow appears to hang:

1. Check Azure portal for VM status
2. Review logs for last completed step
3. Check network connectivity
4. Verify Azure service health

### Cleanup Fails

If cleanup consistently fails:

1. Wait 5 minutes for Azure to release locks
2. Run cleanup script manually
3. Check Azure portal for resource locks
4. Verify service principal permissions

## Best Practices

### 1. Monitor First Run

For the first automated run:
- Monitor the console output
- Verify each step completes
- Check cleanup is successful
- Review new image version

### 2. Schedule Appropriately

For Jenkins automation:
- Run during off-peak hours
- Allow 60-90 minutes per image
- Schedule with buffer time
- Monitor build history

### 3. Verify Results

After each run:
- Check new image version exists
- Verify version number incremented
- Test deploy VM from new image
- Review logs for warnings

### 4. Handle Failures

If a run fails:
- Review logs for error details
- Check Azure activity logs
- Verify cleanup completed
- Fix issue before retrying

## Comparison: Before vs After

### Before (Interactive)

```bash
# User had to:
- Confirm after each step (8 prompts)
- Confirm version number
- Manually run cleanup script
- Monitor for completion

# Total interaction time: 5-10 minutes
```

### After (Automated)

```bash
# User only needs to:
- Start the script
- Wait for completion
- Review results

# Total interaction time: 30 seconds
```

## Summary

The automated workflow provides:

✅ **Zero-touch execution** - No prompts or manual steps  
✅ **Automatic cleanup** - All resources removed on exit  
✅ **Error resilience** - Cleanup runs even on failure  
✅ **Jenkins ready** - Perfect for CI/CD integration  
✅ **Resource safety** - Verifies nothing left behind  
✅ **Complete logging** - Full audit trail of actions  

Perfect for:
- Jenkins automation
- Scheduled updates
- Batch processing
- Unattended execution

---

**Made with Bob** 🤖