# Docker Static containers

A verbose description of our static docker container system can be found in the repository's [FAQ](https://github.com/adoptium/infrastructure/blob/master/FAQ.md#dockerstatic-test-systems)

## The purpose of this role
The DockerStatic ansible role provides allows us to automate the setup of our dockerhost machines using the [dockerhost.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml) playbook.

## Our current Dockerhost machines
* [dockerhost-azure-ubuntu2204-x64-1](https://ci.adoptium.net/computer/dockerhost-azure-ubuntu2204-x64-1/)
* [dockerhost-equinix-ubuntu2204-armv8-1](https://ci.adoptium.net/computer/dockerhost-equinix-ubuntu2204-armv8-1/)
* [dockerhost-equinix-ubuntu2404-armv8-1](https://ci.adoptium.net/computer/dockerhost-equinix-ubuntu2404-armv8-1/)
* [dockerhost-marist-ubuntu2404-s390x-1](https://ci.adoptium.net/computer/dockerhost-marist-ubuntu2404-s390x-1/)
* [dockerhost-osuosl-ubuntu2404-ppc64le-1](https://ci.adoptium.net/computer/dockerhost-osuosl-ubuntu2404-ppc64le-1/)
* [dockerhost-skytap-ubuntu2004-ppc64le-1](https://ci.adoptium.net/computer/dockerhost-skytap-ubuntu2004-ppc64le-1/)
* [dockerhost-skytap-ubuntu2204-x64-1](https://ci.adoptium.net/computer/dockerhost-skytap-ubuntu2204-x64-1/) (Generally offline)

## Setting up a new DockerStatic container with ansible (recommended method)

The [dockerhost.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockernode.yml) playbook is used to deploy docker containers onto our dockerhost machines. 

Example usage:

```
ansible-playbook -u root -i <host-file> AdoptOpenJDK_Unix_Playbook
/dockernode.yml -t "deploy" -e "docker_images=u2204,alp319,deb12"
```

The `docker_images` variable is where the user can specify which docker containers to deploy, using the dockerfiles avaiable [here](https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles) (which do get updated regularly).

The `dockerhost.yml` playbook can deploy single, multiple and duplicate containers, for example

```
-e "docker_images=u2204,alp319,u1804,u1804,u1804"
```

will deploy 1 Ubuntu 22.04 container, 1 Alpine 3.19 container and 3 Ubuntu 18.04 containers.

If you would like to build an arm32 container on an arm64 dockerhost, pass the `build_arm32` variable:

```
ansible-playbook -u root -i <host-file> AdoptOpenJDK_Unix_Playbook
/dockernode.yml -t "deploy" -e "docker_images=u2204 build_arm32=yes"
```

## Setting up a new DockerStatic container (manually)

If you would like to setup an individual container on one of these machines, follow these instructions:

* https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles contains Dockerfiles for our current set of docker static containers.

* To setup a new container, choose from the available Dockerfiles your desired OS

* The Dockerfiles are by default written to setup containers with x86_64 architecture. So if you intend to setup a container on an aarch64 box, be sure to modify the Dockerfile accordingly:

  * Change the jdk binary link to one which downloads an aarch64 jdk.

* On your chosen Dockerhost machine run the following commands

`docker build --cpu-period=100000 --cpu-quota=800000 -t  {{ tag }} --memory=8G -f {{ Dockerfile }} .`

`docker run --restart unless-stopped -p {{ PORT }}:22 --cpus=2.0 --memory=6G --detach --name {{ name }} {{ tag }}`

* Finally, go to https://ci.adoptium.net/computer/new and create a new jenkins node for this container.

**NOTE**
If you are creating a new container with the intention of replacing a container with an older OS, follow the above steps to create the new container. Then:

* Stop the old container, `docker stop {{ old container }}` 

* Instead of creating a new node in Jenkins, simply modify the name and PORT number of the replaced node's entry in Jenkins accordingly

## Retiring a DockerStatic container (automated)

The [remove_container.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/remove_container/tasks/main.yml) role facilitates the removal of DockerStatic containers. Usage:

```
ansible-playbook -u root -i hosts AdoptOpenJDK_Unix_Playbook/dockernode.yml -t "remove" -e "delete_nodes=$NODE_1,$NODE_2,$NODE_3,..."
```

The hosts file should include the dockerhost machine which hosts the docker static nodes. Both the Jenkins nodes and the docker containers will be deleted (as long as the Jenkins nodes are idle).

Use the [DockerInventory.json](https://github.com/adoptium/infrastructure/blob/master/ansible/DockerInventory.json) to lookup the docker static node names and the dockerhost machine to which they belong.

After the playbook deletes the nodes, please update the DockerInventory.json file by following the instructions [here](https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic#inventory).

## Pull request checks

Pull requests that change anything in this role are checked by the [DockerStatic Checker](https://github.com/adoptium/infrastructure/blob/master/.github/workflows/check_dockerstatic.yml) GitHub Action:

* If only files in `Dockerfiles/` changed, only those Dockerfiles are built.
* If any other file in the role changes (scripts, tasks, this README...) or the workflow itself changes, every Dockerfile is built.
* Each image is then started and smoke tested: sshd is listening, password logins are disabled, the `jenkins` and `nagios` users and host keys exist, and the JDK and `ant` are installed and run.
* Dockerfiles that download an aarch64 JDK (currently `centstream9` and `centstream10`) are built on an arm64 runner; everything else uses an x64 runner. A new Dockerfile only needs attention here if it is not x64: `select_dockerfiles.sh` detects aarch64 from the JDK download URL.
* The `DockerStatic Check Result` job is a single check that passes if everything built (or nothing needed building) and is the one to require in branch protection.

The same checks can be run locally with either docker or podman (set `CONTAINER_ENGINE=podman` to force an engine):

```
# Which Dockerfiles would CI build for my branch?
scripts/select_dockerfiles.sh origin/master HEAD

# Build and smoke test one Dockerfile (name with or without the "Dockerfile." prefix)
scripts/build_and_test_dockerfile.sh u2404

# Build only, and remove the image afterwards
scripts/build_and_test_dockerfile.sh --build-only --rm-image u2404
```

Run these from this role directory. When testing an aarch64 Dockerfile on an x64 machine the build and static checks still run, but the JDK and `ant` are not executed.

**Podman note:** `Dockerfile.ubi9` and `Dockerfile.ubi10` use the short image names `redhat/ubi9` and `redhat/ubi10`. Docker resolves these to Docker Hub, but podman refuses to resolve short names without a TTY (`short-name resolution enforced but cannot prompt without a TTY`). To build them with podman, point it at Docker Hub for unqualified names using a temporary registries file rather than editing the Dockerfiles:

```
printf 'unqualified-search-registries = ["docker.io"]\n' > /tmp/registries.conf
CONTAINERS_REGISTRIES_CONF=/tmp/registries.conf CONTAINER_ENGINE=podman scripts/build_and_test_dockerfile.sh ubi9
```

## Patching

* The static containers are patched daily using this [script](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/scripts/updatepackages.sh) which runs on a daily cron job on each of the dockerhost machines.
* The script goes into each container and updates every installed package using the container's package manager, yum, apk, apt etc.

## Inventory

The current static docker inventory is listed in [DockerInventory.json](https://github.com/adoptium/infrastructure/blob/master/ansible/DockerInventory.json).

At the moment we update this file manually; we run the [updateDockerStaticInventory.py](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/scripts/updateDockerStaticInventory.py) script from the ansible/playbooks directory to find changes in our static docker inventory in jenkins:

```
python3 AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/scripts/updateDockerStaticInventory.py $jenkins-username $jenkins-api-token
```
This script uses [jenkinsapi](https://jenkinsapi.readthedocs.io/en/latest/) which can be installed with `pip install jenkinsapi`.

If any changes are found, open a new branch and commit these changes in a pull request.

## Scheduled Static Docker Rebuilds

The Adoptium infrastructure team periodically rebuilds all running static Docker containers on each Linux dockerhost. This ensures containers are running from the latest version of their Dockerfile, picking up any base image updates, new tooling, or configuration changes that have been committed since the containers were originally deployed.

Rebuilds are carried out using the [`regenContainers.yml`](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/regenContainers.yml) playbook:

```
ansible-playbook -u root -i <host-file> AdoptOpenJDK_Unix_Playbook/regenContainers.yml
```

We aim to rebuild the running static containers in line with the jenkins server [maintenance schedule](https://github.com/adoptium/infrastructure/#maintenance-window-schedule).
