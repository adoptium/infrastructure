# Infrastructure guide to frequent modifications and usage

## Access control in the repository
The three github teams relevant to this repository are as follows (Note, you
won't necessarily have access to see these links):

- [adoptopenjdk-infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/adoptopenjdk-infrastructure) - write access to the repository which lets you be an official approver of PRs (triage doesn't)
- [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure) - higher level of access for system administrators only
- [admin_infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/admin_infrastructure) - The Admin team - can force through changes without approval etc.

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
| macOS 10.15 | [build_mac.yml](./.github/workflows/build_mac.yml) | |
| Windows (2019 and 2022) | [build_wsl.yml](./.github/workflows/build_wsl.yml) | Uses Windows Subsystem for Linux to run ansible |
| Solaris 10 | [build_vagrant.yml](./.github/workflows/build_vagrant.yml) | Uses Vagrant to run a Solaris image inside a macOS host |

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
| [Centos7](./ansible/docker/Dockerfile.CentOS7) | [`adoptopenjdk/centos7_build_image`](https://hub.docker.com/r/adoptopenjdk/centos7_build_image) | linux on amd64, arm64, ppc64le | [Jenkins](https://ci.adoptopenjdk.net/job/centos7_docker_image_updater/) | Yes
| [Centos6](./ansible/docker/Dockerfile.CentOS6) | [`adoptopenjdk/centos6_build_image`](https://hub.docker.com/r/adoptopenjdk/centos6_build_image)| linux/amd64 | [GH Actions](.github/workflows/build.yml) | Yes
| [Alpine3](./ansible/docker/Dockerfile.Alpine3) | [`adoptopenjdk/alpine3_build_image`](https://hub.docker.com/r/adoptopenjdk/alpine3_build_image) | linux/x64 & linux/arm64 | [Jenkins](https://ci.adoptopenjdk.net/job/centos7_docker_image_updater/) | Yes

When a change lands into master, the relevant dockerfiles are built using
the appropriate CI system listed in the table above by configuring them with
the ansible playbooks and pushing them up to Docker Hub where they can be
consumed by our jenkins build agents when the `DOCKER_IMAGE` value is
defined on the jenkins build pipelines as configured in the
[pipeline_config files](https://github.com/AdoptOpenJDK/ci-jenkins-pipelines/tree/master/pipelines/jobs/configurations).

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
then the process is typically like this:

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
these from the command line as per the example above, the `TARGET` name
should have an underscore `_` prepended to it.

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

## Testing changes

If you are making a change which might have a negative effect on the
playbooks on other platforms, be sure to run it through the
[VagrantPlaybookCheck](https://ci.adoptopenjdk.net/job/VagrantPlaybookCheck/)
job first. This job takes a branch from a fork of the
`adoptium/infrastructure` repository as a parameter and runs the playbooks
against a variety of Operating Systems using Vagrant and the scripts in
[pbTestScripts](https://github.com/adoptium/infrastructure/tree/master/ansible/pbTestScripts)
to validate them.

## Jenkins access

The AdoptOpenJDK Jenkins server at [https://ci.adoptopenjdk.net](https://ci.adoptopenjdk.net) is used for all the
builds and testing automation. Since we're as open as possible, general read
access is enabled. For others, access is controlled via github teams (via
the Jenkins `Github Authentication Plugin` as follows. (Links here won't work for
most people as the teams are restricted access)

- [release](https://github.com/orgs/AdoptOpenJDK/teams/jenkins-admins/members) can run and configure jobs and views
- [build](https://github.com/orgs/AdoptOpenJDK/teams/build/members) has the access for `release` plus the ability to create new jobs
- [test](https://github.com/orgs/AdoptOpenJDK/teams/test/members) has the same access as `build`
- [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure/members) has the same as `build`/`testing` plus can manage agent machines
- [jenkins-admins](https://github.com/orgs/AdoptOpenJDK/teams/jenkins-admins/members) as you might expect has access to Administer anything

Some jobs within jenkins, such as the
[build signing job](https://ci.adoptopenjdk.net/job/build-scripts/job/release/job/sign_build)
and [Release tool job](https://ci.adoptopenjdk.net/job/build-scripts/job/release/job/refactor_openjdk_release_tool)
are restricted further via the `Enable project-based security` section of
the job definition. In the case of those two in particular it's `jenkins-admins` and
`release` teams only who have access to them respectively.

## Adding new systems

To add a new system:

1. Ensure there is an issue documenting its creation somewhere (Can just be an existing issue that you add the hostname too so it can be found later
2. Obtain system from the appropriate infrastructure provider
3. Add it to bastillion (requires extra privileges) so that all of the appropriate admin keys are deployed to the system (Can be delayed for expediency by putting AWX key into `~root/.ssh/authorized_keys`)
4. Create a PR to add the machine to [inventory.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) (See NOTE at end of the list)
5. Once merged, run the ansible scripts on it - ideally via AWX (Ensure the project and inventory sources are refreshed, then run the appropriate `Deploy **** playbook` template with a `LIMIT` of the new machine name)
6. Add it to jenkins, verify a typical job runs on it if you can and add the appropriate tags

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

### DockerHost TODO

1. Set up patching cycle
2. Identify ways to redeploy when needed to pick up updates
3. Allow dockerhost.yml playbook to adjust core file settings
4. Add mechanism to deploy differently based on host machine size

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
