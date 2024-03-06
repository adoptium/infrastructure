#!/bin/bash

FORCE=""
REMOVE=false

Usage(){
  echo "
Usage: ./updateBoxes.sh [options]

Bash script to update vagrant boxes and remove old versions. Running with no parameters will query the system for outdated boxes and update them, but will retain the old boxes.

Options:
  --remove | -r[f]	Remove outdated boxes. ('-rf' will make this non-interactive)
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

if [ $REMOVE  = true ]; then
  vagrant box prune ${FORCE}  
else
  echo "Not checking for old versions of boxes."
fi
