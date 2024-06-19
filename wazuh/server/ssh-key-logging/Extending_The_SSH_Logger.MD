# Wazuh - How To Extend The SSH Logging decoder

## Requirement

Implementing A Mechanism For Tracing Direct Logins : https://github.com/adoptium/infrastructure/issues/3212

## How

Wazuh uses "decoders" to process the log files shipped from the agents to the servers. The standard set of decoders can be extended and customised. The official Wazuh docs are linked under "References" below, but here we will detail the specific process used to extend the SSH logger to capture the checksum of the SSH keys used to log in.

A pre-requisite of this is to ensure the captured auditd/sshd/system logs have the relevant information for Wazuh to capture and process. Wazuh also provide a very useful testing tool, detailed here: https://documentation.wazuh.com/current/user-manual/ruleset/testing.html

In order to capture the Checksum of an SSH key, it was necessary to extend the following standard decoder : /var/ossec/ruleset/decoders/0310-ssh_decoders.xml.

The standard decoder file that needs customising was identified by running a grep for the program name/item (sshd), in the /var/ossec/ruleset/decoders directory.

## Implementation Steps

* Copy the default decoder file /var/ossec/ruleset/decoders/0310-ssh_decoders.xml to the user folder /var/ossec/etc/decoders. The reasons for doing this are twofold, firstly the default decoders file (0310-ssh_decoders.xml) will be excluded and instead Wazuh will use the new copy, which will be edited and extended to capture the ssh key checksum. Secondly, by following this process, any changes made will be preserved during upgrades and also easier to revert should any issues occur.

* Next edit the /var/ossec/etc/ossec.conf configuration file. Set the <decoder_exclude> tag to exclude the original ruleset/decoders/0310-ssh_decoders.xml decoder file from the loading list. With this configuration, Wazuh loads the decoder file located in the user folder and not the file in the default folder. Below is an example of this change made.

```
<ruleset>
...
<decoder_exclude>ruleset/decoders/0310-ssh_decoders.xml</decoder_exclude>
</ruleset>
```

* Now the edits and customisations to the new customised version of the ssh decoder is made, at this point its worth identifying a log entry that you would like to be captured, the sample used for extending ssh logins was extracted from the auth.log file and is detailed below:

```
Nov 19 21:33:32 xxxxxx sshd[1914646]: Accepted publickey for xxxxxx from xxx.xx.xxx.xxx port xxxxx ssh2: RSA SHA256:XXXXXXXXX
```

The following changes are being made to the new custom/copied decoder file (/var/ossec/etc/decoders/0310-ssh_decoders.xml)
The decoder works by using a regex to parse logfile entries for matches, and then an offset to capture data. Captured fields are shown by the (\S+) strings in the decoder, with the order element of the xml assigning those strings to variables

The default decoder for ssh successful ssh login is detailed below, and as you can see from the example log line, the first string after "for" is allocated to the name the second string element from (\S+) is recorded into the srcip field and the port (\S+) is recorded into the srcport variable.

```
<decoder name="sshd-success">
  <parent>sshd</parent>
  <prematch>^Accepted</prematch>
  <regex offset="after_prematch">^ \S+ for (\S+) from (\S+) port (\S+)</regex>
  <order>user, srcip, srcport</order>
  <fts>name, user, location</fts>
</decoder>
```

In order to update this to capture the SSH key checksum you can see the "regex offset" element gets updated to look for the RSA SHA256 string before assigning that string to a new custom field called "keysum". This field will become available in Wazuh without any further configuration.

```
<decoder name="sshd-success">
  <parent>sshd</parent>
  <prematch>^Accepted</prematch>
  <regex offset="after_prematch">^ \S+ for (\S+) from (\S+) port (\S+) ssh2: RSA SHA256:(\S+)</regex>
  <order>user, srcip, srcport, keysum</order>
  <fts>name, user, location</fts>
</decoder>
```

* Once these changes have been made, it is necessary to restart the Wazuh manager so the changes take effect:

```
systemctl restart wazuh-manager
```

If there are any issues with restarting the server, which can be caused by syntax errors in either the config or decoder files, these can be identified by running a status on the Wazuh manager service.

```
systemctl status wazuh-manager.service
```

## Testing The New Decoder/Changes

Wazuh provide a useful tool for checking whether decoder and rule changes are being parsed properly, this can be used prior to any changes to see what rules etc are being parsed, and what data is being captured. Below is the output of the test of the ssh decoder test detailed above:

To launch the log test utility, on the wazuh server

```
/var/ossec/bin/wazuh-logtest
```

Which will then prompt:

```
Starting wazuh-logtest v4.5.3
Type one log per line
```

At this point, paste in a sample line extracted from a log, e.g

```
Nov 19 21:33:32 xxxxxx sshd[1914646]: Accepted publickey for xxxxxx from xxx.xx.xxx.xxx port xxxxx ssh2: RSA SHA256:XXXXXXXXX
```

The following output is then displayed, which shows the new field being captured:

```
**Phase 1: Completed pre-decoding.
	full event: 'Nov 19 21:33:32 xxxxxx sshd[1914646]: Accepted publickey for xxxxxx from xxx.xx.xxx.xxx port xxxxx ssh2: RSA SHA256:XXXXXXXXX'
	timestamp: 'Nov 19 21:33:32'
	hostname: 'xxxxxx'
	program_name: 'sshd'

**Phase 2: Completed decoding.
	name: 'sshd'
	parent: 'sshd'
	dstuser: 'xxxxxx'
	keysum: 'XXXXXXXXX'
	srcip: 'xxx.xx.xxx.xxx'
	srcport: 'xxxxx'

**Phase 3: Completed filtering (rules).
	id: '5715'
	level: '3'
	description: 'sshd: authentication success.'
	groups: '['syslog', 'sshd', 'authentication_success']'
	firedtimes: '1'
	gdpr: '['IV_32.2']'
	gpg13: '['7.1', '7.2']'
	hipaa: '['164.312.b']'
	mail: 'False'
	mitre.id: '['T1078', 'T1021']'
	mitre.tactic: '['Defense Evasion', 'Persistence', 'Privilege Escalation', 'Initial Access', 'Lateral Movement']'
	mitre.technique: '['Valid Accounts', 'Remote Services']'
	nist_800_53: '['AU.14', 'AC.7']'
	pci_dss: '['10.2.5']'
	tsc: '['CC6.8', 'CC7.2', 'CC7.3']'
**Alert to be generated.
```

## Notes

* It is important to note that custom decoders WILL NOT override existing ones. So in order to amend an existing decoder, it must be removed from the standard rules and replaced with a custom ruleset for all elements.

* Custom rules, decoders, and configuration files should be backed up prior to running an upgrade.

## References

Useful sections from the Wazuh documentation:

* Wazuh Decoder Reference: https://documentation.wazuh.com/current/user-manual/ruleset/custom.html

* Wazuh Ruleset Testing Reference: https://documentation.wazuh.com/current/user-manual/ruleset/testing.html
