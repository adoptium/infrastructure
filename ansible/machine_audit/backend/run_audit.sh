#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTED_INFO_DIR="${SCRIPT_DIR}/collectedInfo"
DEST_DIR="/var/www/jenkins-capacity-report/data/machine_audit"

echo "Running machine audit..."
cd "${SCRIPT_DIR}"
python3 main.py

echo "Copying JSON files to ${DEST_DIR}..."
mkdir -p "${DEST_DIR}"
cp "${COLLECTED_INFO_DIR}"/*.json "${DEST_DIR}/"

echo "Done."
