# openjdk-maintenance

### Maintenance Information:

#### Quarterly Maintenance Window Schedule:
|  Scheduled Date | Start Time | End Time | TimeZone |
|---|---|--|--|
| Month DAY, 2017 | 3pm | 5pm | EDT| 


#### Backups:
The following items are stored in GitHub.
Source code, System deployment scripts (Ansible), Instructions/How to Information

|  Description | Storage Location | Frequency  |
|---|---|---|
| Jenkins - Configuration and Settings | not currently backed up | N/A |
| Nagios - Configuration and Settings | not currently backed up | N/A |
| Semaphore - Configuration and Settings | not currently backed up | N/A |

##### Questions:
Backup schedule:
- How often should be backup?)
- Where should it be stored?

Backup retention:
- How long should be keep it?
- How many copies?

#### OS Patch Management: 
*Most of our systems are internet facing*

| Vulnerability Type | Time Line|
|---|---|
| Critical severity | 72 hours or less |
| High severity | 7 days |
| Moderate and low severity | 60 days|

- Nagios is configured to monitor patches that are required.
- I would recommend enabling auto updates on our systems and configure it to run weekly.

#### Application Updates:
- Quarterly maintenance window to manually update and patch our applications.
- More often when a critical or high severity vulnerability is announced.
