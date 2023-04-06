# Adoptium critical server backup policy

The main servers used as jenkins agents contain no permanent information on
them so is not backed up. A new deployment of the appropriate playbooks is
expected to be able to set up the machines from scratch without any
problems.

The other servers are backed up on a daily basis. Currently these occur to
the machine that runs our Bastillion server in `~backups`.

Jenkins performs its own backups with the "thinbackup" plugin which takes
one "full" backup on the first of the month, and daily increemental backups
thereafter. Prior to April 2023 this was a full backup on Monday, and
inrementals for the rest of the week.

A number of changes were made in March 2023 to reduce the amount of space
that the backups require as some superfluous material was being retained.

Product | Size/day | What is backed up
--- | --- | ---
bastillion | 21Mb | Full product backup with database
nagios | 140Mb | Entire /usr/local/nagios (Now excludes `nagiosgraph.log` and `archives`)
TRSS | 650Mb | Mongodump of database
jenkins | ~16Mb (*) | config.xmls, plus text file with plugin list

(*) - In addition to the 16Mb, `.tar.xz` backups (~45Mb) of the "full"
thinbackup files on the jenkins server will also be taken when new ones are
available (Currently once per month) so the total will be around 18Mb/day on
average.

Older backups will be automatically cleared, but the ones dated on the first
of the month will always be retained.

The script that performs this work is at
https://github.com/adoptium/infrastructure/blob/master/ansible/tools/run_backup.sh
