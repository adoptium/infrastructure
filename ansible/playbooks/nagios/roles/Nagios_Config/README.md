This role installs and configures the Nagios configuration files i.e Servicegroups and Hostgroups files
Currently this role is only supported on Ubuntu 22.04.

the /templates directory contains the jinja2 templates used to populate the various hostgoups files with the relevant info

ansible/playbooks/nagios/roles/Nagios_Config/files/Nagios_Server_Config.py
contains the Template and  Host mapping definitions plus the excluded Hosts at the moment