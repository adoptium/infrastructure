## AdoptOpenJDK - Infrastructure Onboarding Guide

### Tasks before onboarding

- Add user to https://github.com/orgs/AdoptOpenJDK/teams/infrastructure (if they are not in the org you may need an onwer to add them).
- Create Pull Request to add user to https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/README.md#infrastructure.
- Ideally request users public GPG key as well as their public SSH key.

### GitHub

- Full list of machines is [here](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/inventory.yml). Please remember to always update this when adding new machines or removing existing ones.
- Ansible Playbooks are all stored [here](https://github.com/AdoptOpenJDK/openjdk-infrastructure/tree/master/ansible).

#### [Secrets](https://github.com/AdoptOpenJDK/secrets)

- Show user how to access the secets repo and also how to use dotGPG to read files.
- Adding a new user to dotGPG can be done following the instructions [here](https://github.com/AdoptOpenJDK/secrets#adding-users.)

### External Services

#### [ci.adoptopenjdk.net](https://ci.adoptopenjdk.net)

All infrastructure members have full admin access to the jenkins slave section allowing them to create, delete and update slaves.

#### [Nagios](https://nagios.adoptopenjdk.net)

Used for machine monitoring (ensure that the user knows where to find the password).

#### [Ansible AWX](ansible.adoptopenjdk.net)

Used to run all playbooks on new machines (ensure that the an account has been created for the user)

#### [KeyBox](https://keybox.adoptopenjdk.net)

Used to disribute SSH keys. Ensure that both the users SSH key is on the system but also ensure that they know where to find the password.
