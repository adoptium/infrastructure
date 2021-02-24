# Infrastructure

## Build Status

[![Build Status](https://travis-ci.org/AdoptOpenJDK/openjdk-infrastructure.svg?branch=master)](https://travis-ci.org/AdoptOpenJDK/openjdk-infrastructure)

## Documentation Index

* [Contributing Guide](CONTRIBUTING.md) - Our Contribution Guide.
* [Onboarding Guide](ONBOARDING.md) - Our guide for onboarding new team members.
* [Security Guide](SECURITY.md) - Our security policy.
* [Inventory](ansible/inventory.yml) - Our inventory, [visualized](docs/adoptopenjdk.pdf).
* [Ansible at AdoptOpenJDK](ansible/README.md) - Our hosts are built using Ansible Playbooks.

## Mission Statement

To provide infrastructure for the AdoptOpenJDK farm that is:

* **Secure** - Infrastructure is private by default and access is granted in a
time and access control limited manner.
* **Consistent** - Infrastructure is consistent in order to produce consistent
AdoptOpenJDK binaries.
* **Repeatable** - Infrastructure can be reproduced by our _infrastructure as code_.
We embrace the Chaos Monkey.
* **Auditable** - What each host/platform is made up of is publicly accessible
_infrastructure as code_.

The end result should be **immutable** hosts, which can be destroyed and reproduced from Ansible playbooks. See
our [Contribution
Guidelines](https://www.github.com/adoptopenjdk/openjdk-infrastructure/CONTRIBUTING.md)
on how we implement these goals.

## Infrastructure Manifesto

* We prefer using prebuilt, Galaxy provided Ansible playbooks over NIHing our own
* We prefer using binaries from official repositories over building our own
* We prefer explicit comments within the code to explain our reasoning over implicit assumptions
* We embrace the Chaos Monkey

## Related Repositories

* [email](https://www.github.com/adoptopenjdk/email/) - A repo containing configuration for our email aliases etc.
* [secrets](https://www.github.com/adoptopenjdk/secrets/) - A private repo containing encrypted secrets.
* [openjdk-jenkins-helper](https://www.github.com/adoptopenjdk/openjdk-jenkins-helper/) - A repo containing helper scripts for out Jenkins CI.

## Contributing

Please visit our `#infrastructure` [Slack Channel](https://www.adoptopenjdk.net/slack.html) and say hello.
Please read our [Contribution
Guidelines](https://www.github.com/adoptopenjdk/openjdk-infrastructure/CONTRIBUTING.md) before
submitting Pull Requests.

## Members

We list members and their organisation affiliation in GitHub for maximum transparency. Want to add
a new member? Please follow our [Onboarding Process](ONBOARDING.md).

* [infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure) - Can manage issues and PRs at GitHub.
* [infrastructure-core](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-core) - admin access to openjdk-infrastructure.
* [infrastructure-secret](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-secret) - higher level of access for system administrators only.
* [infrastructure-triage](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-triage) - starting team for new joiners.

### Host Information

Most information about our machines can be found at [Inventory](ansible/inventory.yml)

### Maintenance Information

TODO Need to check all of this

### Quarterly Maintenance Window Schedule

***\*\*Proposed Schedule\*\****

**TODO** Needs a rethink

|  Scheduled Date | Eastern Time Zone | British Time Zone |
|---|---|---|
| July 21, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| October 11, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| January 17, 2018 | 3pm - 5pm - Standard Time (UTC - 5) | 20:00 - 22:00 - Greenwich Mean Time (UTC + 0) |

### Standard Action Items

* Apply non-security patches to infrastructure systems.
* Apply Application patches to: Nagios, Jenkins, AWX, etc.

### Backups

The following items are stored in GitHub.

* Source code, System deployment scripts (Ansible), Instructions/How to Information

|  Description | Storage Location | Frequency  |
|---|---|---|
| Jenkins (ci) - Configuration and Settings | localhost `/mnt/backup-server/jenkins_backup` | Daily |
| Nagios - Configuration and Settings | localhost `/root/backups` | Weekly |
| AWX - Configuration and Settings | not currently backed up | N/A |

### Questions

Backup schedule:

* How often should be backup?
* Where should it be stored?

Backup retention:

* How long should be keep it?
* How many copies?

### OS Patch Management

**WARNING:** Several of our hosts are internet facing and we need to stay vigilant
of the potential security risks this presents.

### Patch Management / Minimum Time Frame

| Vulnerability Type | Time Frame|
|---|---|
| Critical severity | 24 hours or less |
| High severity | 7 days |
| Moderate and low severity | 30 days|

* Nagios is configured to monitor each system and report on the status of OS patches required.
* Non-infrastructure systems are configured to automatically apply all patches. (Sundays at 5am local host time)
* Infrastructure systems are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates

### Application Updates

* During our quarterly maintenance window application patches will be applied manually.
* When a critical or high severity vulnerability is announced patching will take place within the time frame stated above.
