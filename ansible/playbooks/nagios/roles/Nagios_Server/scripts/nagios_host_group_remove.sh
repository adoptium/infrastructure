#!/bin/bash
while read -p "Enter the hostgroup name (Enter to finish) :" -r hostgroup_name
do
	if [[ "$hostgroup_name" ]]
	then
		awk -vhostgroup_name="${hostgroup_name}" '
  			/^define hostgroup/ { buf=""; addbuf=prtbuf=1 }
  			addbuf {
    				buf=(buf $0 ORS)
    				if ($1=="hostgroup_name" && $2==hostgroup_name) prtbuf=0
    				if ($1=="}") { addbuf=0; if (prtbuf) printf "%s", buf }
    			next
  			}
  			{ print }
		' /usr/local/nagios/etc/objects/hostgroups.cfg > junk.out
		mv junk.out /usr/local/nagios/etc/objects/hostgroups.cfg
	else
		break;
	fi
done
