#!/bin/bash
################################################################################
# Jenkins Application Configuration Backup Script
#
# Captures Jenkins application-level configuration from JENKINS_HOME.
# Explicitly excludes jobs/, workspace/, cache/, logs/ and fingerprints/ —
# these are either too large, ephemeral, or managed separately.
#
# Each element is archived as its own named tarball inside the outer archive,
# allowing the restore script to selectively omit individual elements:
#
#   config.tar.gz                — config.xml + credentials.xml + root *.xml
#   users.tar.gz                 — users/
#   secrets.tar.gz               — secrets/, .key, secret.key, secret.key.not-so-secret
#   plugins.tar.gz               — plugins/
#   nodes.tar.gz                 — nodes/
#   crontab.txt                  — jenkins user crontab (plain text)
#
# Usage:
#   sudo bash backup-jenkins-app-config.sh
#
# Override defaults via environment variables:
#   JENKINS_HOME=/path/to/jenkins sudo bash backup-jenkins-app-config.sh
#   JENKINS_USER=jenkins sudo bash backup-jenkins-app-config.sh
################################################################################

set -e

# Configuration — override via environment variables if needed
JENKINS_HOME="${JENKINS_HOME:-/home/jenkins/.jenkins}"
JENKINS_USER="${JENKINS_USER:-jenkins}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="jenkins-app-backup-${TIMESTAMP}"
TARBALL="${BACKUP_DIR}.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check JENKINS_HOME exists
if [ ! -d "$JENKINS_HOME" ]; then
    echo -e "${RED}Error: JENKINS_HOME not found at $JENKINS_HOME${NC}"
    echo -e "${YELLOW}Override with: JENKINS_HOME=/path/to/.jenkins sudo bash $0${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins Application Config Backup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "JENKINS_HOME : ${YELLOW}${JENKINS_HOME}${NC}"
echo -e "JENKINS_USER : ${YELLOW}${JENKINS_USER}${NC}"
echo -e "Output       : ${YELLOW}${TARBALL}${NC}"
echo ""

mkdir -p "$BACKUP_DIR"

# Helper — create a named tarball from one or more source paths.
# Files/dirs that don't exist are silently skipped; if nothing exists the
# tarball is not created and the element is marked as skipped.
#
# Usage: pack_element <dest-tarball> <description> <src1> [<src2> ...]
pack_element() {
    local dest="$1"
    local description="$2"
    shift 2
    local sources=("$@")

    local existing=()
    for src in "${sources[@]}"; do
        [ -e "$src" ] && existing+=("$src")
    done

    if [[ ${#existing[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}Skipping ${description} (nothing found)${NC}"
        return
    fi

    echo -n "  Backing up ${description}... "

    # Build tar args: each source is expressed as -C <parent> <basename>
    local tar_args=()
    for src in "${existing[@]}"; do
        tar_args+=(-C "$(dirname "$src")" "$(basename "$src")")
    done

    tar -czf "$dest" "${tar_args[@]}" 2>/dev/null \
        && echo -e "${GREEN}✓${NC}" \
        || echo -e "${RED}✗${NC}"
}

# ---------------------------------------------------------------------------
# Core config XML files
# ---------------------------------------------------------------------------
echo -e "${GREEN}--- Core configuration + root-level XMLs ---${NC}"

# Collect every *.xml in JENKINS_HOME root
xml_sources=()
for xml_file in "$JENKINS_HOME"/*.xml; do
    [ -e "$xml_file" ] && xml_sources+=("$xml_file")
done

pack_element \
    "$BACKUP_DIR/config.tar.gz" \
    "config XMLs (config.xml, credentials.xml, all root *.xml)" \
    "${xml_sources[@]}"

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Users ---${NC}"
pack_element \
    "$BACKUP_DIR/users.tar.gz" \
    "users/" \
    "$JENKINS_HOME/users"

# ---------------------------------------------------------------------------
# Secrets and encryption keys
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Secrets and encryption keys ---${NC}"
pack_element \
    "$BACKUP_DIR/secrets.tar.gz" \
    "secrets/, .key, secret.key, secret.key.not-so-secret" \
    "$JENKINS_HOME/secrets" \
    "$JENKINS_HOME/.key" \
    "$JENKINS_HOME/secret.key" \
    "$JENKINS_HOME/secret.key.not-so-secret"

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Plugins ---${NC}"
pack_element \
    "$BACKUP_DIR/plugins.tar.gz" \
    "plugins/ (this may take a moment)" \
    "$JENKINS_HOME/plugins"

# ---------------------------------------------------------------------------
# Nodes (agents)
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Nodes (agents) ---${NC}"
pack_element \
    "$BACKUP_DIR/nodes.tar.gz" \
    "nodes/" \
    "$JENKINS_HOME/nodes"

# ---------------------------------------------------------------------------
# Jenkins user crontab
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Jenkins crontab ---${NC}"
echo -n "  Backing up jenkins user crontab... "
crontab -u "$JENKINS_USER" -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null \
    || echo "# No crontab for $JENKINS_USER" > "$BACKUP_DIR/crontab.txt"
echo -e "${GREEN}✓${NC}"

# ---------------------------------------------------------------------------
# Package everything into the final outer tarball
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}--- Creating outer tarball ---${NC}"
tar -czf "$TARBALL" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

FILESIZE=$(du -h "$TARBALL" | cut -f1)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Archive  : ${GREEN}${TARBALL}${NC}"
echo -e "Size     : ${GREEN}${FILESIZE}${NC}"
echo ""
echo "Contents of the archive:"
echo "  tar -tzf $TARBALL"
echo ""
echo "To extract:"
echo "  tar -xzf $TARBALL"
echo ""
echo -e "${YELLOW}Note: secrets/ and key files are included in secrets.tar.gz.${NC}"
echo -e "${YELLOW}Store this archive securely — it contains encryption keys.${NC}"
echo ""

# Made with Bob
