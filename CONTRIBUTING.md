# Contributing to infrastructure

Thanks for your interest in this project.

## Project description

This repo contains all information about machine maintenance and configurations

* https://github.com/adoptium/infrastructure

## Developer resources

The project maintains the following source code repositories

* https://github.com/adoptium/infrastructure

## Eclipse Contributor Agreement

Before your contribution can be accepted by the project team contributors must
electronically sign the Eclipse Contributor Agreement (ECA).

* http://www.eclipse.org/legal/ECA.php

Commits that are provided by non-committers must have a Signed-off-by field in
the footer indicating that the author is aware of the terms by which the
contribution has been provided to the project. The non-committer must
additionally have an Eclipse Foundation account and must have a signed Eclipse
Contributor Agreement (ECA) on file.

For more information, please see the Eclipse Committer Handbook:
https://www.eclipse.org/projects/handbook/#resources-commit

## Contact

Contact the Eclipse Foundation Webdev team via webdev@eclipse-foundation.org.

## Mission Statement

To provide **secure**, **consistent**, **repeatable**, and **auditable**
infrastructure for the Adoptium farm.

## Infrastructure As Code

The infrastructure project contains:

1. The [Ansible Playbooks](ansible/playbooks) for bootstrapping the build and test hosts (including a way to test Ansible). There are separate playbooks for Windows, UNIX (Including Linux), and AIX plus some others for individual machines.
1. The [Vagrant and QEMU test scripts](ansible/pbTestScripts) for running our full suite of playbook tests across different OS/distribution combinations. For any non-trivial plasybook change it is expected that they should be run against the vagrant tests at a minimum and not cause problems.
1. The [Dockerfiles](ansible/docker) are used to produce images to run builds on. They run the playbooks to create a docker image that is suitable for running the adoptium build and test suites:
   1. Running a subset of tests as GitHub actions (on a PR).
   1. Providing the base images for running builds on Docker containers in our build farm.
1. The top level [Jenkinsfile] is triggered by the [jenkins job](https://ci.adoptium.net/job/centos7_docker_image_updater) that rebuilds the Linux build containers when playbook changes are made and pushes them to dockerhub.
1. In addition the [Dockerfiles in the DockerStatic role](ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/DockerStatic/Dockerfiles) are standalone source files for containers that have a minimal set of requirements to run our test jobs in. They do not use the playbooks.
1. The overriding [Documentation](docs) for the build farm. The [FAQ](FAQ.md) also contains specific things that it is useful to know about the project and its operations, so if you have any questions it is a good place to check.
1. Configuration files for linters etc in the root folder.

## Submitting a contribution to Adoptium/infrastructure

You can propose contributions by sending pull requests (PRs) through GitHub.
Following these guidelines will help us merge your pull requests smoothly:

1. Your pull request is an opportunity to explain both what changes you'd like
   pulled in, but also _why_ you'd like them added. Providing clarity on why
   you want changes makes it easier to accept, and provides valuable context to
   review.  If there is a link to an issue in the PR that contains these details
   that is sufficient.

2. Follow the commit guidelines found below.

3. We encourage you to open a pull request early, and mark it as "Work In
   Progress", by prefixing the PR title with "WIP". This allows feedback to
   start early, and helps create a better end product. Committers will wait
   until after you've removed the WIP prefix to merge your changes.

## Commit Guidelines

The first line describes the change made. It is written in the imperative mood,
and should say what happens when the patch is applied. Keep it short and
simple. The first line should be less than 70 characters, where reasonable,
and should be written in sentence case preferably not ending in a period.
Leave a blank line between the first line and the message body.

The body should be wrapped at 72 characters, where reasonable.

Include as much information in your commit as possible. You may want to include
designs and rationale, examples and code, or issues and next steps. Prefer
copying resources into the body of the commit over providing external links.
Structure large commit messages with headers, references etc. Remember, however,
that the commit message is always going to be rendered in plain text.

When a commit has related issues or commits, explain the relation in the message
body. When appropriate, use the keywords described in the following help article
to automatically close issues.
[Closing Issues Using Keywords](https://help.github.com/articles/closing-issues-using-keywords/)
For example:

```md
Install OpenSSL in windows playbook

OpenSSL is required to compile java on windows, so the OpenSSL role will
ensure the 32bit and 64bit versions are both installed into C:\openjdk

Fixes: #1234
```

All changes should be made to a personal fork of adoptium/infrastructure for making changes so the following standard GitHub workflow should be used.

1. Fork this repository
1. Create a branch off your fork
1. Make the change
1. Test it (see below)
1. Submit a Pull Request

If you are new to git and GitHub and the above makes no sense to you then [this primer may be useful](http://sxatech.blogspot.com/2021/12/git.html).

Only [committers to the adoptium.temurin project](https://projects.eclipse.org/projects/adoptium.temurin/who)
have permission to merge requests for this repo, so if you feel your PR
is not getting enough attention, let one the team know via the
`#infrastructure` slack channel

If you are adding any downloads into the playbooks, please ensure this is
done over https or another secure channel, and that a GPG checksum of the
file is verified if possible, and if not a SHA checksum is performed after
the download has been performed. There are various examples of this in the
playbooks:

- [gmake role](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/gmake/tasks/main.yml) (GPG verification using [package_signature_verification.sh](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/Supporting_Scripts/package_signature_verification.sh)
- [NVidia_Cuda_Toolkit role](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/NVidia_Cuda_Toolkit/tasks/main.yml) which performs a SHA256 check of the download
- The [gcc_11 role](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/gcc_11/tasks/main.yml) is an example of SHA checks when there are multiple downloads for each architecture. It uses checksums stored in a [separate variables file](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Unix_Playbook/roles/gcc_11/vars/main.yml)

Where possible, if you are modifying a playbook to add something new, please also add information saying what it is needed for (it may be useful to link back to a related PR or issue)

## Using Vagrant to test your Ansible scripts

To test changes made to our ansible playbooks, we have the following test jobs which you can use to validate your pull request:

[VagrantPlaybookCheck](https://ci.adoptium.net/view/Tooling/job/VagrantPlaybookCheck/)
   - Tests changes made to the Unix or Windows playbook.
   - Suitable to test changes made which concern the x86_64 tasks of the ansible playbooks
   - Requires authorised access to kick off (ping a member of the [infrastructure](https://github.com/adoptium/infrastructure#infrastructure-core) team if necessary)

[QemuPlaybookCheck](https://ci.adoptium.net/view/Tooling/job/QEMUPlaybookCheck/)
   - Tests changes made to the Unix playbook
   - Suitable to test changes made which concern non x86_64 tasks of the ansible playbooks, such as s390x, arm32, aarch64, riscv and ppc64le
   - Requires authorised access to kick off (ping a member of the [infrastructure](https://github.com/adoptium/infrastructure#infrastructure-core) team if necessary)

`QEMU-playbook-check` pull request Label
   - Similar to [QemuPlaybookCheck](https://ci.adoptium.net/view/Tooling/job/QEMUPlaybookCheck/), but runs as a github workflow
   - Does not require authorised access to kick off, just add the `QEMU-playbook-check` label to your pull request
   - See https://github.com/adoptium/infrastructure/blob/master/.github/workflows/build_qemu.yml for supported platforms

We have some information on running virtual machines to test the playbooks
in the
[ansible directory README](ansible/README.md#running-via-vagrant-and-virtualbox)

We expect developers to test their Ansible changes in a test environment
whether through vagrant, docker or elsewhere in order to ensure there are as
few problems as possible when the PR is ready for review.

[Ansible Scripts Usage Guide](ansible/README.md)

## Commit messages

Wherever possible, prefix the commit message with the area which you are changing e.g.

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
- tools:
- nagios:
- wazuh:

## Further Docs

Project documentation in permanent form (e.g. Build Farm architecture) is stored
in the [docs](docs) folder.
