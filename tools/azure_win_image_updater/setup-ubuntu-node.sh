#!/bin/bash
#
# Azure Dynamic Windows Agent Image Updater - Ubuntu Node Setup
# This script installs system-wide packages required for the image updater
# MUST be run as root or with sudo
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
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run this script as root or with sudo"
    log_error "This script installs system-wide packages"
    exit 1
fi

log_info "=========================================="
log_info "Azure Image Updater - System Setup"
log_info "=========================================="
log_info "Running as root - installing system-wide packages"

# Update package list
log_info "Updating package list..."
apt-get update

# Install required packages
log_info "Installing required packages..."
apt-get install -y \
    curl \
    jq \
    git \
    unzip \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    gnupg \
    python3 \
    python3-pip \
    ansible

# Install Azure CLI
log_info "Checking Azure CLI installation..."
if command -v az &> /dev/null; then
    log_info "Azure CLI is already installed: $(az version --query '\"azure-cli\"' -o tsv)"
else
    log_info "Installing Azure CLI..."
    
    # Download and install the Microsoft signing key
    mkdir -p /etc/apt/keyrings
    curl -sLS https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor | \
        tee /etc/apt/keyrings/microsoft.gpg > /dev/null
    chmod go+r /etc/apt/keyrings/microsoft.gpg
    
    # Add the Azure CLI software repository
    AZ_REPO=$(lsb_release -cs)
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
        tee /etc/apt/sources.list.d/azure-cli.list
    
    # Update repository information and install the azure-cli package
    apt-get update
    apt-get install -y azure-cli
    
    log_info "Azure CLI installed successfully: $(az version --query '\"azure-cli\"' -o tsv)"
fi

# Install yq for YAML parsing
log_info "Installing yq for YAML parsing..."
if command -v yq &> /dev/null; then
    log_info "yq is already installed: $(yq --version)"
else
    YQ_VERSION="v4.35.1"
    YQ_BINARY="yq_linux_amd64"
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}"
    chmod +x /usr/local/bin/yq
    log_info "yq installed successfully: $(yq --version)"
fi

# Install Python packages for Ansible WinRM
log_info "Installing Python packages for Ansible WinRM support..."
pip3 install --upgrade pip
pip3 install pywinrm requests requests-ntlm requests-credssp

log_info "Python packages installed successfully"

# Save setup info
{
    echo "Setup completed at: $(date)"
    echo "Azure CLI version: $(az version --query '\"azure-cli\"' -o tsv)"
    echo "yq version: $(yq --version)"
    echo "jq version: $(jq --version)"
    echo "Python version: $(python3 --version)"
    echo "pip version: $(pip3 --version)"
    echo "Ansible version: $(ansible --version | head -n1)"
} > /var/log/azure-image-updater-setup.log

log_info "=========================================="
log_info "System-wide package installation complete!"
log_info "=========================================="
echo ""
log_info "Installed packages:"
echo "  - Azure CLI: $(az version --query '\"azure-cli\"' -o tsv)"
echo "  - yq: $(yq --version)"
echo "  - jq: $(jq --version)"
echo "  - Python: $(python3 --version)"
echo "  - pip: $(pip3 --version)"
echo "  - Ansible: $(ansible --version | head -n1)"
echo "  - Python packages: pywinrm, requests, requests-ntlm, requests-credssp"
echo ""
log_info "Setup log saved to: /var/log/azure-image-updater-setup.log"
echo ""
log_info "Next steps:"
echo "  1. Run setup-dedicated-user.sh to create the azureupdater user"
echo "  2. Add SSH public key to /home/azureupdater/.ssh/authorized_keys"
echo "  3. Switch to azureupdater user and run complete-setup.sh"
echo ""
log_info "All done! 🎉"

# Made with Bob
