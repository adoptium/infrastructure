#!/bin/bash
################################################################################
# Jenkins Application Configuration Restore Script
#
# Restores a backup produced by backup-jenkins-app-config.sh into JENKINS_HOME.
# Each element is stored as its own named tarball inside the outer archive;
# use --skip flags to omit any element during restore.
#
# Elements:
#   config      — root-level XML files (config.xml, credentials.xml, *.xml)
#   users       — users/
#   secrets     — secrets/, .key, secret.key, secret.key.not-so-secret
#   plugins     — plugins/
#   nodes       — nodes/
#   crontab     — jenkins user crontab
#
# Environment-specific XML overrides are applied from restore-config-overrides.env
# (located alongside this script). Any variable left empty in that file is skipped.
# Override the path via: OVERRIDES_FILE=/path/to/overrides.env
#
# Flags:
#   --skip <element> [<element> ...]   Omit one or more elements during restore.
#   --blank-oauth                      Clear the GitHub OAuth client ID and secret
#                                      from config.xml and switch the security realm
#                                      to Jenkins' own user database. Use when
#                                      restoring to a different environment where a
#                                      new OAuth app must be registered. Omit this
#                                      flag when restoring to the same environment.
#
# Usage:
#   sudo bash restore-jenkins-app-config.sh <backup-tarball> [--skip <element> ...] [--blank-oauth]
#
#   Cross-environment restore (new OAuth app needed):
#   sudo bash restore-jenkins-app-config.sh jenkins-app-backup-20260706-113355.tar.gz --blank-oauth
#
#   Same-environment restore (keep OAuth config intact):
#   sudo bash restore-jenkins-app-config.sh jenkins-app-backup-20260706-113355.tar.gz
#
# Override defaults via environment variables:
#   JENKINS_HOME=/path/to/.jenkins sudo bash restore-jenkins-app-config.sh <tarball>
#   JENKINS_USER=jenkins           sudo bash restore-jenkins-app-config.sh <tarball>
################################################################################

set -e

# Configuration — override via environment variables if needed
JENKINS_HOME="${JENKINS_HOME:-/home/jenkins/.jenkins}"
JENKINS_USER="${JENKINS_USER:-jenkins}"
JENKINS_PORT="${JENKINS_PORT:-8080}"

# Path to the env file containing environment-specific XML overrides.
# Defaults to a sibling file in the same directory as this script.
OVERRIDES_FILE="${OVERRIDES_FILE:-$(dirname "$0")/restore-config-overrides.env}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

###############################################
# Argument parsing
###############################################

TARBALL="${1:-}"
if [[ -z "$TARBALL" ]]; then
    echo -e "${RED}Error: No backup tarball specified.${NC}"
    echo ""
    echo "Usage: sudo bash $0 <backup-tarball> [--skip <element> [<element> ...]] [--blank-oauth]"
    echo ""
    echo "Elements: config  users  secrets  plugins  nodes  crontab"
    echo ""
    echo "  Same-env restore  : sudo bash $0 jenkins-app-backup-20260706-113355.tar.gz"
    echo "  Cross-env restore : sudo bash $0 jenkins-app-backup-20260706-113355.tar.gz --blank-oauth"
    exit 1
fi
shift

# Collect --skip values and other flags from remaining args.
# --skip supports space-separated elements:  --skip nodes plugins
# or repeated flags:                         --skip nodes --skip plugins
declare -A SKIP
BLANK_OAUTH=0
VALID_ELEMENTS=("config" "users" "secrets" "plugins" "nodes" "crontab")
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip)
            shift
            if [[ -z "${1:-}" || "${1:-}" == --* ]]; then
                echo -e "${RED}Error: --skip requires at least one element name.${NC}"
                exit 1
            fi
            # Consume all following non-flag words that are valid element names.
            # Stop at any word starting with '--' OR any word that is not a
            # recognised element (e.g. a bare "blank-oauth" typo).
            consumed=0
            while [[ $# -gt 0 && "${1:-}" != --* ]]; do
                elem_valid=0
                for v in "${VALID_ELEMENTS[@]}"; do [[ "$1" == "$v" ]] && elem_valid=1 && break; done
                if [[ $elem_valid -eq 0 ]]; then
                    echo -e "${RED}Error: Unknown element '${1}' passed to --skip.${NC}"
                    echo -e "${YELLOW}Valid elements: ${VALID_ELEMENTS[*]}${NC}"
                    echo -e "${YELLOW}Flags like --blank-oauth must use the -- prefix.${NC}"
                    exit 1
                fi
                SKIP["$1"]=1
                consumed=$((consumed + 1))
                shift
            done
            if [[ $consumed -eq 0 ]]; then
                echo -e "${RED}Error: --skip requires at least one element name.${NC}"
                exit 1
            fi
            ;;
        --blank-oauth)
            BLANK_OAUTH=1
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown argument: $1${NC}"
            exit 1
            ;;
    esac
done

###############################################
# Load config overrides (if present)
###############################################

# Initialise all override variables to empty so they are always defined,
# even if the env file is absent or a variable is omitted from it.
JENKINS_URL=""
JENKINS_ADMIN_EMAIL=""
THINBACKUP_PATH=""
SLACK_TEAM_DOMAIN=""
SLACK_DEFAULT_ROOM=""

if [[ -f "$OVERRIDES_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$OVERRIDES_FILE"
fi

###############################################
# Pre-flight Checks
###############################################

# Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

if [[ ! -f "$TARBALL" ]]; then
    echo -e "${RED}Error: Backup file not found: ${TARBALL}${NC}"
    exit 1
fi

# Verify the Jenkins user exists
if ! id "$JENKINS_USER" &>/dev/null; then
    echo -e "${RED}Error: Jenkins user '${JENKINS_USER}' does not exist.${NC}"
    echo -e "${YELLOW}Create the user before running this script.${NC}"
    exit 1
fi

# Resolve to an absolute path so it stays valid after any cd
TARBALL="$(realpath "$TARBALL")"
TARBALL_BASENAME="$(basename "$TARBALL")"
# Strip .tar.gz to get the inner directory name produced by the backup script
BACKUP_STEM="${TARBALL_BASENAME%.tar.gz}"

RESTORE_TMP="$(mktemp -d /tmp/jenkins-restore-XXXXXX)"
# Ensure temp dir is cleaned up on exit (normal or error)
trap 'rm -rf "$RESTORE_TMP"' EXIT

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Jenkins Application Config Restore${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Backup file  : ${YELLOW}${TARBALL}${NC}"
echo -e "JENKINS_HOME : ${YELLOW}${JENKINS_HOME}${NC}"
echo -e "JENKINS_USER : ${YELLOW}${JENKINS_USER}${NC}"
if [[ ${#SKIP[@]} -gt 0 ]]; then
    echo -e "Skipping     : ${YELLOW}${!SKIP[*]}${NC}"
fi
if [[ -f "$OVERRIDES_FILE" ]]; then
    echo -e "Overrides    : ${YELLOW}${OVERRIDES_FILE}${NC}"
else
    echo -e "Overrides    : ${YELLOW}none (${OVERRIDES_FILE} not found)${NC}"
fi
if [[ "$BLANK_OAUTH" -eq 1 ]]; then
    echo -e "OAuth        : ${YELLOW}will be blanked (--blank-oauth)${NC}"
else
    echo -e "OAuth        : ${YELLOW}restored as-is (pass --blank-oauth for cross-env restore)${NC}"
fi
echo ""

###############################################
# Stop Jenkins
###############################################
echo -e "${GREEN}--- Stopping Jenkins service ---${NC}"
if systemctl is-active --quiet jenkins; then
    systemctl stop jenkins
    echo -e "  Jenkins stopped ${GREEN}✓${NC}"
else
    echo -e "  ${YELLOW}Jenkins was not running — continuing${NC}"
fi
echo ""

###############################################
# Extract outer backup tarball
###############################################
echo -e "${GREEN}--- Extracting backup ---${NC}"
chmod 700 "$RESTORE_TMP"
tar -xzf "$TARBALL" -C "$RESTORE_TMP"
echo -e "  Extracted to ${RESTORE_TMP} ${GREEN}✓${NC}"
echo ""

BACKUP_ROOT="${RESTORE_TMP}/${BACKUP_STEM}"

if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo -e "${RED}Error: Expected directory '${BACKUP_STEM}' not found inside tarball.${NC}"
    echo -e "${YELLOW}Is this a valid backup produced by backup-jenkins-app-config.sh?${NC}"
    exit 1
fi

mkdir -p "$JENKINS_HOME"

# ---------------------------------------------------------------------------
# Helper — apply a sed replacement to a single XML element in a file.
# Replaces the text content of <element>...</element> (single-line form).
# No-op if new_value is empty.
#
# Usage: apply_override <file> <xml-element> <new-value>
# ---------------------------------------------------------------------------
apply_override() {
    local file="$1"
    local element="$2"
    local new_value="$3"

    [[ -z "$new_value" ]] && return 0
    [[ ! -f "$file" ]]   && return 0

    sed -i "s|<${element}>[^<]*</${element}>|<${element}>${new_value}</${element}>|g" "$file"
}

# ---------------------------------------------------------------------------
# Helper — restore a single element from its inner tarball into JENKINS_HOME.
# The 'config' element has special handling: it is extracted to a staging
# directory first so overrides can be applied before copying to JENKINS_HOME.
#
# Usage: restore_element <element-name> <description>
# ---------------------------------------------------------------------------
restore_element() {
    local name="$1"
    local description="$2"
    local inner_tar="${BACKUP_ROOT}/${name}.tar.gz"

    echo -e "${GREEN}--- ${description} ---${NC}"

    if [[ -n "${SKIP[$name]+x}" ]]; then
        echo -e "  ${YELLOW}Skipped (--skip ${name})${NC}"
        echo ""
        return
    fi

    if [[ ! -f "$inner_tar" ]]; then
        echo -e "  ${YELLOW}Not present in backup — skipped${NC}"
        echo ""
        return
    fi

    if [[ "$name" == "config" ]]; then
        # Extract to a staging area, apply overrides, then copy into JENKINS_HOME
        local staging="${RESTORE_TMP}/config-staging"
        mkdir -p "$staging"
        echo -n "  Extracting ${description}... "
        tar -xzf "$inner_tar" -C "$staging" 2>/dev/null \
            && echo -e "${GREEN}✓${NC}" \
            || { echo -e "${RED}✗${NC}"; echo ""; return; }

        _apply_config_overrides "$staging"

        echo -n "  Copying ${description} to JENKINS_HOME... "
        cp -a "${staging}/." "${JENKINS_HOME}/" 2>/dev/null \
            && echo -e "${GREEN}✓${NC}" \
            || echo -e "${RED}✗${NC}"
    else
        echo -n "  Restoring ${description}... "
        tar -xzf "$inner_tar" -C "$JENKINS_HOME" 2>/dev/null \
            && echo -e "${GREEN}✓${NC}" \
            || echo -e "${RED}✗${NC}"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Apply all environment-specific overrides to the staged config XML files.
# Called after config.tar.gz is extracted into the staging directory.
# ---------------------------------------------------------------------------
_apply_config_overrides() {
    local staging="$1"

    local config="${staging}/config.xml"
    local loc_cfg="${staging}/jenkins.model.JenkinsLocationConfiguration.xml"
    local mailer="${staging}/hudson.tasks.Mailer.xml"
    local header="${staging}/io.jenkins.plugins.customizable_header.CustomHeaderConfiguration.xml"
    local thinbackup="${staging}/org.jvnet.hudson.plugins.thinbackup.ThinBackupPluginImpl.xml"
    local slack="${staging}/jenkins.plugins.slack.SlackNotifier.xml"
    local ansible="${staging}/org.jenkinsci.plugins.ansible_tower.AnsibleTower.xml"
    local queue="${staging}/queue.xml"

    echo -e "  ${GREEN}Applying config overrides:${NC}"

    # JENKINS_URL → jenkinsUrl, hudsonUrl, and the logoPath prefix
    if [[ -n "$JENKINS_URL" ]]; then
        apply_override "$loc_cfg"  "jenkinsUrl" "${JENKINS_URL}"
        apply_override "$mailer"   "hudsonUrl"  "${JENKINS_URL}"
        # logoPath has a suffix (path) appended to the base URL — replace only the URL prefix
        if [[ -f "$header" ]]; then
            local logo_suffix
            logo_suffix=$(grep -oP '(?<=<logoPath>)[^<]*' "$header" | sed 's|.*/userContent|/userContent|' || true)
            if [[ -n "$logo_suffix" ]]; then
                local new_logo="${JENKINS_URL%/}${logo_suffix}"
                apply_override "$header" "logoPath" "${new_logo}"
            else
                # No userContent suffix found — replace the whole value
                apply_override "$header" "logoPath" "${JENKINS_URL}"
            fi
        fi
        echo -e "    JENKINS_URL            → ${JENKINS_URL} ${GREEN}✓${NC}"
    else
        echo -e "    JENKINS_URL            — ${YELLOW}skipped (empty)${NC}"
    fi

    # JENKINS_ADMIN_EMAIL → adminAddress
    if [[ -n "$JENKINS_ADMIN_EMAIL" ]]; then
        apply_override "$loc_cfg" "adminAddress" "${JENKINS_ADMIN_EMAIL}"
        echo -e "    JENKINS_ADMIN_EMAIL    → ${JENKINS_ADMIN_EMAIL} ${GREEN}✓${NC}"
    else
        echo -e "    JENKINS_ADMIN_EMAIL    — ${YELLOW}skipped (empty)${NC}"
    fi

    # THINBACKUP_PATH → backupPath
    if [[ -n "$THINBACKUP_PATH" ]]; then
        apply_override "$thinbackup" "backupPath" "${THINBACKUP_PATH}"
        echo -e "    THINBACKUP_PATH        → ${THINBACKUP_PATH} ${GREEN}✓${NC}"
    else
        echo -e "    THINBACKUP_PATH        — ${YELLOW}skipped (empty)${NC}"
    fi

    # SLACK_TEAM_DOMAIN → teamDomain
    if [[ -n "$SLACK_TEAM_DOMAIN" ]]; then
        apply_override "$slack" "teamDomain" "${SLACK_TEAM_DOMAIN}"
        echo -e "    SLACK_TEAM_DOMAIN      → ${SLACK_TEAM_DOMAIN} ${GREEN}✓${NC}"
    else
        echo -e "    SLACK_TEAM_DOMAIN      — ${YELLOW}skipped (empty)${NC}"
    fi

    # SLACK_DEFAULT_ROOM → room
    if [[ -n "$SLACK_DEFAULT_ROOM" ]]; then
        apply_override "$slack" "room" "${SLACK_DEFAULT_ROOM}"
        echo -e "    SLACK_DEFAULT_ROOM     → ${SLACK_DEFAULT_ROOM} ${GREEN}✓${NC}"
    else
        echo -e "    SLACK_DEFAULT_ROOM     — ${YELLOW}skipped (empty)${NC}"
    fi

    # Ansible Tower — always blanked (not used in this environment)
    if [[ -f "$ansible" ]]; then
        sed -i 's|<towerURL>[^<]*</towerURL>|<towerURL></towerURL>|g'                             "$ansible"
        sed -i 's|<towerDisplayName>[^<]*</towerDisplayName>|<towerDisplayName></towerDisplayName>|g' "$ansible"
        echo -e "    Ansible Tower fields   → blanked ${GREEN}✓${NC}"
    fi

    # Build queue — always cleared on restore to avoid stale queued jobs
    if [[ -f "$queue" ]]; then
        printf '<?xml version='"'"'1.1'"'"' encoding='"'"'UTF-8'"'"'?>\n<queue>\n  <discoverableItems/>\n  <blockedProjects/>\n  <buildableItems/>\n  <pendingItems/>\n</queue>\n' > "$queue"
        echo -e "    Build queue            → cleared ${GREEN}✓${NC}"
    fi

    # GitHub OAuth — only blanked when --blank-oauth is passed.
    # Clears clientID and clientSecret from config.xml and replaces the
    # GitHub security realm with Jenkins' own user database so the instance
    # is accessible immediately while a new OAuth app is registered.
    if [[ "$BLANK_OAUTH" -eq 1 ]] && [[ -f "$config" ]]; then
        # The securityRealm block spans multiple lines so use python for a
        # reliable multiline replacement rather than fragile sed tricks.
        python3 - "$config" <<'PYEOF'
import re, sys
path = sys.argv[1]
content = open(path).read()
# Blank OAuth credentials
content = re.sub(r'<clientID>[^<]*</clientID>', '<clientID></clientID>', content)
content = re.sub(r'<clientSecret>[^<]*</clientSecret>', '<clientSecret></clientSecret>', content)
# Replace the GitHub security realm block with Jenkins' own user database
content = re.sub(
    r'<securityRealm\s+class="org\.jenkinsci\.plugins\.GithubSecurityRealm"[^>]*>.*?</securityRealm>',
    '<securityRealm class="hudson.security.HudsonPrivateSecurityRealm">'
    '<disableSignup>false</disableSignup>'
    '<enableCaptcha>false</enableCaptcha>'
    '</securityRealm>',
    content,
    flags=re.DOTALL
)
# Grant Hudson.Administer to the local admin user if not already present.
# The backup's authorization matrix only grants admin to GitHub groups —
# the local admin account needs an explicit USER permission to see Manage Jenkins.
administer_perm = '<permission>USER:hudson.model.Hudson.Administer:admin</permission>'
if administer_perm not in content:
    content = content.replace(
        '<permission>GROUP:hudson.model.Hudson.Administer:AdoptOpenJDK*jenkins-admins</permission>',
        '<permission>GROUP:hudson.model.Hudson.Administer:AdoptOpenJDK*jenkins-admins</permission>\n    ' + administer_perm,
        1
    )
    # Fallback: if that exact group line isn't present, insert before </authorizationStrategy>
    if administer_perm not in content:
        content = content.replace(
            '</authorizationStrategy>',
            '    ' + administer_perm + '\n  </authorizationStrategy>',
            1
        )
open(path, 'w').write(content)
PYEOF
        echo -e "    GitHub OAuth           → blanked, switched to Jenkins user DB ${GREEN}✓${NC}"
        echo -e "    admin permissions      → Hudson.Administer granted to local admin ${GREEN}✓${NC}"
        echo -e "    ${YELLOW}Note: log in at /login and reconfigure OAuth under Manage Jenkins.${NC}"
    elif [[ "$BLANK_OAUTH" -eq 0 ]]; then
        echo -e "    GitHub OAuth           — restored as-is (--blank-oauth not set)"
    fi
}

###############################################
# Restore individual elements
###############################################
restore_element "config"      "Core configuration + root-level XMLs"
restore_element "users"       "Users"
restore_element "secrets"     "Secrets and encryption keys"
restore_element "plugins"     "Plugins"
restore_element "nodes"       "Nodes (agents)"

###############################################
# Restore Jenkins user crontab
###############################################
echo -e "${GREEN}--- Jenkins crontab ---${NC}"
if [[ -n "${SKIP[crontab]+x}" ]]; then
    echo -e "  ${YELLOW}Skipped (--skip crontab)${NC}"
elif [[ ! -f "${BACKUP_ROOT}/crontab.txt" ]]; then
    echo -e "  ${YELLOW}Not present in backup — skipped${NC}"
else
    CRONTAB_FILE="${BACKUP_ROOT}/crontab.txt"
    # Skip installing if the file only contains a "no crontab" comment
    if grep -qvE '^\s*#|^\s*$' "$CRONTAB_FILE"; then
        crontab -u "$JENKINS_USER" "$CRONTAB_FILE"
        echo -e "  Crontab restored ${GREEN}✓${NC}"
    else
        echo -e "  ${YELLOW}Crontab file is empty/comment-only — skipped${NC}"
    fi
fi
echo ""

###############################################
# Fix ownership across all restored files
###############################################
echo -e "${GREEN}--- Fixing ownership ---${NC}"
chown -R "${JENKINS_USER}:${JENKINS_USER}" "$JENKINS_HOME"
echo -e "  Ownership set to ${JENKINS_USER} ${GREEN}✓${NC}"
echo ""

###############################################
# Create local admin user (--blank-oauth only)
###############################################
# When --blank-oauth is used the GitHub OAuth realm is replaced with Jenkins'
# own user database. The backup only contains GitHub OAuth users (no local
# password hashes), so a fresh local admin account must be created from scratch.
RESET_PASSWORD=""
if [[ "$BLANK_OAUTH" -eq 1 ]]; then
    echo -e "${GREEN}--- Creating local admin user ---${NC}"

    # Generate a random 16-character alphanumeric password and write it to a
    # temp file — never interpolated into shell strings to avoid quoting issues.
    RESET_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    PASS_TMP=$(mktemp)
    printf '%s' "$RESET_PASSWORD" > "$PASS_TMP"

    # Produce a bcrypt hash (cost 10). Jenkins requires the $2a$ variant.
    # python3-bcrypt produces $2b$; htpasswd produces $2y$ — both normalised.
    HASHED=""
    if python3 -c "import bcrypt" 2>/dev/null; then
        HASHED=$(python3 - "$PASS_TMP" <<'PYEOF'
import bcrypt, sys
password = open(sys.argv[1], 'rb').read()
hashed = bcrypt.hashpw(password, bcrypt.gensalt(10)).decode()
# Jenkins requires $2a$ — python bcrypt emits $2b$
print(hashed.replace('$2b$', '$2a$', 1))
PYEOF
)
    elif command -v htpasswd &>/dev/null; then
        HASHED=$(htpasswd -bnBC 10 "" "$(cat "$PASS_TMP")" \
            | tr -d ':\n' \
            | sed 's/\$2y\$/\$2a\$/; s/\$2b\$/\$2a\$/')
    else
        echo -e "  ${YELLOW}Warning: neither python3-bcrypt nor htpasswd found.${NC}"
        echo -e "  ${YELLOW}Install python3-bcrypt or apache2-utils and re-run.${NC}"
        RESET_PASSWORD=""
    fi
    rm -f "$PASS_TMP"

    if [[ -n "$RESET_PASSWORD" && -n "$HASHED" ]]; then
        # Write the user into the legacy plain-name directory (users/admin/).
        # Jenkins on startup auto-migrates this to the HMAC-keyed hashed
        # directory name and writes users.xml itself — this is more reliable
        # than trying to predict the HMAC hash externally, which requires
        # reading Jenkins' per-instance secret from secrets/.
        #
        # Remove any stale hashed admin dir left from a previous attempt so
        # there is no conflict during migration.
        find "${JENKINS_HOME}/users" -maxdepth 1 -name 'admin_*' -exec rm -rf {} + 2>/dev/null || true
        rm -f "${JENKINS_HOME}/users/users.xml"
        ADMIN_USER_DIR="${JENKINS_HOME}/users/admin"
        mkdir -p "$ADMIN_USER_DIR"

        # Write user config.xml via Python — avoids shell expansion of the
        # bcrypt hash ($2a$10$...) which would corrupt it in a heredoc.
        python3 - "$ADMIN_USER_DIR/config.xml" "$HASHED" <<'PYEOF'
import sys
user_xml_path, hashed = sys.argv[1], sys.argv[2]
with open(user_xml_path, 'w') as f:
    f.write(
        "<?xml version='1.1' encoding='UTF-8'?>\n"
        "<user>\n"
        "  <version>10</version>\n"
        "  <id>admin</id>\n"
        "  <fullName>admin</fullName>\n"
        "  <properties>\n"
        "    <hudson.security.HudsonPrivateSecurityRealm_-Details>\n"
        "      <passwordHash>#jbcrypt:" + hashed + "</passwordHash>\n"
        "    </hudson.security.HudsonPrivateSecurityRealm_-Details>\n"
        "    <jenkins.security.ApiTokenProperty>\n"
        "      <tokenStore><tokenList/></tokenStore>\n"
        "    </jenkins.security.ApiTokenProperty>\n"
        "    <hudson.model.TimeZoneProperty/>\n"
        "  </properties>\n"
        "</user>\n"
    )
PYEOF

        chown -R "${JENKINS_USER}:${JENKINS_USER}" "$ADMIN_USER_DIR"
        echo -e "  local admin user created (users/admin/ — Jenkins will migrate on startup) ${GREEN}✓${NC}"
    fi
    echo ""
fi

###############################################
# Start Jenkins
###############################################
echo -e "${GREEN}--- Starting Jenkins service ---${NC}"
systemctl daemon-reload
systemctl enable --quiet jenkins
systemctl start jenkins
echo -e "  Jenkins started ${GREEN}✓${NC}"
echo ""

echo -e "${GREEN}--- Waiting for Jenkins to be ready (port ${JENKINS_PORT}) ---${NC}"
RETRIES=30
DELAY=10
for ((i = 1; i <= RETRIES; i++)); do
    if curl -sf "http://localhost:${JENKINS_PORT}/login" -o /dev/null; then
        echo -e "  Jenkins is ready ${GREEN}✓${NC}"
        break
    fi
    if [[ $i -eq $RETRIES ]]; then
        echo -e "${YELLOW}Warning: Jenkins did not respond after $((RETRIES * DELAY))s.${NC}"
        echo -e "${YELLOW}Check: systemctl status jenkins${NC}"
        break
    fi
    echo -e "  Waiting... (attempt ${i}/${RETRIES})"
    sleep "$DELAY"
done
echo ""

###############################################
# Summary
###############################################
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Restore Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Backup file  : ${GREEN}${TARBALL_BASENAME}${NC}"
echo -e "Jenkins Home : ${GREEN}${JENKINS_HOME}${NC}"
echo -e "Jenkins URL  : ${GREEN}http://localhost:${JENKINS_PORT}${NC}"
if [[ ${#SKIP[@]} -gt 0 ]]; then
    echo -e "Skipped      : ${YELLOW}${!SKIP[*]}${NC}"
fi
echo ""
echo -e "${YELLOW}Note: If secrets were restored, ensure the Jenkins URL and${NC}"
echo -e "${YELLOW}credentials configuration still matches this environment.${NC}"
if [[ -n "$JENKINS_URL" ]]; then
    echo -e "${YELLOW}Jenkins URL override was applied — register a matching GitHub OAuth app${NC}"
    echo -e "${YELLOW}at ${JENKINS_URL}securityRealm/finishLogin if using GitHub auth.${NC}"
fi
if [[ -n "$RESET_PASSWORD" ]]; then
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  Admin password was reset (--blank-oauth)        │${NC}"
    echo -e "${YELLOW}│                                                   │${NC}"
    echo -e "${YELLOW}│  Username : admin                                 │${NC}"
    echo -e "${YELLOW}│  Password : ${GREEN}${RESET_PASSWORD}${YELLOW}                    │${NC}"
    echo -e "${YELLOW}│                                                   │${NC}"
    echo -e "${YELLOW}│  Change this password after first login.          │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────┘${NC}"
fi
echo ""

# Made with Bob
