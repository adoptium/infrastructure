#!/bin/sh
set -x

# This script runs on the TRSS docker container host, and runs a restart
# if the LOCKFILE is not present.

# Constant definitions to monitor backup in progress.
LOCKFILE="/tmp/trss-backup.lock" # This is created by the run_backups script
MAX_WAIT_MINUTES=180 # Allow MAX 3 hours for backup to run
SLEEP_INTERVAL=300  # in seconds ( period between checks for lock )
WAITED_MINUTES=0

echo "$(date +%T)" : Starting TRSS restart script...

while [ -f "$LOCKFILE" ]; do
  echo ""$(date +%T)" : Backup in progress. Lock file found at $LOCKFILE. Waiting..."
  sleep "$SLEEP_INTERVAL"
  WAITED_MINUTES=$((WAITED_MINUTES + 1))

  if [ "$WAITED_MINUTES" -ge "$MAX_WAIT_MINUTES" ]; then
    echo "$(date +%T)" : Lock still present after $MAX_WAIT_MINUTES minutes. Restart aborted.
    exit 1
  fi
done

echo ""$(date +%T)" : No backup in progress. Proceeding with TRSS restart..."

# Stop TRSS
echo ""$(date +%T)" : Stopping TRSS with 'npm run docker-down'..."
npm run docker-down

# Start TRSS
echo ""$(date +%T)" : Starting TRSS with 'nohup npm run docker &'..."
nohup npm run docker > /dev/null 2>&1 &

echo ""$(date +%T)" : TRSS restart complete."
