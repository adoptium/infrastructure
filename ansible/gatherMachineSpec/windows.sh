#!/bin/bash

set -e
set -u
set -o pipefail

wmic cpu get caption, deviceid, name, numberofcores, maxclockspeed, status || true
echo ""
systeminfo | findstr /C:"Total Physical Memory" || true