#!/bin/bash

echo "enter the hostgroup name"
read hostgroup_name

echo "enter the hostgroup elias"
read hostgroup_elias

echo "enter enter the hostgroup members"
read hostgroup_members

echo "define hostgroup{" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        hostgroup_name  $hostgroup_name" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        alias           $hostgroup_elias" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        members         $hostgroup_members" >> /usr/local/nagios/etc/objects/hostgroups.cfg
echo "        }" >> /usr/local/nagios/etc/objects/hostgroups.cfg
