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

* [secrets](https://www.github.com/adoptium/secrets/) - A private repo containing encrypted secrets.
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

### Maintenance Window Schedule

We will aim to perform routine maintenance on the first Tuesday of each
month, generally between 1000-1200 (UTC).  This will be announced in the
infrastructure channel on slack on the day prior to the maintenance.  This
timing should typically avoid coinciding with release work, although if a
release in the previous month is ongoing then the window can be delayed til
the following Tuesday.

Jenkins and it's plugins will be updated to the latest LTS every month. 
Other services such as Bastillion, AWX, and Nagios will be updated as
required on a quarterly basis (On the first month of each quarter) during
the same window if required for security reasons. In some cases we may wish
to do an out-of-bound patch if a sufficientl sever issue is identified.

### Standard Action Items

### Jenkins

1. Ensure off-machine backups are working!
1. Ensure that no non-pipeline jobs are running on the server as they
   will often hold up restarts
1. Check for plugin updates that will apply to the current version of
   jenkins (Each plugin should be checked for potential issues in the readme)
1. Repeat step 1 if necessary until jenkins does not offer any more plugins
1. Identify new LTS level - check [the release notes](https://www.jenkins.io/doc/upgrade-guide/)
   to identify any potential problems. Allow jenkins to upgrade itself
1. Redo step 1/2 so that any plugins that were unable to be updated due to
   the older jenkins level can update themselves.
1. If necessary, and the remediation cannot be performed within the
   maintenance window, identify potentially risky plugins that were held
   back and create an issue to deal with them in the next cycle.
1. Backup the main war in /usr/share/jenkins to a name with a version suffix
   in case of corruption to the main jar.

### Backups

These are taken on a daily basis, and one per month is currently kept
"forever" on our backup server. Details are now in a
[separate document](docs/Backups.md)

### OS Patch Management

* Nagios is configured to monitor each system and report on the status of OS patches required so we can identify if any system is not self-updating
* Non-infrastructure systems are configured by ansible to automatically apply all patches. (Sundays at 5am local host time) where possible
* Infrastructure systems are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates
* We do not currently schedule outages to reboot to pick up new kernels.

