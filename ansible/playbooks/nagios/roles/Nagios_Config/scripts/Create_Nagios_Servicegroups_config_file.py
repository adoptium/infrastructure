#!/usr/bin/python3
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import os
import subprocess
import sys
import re
from os import path

# Input_Path = sys.argv[1]
Output_Path = sys.argv[1]
Nagios_Service_Types = sys.argv[2]

def main():

    service_list_with_default='Web'+' '+Nagios_Service_Types

    service_list=service_list_with_default.split(' ')

   # Check To See If File Exists
    path = Output_Path+"/servicegroups.cfg"
    check_file = os.path.isfile(path)

    # print("path = "+path)
    # print(check_file)

    foundList=[]
    notfoundList=[]
    UniqfoundList=[]
    UniqnotfoundList=[]
    MissingList=[]

    if check_file is False:
        for service in service_list:
            servicegroup_name = service+'_Servers'
            servicegroup_alias = service+'_Servers'
            with open(f"{Output_Path}/servicegroups.cfg", "a") as s:
                s.write(f"define servicegroup{{\n")
                s.write(f"  servicegroup_name {servicegroup_name}\n")
                s.write(f"  alias {servicegroup_alias}\n")
                s.write(f"}}\n")
                s.close()
    else:
        for service in service_list:
            servicegroup_name = service+'_Servers'
            servicegroup_alias = service+'_Servers'
            # print(servicegroup_name+' '+servicegroup_alias)
            file = open(Output_Path+"/servicegroups.cfg", "r")
            for line in file:
                if re.search(servicegroup_name, line):
                    foundList.append(servicegroup_name)
                else:
                    notfoundList.append(servicegroup_name)

        for service in (foundList):
            if service not in UniqfoundList:
              UniqfoundList.append(service)

        for service in (notfoundList):
            if service not in UniqnotfoundList:
              UniqnotfoundList.append(service)

        for service in UniqnotfoundList:
            if service not in UniqfoundList:
                MissingList.append(service)

        for service in MissingList:
            servicegroup_name = service+'_Servers'
            servicegroup_alias = service+'_Servers'
            with open(f"{Output_Path}/servicegroups.cfg", "a") as t:
                t.write(f"define servicegroup{{\n")
                t.write(f"  servicegroup_name {servicegroup_name}\n")
                t.write(f"  alias {servicegroup_alias}\n")
                t.write(f"}}\n")
                t.close()


if __name__ == "__main__":

    main()
