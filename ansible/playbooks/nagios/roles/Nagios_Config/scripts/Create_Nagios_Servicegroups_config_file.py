#!/usr/bin/python3
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import os
import subprocess
import sys
from os import path

# Input_Path = sys.argv[1]
Output_Path = sys.argv[1]
Nagios_Service_Types = sys.argv[2]

def main():

    service_list_with_default='Web'+' '+Nagios_Service_Types

    service_list=service_list_with_default.split(' ')
    for service in service_list:
       servicegroup_name = service+'_Servers'
       servicegroup_alias = service+'_Servers'

       # Add service group information to servicegroups.cfg file
       with open(f"{Output_Path}/servicegroups.cfg", "a") as s:
            s.write(f"define servicegroup{{\n")
            s.write(f"  servicegroup_name {servicegroup_name}\n")
            s.write(f"  alias {servicegroup_alias}\n")
            s.write(f"}}\n")

if __name__ == "__main__":

    main()
