#!/bin/bash
set -e

# Automated Full Workflow - No Prompts
# This script runs all steps sequentially with validation and automatic cleanup
# Designed for Jenkins automation and unattended execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Track workflow state
WORKFLOW_START_TIME=$(date +%s)
CLEANUP_NEEDED=false
VM_NAME=""

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Cleanup function - called on exit
cleanup_resources() {
    local exit_code=$?
    
    if [ "$CLEANUP_NEEDED" = true ]; then
        log_step "Cleanup: Removing Temporary Resources"
        
        # Load environment to get resource group
        if [ -f "$PROJECT_ROOT/.env" ]; then
            source "$PROJECT_ROOT/.env"
        fi
        
        if [ -n "$VM_NAME" ] && [ -n "$AZURE_RESOURCE_GROUP" ]; then
            log_info "Cleaning up resources for VM: $VM_NAME"
            
            # Delete VM
            log_info "Deleting VM: $VM_NAME"
            if az vm delete \
                --resource-group "$AZURE_RESOURCE_GROUP" \
                --name "$VM_NAME" \
                --yes \
                --output none 2>/dev/null; then
                log_success "VM deleted"
            else
                log_warning "VM deletion failed or already deleted"
            fi
            
            # Wait for Azure to release locks
            log_info "Waiting 30 seconds for Azure to release resource locks..."
            sleep 30
            
            # Delete associated resources
            local resources_to_check=("nic" "public-ip" "nsg" "disk")
            local resource_types=("network nic" "network public-ip" "network nsg" "disk")
            
            for i in "${!resources_to_check[@]}"; do
                local resource_type="${resources_to_check[$i]}"
                local az_command="${resource_types[$i]}"
                
                log_info "Checking for ${resource_type}s..."
                local resources=$(az ${az_command} list \
                    --resource-group "$AZURE_RESOURCE_GROUP" \
                    --query "[?starts_with(name, '${VM_NAME}')].name" \
                    --output tsv 2>/dev/null)
                
                if [ -n "$resources" ]; then
                    while IFS= read -r resource_name; do
                        log_info "Deleting ${resource_type}: $resource_name"
                        if [ "$resource_type" = "disk" ]; then
                            az ${az_command} delete \
                                --resource-group "$AZURE_RESOURCE_GROUP" \
                                --name "$resource_name" \
                                --yes \
                                --output none 2>/dev/null && log_success "Deleted: $resource_name" || log_warning "Failed: $resource_name"
                        else
                            az ${az_command} delete \
                                --resource-group "$AZURE_RESOURCE_GROUP" \
                                --name "$resource_name" \
                                --output none 2>/dev/null && log_success "Deleted: $resource_name" || log_warning "Failed: $resource_name"
                        fi
                    done <<< "$resources"
                fi
            done
            
            # Final verification
            log_info "Verifying cleanup completion..."
            local remaining=0
            for i in "${!resources_to_check[@]}"; do
                local az_command="${resource_types[$i]}"
                local count=$(az ${az_command} list \
                    --resource-group "$AZURE_RESOURCE_GROUP" \
                    --query "[?starts_with(name, '${VM_NAME}')].name" \
                    --output tsv 2>/dev/null | wc -l)
                remaining=$((remaining + count))
            done
            
            if [ $remaining -eq 0 ]; then
                log_success "All resources cleaned up successfully"
            else
                log_warning "$remaining resources still remain - may need manual cleanup"
            fi
        else
            log_warning "VM name or resource group not available for cleanup"
        fi
    fi
    
    # Calculate total duration
    local end_time=$(date +%s)
    local duration=$((end_time - WORKFLOW_START_TIME))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    echo ""
    log_step "Workflow Complete"
    log_info "Total Duration: ${duration_min}m ${duration_sec}s"
    
    if [ $exit_code -eq 0 ]; then
        log_success "Workflow completed successfully"
    else
        log_error "Workflow failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

# Register cleanup function
trap cleanup_resources EXIT INT TERM

# Function to run a script with validation
run_script() {
    local script_num="$1"
    local script_name="$2"
    local script_path="$SCRIPT_DIR/$script_num-$script_name.sh"
    local step_start=$(date +%s)
    
    log_step "Step $script_num: $script_name"
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    log_info "Executing: $script_path"
    
    if bash "$script_path"; then
        local step_end=$(date +%s)
        local step_duration=$((step_end - step_start))
        log_success "Step $script_num completed in ${step_duration}s"
        
        # After step 1, mark cleanup as needed and capture VM name
        if [ "$script_num" = "1" ]; then
            CLEANUP_NEEDED=true
            if [ -f "$PROJECT_ROOT/.last-vm-name" ]; then
                VM_NAME=$(cat "$PROJECT_ROOT/.last-vm-name")
                log_info "VM Name captured for cleanup: $VM_NAME"
            fi
        fi
        
        return 0
    else
        local step_end=$(date +%s)
        local step_duration=$((step_end - step_start))
        log_error "Step $script_num failed after ${step_duration}s"
        return 1
    fi
}

# Main workflow
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Azure Windows Image Updater - Automated Workflow     ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Starting automated workflow at $(date)"
log_info "Image: ${AZURE_IMAGE_DEFINITION:-<not set>}"
echo ""

# Step 0: Check prerequisites
run_script "0" "check-prerequisites" || exit 1

# Step 1: Provision VM
run_script "1" "provision-vm" || exit 1

# Step 2: Test Custom Script Extension
run_script "2" "test-custom-script-extension" || exit 1

# Step 3: Configure WinRM
run_script "3" "configure-winrm" || exit 1

# Step 4: Test Ansible
run_script "4" "test-ansible" || exit 1

# Step 5: Run Updates
run_script "5" "run-updates" || exit 1

# Step 6: Run Sysprep
run_script "6" "run-sysprep" || exit 1

# Step 7: Validate VM is ready (this will wait for VM to stop)
run_script "7" "validate-vm-ready" || exit 1

# Step 8: Capture image
run_script "8" "capture-image" || exit 1

# If we reach here, all steps succeeded
log_step "All Steps Completed Successfully"
echo ""
log_success "✓ VM provisioned and configured"
log_success "✓ Windows Updates installed"
log_success "✓ VM sysprepped and validated"
log_success "✓ New image version captured"
echo ""

# Cleanup will be handled by trap
exit 0

# Made with Bob
