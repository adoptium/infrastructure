#!/bin/bash
set -eu

FILEPATH=""
FILELINK=""
SIGPATH=""
SIGLINK=""

usage() {

	echo "Usage of script:
  -f Path to file (cannot be used with -fl)
  -fl Link to file (cannot be used with -f)
  -s Path to signature file (asc/sig) (cannot be used with -sl)
  -sl Link to signature file (asc/sig) (cannot be used with -s)
  -k Key fingerprint"
}

#Verify parameters
while [[ $# -gt 0 ]]; do
  case $1 in
    -f)
      FILEPATH="$2"
      shift 2
      ;;
    -fl)
      FILELINK="$2"
      shift 2
      ;;
    -s)
      SIGPATH="$2"
      shift 2
      ;;
    -sl)
      SIGLINK="$2"
      shift 2
      ;;
    -k)
      KEY="$2"
      shift 2
      ;;
    -*|--*)
      echo "Unknown option $1"
      usage;
      exit 1
      ;;
    *)
      shift
      ;;
  esac
done

if [ ! -z "$FILEPATH" ] && [ ! -z "$FILELINK" ]; then
  echo "Use -f or -fl, not both"
  usage
  exit 1
fi

if [ ! -z "$SIGPATH" ] && [ ! -z "$SIGLINK" ]; then
  echo "Use -s or -sl, not both"
  usage
  exit 1
fi

if [ ! -z "$FILEPATH" ]; then
  if [ -f "$FILEPATH" ]; then
    FILE=$FILEPATH
  else
    echo "The file does not exist"
    exit 1
  fi
elif [ ! -z "$FILELINK" ]; then
  wget -q $FILELINK -O binary.tar.gz
  FILE="binary.tar.gz"
else
  echo "Use either -f or -fl"
  usage
  exit 1
fi

if [ ! -z "$SIGPATH" ]; then
  if [ -f "$SIGPATH" ]; then
    SIG=$SIGPATH
  else
    echo "The signature file does not exist"
    exit 1
  fi
elif [ ! -z "$SIGLINK" ]; then
  wget -q $SIGLINK -O sigfile
  SIG="sigfile"
else
  echo "Use either s or -sl"
  usage
  exit 1
fi

if [ ! -z "$FILE" ] && [ ! -z "$SIG" ] && [ ! -z "$KEY" ]; then
	gpg --keyserver keyserver.ubuntu.com --recv-keys $KEY
	gpg --verify $SIG $FILE
  rm $SIG
else
	echo "Variables not valid"
	usage
	exit 1
fi
