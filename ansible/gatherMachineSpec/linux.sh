#!/bin/bash

set -e
set -u
set -o pipefail

hwinfo --short || lscpu || true
echo ""
free -h || cat /proc/meminfo || vmstat -s || true