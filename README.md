# Infrastructure

## Mission Statement

To provide infrastructure for the Adoptium farm that is:

* **Secure** - Infrastructure is private by default and access is granted in a time and access control limited manner.
* **Consistent** - Infrastructure is consistent in order to produce consistent binaries of Eclipse temurin by Adoptium.
* **Repeatable** - Infrastructure can be reproduced by our _infrastructure as code_ to recover from machine outages and replicate across providers for redundancy. 
* **Auditable** - What each host/platform is made up of is publicly accessible _infrastructure as code_.

The end result should be **immutable** hosts, which can be destroyed and reproduced from Ansible playbooks. See
our [Contribution Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md)
on how we implement these goals.

## Related Repositories

* [secrets](https://www.github.com/adoptium/secrets/) - A private repo containing secrets encrypted and managed with dotgpg.

## Important Documentation

* [hosts](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) - Our inventory file as used by ansible, [visualized](https://github.com/adoptium/infrastructure/blob/master/docs/adoptopenjdk.pdf) (now out of date).
* [Ansible at Adoptium](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) - Our hosts are built using Ansible Playbooks.

## Contributing

Please visit our `#infrastructure` [Slack Channel](https://adoptium.net/slack) and say hello.
Please read our [Contribution
Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md) before
submitting Pull Requests.

## Members

We list administrative members and their organisation affiliation for maximum transparency.
Want to add a new member? Please follow our [Onboarding Process](ONBOARDING.md).
If you want access for yourself, raise an issue in this repository for the
team to consider it - if you are working on an issue here we will generally
be happy to add you to the triage team.

`*` Indicates access to the secrets repo

## [@infrastructure-core](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-core)

Members of this team that holds super user access to our machines to perform maintenance

* [@karianna](https://github.com/karianna) - Martijn Verburg (Microsoft) - *
* [@gdams](https://github.com/gdams) - George Adams (Microsoft) - *
* [@johnoliver](https://github.com/johnoliver) - John Oliver (MicrosoftLJC) - *
* [@sxa](https://github.com/sxa) - Stewart X Addison (IBM) - *
* [@Haroon-Khel](https://github.com/Haroon-Khel) - Haroon Khel (IBM)
* [@steelhead31](https://github.com/steelhead31) - Scott Fryer (IBM)

Former members:

* [@aahlenst](https://github.com/aahlenst) - Andreas Ahlenstorf (ZHAW)
* [@willsparker](https://github.com/Willsparker) - Will Parker (Red Hat)

## [@infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)

The primary infrastructure team who manage issues and PRs in this repository.
This group controls access to certain jobs in jenkins that are related to
infrastructure. Issues and PR permissions are controlled by membership of the
[Eclipse adoptium.temurin project](https://projects.eclipse.org/projects/adoptium.temurin/who).
People in that project are committers and able to merge pull requests
in this repository.  In general if you need assistance from a committer,
please post a message into the `#infrastructure` slack channel where one of
the committers should be able to assist you rather than attempting to contact
someone directly.

## Infrastructure Providers
The Adoptium project is proud to receive contributions from many companies, both in the form of monetary contributions in exchange for membership or in-kind contributions for required resources. The Infrastructure collaborates with the following companies who contribute various kinds of cloud and physical hardware to the Adoptium project.

- [Microsoft Azure](https://portal.azure.com) (x64 and arm)
- IBM Cloud (x64)
- [MacStadium](https://portal.macstadium.com/login) (macos on x86 and arm)
- [MacInCloud](https://portal.macincloud.com) (macos/x64)
- OSUOSL (ppc64/[ppc64le](https://openpower-openstack.osuosl.org/auth/login/)/[aarch64](https://arm-openstack.osuosl.org/auth/login/))
- [Skytap](https://cloud.skytap.com) (ppc64/ppc64le)
- [Marist university](https://linuxone.cloud.marist.edu/oss/#/login) (s390x)

In addition we have some additional capacity primarily for some of the less common platforms:

- [Siteox](https://www.siteox.com) (Solaris/SPARC)
- [AWS](https://console.aws.amazon.com/) (x64 and arm)
- [Scaleway](https://console.scaleway.com/login) (riscv64)

Tutorial videos showing how to provision machines at most of the providers
above, along with some extra videos on using some of our internal services
such as VagrantPlaybookCheck, Ansible AWX and Bastillion are on
[this youtube playlist](https://www.youtube.com/watch?v=M60qElYGQLg&list=PL5XaxCIAi_2nUIzlEc4iaDS0iOViwWhzT)

## BitWarden

The team utilises [Bitwarden](https://bitwarden.com) which is managed by the
Eclipse Foundation.  The credentials for the infrastructure accounts at the
web sites linked above are stored in there and where possible all have MFA
enabled.  If you are part of the infrastructure core team then you will be
able to request access to the Adoptium BitWarden account.

## Host Information and Ansible AWX

Most information about our machines can be found at
[Inventory](ansible/inventory.yml) This file is important not only as a
reference for the team, but is used by our AWX server which is used to
ensure the playbooks are deployed on the machines on a regular basis to keep
them up to date

### Types of systems

The infrastructure is divided into a few types of systems and they have different setups

- **Infrastructure** includes the jenkins server and other systems used to perform administrative functions including Ansible AWX, Nagios, Wazuh, bastillion.
- **Normal test systems** are configured via the ansible playbooks and have a single jenkins agent running on them.
- **dockerhost systems** are configured to allow work to happen within containers on a large host system. These typically run two types of containers. Thesse are created using the [dockerhost.yml playbook](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml).
  - **Static docker containers** are used for testing. The process for deploying these is described in the [DockerStatic role](ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/README.md) which makes use of the files in the Dockerfiles directory under that role. Each static docker container has its own agent definition in jenkins and has a name prefixed `test-docker-`.
  - **Build images** are created and published to dockerhub and GitHub's container registry. They are created by running the playbooks inside a container of the operating system we build Temurin on using the dockerfiles in [ansible/docker](https://github.com/adoptium/infrastructure/tree/master/ansible/docker). For more details on how these are build, see [the FAQ](https://github.com/adoptium/infrastructure/blob/master/FAQ.md#what-about-the-builds-that-use-the-dockerbuild-tag). Build containers are instantiated during build execution and not retained afterwards in order to meet our secure development requirements. For licensing reasons, Windows build containers are pushed to a private Azure container repository and not made available on dockerhub/ghcr.
- **Non-docker build systems** For AIX and Solaris we do not use containers for building. These machines are named `build-` and are set up in the same way as the test systems. Note that for Solaris we do not attach the machines directly to jenkins any more and connet to them via a proxy machine (See [this issue](https://github.com/adoptium/infrastructure/issues/3742) for why. For x64 we use Vagrant VMs on a Linux/x64 dockerhosthost machine.

## Dynamic provisioning

In addition to the build containers which are spun up dynamically we have some support for instantiating short-lived system on some of our infrastructure providers. All of these are configured via the corresponding [jenkins plugin configuration](https://ci.adoptium.net/cloud) for each provider.
- **MacStadium Orka** is used for most of our macos build and testing. These images are built using our [packer scripts](https://github.com/adoptium/infrastructure/tree/master/ansible/packer)
- **Azure** has the ability to spin up systems used for build and test by starting a base system and running a suitable container inside to perform the work
- in the past we have interfaced with the **OSUOSL OpenStack interface** to perform the same funtionality there, but that is currently not being used.

Careful consideration should be given when deciding whether to add additional dynamic systems to this list, as it will frequently require that a new provider-specific template image is created at each provider which will have additional maintenance overhead and processes required to keep them up to date with the playbooks.

## Maintenance Window Schedule

We will aim to perform routine maintenance on the first Tuesday of each
month, generally between 1000-1200 (UTC) for performing jenkins updates.
For more details see the
[maintenance window documentation](docs/JenkinsMaintenance.md)

## Backups

These are taken on a daily basis, and one per month is currently kept
"forever" on our backup server. Details are now in a
[separate document](docs/Backups.md)

## OS Patch Management

* Nagios is configured to monitor each system and report on the status of OS patches required so we can identify if any system is not self-updating
* Wazuh is used to perform intrusion detection on our infrastructure
* Non-infrastructure systems are configured by ansible to automatically apply all patches. (Sundays at 5am local host time) where possible
* Infrastructure systems are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates
* We do not currently schedule outages to reboot to pick up new kernels.

## Quick start guide to setting up machines manually

Typically our machines are set up using Ansible AWX, but if you need to do it yourself (for example on a personal machine) here is what you should do starting from a clone of this repository. Replace `podman` with `docker` in these commands if that's what is on your system:
- **DockerStatic test machine:** `podman build -t aqa_u2404 -f ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles/Dockerfile.u2404`
- **Docker build image:** `podman build --build-arg git_sha=$(git rev-parse --short HEAD) -t c7build -f ansible/docker/Dockerfile.CentOS7 .`

To run the playbooks on a local machine you should first install ansible, then
```
echo "localhost ansible_connection=local" > hosts
ansible-playbook -i hosts --skip-tags=adoptopenjdk,jenkins ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```
To run the playbooks against a remote machine, make sure your ssh keys are appropriately configured to log into the remote machines as root, then:
```
perl -p -i -e 's/hosts: .*/hosts: all/' ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
echo "test-<provider>-<distribution>-<arch>-<number> ansible_host=<ip_address_of_machine>" > hosts
ansible-playbook -i hosts --skip-tags=adoptopenjdk,jenkins ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```
The above should work for most UNIX/Linux machines including macos. AIX has a separate playbook in `AdoptOpenJDK_AIX_Playbook` but otherwise works with the same commands. The `--skip-tags` of `adoptopenjdk` will stop it configuring things that are specific to the adoptium infrastructure, including the reading of things in `/Vendor_Files` which contains some non-public data. If you're not setting up a system that will go into the adoptium jenkins, then skipping the jenkins tag is appropriate too. Note that if you're skipping the adopopenjdk tags then you can simplify the above by just using the IP address on its own in the hosts file as the name should be unused.

For Windows there are other steps needed as ansible communicates with Windows systems via the WinRM protocol. For full information on the setup for that, and other information on running the playbooks see [The ansible documentation](https://github.com/adoptium/infrastructure/tree/master/ansible#how-do-i-run-the-playbooks-on-a-remote-windows-host)

## Playbook testing

We have several different processes for testing playbook changes. Firstly we have the VagrantPlaybookCheck job which runs on a machine with Vagrant and VirtualBox and runs the playbooks on a clean machine, optionally running a build and basic test on the machines to ensure they work adequately. This can be set up on your local machine if desired. See the ansible page in the previous section for how to set it up on different host operating systems.

- **VagrantPlaybookCheck** is our main checking process. It is x64 only ans has support for Windows, Linux and Solaris. Generally you should run this on each PR before merging. There is a checkbox in the PR template to remind you to run it. The scripts and documentation are in [ansible/pbTestScripts](https://github.com/adoptium/infrastructure/tree/master/ansible/pbTestScripts) but in general you can run it on the Adoptium infrastructure via jenkins with the [VagrantPlaybookCheck](https://ci.adoptium.net/job/VagrantPlaybookCheck/) job
- **QEMUPlaybookCheck** is similar but uses qemu to test non-x64 distributions. Note that this has not been actively maintained for a while so does not currently work effectively. The jenkins job is at [QEMUPlaybookCheck](https://ci.adoptium.net/job/QEMUPlaybookCheck/) (If you're interested in helping improve that, see [issue 2121](https://github.com/adoptium/infrastructure/issues/2121)
- Various github actions checks triggered automatically on each PR to run the playbooks on macos, Solaris, build the CentOS6 and Alpine3 build dockerfiles

## Further information

For more information on infrastructure related topics please look in the
[docs](docs) directory or for some "howto"/"cheatsheet"-style documentation
take a look at the [Infrastructure FAQ](FAQ.md).
