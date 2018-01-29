# Maintenance Information:

#### Quarterly Maintenance Window Schedule:

***\*\*Proposed Schedule\*\****

|  Scheduled Date | Eastern Time Zone | British Time Zone |
|---|---|--|
| July 21, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| October 11, 2017 | 3pm - 5pm - Daylight Time (UTC - 4) | 20:00 - 22:00 - Summer Time (UTC + 1) |
| January 17, 2018 | 3pm - 5pm - Standard Time (UTC - 5) | 20:00 - 22:00 - Greenwich Mean Time (UTC + 0) |


#### Standard Action Items:
- Apply non-security patches to infrastructure systems.
- Apply Application patches to: Nagios, Jenkins, Semaphore, etc.

#### Backups:
The following items are stored in GitHub.
- Source code, System deployment scripts (Ansible), Instructions/How to Information

|  Description | Storage Location | Frequency  |
|---|---|---|
| Jenkins - Configuration and Settings | localhost `/mnt/backup-server/jenkins_backup` | Daily |
| Nagios - Configuration and Settings | localhost `/root/backups` | Weekly |
| AWX - Configuration and Settings | not currently backed up | N/A |

##### Questions:
Backup schedule:
- How often should be backup?
- Where should it be stored?

Backup retention:
- How long should be keep it?
- How many copies?

#### OS Patch Management: 
*Most of our systems are internet facing and we need to stay vigilant of the potential security risks this presents.*

##### Patch Management Time Frame:
| Vulnerability Type | Time Frame|
|---|---|
| Critical severity | 72 hours or less |
| High severity | 7 days |
| Moderate and low severity | 60 days|

- Nagios is configured to monitor each system and report on the status of OS patches required.
- Non-infrastructure systems are configured to automatically apply all patches. (Sundays at 5am local host time)
- Infrastructure systems are configured to automatically apply security patches only. (Sundays at 5am local host time) This information is logged on the localhost: /var/log/apt-security-updates

#### Application Updates:
- During our quarterly maintenance window application patches will be applied manually.
- When a critical or high severity vulnerability is announced patching will take place within the time frame stated above.
