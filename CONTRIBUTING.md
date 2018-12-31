# Contributing to AdoptOpenJDK/infrastructure

Thank you for your interest in AdoptOpenJDK/infrastructure!

We welcome and encourage all kinds of contributions to the project, not only
code. This includes bug reports, user experience feedback, assistance in
reproducing issues and more.

## Mission Statement

To provide **secure**, **consistent**, **repeatable**, and **auditable** 
infrastructure for the AdoptOpenJDK farm. See our full [Mission Statement]() for more details.

## Infrastructure Manifesto

* We prefer using prebuilt, Galaxy provided Ansible playbooks over NIHing our own
* We prefer using binaries from official repositories over building our own
* We prefer explicit comments within the code to explain our reasoning over implicit assumptions
* We embrace the Chaos Monkey

## Infrastructure As Code

The infrastructure project contains:

1. The [Ansible Playbooks](ansible/playbooks) for bootstrapping the build and test hosts (including a way to test Ansible)
1. The overriding [Documentation](docs) for the build farm

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
https://help.github.com/articles/closing-issues-using-keywords/
For example:

```
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

Only reviewers in the [admin_infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/admin_infrastructure) team have permission to merge requests for this `openjdk-infrastructure` repo, 
so please ask one of those team members to review your Pull Request. 

# Using Vagrant to test your Ansible scripts (Ubuntu based)

**TODO** This has bit rotteed somewhat and needs to be looked at again.

We expect developers to test their Ansible changes in a test environment.  
A default one for Ubuntu based systems is provided for you via VirtualBox / Vagrant.  
See the guide below.

[Ansible Scripts Guide](ansible/README.md)

# Docs

Project documentation in permanent form (e.g. Build Farm architecture) is stored 
in the [docs](docs) folder.
