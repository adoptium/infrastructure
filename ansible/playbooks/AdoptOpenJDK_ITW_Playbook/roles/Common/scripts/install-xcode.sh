#!/bin/bash
os_maj_vers=$(sw_vers -productVersion | awk -F "." '{print $1}')
osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

echo 1 = $os_maj_vers
echo 2 = $osx_vers

# Installing the latest Xcode command line tools on 10.9.x or higher

if [[ "$os_maj_vers" -eq 10 ]] && [[ "$osx_vers" -ge 9 ]]; then
  touch "$cmd_line_tools_temp_file";
  PROD=$(softwareupdate -l |
    grep "\*.*Command Line" |
    head -n 1 | awk -F"*" '{print $2}' |
    sed -e 's/^ *//' |
    tr -d '\n')
  softwareupdate -i "$PROD";
fi

# Installing the latest Xcode command line tools on 10.7.x and 10.8.x

# on 10.7/10.8, instead of using the software update feed, the command line tools are downloaded
# instead from public download URLs, which can be found in the dvtdownloadableindex:
# https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-3905972D-B609-49CE-8D06-51ADC78E07BC.dvtdownloadableindex

if ([[ "$os_maj_vers" -eq 10 ]] && [[ "$osx_vers" -eq 7 ]]) || ([[ "$os_maj_vers" -eq 10 ]] && [[ "$osx_vers" -eq 8 ]]);
  if [[ "$osx_vers" -eq 7 ]]; then
    DMGURL=http://devimages.apple.com/downloads/xcode/command_line_tools_for_xcode_os_x_lion_april_2013.dmg
    DMGSHA="20a3e1965c685c6c079ffe89b168c3975c9a106c4b33b89aeac93c8ffa4e0523"
  fi

  if [[ "$osx_vers" -eq 8 ]]; then
    DMGURL=http://devimages.apple.com/downloads/xcode/command_line_tools_for_osx_mountain_lion_april_2014.dmg
    DMGSHA="2ce8cb402efe7a1fe104759d9f32bed3c9b5e9f9db591f047702ae5dc7f3d1ac"
  fi

  TOOLS=cltools.dmg
  curl "$DMGURL" -o "$TOOLS"
  DLSUM=`shasum -a 256 "$TOOLS"|cut -d" " -f1`

  if [[ "$DLSUM" == "$DMGSHA" ]]; then
    TMPMOUNT=`/usr/bin/mktemp -d /tmp/clitools.XXXX`
    hdiutil attach "$TOOLS" -mountpoint "$TMPMOUNT" -nobrowse
    # The "-allowUntrusted" flag has been added to the installer
    # command to accomodate for now-expired certificates used
    # to sign the downloaded command line tools.
    installer -allowUntrusted -pkg "$(find $TMPMOUNT -name '*.mpkg')" -target /
    hdiutil detach "$TMPMOUNT"
    rm -rf "$TMPMOUNT"
    rm "$TOOLS"
  else
    echo "Error - Checksums Do Not Match"
    exit 1
  fi
fi
