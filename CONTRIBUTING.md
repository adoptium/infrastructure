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
infrastructure for the AdoptOpenJDK farm.

## Infrastructure As Code

The infrastructure project contains:

1. The [Ansible Playbooks](ansible/playbooks) for bootstrapping the build and test hosts (including a way to test Ansible).
1. The [Vagrant and QEMU test scripts](ansible/pbTestScripts) for running our full suite of playbook tests.
1. The [Dockerfiles](ansible/) are used for:
   1. Running a subset of tests as GitHub actions (on a PR).
   1. Providing the base images for running builds on Docker containers in our build farm.
1. The overriding [Documentation](docs) for the build farm.
1. Configuration files for linters etc in the root folder.

## Submitting a contribution to AdoptOpenJDK/infrastructure

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

All changes should be made to a personal fork of AdoptOpenJDK/infrastructure for making changes.

1. Fork this repository
1. Create a branch off your fork
1. Make the change
1. Test it (see below)
1. Submit a Pull Request

Only reviewers in the
[infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)
team have permission to merge requests for this repo, so if you feel your PR
is not getting enough attention, let one the team know via the
`#infrastructure` slack channel

## Using Vagrant to test your Ansible scripts (Ubuntu based)

We have some information on running virtual machines to test the playbooks
in the
[ansible directory README](ansible/README.md#running-via-vagrant-and-virtualbox)
and we also have the
[VagrantPlaybookCheck](https://ci.adoptopenjdk.net/view/Tooling/job/VagrantPlaybookCheck/)
and [QemuPlaybookCheck](https://ci.adoptopenjdk.net/view/Tooling/job/QEMUPlaybookCheck/)
jobs which you can submit your pull request to in order to validate it on a
clean machine.

We expect developers to test their Ansible changes in a test environment
whether through vagrant or elsewhere in order to ensure there are as few
problems as possible.

[Ansible Scripts Guide](ansible/README.md)

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

## Further Docs

Project documentation in permanent form (e.g. Build Farm architecture) is stored
in the [docs](docs) folder.
