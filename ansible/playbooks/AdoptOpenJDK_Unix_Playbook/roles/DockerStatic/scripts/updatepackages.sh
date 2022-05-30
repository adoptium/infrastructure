 #!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
containerIds=$(docker ps -q)

for container in $containerIds
do
    OS=$(docker exec -it $container sh -c "cat /etc/os-release" | head -n 1)
    if [[ $OS =~ "CentOS" || $OS =~ "Fedora" || $OS=~ "Red Hat Enterprise Linux" ]]; then
        installCommand="yum -y update"
    elif [[ $OS =~ "Ubuntu" ]]; then
        installCommand="apt-get update && apt-get -y upgrade"
    elif [[ $OS =~ "Alpine" ]]; then
        installCommand="apk update && apk upgrade"
    else 
        echo "Unrecognised OS, skipping package update"
        continue
    fi
    echo "Updating packages for container $container"
    docker exec -it $container sh -c "$installCommand"
    echo "=============================================="
done
