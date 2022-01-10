# Docker Static containers

## The purpose of this role
The DockerStatic ansible role provides allows us to automate the setup of our dockerhost machines using the [dockerhost.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml) playbook.

## Our current Dockerhost machines
* [docker-packet-ubuntu2004-amd-1](https://ci.adoptopenjdk.net/computer/docker-packet-ubuntu2004-amd-1/)
* [docker-packet-ubuntu2004-intel-1](https://ci.adoptopenjdk.net/computer/docker-packet-ubuntu2004-intel-1/)
* [docker-packet-ubuntu2004-armv8-1](https://ci.adoptopenjdk.net/computer/docker-packet-ubuntu2004-armv8-1/)
* [dockerhost-equinix-ubuntu2004-armv8-1](https://ci.adoptopenjdk.net/computer/dockerhost-equinix-ubuntu2004-armv8-1/)

## Setting up a new DockerStatic container

If you would like to setup an individual container on one of these machines, follow these instructions:

* https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles contains Dockerfiles for our current set of docker static containers.

* To setup a new container, choose from the available Dockerfiles your desired OS

* The Dockerfiles are by default written to setup containers with x86_64 architecture. So if you intend to setup a container on an aarch64 box, be sure to modify the Dockerfile accordingly:

  * Change the jdk binary link to one which downloads an aarch64 jdk.

* On your chosen Dockerhost machine run the following commands

`docker build --cpu-period=100000 --cpu-quota=800000 -t  {{ tag }} --memory=8G -f {{ Dockerfile }} .`

`docker run --restart unless-stopped -p {{ PORT }}:22 --cpus=2.0 --memory=6G --detach --name {{ name }} {{ tag }}`

* Finally, go to https://ci.adoptopenjdk.net/computer/new and create a new jenkins node for this container.

