#!/bin/bash
set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
containerIds=$(docker ps -q)

commonPackages="gnupg fakeroot fontconfig"
fedoraPackages="procps-ng hostname shared-mime-info"
debianPackages=""
alpinePackages=""

for container in $containerIds
do
    OS=$(docker exec -it $container sh -c "cat /etc/os-release" | head -n 1)
    if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Fedora"* ]] || [[ "$OS" == *"Red Hat Enterprise Linux"* ]]; then
        installCommand="yum -y update && yum -y install $commonPackages $fedoraPackages"
    elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        installCommand="apt-get update && apt-get -y upgrade && apt-get -y install $commonPackages $debianPackages"
    elif [[ "$OS" == *"Alpine"* ]]; then
        installCommand="apk update && apk upgrade && apk --update add $commonPackages $alpinePackages"
    else 
        echo "Unrecognised OS, skipping package update"
        continue
    fi
    echo "Updating packages for container $container"
    echo "Running $installCommand"
    docker exec -it $container sh -c "$installCommand"
    echo "=============================================="
done
