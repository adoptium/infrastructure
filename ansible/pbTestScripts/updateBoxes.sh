#!/bin/bash

FORCE=""
REMOVE=false

Usage(){
  echo "
Usage: ./updateBoxes.sh [options]

Bash script to update vagrant boxes and remove old versions.

Options:
  --remove | -r[f]	Remove outdated boxes. ('-rf' will force remove outdated boxes)
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
    vagrant box update --box $x
  done
fi

if [ $REMOVE  = true ]; then
  vagrant box prune ${FORCE}  
else
  echo "Not checking for old versions of boxes."
fi
