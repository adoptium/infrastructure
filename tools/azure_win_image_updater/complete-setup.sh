#!/bin/bash
#
# Complete setup for Azure Image Updater
# Run this script as the azureupdater user (or your dedicated user)
# This handles user-level configuration after system packages are installed
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    log_error "Please do not run this script as root"
    log_error "Run as the dedicated user (e.g., azureupdater)"
    exit 1
fi

log_info "=========================================="
log_info "Completing Azure Image Updater Setup"
log_info "=========================================="
log_info "Running as user: $(whoami)"
log_info "Working directory: $(pwd)"

# Verify system packages are installed
log_info "Verifying system packages..."
if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Please run setup-ubuntu-node.sh as root first."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    log_error "yq not found. Please run setup-ubuntu-node.sh as root first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq not found. Please run setup-ubuntu-node.sh as root first."
    exit 1
fi

log_info "All required packages are installed"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p logs
mkdir -p temp

# Set up environment file template (only if it doesn't exist)
if [ ! -f .env.template ]; then
    log_info "Creating environment file template..."
    cat > .env.template << 'EOF'
# Azure Service Principal Credentials
# DO NOT commit this file with actual values!
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-service-principal-client-id"
export AZURE_CLIENT_SECRET="your-service-principal-client-secret"
EOF
else
    log_info ".env.template already exists (preserving existing template)"
fi

# Check if .env file exists
if [ ! -f .env ]; then
    log_warn ".env file not found. Creating from template..."
    cp .env.template .env
    log_warn "Please edit .env file with your Azure credentials before running the updater."
else
    log_info ".env file already exists."
fi

# Add .env to .gitignore if it exists
if [ -f .gitignore ]; then
    if ! grep -q "^\.env$" .gitignore; then
        echo ".env" >> .gitignore
        log_info "Added .env to .gitignore"
    fi
else
    echo ".env" > .gitignore
    log_info "Created .gitignore with .env"
fi

# Test Azure CLI
log_info "Testing Azure CLI..."
if az version &> /dev/null; then
    log_info "Azure CLI is working correctly"
else
    log_error "Azure CLI test failed"
    exit 1
fi

# Display setup summary
echo ""
log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
echo ""
log_info "Next steps:"
echo ""
echo "1. Configure Azure credentials:"
echo "   nano .env"
echo ""
echo "   Add your Azure Service Principal details:"
echo "   export AZURE_SUBSCRIPTION_ID=\"your-subscription-id\""
echo "   export AZURE_TENANT_ID=\"your-tenant-id\""
echo "   export AZURE_CLIENT_ID=\"your-client-id\""
echo "   export AZURE_CLIENT_SECRET=\"your-client-secret\""
echo ""
echo "2. Configure Azure resources:"
echo "   nano config.yaml"
echo ""
echo "   Update with your:"
echo "   - Resource group names"
echo "   - Compute Gallery name"
echo "   - Image definition name"
echo "   - VNet and Subnet names"
echo ""
echo "3. Source the environment file:"
echo "   source .env"
echo ""
echo "4. Test Azure authentication:"
echo "   az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID"
echo "   az account set --subscription \$AZURE_SUBSCRIPTION_ID"
echo "   az account show"
echo ""
echo "5. Test the update process (dry run):"
echo "   ./scripts/update-image.sh --dry-run"
echo ""
echo "6. Run actual update:"
echo "   ./scripts/update-image.sh"
echo ""
log_info "For more information, see:"
echo "  - README.md (complete guide)"
echo "  - QUICKSTART.md (quick setup)"
echo "  - DEDICATED_USER_GUIDE.md (dedicated user details)"
echo ""
log_info "=========================================="

# Made with Bob
