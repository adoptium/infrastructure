#!/bin/bash

echo "enter the hostgroup name"
read hostgroup_name

echo "enter the hostgroup alias"
read hostgroup_alias

echo "enter the hostgroup members"
read hostgroup_members

echo "define hostgroup{" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        hostgroup_name  $hostgroup_name" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        alias           $hostgroup_alias" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        members         $hostgroup_members" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        }" >> /usr/local/nagios/etc/objects/hostgroups.cfg
