#!/bin/bash

set -e
set -u
set -o pipefail

sysctl -a | grep hw.physicalcpu || true      
echo ""          
sysctl -a | grep machdep.memmap.Conventional || true