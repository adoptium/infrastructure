# openjdk-infrastructure guide to frequent modifications and usage

## Access control in the repository

The three github teams relevant to this repository are as follows (Note, you
won't necessarily have access to see these links):

- [adoptopenjdk-infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/adoptopenjdk-infrastructure) - write access to the repository which lets you be an official approver of PRs (triage doesn't)
- [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure) - higher level of access for system administrators only
- [admin_infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/admin_infrastructure) - The Admin team - can force through changes without approval etc.

## Commit messages

Wherever possible, prefix the commit message with the area which you are
changing e.g.

- unixPB:
- winPB:
- aixPB:
- ansible:
- vagrant:
- pbTests:
- docs:
- plugins:
- inventory:
- github:

## Change approvals

All changes to the repository should be made via GitHub pull requests.

Reviews are required for PRs in this repository. In very special
circumstances such as a clear breakage that has a simple fix available
then a repository admin may override that requirement to push through
a change if no reviewers are available, but in such cases a comment
explaining why must be added to the Pull Request.

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
[GIT_Source](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/GIT_Source/tasks/main.yml)
as an example

## Testing changes

If you are making a change which might have a negative effect on the
playbooks on other platforms, be sure to run it through the
[VagrantPlaybookCheck](https://ci.adoptopenjdk.net/view/work%20in%20progress/job/VagrantPlaybookCheck/)
job first. This job takes a branch from a fork of the
`openjdk-infrastructure` repository as a parameter and runs the playbooks
against a variety of Operating Systems using Vagrant and the scripts in
[pbTestScripts](https://github.com/AdoptOpenJDK/openjdk-infrastructure/tree/master/ansible/pbTestScripts)
to validate them.

## Jenkins access

The AdoptOpenJDK Jenkins server at [https://ci.adoptopenjdk.net](https://ci.adoptopenjdk.net) is used for all the
builds and testing automation. Since we're as open as possible, general read
access is enabled. For others, access is controlled via github teams (via
the Jenkins `Github Authentication Plugin` as follows. (Links here won't work for
most people as the teams are restricted access)

- [release](https://github.com/orgs/AdoptOpenJDK/teams/jenkins-admins/members) can run and configure jobs and views
- [build](https://github.com/orgs/AdoptOpenJDK/teams/build/members) has the access for `release` plus the ability to create new jobs
- [testing](https://github.com/orgs/AdoptOpenJDK/teams/testing/members) has the same access as `build`
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
4. Create a PR to add the machine to [inventory.yml](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/inventory.yml) (See NOTE at end of the list)
5. Once merged, run the ansible scripts on it - ideally via AWX (Ensure the project and inventory sources are refreshed, then run the appropriate `Deploy **** playbook` template with a `LIMIT` of the new machine name)
6. Add it to jenkins, verify a typical job runs on it if you can and add the appropriate tags

NOTE ref inventory: If you are adding a new type of machine (`build`, `perf` etc.) you should also add it to
   [adoptopenjdk_yaml.py](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/plugins/inventory/adoptopenjdk_yaml.py#L45)
   and, if it will be configured via the standard playbooks, add the new type to the
   list at the top of the main playbook files for
   [*IX](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/main.yml#L8) and
   [windows](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml#L20)
