# Contribution Guide

The infrastructure project contains:

1. The [Ansible Playbooks](ansible/playbooks) for bootstrapping the build and test hosts (including a way to test Ansible)
1. The overriding [Documentation](docs) for the build farm

To make a change please:
 
1. Fork this repository
1. Create a branch off your fork
1. Make the change
1. Test it (see below)
1. Submit a Pull Request

Only reviewers in the [admin_infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/admin_infrastructure) team have permission to merge requests for this `openjdk-infrastructure` repo, 
so please ask one of those team members to review your Pull Request. 

# Using Vagrant to test your Ansible scripts (Ubuntu based)

We expect developers to test their Ansible changes in a test environment.  A default one for Ubuntu based systems 
is provided for you via VirtualBox / Vagrant.  See the guide below.

[Ansible Scripts Guide](ansible/README.md)

# Docs

Project documentation in permanent form (e.g. Build Farm architecture) is stored in the [docs](docs) folder.
