#!/bin/bash

FORCE=""
REMOVE=false
PROVIDER="virtualbox"

# Remove libvirt storage pool volumes for boxes that were pruned.
# vagrant box prune only removes the ~/.vagrant.d/boxes entry; the libvirt
# storage pool image is left behind and must be deleted manually.
# PRE_VOLUMES is the list of pool volumes captured before the prune ran.
# Any volume whose derived box name is no longer in the vagrant box store is deleted.
cleanupOrphanedLibvirtVolumes()
{
  local pool="$1"
  local preVolumes="$2"

  if [[ -z "$preVolumes" ]]; then
    echo "=== No libvirt box volumes were present before prune; nothing to clean up."
    return
  fi

  echo "=== Checking for orphaned libvirt storage pool volumes in pool '${pool}'"
  while IFS= read -r vol; do
    # Derive the box name from the volume name:
    #   generic-VAGRANTSLASH-ubuntu2204_vagrant_box_image_4.3.12.img  ->  generic/ubuntu2204
    local boxName
    boxName=$(echo "$vol" | sed 's/_vagrant_box_image_.*//' | sed 's/-VAGRANTSLASH-/\//g')

    # Check whether this box still exists in the vagrant box store
    if vagrant box list | grep -q "^${boxName}\s"; then
      echo "=== Skipping volume '$vol': box '${boxName}' is still present"
    else
      echo "=== Deleting orphaned libvirt volume: $vol (box '${boxName}' no longer exists)"
      virsh vol-delete --pool "$pool" "$vol" || echo "WARNING: failed to delete volume $vol"
    fi
  done <<< "$preVolumes"
}

Usage(){
  echo "
Usage: ./updateBoxes.sh [options]

Bash script to update vagrant boxes and remove old versions. Running with no parameters will query the system for outdated boxes and update them, but will retain the old boxes.

Options:
  --remove | -r[f]	Remove outdated boxes. ('-rf' will make this non-interactive)
  --provider | -p <name>	Specify the provider: virtualbox (default) or libvirt
                        	When libvirt is selected, orphaned storage pool volumes are
                        	also cleaned up after box prune.
  --help | -h		Show this help message.
  "
}

while [ "$1" != "" ]; do
  case $1 in
    -r | --remove )
      REMOVE=true
      ;;
    -rf )
      REMOVE=true
      FORCE="--force"
      ;;
    -p | --provider )
      shift
      PROVIDER="$1"
      ;;
    -h | --help )
      Usage; exit 0
      ;;
    * )
      echo "Unrecognised option: $1"; Usage; exit 1
      ;;
  esac
  shift
done

VBList=$(vagrant box outdated --global | awk '/outdated/{print $2}' | sed "s/'//g")

if [[ -z "$VBList" ]]; then
  echo "No boxes require updating."
else
  for x in $VBList
  do
    # Ignore Debian8 for now; See: https://adoptium.slack.com/archives/C53GHCXL4/p1637069847046900
    if [[ "$x" != "roboxes/debian8" ]]; then 
      vagrant box update --box "$x"
    fi
  done
fi

if [ $REMOVE = true ]; then
  if [[ "$PROVIDER" == "libvirt" ]]; then
    # Snapshot pool volumes before prune so we can identify what gets orphaned.
    # vagrant box prune only removes the ~/.vagrant.d/boxes entry; the libvirt
    # storage pool image is left behind and must be deleted manually.
    POOL="default"
    PRE_VOLUMES=$(virsh vol-list "$POOL" 2>/dev/null | awk 'NR>2 && $1!="" { print $1 }' | grep '_vagrant_box_image_' || true)
  fi

  vagrant box prune ${FORCE}

  if [[ "$PROVIDER" == "libvirt" ]]; then
    cleanupOrphanedLibvirtVolumes "$POOL" "$PRE_VOLUMES"
  fi
else
  echo "Not checking for old versions of boxes."
fi

