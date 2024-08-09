# Infrastructure guide to frequent modifications and usage

## Access control in the repository
The three github teams relevant to this repository are as follows (Note, you
won't necessarily have access to see these links):

- [infrastructure-triage](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure) - was used for pre-Adoptium github access, but no longer actively used. Superceded by Temurin Contributor status
- [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure) - the main team of people working on infrastructure issues (Mostly superceded by Temurin->Collaborator access)
- [infrastructure-core](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-core) - higher level of access for system administrators only. Allows control of jenkins agents
- [infrastructure-secret](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-secret) - The group of people who have access to the secrets repository.

## Change approvals

All changes to the repository should be made via GitHub pull requests.

Reviews are required for PRs in this repository. In very special
circumstances such as a clear breakage that has a simple fix available
then a repository admin may override that requirement to push through
a change if no reviewers are available, but in such cases a comment
explaining why must be added to the Pull Request.

## GitHub actions CI jobs

Most Ansible changes are tested automatically with a series of CI jobs:

| Platform | Workflow File | Notes
|---|---|---|
| Centos 6 | [build.yml](./.github/workflows/build.yml) | |
| Alpine 3 | [build.yml](./.github/workflows/build.yml) | |
| macOS 11 | [build_mac.yml](./.github/workflows/build_mac.yml) | |
| Windows (2019 and 2022) | [build_wsl.yml](./.github/workflows/build_wsl.yml) | Uses Windows Subsystem for Linux to run ansible |
| Solaris 10 | [build_vagrant.yml](./.github/workflows/build_vagrant.yml) | Uses Vagrant to run a Solaris image inside a macOS host |

Please note that the Centos 6 & Alpine 3 build jobs, build a docker image but DO NOT PUSH to dockerhub. The job has a seperate configuration section to push to dockerhub when a PR is merged, however that function is disabled, and has been superceded by the Jenkins docker image updater job. The code has been left in place for two reasons, the first to allow the ability to re-enable quickly, and also to test the authentication job for the dockerhub credentials. These credentials are stored in GitHub and are managed by the EF infrastructure team.

## Running the ansible scripts on local machines

The full documentation for running locally is at [ansible/README.md].

### Running the ansible scripts on your current machine

Assuming you have ansible installed on your UNIX-based machine, clone this
repository, create an `inventory` text file with the word `localhost`
and run this from the `ansible` directory:

```sh
ansible-playbook -b -i inventory_file --skip-tags adoptopenjdk,jenkins_user playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```

NOTE: For windows machines you cannot use this method (i.e., as localhost) as ansible does not
run natively on Windows

## Running the ansible scripts on another machine or machines (including Windows)

On an Ansible Control Node create an inventory file with the list of machines you want to set up, then
from the `ansible` directory in this repository run something like this:

```sh
ansible-playbook -b -i inventory_file --skip-tags adoptopenjdk,jenkins_user playbooks/AdoptOpenJDK_Unix_Playbook/main.yml
```

If you don't have ssh logins enabled as root, add `-b -u myusername` to the
command line which will ssh into the target machine as `myusername` and use
`sudo` to gain root access to do the work.

To do this you ideally need to be using key-based ssh logins. If you use a
passphrase on your ssh key use the following to hold the credentials in the
shell:

```sh
eval `` `ssh-agent` ``
ssh-add
```

and if using the `-b` option, ensure that your user has access to `sudo`
without a password to the `root` account (often done by adding it to the `wheel` group)

## What about the builds that use the `dockerBuild` tag?

In addition to the static build machines which we have, there are also
Dockerfiles that are used to build the base images that our build farm uses
for running docker based builds on some of our platforms - this is what we
have at the moment:

| Dockerfile | Image | Platforms  | Where is this built? | In use?
|---|---|---|---|---|
| [Centos7](./ansible/docker/Dockerfile.CentOS7) | [`adoptopenjdk/centos7_build_image`](https://hub.docker.com/r/adoptopenjdk/centos7_build_image) | linux on amd64, arm64, ppc64le | [Jenkins](https://ci.adoptium.net/job/centos7_docker_image_updater/) | Yes
| [RHEL7](./ansible/docker/Dockerfile.RHEL7) | n/a - restricted (*) | s390x | [Jenkins](https://ci.adoptium.net/job/rhel7_docker_image_updater/) | Yes
| [Centos6](./ansible/docker/Dockerfile.CentOS6) | [`adoptopenjdk/centos6_build_image`](https://hub.docker.com/r/adoptopenjdk/centos6_build_image)| linux/amd64 | [GH Actions](.github/workflows/build.yml) | Yes
| [Alpine3](./ansible/docker/Dockerfile.Alpine3) | [`adoptopenjdk/alpine3_build_image`](https://hub.docker.com/r/adoptopenjdk/alpine3_build_image) | linux/x64 & linux/arm64 | [Jenkins](https://ci.adoptium.net/job/centos7_docker_image_updater/) | Yes
| [Ubuntu 20.04 (riscv64 only)](./ansible/docker/Dockerfile.Ubuntu2004-riscv64) | [`adoptopenjdk/ubuntu2004_build_image:linux-riscv64`](https://hub.docker.com/r/adoptopenjdk/ubuntu2004_build_image) | linux/riscv64 | [Jenkins](https://ci.adoptium.net/job/centos7_docker_image_updater/) | Yes
| [Windows Server 2022](./ansible/docker/Dockerfile.win2022) | n/a - restricted | Windows | No

<details>
<summary>(*) - Caveats:</summary>

The RHEL7 image creation for s390x has to be run on a RHEL host using a
container implementation supplied by Red Hat, and we are using RHEL8 for
this as it has a stable implemention.  The image creation requires the
following:

1. The host needs to have an active RHEL subscription
2. The RHEL7 devkit (which cannot be made public) to be available in a tar file under /usr/local on the host as per the name in the Dockerfile
</details>

When a change lands into master, the relevant dockerfiles are built using
the appropriate CI system listed in the table above by configuring them with
the ansible playbooks and - with the exception of the RHEL7 image for s390x -
pushing them up to Docker Hub where they can be consumed by our jenkins
build agents when the `DOCKER_IMAGE` value is defined on the jenkins build
pipelines as configured in the [pipeline_config
files](https://github.com/AdoptOpenJDK/ci-jenkins-pipelines/tree/master/pipelines/jobs/configurations).

### Adding a new dockerBuild dockerhub repository

To add a new repository to the [AdoptOpenJDK dockerhub](https://hub.docker.com/u/adoptopenjdk), a user with `owner` privileges must create the repository initially and then give the automated `adoptopenjdkuser` user read and write permissions.

Users with `owner` privileges include:
- Tim Ellison @tellison
- George Adams @gadams
- Martijn Verburg @karianna

## Adding a new role to the ansible scripts

Other than the dependencies on the machines which come from packages shipped
with the operating system, we generally use individual roles for each piece
of software which we install on the machines. For the main Unix and Windows
playbooks each role has it's own directory and is called from the top level
`main.yml` playbook. They are fairly easy to add and in most cases you can
look at an existing one and copy it.

As far as possibly, give each operation within the role a tag so that it
can either be skipped if someone doesn't want it, or run on its own if
desired.

If something is specific to the adoptopenjdk infrastructure (e.g. setting
host names, or configuring things specific to our setup but aren't required
to be able to run build/test operations) then give the entries in that role
an `adoptopenjdk` tag as well. If you need to do something potentially
adjusting the users' system, use the `dont_remove_system` tag. This is
occasionally required if, for example, we need a specific version of a tool
on the machine that is later than the default, and want to ensure that the
old version does not get invoked by default on the adoptopenjdk machines.
See
[GIT_Source](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/GIT_Source/tasks/main.yml)
as an example

## How do I replicate a build failure?

The build triage team will frequently raise issues if they determine that a
build failure is occurring on a particular system. Assuming it's not a
"system is offline" issue you may wish to replicate the build process
locally. The easiest way to do this is as follows (ideally not as root as
that can mask problems).

```sh
git clone https://github.com/adoptium/temurin-build
cd temurin-build/build-farm
export CONFIGURE_ARGS=--with-native-debug-symbols=none
export BUILD_ARGS="--custom-cacerts false"
./make-adopt-build-farm.sh jdk11u
```

(NOTE: `jdk11u` is the default if nothing is specified)

The two `export` lines are based on the options in the
[Build FAQ](https://github.com/AdoptOpenJDK/ci-jenkins-pipelines/blob/quickbuild/FAQ.md#how-do-i-build-more-quickly)
and speed up the process by not building the debug
symbols and not generating our own certificate bundles.  For most problems,
neither are needed Look at the start of the script for other environment
variables that can be set control what is built - for example `VARIANT` can
be set to `openj9` and others instead of the default of `hotspot`.  The
script uses the appropriate environment configuration files under
`build-form/platform-specific-configurations` to set some options.

## How do I replicate a test failure

Many infrastructure issues (generally
[those tagged as testFail](https://github.com/adoptium/infrastructure/issues?q=is%3Aopen+is%3Aissue+label%3AtestFail) are raised
as the result of failing JDK tests which are believed to be problems
relating to the set up of our machines.  In most cases it is useful to
re-run jobs using the jenkins
[Grinder](https://github.com/AdoptOpenJDK/openjdk-tests/wiki/How-to-Run-a-Grinder-Build-on-Jenkins)
jobs which lets you run almost any test on any machine which is connected to
jenkins.  In most cases `testFail` issues will have a link to the jenkins
job where the failure occurred.  On that job there will be a "Rerun in
Grinder" link if you need to re-run the whole job (which will run lots of
tests and may take a while) or within the job you will find individual
Grinder re-run links for different test subsets.  When you click them, you
can set the `LABEL` to the name of the machine you want to run on if you
want to try and replicate it, or determine which machines it passes and
fails on.

For more information on test case diagnosis, there is a full
[Triage guide](https://github.com/AdoptOpenJDK/openjdk-tests/blob/master/doc/Triage.md)
in the openjdk-tests repository

The values for `TARGET` can be found in the `<testCaseName>` elements of
.the various `playlist.xml` files in the test repositories. It can also be
`jdk_custom` which case you should set the `CUSTOM_TARGET` to the name of
an individual test for example:
`test/jdk/java/lang/invoke/lambda/LambdaFileEncodingSerialization.java`

If you then need to run manually on the machine itself (outside jenkins)
then the process is typically like this.  To avoid the test material not
matching the JDK under test which can lead to false failures when you're
testing a build which isn't the latest (such as a previous GA/the last
release), it is recommended that you check out the appropriate branch for
the last release from the aqa-tests repository in the first line here.

```sh
git clone https://github.com/adoptium/aqa-tests && cd aqa-tests
./get.sh && cd TKG
export TEST_JDK_HOME=<path to JDK which you want to use for the tests>
export BUILD_LIST=openjdk
make compile
make _<target>
```

`BUILD_LIST` depends on the suite you want to run, and can be omitted to build
the tests for everything, but that make take a while and requires `docker`
to be available.  Note that when building the `system` suite, there must be
a java in the path to build the mauve tests.  The final make command runs
the test - it is normally a valid Grinder `TARGET` such as `jdk_net`. There
is more information on running tests yourself in the
[tests repository](https://github.com/AdoptOpenJDK/openjdk-tests/blob/master/doc/userGuide.md#local-testing-via-make-targets-on-the-commandline)

A few examples that test specific pieces of infra-related functionality so useful to be aware of.
These are the parameters to pass into a Grinder job in jenkins. If using
these from the command line instead of a Grinder job there are a couple of
things regarding the information in this table:
- The `TARGET` name should have an underscore `_` prepended to it (like the shell snippet above)
- For custom targets, specify it as a JDK_CUSTOM_TARGET variable to make e.g. `make _jdk_custom JDK_CUSTOM_TARGET=java/lang/invoke/lambda/LambdaFileEncodingSerialization.java`

| `BUILD_LIST` | `TARGET` | `CUSTOM_TARGET` | What does it test? |
| --- | --- | --- | --- |
| `system` | `MachineInfo` | | Basic test that JVM can retrieve system info |
| `functional` | `MBCS_Tests_pref_ja_JP_linux_0` |  | MBCS packages and perl modules |
| `openjdk` | `jdk_custom` | `java/lang/invoke/lambda/LambdaFileEncodingSerialization.java` | en_US.UTF8 locale required
| `openjdk` | `jdk_custom` | `java/lang/ProcessHandle/InfoTest.java.InfoTest` | [Fails if 'sleep' invokes another process](https://github.com/adoptium/infrastructure/pull/2557#issuecomment-1135009749)
| `openjdk` | `jdk_custom` | `javax/imageio/plugins/shared/ImageWriterCompressionTest.java` | Requires fontconfig on linux |
| `system` | `system_custom` | `-test=MixedLoadTest -test-args=timeLimit=10m` | Run a longer systemtest |

(For the last one, that makes use of the system.custom target added via
[this PR](https://github.com/AdoptOpenJDK/openjdk-tests/pull/2234))

## Running The SSL Test Suites
<details>
<summary>Quick Guide To Running The SSL Test Suites</summary>

As part of the fix for infrastructure [issue 3059](https://github.com/adoptium/infrastructure/issues/3059) several new pre-requisite packages have been added to the Unix playbooks, usually things such as (gnutls, gnutls-utils, libnss3.so, libnssutil3.so, nss-devel, nss-tools) or their O/S specific variants. In order to validate that these tests can run following any changes, the following process can be followed once the playbooks have been run successfully:

N.B. Currently the integration testing for other clients is currently not enabed on non-Linux platforms.

1) Clone The Open JDK ssl test suites

```
git clone https://github.com/rh-openjdk/ssl-tests

```

2) Download and install the JDK to be tested, and export the TESTJAVA environment variable.
```
export TESTJAVA=/home/user/jdk17
```

3) Execute The 3 Test Suites To Test External clients, from the directory the git clone of the openjdk ssl test suites was carried out:
```
cd ssl-tests/jtreg-wrappers

Run each of the following test suites:

./ssl-tests-gnutls-client.sh
./ssl-tests-nss-client.sh
./ssl-tests-openssl-client.sh
```

Each script should produce output similar to the below, with some tests being completed, and others skipped, but as long as the tests run without errors, this can be considered a success.

```
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_DHE_RSA_WITH_AES_256_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_DHE_DSS_WITH_AES_256_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_DHE_RSA_WITH_AES_128_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_DHE_DSS_WITH_AES_128_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDH_RSA_WITH_AES_256_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_ECDH_RSA_WITH_AES_128_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_256_GCM_SHA384
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_128_GCM_SHA256
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_256_CBC_SHA256
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_128_CBC_SHA256
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_256_CBC_SHA
PASSED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_RSA_WITH_AES_128_CBC_SHA
IGNORED: SunJSSE/TLSv1.3: TLSv1.2 + TLS_EMPTY_RENEGOTIATION_INFO_SCSV

```

N.B. Due to a missing pre-requisite binary(tstclnt) not being available in the nss packages on Alpine, OpenSuse or SLES, the ssl-tests-nss-client.sh tests can not be run.

</details>

## Testing changes

If you are making a change which might have a negative effect on the
playbooks on other platforms, be sure to run it through the
[VagrantPlaybookCheck](https://ci.adoptium.net/job/VagrantPlaybookCheck/)
job first. This job takes a branch from a fork of the
`adoptium/infrastructure` repository as a parameter and runs the playbooks
against a variety of Operating Systems using Vagrant and the scripts in
[pbTestScripts](https://github.com/adoptium/infrastructure/tree/master/ansible/pbTestScripts)
to validate them.

## Jenkins access

The Adoptium Jenkins server at [https://ci.adoptium.net](https://ci.adoptium.net) is used for all the
builds and testing automation. Since we're as open as possible, general read
access is enabled. For others, access is controlled via github teams (via
the Jenkins `Github Authentication Plugin` as follows. (Links here won't work for
most people as the teams are restricted access)

- [jenkins-admins](https://github.com/orgs/AdoptOpenJDK/teams/jenkins-admins/members) Full administrative access to the jenkins server
- [build-triage](https://github.com/orgs/AdoptOpenJDK/teams/build-triage/members) View and run access to all build jobs (including non-Temurin ones)
- [build](https://github.com/orgs/AdoptOpenJDK/teams/build/members) has the access for performing releases plus the ability to create new jobs
- [build-core](https://github.com/orgs/AdoptOpenJDK/teams/build-core/members) Build members who have access to all jobs including signing
- [build-release](https://github.com/orgs/AdoptOpenJDK/teams/build-release/members) Similar to build-core but without access to create new jobs and run [refactor_openjdk_release_tool](https://ci.adoptium.net/job/build-scripts/job/release/job/refactor_openjdk_release_tool/)
- [installer](https://github.com/orgs/AdoptOpenJDK/teams/installer/members) Users who can access the installer creation jobs
- [test-triage](https://github.com/orgs/AdoptOpenJDK/teams/test-triage/members) has ability to run Grinder jobs
- [test](https://github.com/orgs/AdoptOpenJDK/teams/test/members) has the same access as `build`
- [test-core](https://github.com/orgs/AdoptOpenJDK/teams/test-core/members) As test, but can also perform [TRSS syncs](https://ci.adoptium.net/job/TRSS_Code_Sync/)
- [intrastructure-triage](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-triage-/members) Allows access to [VPC](https://ci.adoptium.net/job/build-scripts/job/release/job/refactor_openjdk_release_tool) and [QPC](https://ci.adoptium.net/view/Tooling/job/VagrantPlaybookCheck/)
- [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure/members) has the same as `build`/`test` plus can manage agent machines
- [infrastructure-core](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-core/members) List of people with admin access to jenkins and infrastructure providers

Note that the special `eclipse-temurin-bot` has explicit read only access to some of the build pipelines jobs too.

For GitHub issue access, this is controlled by the Eclipse Foundation via
the Adoptium projects, and people can be given "contributor" or
"collaborator" access (see
[the wiki](https://github.com/adoptium/adoptium/wiki/Working-with-Eclipse) for
the processes around this) to the repositories which are under each Adoptium
project as per
[this comment](https://github.com/adoptium/infrastructure/issues/2549#issuecomment-1178903957).
Most of the relevant ones are under the
[temurin](https://projects.eclipse.org/projects/adoptium.temurin/who)
or [aqavit](https://projects.eclipse.org/projects/adoptium.aqavit) projects.

## Patching

At Adoptium we use scheduled jobs within [AWX](https://awx2.adoptopenjdk.net/#/home) to execute our platform playbooks onto our machines.
The Unix, Windows, MacOS and AIX playbooks are executed weekly onto our [machines](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) to keep them patched and up to date.

For more information see https://github.com/adoptium/infrastructure/wiki/Ansible-AWX#schedules

## Adding new systems

To add a new system:

1. Ensure there is an issue documenting its creation somewhere (Can just be an existing issue that you add the hostname too so it can be found later
2. Obtain system from the appropriate infrastructure provider
3. Add it to bastillion (requires extra privileges) so that all of the appropriate admin keys are deployed to the system (Can be delayed for expediency by putting AWX key into `~root/.ssh/authorized_keys`)
4. Create a PR to add the machine to [inventory.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) (See NOTE at end of the list)
5. Once merged, run the ansible scripts on it - ideally via AWX (Ensure the project and inventory sources are refreshed, then run the appropriate `Deploy **** playbook` template with a `LIMIT` of the new machine name)
6. Add it to Jenkins and verify a typical job runs on it if you can and add the appropriate tags.  When adding systems for use by test pipelines, verify all of the different types of tests can successfully run on that system by launching an [AQA_Test_Pipeline](https://ci.adoptium.net/job/AQA_Test_Pipeline/) job and setting LABEL parameter to the hostname of the machine.  Once you verify that the AQA_Test_Pipeline runs cleanly, you can add the appropriate test labels (as per LABELs defined in the aqa-tests [PLATFORM_MAP](https://github.com/adoptium/aqa-tests/blob/master/buildenv/jenkins/openjdk_tests#L3)).

NOTE ref inventory: If you are adding a new type of machine (`build`, `perf` etc.) you should also add it to
   [adoptopenjdk_yaml.py](https://github.com/adoptium/infrastructure/blob/master/ansible/plugins/inventory/adoptopenjdk_yaml.py#L45)
   and, if it will be configured via the standard playbooks, add the new type to the
   list at the top of the main playbook files for
   [*IX](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml#L8) and
   [windows](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml#L20)

## "DockerStatic" test systems

The [DockerStatic role](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/tasks/main.yml)
was first implemented in [this PR](https://github.com/adoptium/infrastructure/pull/1925)
and extended through
[this issue](https://github.com/adoptium/infrastructure/issues/1809) and is intended to allow us to make more
efficient use of larger machines.  The role uses a set of Dockerfiles, one
per distribution, which can be used to generate a set of docker machines
that are started, exposed on an ssh port, and connected to jenkins.  They
only contain the minimum required to run test jobs and cannot be used for
builds.  These containers serve several purposes:

1. We have some quite large machines, and this lets us split them up without full virtualisation
2. It allows us to increase the number of distributions we test on
3. We can run multiple tests in parallel on the host with isolation not available when multiple executors are used

The DockerStatic role sets up several containers each with a different
distribution and exposed on a specific port.  It also (at the time of
writing) sets them up to be restricted to two cores and 6Gb of RAM which is
adequate for most tests.  On larger machines it may be appropriate to modify
those values, and we should look at whether we can reasonably autodetect or
parameterize those values. Potentially we could also scale up and create
more than one of each OS on a given host. To set up a host for running these
you can use the
[dockerhost.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/dockerhost.yml)
playbook (Also available via AWX).

Once the static docker containers have been created they are connected into
jenkins with a `test-docker-` prefix. Ideally the description of the machine
in jenkins should list which host it's on, but you can also look up the
IP address of the `test-docker-` system in the inventory.yml file to find
out the host. The inventory file does NOT contain any of the `test-docker-`
systems as they do not have the playbooks run against them. Normally
machines used for this purpose will be prefixed `test-dockerhost-` to
identify them and split them out so they do not have the full playbooks
executed against them in order to keep the host system "clean". In some
cases they may be used as `dockerBuild` hosts too.

Instructions on how to create a static docker container can be found [here](https://github.com/adoptium/infrastructure/tree/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/README.md)

### Dockerhost Patching

At the moment we have the [updatepackages.sh](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/scripts/updatepackages.sh) script which runs weekly on all of our Dockerhost systems via a [scheduled job on our AWX server](https://awx2.adoptopenjdk.net/#/templates/job_template/34?template_search=page_size:20;order_by:name;type:workflow_job_template,job_template) to ensure that the Static Docker containers are patched and up to date. The script is also used to install new test [prerequisite](https://github.com/adoptium/aqa-tests/blob/master/doc/Prerequisites.md#prerequisites) packages onto the containers.

### DockerHost TODO

1. Allow dockerhost.yml playbook to adjust core file settings
2. Add mechanism to deploy differently based on host machine size

## Temporary access to a machine

In some occasions non-infrastructure team members may wish to access a
machine in order to reproduce a test case failure, particularly if they do
not have access to a machine of any given platform, or if the problem
appears to be specific to a particular machine or cloud provider. In this
case, the following procedure should be followed. Example commands are
suitable for most UNIX-based platforms:

1. User should raise a request for access using
   [this template](https://github.com/adoptium/infrastructure/issues/new?assignees=sxa&labels=Temp+Infra+Access&template=machineaccess.md&title=Access+request+for+%3Cyour+username%3E)
   (in general, "Non-privileged" is the correct option to choose
2. Infrastructure team member doing the following steps should assign the issue to themselves
3. For non-privileged users, create an account with a GECOS field referencing the requester and issue number e.g. `useradd -m -c "Stewart Addison 1234" sxa`
4. Add the user's key to `.ssh/authorized_keys` on the machine with the user's public ssh key in it
5. Add a comment to the issue with the username and IP address details
6. The issue should be left open until the user is finished with the machine (if it has been a while, ask them in the issue)
7. Once user is finished, remove the ID (`userdel -r username`)
8. Close the issue
