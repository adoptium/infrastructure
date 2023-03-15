# Infrastructure

## Mission Statement

To provide infrastructure for the Adoptium farm that is:

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
Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md)
on how we implement these goals.

## Can we Chaos Monkey it

See our current [Chaos Monkey Status](CHAOS_MONKEY.md).

## Related Repositories

* [secrets](https://www.github.com/adoptopenjdk/secrets/) - A private repo containing encrypted secrets.
* [openjdk-jenkins-helper](https://www.github.com/adoptopenjdk/openjdk-jenkins-helper/) - A repo containing helper scripts for out Jenkins CI.

## Important Documentation

* [hosts](https://github.com/adoptium/infrastructure/blob/master/ansible/inventory.yml) - Our inventory, [visualized](https://github.com/adoptium/infrastructure/blob/master/docs/adoptopenjdk.pdf).
* [Ansible at AdoptOpenJDK](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) - Our hosts are built using Ansible Playbooks.

## Contributing

Please visit our `#infrastructure` [Slack Channel](https://www.adoptopenjdk.net/slack.html) and say hello.
Please read our [Contribution
Guidelines](https://github.com/adoptium/infrastructure/blob/master/CONTRIBUTING.md) before
submitting Pull Requests.

## Members

We list administrative members and their organisation affiliation for maximum transparency.
Want to add a new member? Please follow our [Onboarding Process](ONBOARDING.md).
If you want access for yourself, raise an issue in this repository for the
team to consider it - if you are working on an issue here we will generally
be happy to add you to the triage team.

`*` Indicates access to the secrets repo

## [@infrastructure-core](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure-core)

Members of this team that holds super user access to our machines to perform maintenance

* [@karianna](https://github.com/karianna) - Martijn Verburg (Microsoft) - *
* [@gdams](https://github.com/gdams) - George Adams (Microsoft) - *
* [@johnoliver](https://github.com/johnoliver) - John Oliver (Microsoft / LJC) - *
* [@sxa](https://github.com/sxa) - Stewart X Addison (Red Hat) - *
* [@willsparker](https://github.com/Willsparker) - Will Parker (Red Hat)
* [@Haroon-Khel](https://github.com/Haroon-Khel) - Haroon Khel (Red Hat)
* [@aahlenst](https://github.com/aahlenst) - Andreas Ahlenstorf (ZHAW)
* [@steelhead31](https://github.com/steelhead31) - Scott Fryer (Red Hat)

## [@infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)

The primary infrastructure team who manage issues and PRs in this
repository.  People in this team are committers and able to merge pull requests
in this repository.  In general if you need assistance from a committer,
please post a message into the `#infrastructure` slack channel where one of
the committers should be able to help rather than attempting to contact
someone directly.

## [@adoptopenjdk-triage](https://github.com/orgs/AdoptOpenJDK/teams/adoptopenjdk-triage)

This team is the starting point for new members.

People in this team can take ownership of issues but do not have the
privileges to merge pull requests.  In general new people in the team will
go into this group for a while before being granted additional access.

## Infrastructure Providers
The Adoptium project is proud to receive contributions from many companies, both in the form of monetary contributions in exchange for membership or in-kind contributions for required resources. The Infrastructure collaborates with the following companies who contribute various kinds of cloud and physical hardware to the Adoptium project.

![Infra Sponsors Page](https://user-images.githubusercontent.com/20224954/141327230-04524d09-ebd2-4e07-9c74-6c9ae9bdfc11.png)

### Host Information

Most information about our machines can be found at
[Inventory](ansible/inventory.yml) This file is important not only as a
reference for the team, but is used by AWX which we often use to deploy
ansible playbooks so it is important that it is kept up to date

### Infrastructure Map

[Here](https://github.com/adoptium/infrastructure/blob/master/docs/AdoptiumInfrastructureMapMiro.pdf) is a map of our Build, Test, Dockerhost and Other Infrastructure machines. 

The original Miro board can be viewed [here](https://miro.com/app/board/uXjVMfhXwh0=/?share_link_id=454451259876)

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
