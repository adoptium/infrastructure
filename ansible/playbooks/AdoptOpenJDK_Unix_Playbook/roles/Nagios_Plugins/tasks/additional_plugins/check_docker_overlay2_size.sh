#!/bin/bash

# Nagios plugin to check the size of /var/lib/docker/overlay2
# Allows passing thresholds as parameters

# Default thresholds (in GB)
DEFAULT_WARN_THRESHOLD=20
DEFAULT_CRIT_THRESHOLD=40

# Folder to check
TARGET_DIR="/var/lib/docker/overlay2/"

# Function to display usage
usage() {
    echo "Usage: $0 -w <warn_threshold_in_GB> -c <crit_threshold_in_GB>"
    echo "  -w: Warning threshold in GB (default: $DEFAULT_WARN_THRESHOLD)"
    echo "  -c: Critical threshold in GB (default: $DEFAULT_CRIT_THRESHOLD)"
    exit 3
}

# Parse command-line arguments
while getopts "w:c:" opt; do
    case $opt in
        w) WARN_THRESHOLD=$OPTARG ;;
        c) CRIT_THRESHOLD=$OPTARG ;;
        *) usage ;;
    esac
done

# Set default thresholds if not provided
WARN_THRESHOLD=${WARN_THRESHOLD:-$DEFAULT_WARN_THRESHOLD}
CRIT_THRESHOLD=${CRIT_THRESHOLD:-$DEFAULT_CRIT_THRESHOLD}

# Convert GB to bytes
WARN_THRESHOLD_BYTES=$((WARN_THRESHOLD * 1024 * 1024 * 1024))
CRIT_THRESHOLD_BYTES=$((CRIT_THRESHOLD * 1024 * 1024 * 1024))

# Check if the directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "CRITICAL: Directory $TARGET_DIR does not exist."
    exit 2
fi

# Get the size of the folder in bytes
FOLDER_SIZE_BYTES=$(du -sb "$TARGET_DIR" 2>/dev/null | awk '{print $1}')

# Handle error if du fails
if [[ -z "$FOLDER_SIZE_BYTES" ]]; then
    echo "CRITICAL: Failed to determine the size of $TARGET_DIR."
    exit 2
fi

# Convert size to GB for display
FOLDER_SIZE_GB=$(echo "scale=2; $FOLDER_SIZE_BYTES / (1024 * 1024 * 1024)" | bc)

# Determine Nagios status
if (( FOLDER_SIZE_BYTES > CRIT_THRESHOLD_BYTES )); then
    echo "CRITICAL: $TARGET_DIR size is ${FOLDER_SIZE_GB}GB (Threshold: >${CRIT_THRESHOLD}GB)"
    exit 2
elif (( FOLDER_SIZE_BYTES > WARN_THRESHOLD_BYTES )); then
    echo "WARNING: $TARGET_DIR size is ${FOLDER_SIZE_GB}GB (Threshold: >${WARN_THRESHOLD}GB)"
    exit 1
else
    echo "OK: $TARGET_DIR size is ${FOLDER_SIZE_GB}GB (Threshold: <=${WARN_THRESHOLD}GB)"
    exit 0
fi
