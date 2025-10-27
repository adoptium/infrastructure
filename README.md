# Infrastructure

## Mission Statement

To provide infrastructure for the Adoptium farm that is:

* **Secure** - Infrastructure is private by default and access is granted in a time and access control limited manner and aligns with industry best practices.
* **Consistent** - Infrastructure is consistent in order to produce and release consistent binaries of Eclipse temurin by Adoptium and allow consistency of test results.
* **Repeatable** - Infrastructure can be reproduced by our _infrastructure as code_ to recover from machine outages and replicate across providers for redundancy. 
* **Auditable** - What each host/platform is made up of is publicly accessible _infrastructure as code_.

The end result should be **immutable** hosts, which can be destroyed and reproduced from Ansible playbooks. See
our [Contribution Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md)
on how we implement these goals.

## Related Repositories

* [secrets](https://www.github.com/adoptium/secrets/) - A private repo containing secrets encrypted and managed with `dotgpg`.

## Important Documentation and terminology

* [hosts](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) - Our inventory file as used by ansible, [visualized](https://github.com/adoptium/infrastructure/blob/master/docs/adoptopenjdk.pdf) (now out of date).
* [Ansible at Adoptium](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) - Our hosts are built using Ansible Playbooks.
* [End of support dates](https://github.com/adoptium/infrastructure/wiki/End-of-support-date-for-OS-distributions) for operating systems/distributions which we use.
* [Infrastructure wiki](https://github.com/adoptium/infrastructure/wiki) has infromationon how to set up some of the software we use for infrastructure management.
* [The infrastructure FAQ](FAQ.md) describes how to do various day to day operations and can be used as a "How-to" guide.

Note that in this documentation you will see "machines" and "agents" used. 
Machines refers to the entities provisioned via our infrastructure
providers, each of which runs an operating system kernel.  For some systems
which run containers and act as independents machines with their own [agent
proces in jenkins](https://www.jenkins.io/doc/book/using/using-agents/)
there will be multiple agents on each machine.  Where the term "host" is
used it will typically mean the initial operating system on the machine as
distinct from any containers on that host.

## Contributing

Please visit our `#infrastructure` [Slack Channel](https://adoptium.net/slack) and say hello.
Please read our [Contribution
Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md) before
submitting Pull Requests.

## Members

We list administrative members and their organisation affiliation for maximum transparency.
For adding new team members please follow our [Onboarding Process](ONBOARDING.md).
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

The primary infrastructure team members who manage issues and PRs in this
repository.  This group controls access to certain [jobs in jenkins that are
related to infrastructure](https://ci.adoptium.net/view/Infra/).  Issues and
PR permissions are controlled by membership of the [Eclipse adoptium.temurin
project](https://projects.eclipse.org/projects/adoptium.temurin/who). 
People in that project are committers and able to merge pull requests in
this repository.  In general if you need assistance from a committer, please
post a message into the `#infrastructure` slack channel where one of the
committers should be able to assist you rather than attempting to contact
someone directly.

## Infrastructure Providers

The Adoptium project utilises machines from various different providers. 
These are enumerated in a [separate document](docs/InfrastructureProviders.md)
and on our [sustainers page](https://adoptium.net/en-GB/sustainers)

## BitWarden

The team utilises [Bitwarden](https://bitwarden.com) which is managed by the
Eclipse Foundation.  The credentials for the infrastructure accounts at the
web sites linked above are stored in there and where possible all have MFA
enabled.  If you are part of the infrastructure core team then you will be
able to request access to the Adoptium BitWarden account to manage the hosts
at each provider.

## Host Information and Ansible AWX

Most information about our machines can be found at
[Inventory](ansible/inventory.yml) This file is important not only as a
reference for the team, but is used by our
[AWX server](https://awx.adoptium.net) which is used to ensure the playbooks
are deployed on the machines on a regular basis to keep them up to date

### Types of machines

The infrastructure is divided into a few types of machines and they have different setups

- **Infrastructure** includes the jenkins server and other machines used to perform administrative functions including Jenkins, Ansible AWX, Nagios, Wazuh, and Bastillion.
- **Normal test machines** are configured via the ansible playbooks and have a single jenkins agente running on them.
- **dockerhost machines** are configured to allow work to happen within containers on a large host machine. These will typically have multiple jenkins agents running on them. Thesse are created using the [dockerhost.yml playbook](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml). Dockerhost machines typically run two types of containers:
  - **Static docker containers** are used for testing. The process for deploying these is described in the [DockerStatic role](ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/README.md) which makes use of the files in the Dockerfiles directory under that role. Each static docker container has its own agent definition in jenkins and has a name prefixed `test-docker-`.
  - **Build images** are created and published to both [dockerhub](https://hub.docker.com/u/adoptopenjdk?page=1&search=build_image), [GitHub's container registry](https://github.com/orgs/adoptium/packages/container/package/adoptium_build_image) and azure's container registry (private - windows only). They are created by running the playbooks inside a container of the operating system we build Temurin on using the dockerfiles in [ansible/docker](https://github.com/adoptium/infrastructure/tree/master/ansible/docker). For more details on how these are build, see [the FAQ](https://github.com/adoptium/infrastructure/blob/master/FAQ.md#what-about-the-builds-that-use-the-dockerbuild-tag). Build containers are instantiated during build execution and not retained afterwards in order to meet our secure development requirements. For licensing reasons, Windows build containers are pushed to a private Azure container repository and not made available on dockerhub/ghcr. The jenkins agent for instantiating these containers runs on the host machine.
- **Non-docker build machines** For AIX and Solaris we do not use containers for building. The builds for those machines are named `build-` and are set up with ansible in the same way as the test machines. Note that for Solaris we do not attach the machines directly to jenkins any more and connet to them via a proxy machine (See [this issue](https://github.com/adoptium/infrastructure/issues/3742) for why and [this link](https://github.com/adoptium/temurin-build/blob/master/SOLARIS.md) for how to diagnose those proxy jobs on machines labelled as [buildproxy](https://ci.adoptium.net/label/buildproxy) or [tastproxy](https://ci.adoptium.net/label/testproxy). For Solaris/x64 we use Vagrant VMs on a Linux/x64 dockerhosthost machine (The same one that runs the proxy)

## Dynamic provisioning

In addition to the build containers which are spun up dynamically we have
some support for instantiating short-lived machines on some of our
infrastructure providers.  All of these are configured via the corresponding
[jenkins plugin configuration](https://ci.adoptium.net/cloud) for each
provider:

- **MacStadium Orka** is used for most of our macos build and testing. These images are built using our [packer scripts](https://github.com/adoptium/infrastructure/tree/master/ansible/packer).
- **Azure** has the ability to spin up machines used for build and test by starting a base machine and running a suitable container inside to perform the work.
- in the past we have interfaced with the **OSUOSL OpenStack interface** to perform the same funtionality there, but that is currently not being used.

Careful consideration should be given when deciding whether to add
additional dynamic machines from other providers to this list, as it will
frequently require that a new provider-specific template image is created at
each provider which will have additional maintenance overhead and processes
required to keep them up to date with the playbooks.

## Jenkins

Our jenkins CI server is at [https://ci.adoptium.net].  It co-ordinates the
CI pipelines for [build](https://github.com/adoptium/ci-jenkins-pipelines/) (In
the [build-scripts](https://ci.adoptium.net/job/build-scripts/) folder) and
[test](https://github.com/adoptium/aqa-tests/) (Prefixed `Test_` or
`Grinder`) and various other operations.

### Labels in jenkins

Jenkins agents (machines) are labelled with various names in order to allow
the pipelines to know which jobs can run on each machine.  The labels will
include the operating system and architecture as well as potentially other
information about the machine used for selecting machines to run on.  THis
list gives an example of how we use labels but should not be considered a
comprehensive list.

- Build agents are either:
  - labelled as [build](https://ci.adoptium.net/label/build/) if the machine configured and used directly for building (AIX/Solaris)
  - labelled as [dockerBuild](https://ci.adoptium.net/label/dockerBuild) if the machine is used as a host where ephemeral containers are spun up dynamically, used once and then shut down again. The dockerBuild hosts will frequently also host static docker containers for test to ensure we have good utilisation on those machines.
  - Some dockerBuild machines have a label of [qemustatic](https://ci.adoptium.net/label/qemustatic/) when a dockerBuild machine has the qemu packages installed. This is used for building riscv64 because running in emulation is currently slightly more efficient than running on the native machinas that we have. There are a few others labels used, such as `xlc13` `xlc16` and `xlc17` (examples for AIX) depending on which compilers they have installed.
- build machines are labelled with short names to determine they architecture they can build for e.g. [linux](https://ci.adoptium.net/label/linux/) or [aarch64](https://ci.adoptium.net/label/aarch64/). These can be combined into e.g. [dockerBuild&&linux&&aarch64](https://ci.adoptium.net/label/dockerBuild&&linux&&aarch64/) to show agents which can build for a specific platform.
- For static docker test machines (The ones with names prefixed with `test-docker-` and not listed in the inventory files) they will generally have an additional label of `hw.dockerhost.<name of host>` to help identify which container is on which host. This is used for assisting the admins using the jenkins UI and not by any of the jenkins pipelines.
- For test machines a more hierarchical system is currently used. All machines available for test have the [ci.role.test](https://ci.adoptium.net/label/ci.role.test/) label. Operating system and architecture are determined by labels such as [sw.os.linux](https://ci.adoptium.net/label/sw.os.linux/) and [hw.arch.aarch64](https://ci.adoptium.net/label/hw.arch.aarch64/) and these can be combined as e.g. [ci.role.test&&sw.os.linux&&hw.arch.aarch64](https://ci.adoptium.net/label/ci.role.test&&sw.os.linux&&hw.arch.aarch64/).
- Where further distinction is required we add other custom labels for test machiens e.g.
  - [sw.tool.glibc.2_12](https://ci.adoptium.net/computer/test%2Dibmcloud%2Drhel6%2Dx64%2D1/) (used to stop JDK21+ on x64 being scheduled on those older agents)
  - [sw.os.aix.7_2](https://ci.adoptium.net/computer/test-osuosl-aix72-ppc64-2/) Used to be used to restrict things that wouldn't run on AIX 7.1

There is a long standing issue to [look at unifying the labelling structure
across build and test](https://github.com/adoptium/infrastructure/issues/93)
but that has not made it to the top of anyone's priority list.

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

* Nagios is configured to monitor each machine and report on the status of OS patches required so we can identify if any machine is not self-updating
* Wazuh is used to perform intrusion detection on our infrastructure
* Non-infrastructure machines are configured by ansible to automatically apply all patches. (Sundays at 5am local host time) where possible
* Infrastructure machines are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates
* We do not currently schedule outages to reboot to pick up new kernels.

## Quick start guide to setting up machines manually

Typically our machines are set up using Ansible AWX, but if you need to do
it yourself (for example on a personal machine) here is what you should do
starting from a clone of this repository.  Replace `podman` with `docker` in
these commands if that is your container management tool of choice on your machine:

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
The above should work for most UNIX/Linux machines including macos. AIX has a separate playbook in `AdoptOpenJDK_AIX_Playbook` but otherwise works with the same commands. The `--skip-tags` of `adoptopenjdk` will stop it configuring things that are specific to the adoptium infrastructure, including the reading of things in `/Vendor_Files` which contains some non-public data. If you're not setting up a machine that will go into the adoptium jenkins, then skipping the jenkins tag is appropriate too. Note that if you're skipping the adopopenjdk tags then you can simplify the above by just using the IP address on its own in the hosts file as the name should be unused.

For Windows there are other steps needed as ansible communicates with Windows machines via the WinRM protocol. For full information on the setup for that, and other information on running the playbooks see [The ansible documentation](https://github.com/adoptium/infrastructure/tree/master/ansible#how-do-i-run-the-playbooks-on-a-remote-windows-host)

## Playbook testing

We have several different processes for testing playbook changes.  Firstly
we have the VagrantPlaybookCheck job which runs on a machine with Vagrant
and VirtualBox and runs the playbooks on a clean machine, optionally running
a build and basic test on the machines to ensure they work adequately.  This
can be set up on your local machine if desired.  See the ansible page in the
previous section for how to set it up on different host operating systems.

- **VagrantPlaybookCheck** is our main checking process. It is x64 only ans has support for Windows, Linux and Solaris. Generally you should run this on each PR before merging. There is a checkbox in the PR template to remind you to run it. The scripts and documentation are in [ansible/pbTestScripts](https://github.com/adoptium/infrastructure/tree/master/ansible/pbTestScripts) but in general you can run it on the Adoptium infrastructure via jenkins with the [VagrantPlaybookCheck](https://ci.adoptium.net/job/VagrantPlaybookCheck/) job
- **QEMUPlaybookCheck** is similar but uses qemu to test non-x64 distributions. Note that this has not been actively maintained for a while so does not currently work effectively. The jenkins job is at [QEMUPlaybookCheck](https://ci.adoptium.net/job/QEMUPlaybookCheck/) (If you're interested in helping improve that, see [issue 2121](https://github.com/adoptium/infrastructure/issues/2121)
- Various github actions checks triggered automatically on each PR to run the playbooks on macos, Solaris, build the CentOS6 and Alpine3 build dockerfiles

## Secure development

Most of the Temurin builds are compliant with [SLSA
Build](https://slsa.dev/spec/v1.1/) level 3.  We also aim to follow the
[NIST SSDF](https://csrc.nist.gov/Projects/ssdf) framework and
[OpenSSF Baseline](https://baseline.openssf.org) requirements.  For more
information on secure development at the project see the "Secure Software"
section of the [Adoptium documantation](https://adoptium.net/en-GB/docs).
The Temurin project also participated in an [external security audit](https://adoptium.net/en-GB/news/2024/06/external_audit)
performed by Trail of Bits to validate our secure development practices.
There is a secure development call which is held on every second Monday
for interested parties.

## Further information

For more information on infrastructure related topics please look in the
[docs](docs) directory or for some "howto"/"cheatsheet"-style documentation
take a look at the [Infrastructure FAQ](FAQ.md).
