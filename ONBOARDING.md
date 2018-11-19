# AdoptOpenJDK - Infrastructure Onboarding Guide

## Tasks before onboarding

- Submit a Pull Request to the [README](README.md) with the proposed user and level of access required.

Assuming the PR is approved

- Create Pull Request to add user to https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/README.md#infrastructure.
- Ideally request users public GPG key as well as their public SSH key.

## GitHub

Add the user to the correct Infrastructure team:

**TODO** Finish this properly

- [infrastructure team](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)
- [infrastructure team](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)
- [infrastructure team](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)


### [Secrets](https://github.com/AdoptOpenJDK/secrets)

- Show user how to access the secrets repo and also how to use dotGPG to read files.
- Adding a new user to dotGPG can be done following the instructions [here](https://github.com/AdoptOpenJDK/secrets#adding-users.)

## External Services

### [ci.adoptopenjdk.net](https://ci.adoptopenjdk.net)

All infrastructure members have full admin access to the jenkins slave section allowing them to create, delete and update slaves.

### [Nagios](https://nagios.adoptopenjdk.net)

Used for machine monitoring (ensure that the user knows where to find the password).

### [Ansible AWX](https://ansible.adoptopenjdk.net)

Used to run all playbooks on new machines (ensure that the an account has been created for the user)

### [KeyBox](https://keybox.adoptopenjdk.net)

Used to distribute SSH keys. Ensure that both the users SSH key is on the system but also ensure that they know where to find the password.
