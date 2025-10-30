## Maintenance Window Schedule

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
1. Create a tarball backup of the main config.xml and plugins.xml so they
   can be quickly restored in the event of upgrade problems: `tar czf /home/jenkins/jenkinsbackup.$(date +%Y%m%d).tar.gz -C ~jenkins config.xml plugins`
1. Check for plugin updates that will apply to the current version of
   jenkins (Each plugin should be checked for potential issues in the readme)
1. Repeat step 1 if necessary until jenkins does not offer any more plugins
1. Identify new LTS level - check [the release upgrade guide](https://www.jenkins.io/doc/upgrade-guide/)
   for the version and the [LTS changelog](https://www.jenkins.io/changelog-stable/) 
   to identify any potential problems. Allow jenkins to upgrade itself
1. Redo step 1/2 so that any plugins that were unable to be updated due to
   the older jenkins level can update themselves.
1. If necessary, and the remediation cannot be performed within the
   maintenance window, identify potentially risky plugins that were held
   back and create an issue to deal with them in the next cycle.
1. Backup the main `.war` file in /usr/share/jenkins to a name with a version suffix
   in case of corruption to the main jar.
1. Once the upgrade is done, restart agents which do not auto-restart such as the Windows ones not running as a service
1. Once the upgrade is done, check the Azure cloud plugin configuration, particularly the network security group configuration
1. Post a message in the #infrastructure slack channel announcing the completion of the upgrade and including a link to the appropriate "upgrade guide(s)" with the change information.

