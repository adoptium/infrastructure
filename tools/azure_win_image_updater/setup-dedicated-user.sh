#!/bin/bash
#
# Create dedicated user for Azure Image Updater
# Run this script as root or with sudo
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
    exit 1
fi

# Configuration
USERNAME="azureupdater"
USER_HOME="/home/${USERNAME}"
PROJECT_DIR="${USER_HOME}/azure-image-updater"

log_info "=========================================="
log_info "Creating Dedicated User for Azure Image Updater"
log_info "=========================================="

# Check if user already exists
if id "${USERNAME}" &>/dev/null; then
    log_warn "User '${USERNAME}' already exists"
    read -p "Do you want to continue and reconfigure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Exiting..."
        exit 0
    fi
else
    # Create user without password (SSH key only)
    log_info "Creating user: ${USERNAME}"
    useradd -m -s /bin/bash "${USERNAME}"
    
    # Lock the password to prevent password authentication
    passwd -l "${USERNAME}"
    
    log_info "User created without password (SSH key authentication only)"
fi

# Create project directory
log_info "Creating project directory: ${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}"

# Copy project files if running from project directory
if [ -f "config.yaml" ] && [ -d "scripts" ]; then
    log_info "Copying project files to ${PROJECT_DIR}"
    cp -r ./* "${PROJECT_DIR}/"
    
    # Don't copy .env if it exists (security)
    if [ -f "${PROJECT_DIR}/.env" ]; then
        rm "${PROJECT_DIR}/.env"
        log_warn "Removed .env file - will need to be recreated"
    fi
else
    log_warn "Not running from project directory - files not copied"
    log_info "You'll need to clone/copy the project to ${PROJECT_DIR}"
fi

# Set ownership
log_info "Setting ownership to ${USERNAME}"
chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}"

log_info "User setup complete - no systemd services or sudoers created"
log_info "This user will be triggered exclusively from Jenkins"

# Create .ssh directory with proper permissions
log_info "Creating .ssh directory for ${USERNAME}..."
mkdir -p "${USER_HOME}/.ssh"
chmod 700 "${USER_HOME}/.ssh"
chown "${USERNAME}:${USERNAME}" "${USER_HOME}/.ssh"

# Create authorized_keys file
touch "${USER_HOME}/.ssh/authorized_keys"
chmod 600 "${USER_HOME}/.ssh/authorized_keys"
chown "${USERNAME}:${USERNAME}" "${USER_HOME}/.ssh/authorized_keys"

log_info "SSH directory created. Add your public key to:"
log_info "  ${USER_HOME}/.ssh/authorized_keys"

# Create a setup completion script for the user
cat > "${PROJECT_DIR}/complete-setup.sh" << 'EOF'
#!/bin/bash
# Run this script as the azureupdater user to complete setup

echo "Completing setup for Azure Image Updater..."

# Run the main setup script
cd ~/azure-image-updater
./setup-ubuntu-node.sh

# Configure credentials
echo ""
echo "Next steps:"
echo "1. Edit .env file with your Azure credentials:"
echo "   nano ~/azure-image-updater/.env"
echo ""
echo "2. Edit config.yaml with your Azure resources:"
echo "   nano ~/azure-image-updater/config.yaml"
echo ""
echo "3. Source the environment file:"
echo "   source ~/azure-image-updater/.env"
echo ""
echo "4. Test the setup:"
echo "   cd ~/azure-image-updater"
echo "   ./scripts/update-image.sh --dry-run"
EOF

chmod +x "${PROJECT_DIR}/complete-setup.sh"
chown "${USERNAME}:${USERNAME}" "${PROJECT_DIR}/complete-setup.sh"

# Summary
log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
echo ""
log_info "User Details:"
echo "  Username: ${USERNAME}"
echo "  Home Directory: ${USER_HOME}"
echo "  Project Directory: ${PROJECT_DIR}"
echo "  Authentication: SSH key only (password disabled)"
echo ""
log_info "Next Steps:"
echo ""
echo "1. Add your SSH public key to authorized_keys:"
echo "   sudo nano ${USER_HOME}/.ssh/authorized_keys"
echo "   # Paste your public key and save"
echo ""
echo "2. Test SSH access:"
echo "   ssh ${USERNAME}@localhost"
echo ""
echo "3. Or switch to the user directly:"
echo "   sudo su - ${USERNAME}"
echo ""
echo "2. Complete the setup:"
echo "   cd ${PROJECT_DIR}"
echo "   ./complete-setup.sh"
echo ""
echo "3. Configure credentials and resources:"
echo "   nano .env"
echo "   nano config.yaml"
echo ""
echo "4. Test the setup:"
echo "   source .env"
echo "   ./scripts/update-image.sh --dry-run"
echo ""
log_info "Jenkins Integration:"
echo "   This user is designed to be triggered from Jenkins only"
echo "   Configure Jenkins to use SSH authentication with this user"
echo "   Add this user's authorized_keys to Jenkins SSH credentials"
echo ""
log_warn "IMPORTANT: Add your SSH public key before attempting to SSH!"
echo "   sudo nano ${USER_HOME}/.ssh/authorized_keys"
echo ""
log_info "=========================================="

# Made with Bob
