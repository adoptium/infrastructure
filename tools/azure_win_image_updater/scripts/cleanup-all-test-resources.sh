#!/bin/bash
set -e

# Cleanup script for resources created by 1-provision-vm.sh
# Only deletes: VMs, NICs, Public IPs, NSGs, and Disks with specific naming patterns

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/.env"

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track failures for retry
FAILED_RESOURCES=false

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Please install it first."
    exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Azure Test Resources Cleanup Tool    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Find all test VMs (only those created by provision script)
log_info "Finding test VMs in resource group: $RESOURCE_GROUP"

VM_NAMES=$(az vm list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'upd-')].name" \
    --output tsv)

if [ -z "$VM_NAMES" ]; then
    log_info "No test VMs found"
else
    # Show VMs found
    VM_COUNT=$(echo "$VM_NAMES" | wc -l)
    log_warning "Found $VM_COUNT test VM(s):"
    echo "$VM_NAMES" | while read vm; do echo "  - $vm"; done
    echo ""
    
    # Ask for confirmation
    read -p "Delete these VMs? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "VM deletion cancelled"
        exit 0
    fi
    
    # Step 1: Delete VMs and WAIT for completion
    log_info "Step 1: Deleting VMs (waiting for completion)..."
    echo ""
    
    DELETED=0
    FAILED=0
    
    while IFS= read -r vm_name; do
        log_info "Deleting VM: $vm_name"
        
        # Use --wait to ensure VM is fully deleted before proceeding
        if az vm delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$vm_name" \
            --yes \
            --output none 2>&1; then
            log_success "Deleted: $vm_name"
            ((++DELETED))
        else
            log_error "Failed: $vm_name"
            ((++FAILED))
        fi
    done <<< "$VM_NAMES"
    
    echo ""
    log_success "VM deletion complete: $DELETED deleted, $FAILED failed"
    
    # Extra wait to ensure Azure has fully processed the deletions and released locks
    # Azure can take 60-90 seconds to fully release locks on associated resources
    log_info "Waiting 60 seconds for Azure to release resource locks..."
    sleep 60
    echo ""
fi

# Always check for orphaned resources (whether VMs were found or not)
echo ""
log_info "Checking for orphaned resources..."

# Step 2: Clean up Network Interfaces (only from provision script)
echo ""
log_info "Step 2: Cleaning up Network Interfaces..."
log_info "Finding NICs..."

NICS=$(az network nic list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'upd-')].name" \
    --output tsv)

if [ -n "$NICS" ]; then
    NIC_COUNT=$(echo "$NICS" | wc -l)
    log_warning "Found $NIC_COUNT NICs"
    
    while IFS= read -r nic_name; do
        log_info "Deleting: $nic_name"
        if az network nic delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$nic_name" \
            --output none 2>&1; then
            log_success "Deleted: $nic_name"
        else
            log_warning "Failed (may be reserved): $nic_name"
            FAILED_RESOURCES=true
        fi
    done <<< "$NICS"
else
    log_info "No NICs found"
fi

# Step 3: Clean up Public IPs (only from provision script)
echo ""
log_info "Step 3: Cleaning up Public IPs..."
log_info "Finding Public IPs..."

PUBLIC_IPS=$(az network public-ip list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'upd-')].name" \
    --output tsv)

if [ -n "$PUBLIC_IPS" ]; then
    IP_COUNT=$(echo "$PUBLIC_IPS" | wc -l)
    log_warning "Found $IP_COUNT Public IPs"
    
    while IFS= read -r ip_name; do
        log_info "Deleting: $ip_name"
        if az network public-ip delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$ip_name" \
            --output none 2>&1; then
            log_success "Deleted: $ip_name"
        else
            log_warning "Failed (may be in use): $ip_name"
            FAILED_RESOURCES=true
        fi
    done <<< "$PUBLIC_IPS"
else
    log_info "No Public IPs found"
fi

# Step 4: Clean up Network Security Groups (only from provision script)
echo ""
log_info "Step 4: Cleaning up Network Security Groups..."
log_info "Finding NSGs..."

NSGS=$(az network nsg list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'upd-')].name" \
    --output tsv)

if [ -n "$NSGS" ]; then
    NSG_COUNT=$(echo "$NSGS" | wc -l)
    log_warning "Found $NSG_COUNT NSGs"
    
    while IFS= read -r nsg_name; do
        log_info "Deleting: $nsg_name"
        if az network nsg delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$nsg_name" \
            --output none 2>&1; then
            log_success "Deleted: $nsg_name"
        else
            log_warning "Failed (may be in use): $nsg_name"
            FAILED_RESOURCES=true
        fi
    done <<< "$NSGS"
else
    log_info "No NSGs found"
fi

# Step 5: Clean up Disks (only from provision script)
echo ""
log_info "Step 5: Cleaning up Disks..."

DISKS=$(az disk list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, 'upd-')].name" \
    --output tsv)

if [ -n "$DISKS" ]; then
    DISK_COUNT=$(echo "$DISKS" | wc -l)
    log_warning "Found $DISK_COUNT Disk(s)"
    
    while IFS= read -r disk_name; do
        log_info "Deleting disk: $disk_name"
        if az disk delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$disk_name" \
            --yes \
            --output none 2>&1; then
            log_success "Deleted: $disk_name"
        else
            log_error "Failed: $disk_name"
        fi
    done <<< "$DISKS"
else
    log_info "No disks found"
fi

# Step 6: Retry failed resources if any (only if there were failures)
if [ "$FAILED_RESOURCES" = true ]; then
    echo ""
    log_info "Step 6: Retrying failed resources after 180 second wait..."
    log_info "Waiting for Azure to release reserved resources..."
    sleep 180

    # Retry NICs
    NICS=$(az network nic list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?starts_with(name, 'upd-')].name" \
        --output tsv)

    if [ -n "$NICS" ]; then
        log_info "Retrying NICs..."
        while IFS= read -r nic_name; do
            log_info "Deleting: $nic_name"
            az network nic delete \
                --resource-group "$RESOURCE_GROUP" \
                --name "$nic_name" \
                --output none 2>&1 && log_success "Deleted: $nic_name" || log_error "Still failed: $nic_name"
        done <<< "$NICS"
    fi

    # Retry Public IPs
    PUBLIC_IPS=$(az network public-ip list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?starts_with(name, 'upd-')].name" \
        --output tsv)

    if [ -n "$PUBLIC_IPS" ]; then
        log_info "Retrying Public IPs..."
        while IFS= read -r ip_name; do
            log_info "Deleting: $ip_name"
            az network public-ip delete \
                --resource-group "$RESOURCE_GROUP" \
                --name "$ip_name" \
                --output none 2>&1 && log_success "Deleted: $ip_name" || log_error "Still failed: $ip_name"
        done <<< "$PUBLIC_IPS"
    fi

    # Retry NSGs
    NSGS=$(az network nsg list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?starts_with(name, 'upd-')].name" \
        --output tsv)

    if [ -n "$NSGS" ]; then
        log_info "Retrying NSGs..."
        while IFS= read -r nsg_name; do
            log_info "Deleting: $nsg_name"
            az network nsg delete \
                --resource-group "$RESOURCE_GROUP" \
                --name "$nsg_name" \
                --output none 2>&1 && log_success "Deleted: $nsg_name" || log_error "Still failed: $nsg_name"
        done <<< "$NSGS"
    fi
fi

# Final check: Count remaining resources
echo ""
log_info "Performing final check for remaining resources..."

REMAINING_NICS=$(az network nic list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)
REMAINING_IPS=$(az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)
REMAINING_NSGS=$(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)
REMAINING_DISKS=$(az disk list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)

TOTAL_REMAINING=$((REMAINING_NICS + REMAINING_IPS + REMAINING_NSGS + REMAINING_DISKS))

if [ $TOTAL_REMAINING -gt 0 ]; then
    log_warning "Found $TOTAL_REMAINING remaining resources (NICs: $REMAINING_NICS, IPs: $REMAINING_IPS, NSGs: $REMAINING_NSGS, Disks: $REMAINING_DISKS)"
    log_info "Waiting 60 seconds for Azure to release locks, then retrying..."
    sleep 60
    
    # Retry cleanup for remaining resources
    echo ""
    log_info "Retrying cleanup of remaining resources..."
    
    # Retry NICs
    if [ $REMAINING_NICS -gt 0 ]; then
        NICS=$(az network nic list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv)
        while IFS= read -r nic_name; do
            log_info "Deleting NIC: $nic_name"
            az network nic delete --resource-group "$RESOURCE_GROUP" --name "$nic_name" --output none 2>&1 && log_success "Deleted: $nic_name" || log_warning "Failed: $nic_name"
        done <<< "$NICS"
    fi
    
    # Retry Public IPs
    if [ $REMAINING_IPS -gt 0 ]; then
        PUBLIC_IPS=$(az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv)
        while IFS= read -r ip_name; do
            log_info "Deleting Public IP: $ip_name"
            az network public-ip delete --resource-group "$RESOURCE_GROUP" --name "$ip_name" --output none 2>&1 && log_success "Deleted: $ip_name" || log_warning "Failed: $ip_name"
        done <<< "$PUBLIC_IPS"
    fi
    
    # Retry NSGs
    if [ $REMAINING_NSGS -gt 0 ]; then
        NSGS=$(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv)
        while IFS= read -r nsg_name; do
            log_info "Deleting NSG: $nsg_name"
            az network nsg delete --resource-group "$RESOURCE_GROUP" --name "$nsg_name" --output none 2>&1 && log_success "Deleted: $nsg_name" || log_warning "Failed: $nsg_name"
        done <<< "$NSGS"
    fi
    
    # Retry Disks
    if [ $REMAINING_DISKS -gt 0 ]; then
        DISKS=$(az disk list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv)
        while IFS= read -r disk_name; do
            log_info "Deleting Disk: $disk_name"
            az disk delete --resource-group "$RESOURCE_GROUP" --name "$disk_name" --yes --output none 2>&1 && log_success "Deleted: $disk_name" || log_warning "Failed: $disk_name"
        done <<< "$DISKS"
    fi
fi

# Summary
echo ""
log_info "==================================="
log_success "Cleanup Complete!"
log_info "==================================="
log_info "All test resources have been processed"

# Final count
FINAL_REMAINING=$(az network nic list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)
FINAL_REMAINING=$((FINAL_REMAINING + $(az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)))
FINAL_REMAINING=$((FINAL_REMAINING + $(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)))
FINAL_REMAINING=$((FINAL_REMAINING + $(az disk list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, 'upd-')].name" -o tsv | wc -l)))

if [ $FINAL_REMAINING -gt 0 ]; then
    log_warning "$FINAL_REMAINING resources still remain - may need manual cleanup"
else
    log_success "All resources cleaned successfully"
fi
echo ""

# Made with Bob
