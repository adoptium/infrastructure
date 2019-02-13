[![Build Status](https://travis-ci.org/AdoptOpenJDK/openjdk-infrastructure.svg?branch=master)](https://travis-ci.org/AdoptOpenJDK/openjdk-infrastructure)


# Mission Statement

To provide infrastructure for the AdoptOpenJDK farm that is:

* **Secure** - Infrastructure is private by default and access is granted in a 
time and access control limited manner.
* **Consistent** - Infrastructure is consistent in order to produce consistent 
AdoptOpenJDK binaries.
* **Repeatable** - Infrastructure can be reproduced by our _infrastrucure as code_. 
We embrace the Chaos Monkey.
* **Auditable** - What each host/platform is made up of is publicly accessible 
_infrastructure as code_.

The end result should be **immutable** hosts, which can be destroyed and reproduced from Ansible playbooks. See 
our [Contribution
Guidelines](https://www.github.com/adoptopenjdk/openjdk-infrastructure/CONTRIBUTING.md) 
on how we implement these goals.

## Can we Chaos Monkey it?

See our current [Chaos Monkey Status](CHAOS_MONKEY.md).

# Related Repos

* [email](https://www.github.com/adoptopenjdk/email/) - A repo containing configuration for our email aliases etc.
* [secrets](https://www.github.com/adoptopenjdk/secrets/) - A private repo containing encrypted secrets.
* [openjdk-jenkins-helper](https://www.github.com/adoptopenjdk/openjdk-jenkins-helper/) - A repo containing helper scripts for out Jenkins CI.

## Important Documentation

* [hosts](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/inventory.yml) - Our inventory, [visualised](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/docs/adoptopenjdk.pdf).
* [Ansible at AdoptOpenJDK](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/README.md) - Our hosts are built using Ansible Playbooks. 

# Contributing

Please visit our `#infrastructure` [Slack Channel](https://www.adoptopenjdk.net/slack.html) and say hello. 
Please read our [Contribution
Guidelines](https://www.github.com/adoptopenjdk/openjdk-infrastructure/CONTRIBUTING.md) before 
submitting Pull Requests.

# Members

We list members and their organisation affiliation for maximum transparency. Want to add 
a new member? Please follow our [Onboarding Process](ONBOARDING.md). 

* - Indicates access to the secrets repo

## [@admin_infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/admin_infrastructure)

Team that holds super user access to Infrastructure

- [@gdams](https://github.com/gdams) - George Adams (IBM) - *
- [@johnoliver](https://github.com/johnoliver) - John Oliver (jClarity / LJC) - *
- [@sxa555](https://github.com/sxa555) - Stewart X Addison (IBM) - *

## [@infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/infrastructure)

Core infrastructure team - granted access to hosts on a case by case basis

- [@ali-ince](https://github.com/ali-ince) - Ali Ince (LJC)
- [@gdams](https://github.com/gdams) - George Adams (IBM)
- [@geraintwjones](https://github.com/geraintwjones) - Geraint Jones (IBM) - *
- [@jdekonin](https://github.com/jdekonin) - Joe deKoning (IBM)
- [@johnoliver](https://github.com/johnoliver) - John Oliver (jClarity / LJC)
- [@karianna](https://github.com/karianna) - Martijn Verburg (jClarity / LJC) - *
- [@mwornast](https://github.com/mwornast) - Marcus Wornast (IBM) - *
- [@pnstanton](https://github.com/pnstanton) - Peter Stanton (IBM) - *
- [@sej-jackson](https://github.com/sej-jackson) - Sej Jackson (IBM)
- [@tellison](https://github.com/tellison) - Tim Ellison (IBM) - * 
- [@vsebe](https://github.com/vsebe) - Violeta Sebe (IBM)

## [@adoptopenjdk-infrastructure](https://github.com/orgs/AdoptOpenJDK/teams/adoptopenjdk-infrastructure)

Issues can be assigned to these folks

- [@AdamBrousseau](https://github.com/AdamBrousseau) - Adam Brousseau (IBM)
- [@CJKwork](https://github.com/CJKwork) - Clive Kennedy (IBM)
- [@cwillhelm](https://github.com/cwillhelm) - Connor Willhelm (IBM)
- [@jdekonin](https://github.com/jdekonin) - Joe deKoning (IBM)
- [@karianna](https://github.com/karianna) - Martijn Verburg (jClarity / LJC)
- [@sej-jackson](https://github.com/sej-jackson) - Sej Jackson (IBM)
- [@vsebe](https://github.com/vsebe) - Violeta Sebe (IBM)

## [@jenkins-admins](https://github.com/orgs/AdoptOpenJDK/teams/jenkins-admins)
- [@ali-ince](https://github.com/ali-ince) Ali Ince (LJC)
-	[@andrew-m-leonard](https://github.com/andrew-m-leonard) Andrew M Leonard (IBM)
- [@gdams](https://github.com/gdams) - George Adams (IBM)
- [@geraintwjones](https://github.com/geraintwjones) - Geraint Jones (IBM)
- [@johnoliver](https://github.com/johnoliver) - John Oliver (jClarity / LJC)
- [@karianna](https://github.com/karianna) - Martijn Verburg (jClarity / LJC)
- [@mwornast](https://github.com/mwornast) - Marcus Wornast (IBM)
- [@neomatrix369](https://github.com/neomatrix369) - Mani Sarkar (LJC)
- [@smlambert](https://github.com/smlambert) - Shelley Lambert (IBM)
- [@sxa555](https://github.com/sxa555) - Stewart X Addison (IBM)
- [@tellison](https://github.com/tellison) - Tim Ellison (IBM)
- [@VermaSh](https://github.com/VermaSh) Shubham Verma (IBM)

# Host Information
Most information about our machines can be found at https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/inventory.yml

# Maintenance Information:

TODO Need to check all of this

## Quarterly Maintenance Window Schedule

***\*\*Proposed Schedule\*\****

**TODO** Needs a rethink

|  Scheduled Date | Eastern Time Zone | British Time Zone |
|---|---|---|
| July 21, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| October 11, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| January 17, 2018 | 3pm - 5pm - Standard Time (UTC - 5) | 20:00 - 22:00 - Greenwich Mean Time (UTC + 0) |

### Standard Action Items
- Apply non-security patches to infrastructure systems.
- Apply Application patches to: Nagios, Jenkins, AWX, etc.

## Backups:
The following items are stored in GitHub.
- Source code, System deployment scripts (Ansible), Instructions/How to Information

|  Description | Storage Location | Frequency  |
|---|---|---|
| Jenkins (ci) - Configuration and Settings | localhost `/mnt/backup-server/jenkins_backup` | Daily |
| Jenkins (ci-jck) - Configuration and Settings | localhost `/mnt/backup/` | Daily |
| Nagios - Configuration and Settings | localhost `/root/backups` | Weekly |
| AWX - Configuration and Settings | not currently backed up | N/A |

### Questions
Backup schedule:
- How often should be backup?
- Where should it be stored?

Backup retention:
- How long should be keep it?
- How many copies?

## OS Patch Management
**WARNING:** Several of our hosts are internet facing and we need to stay vigilant 
of the potential security risks this presents.

### Patch Management / Minimum Time Frame
| Vulnerability Type | Time Frame|
|---|---|
| Critical severity | 24 hours or less |
| High severity | 7 days |
| Moderate and low severity | 30 days|

- Nagios is configured to monitor each system and report on the status of OS patches required.
- Non-infrastructure systems are configured to automatically apply all patches. (Sundays at 5am local host time)
- Infrastructure systems are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates

### Application Updates
- During our quarterly maintenance window application patches will be applied manually.
- When a critical or high severity vulnerability is announced patching will take place within the time frame stated above.
