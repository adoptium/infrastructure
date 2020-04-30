#!/usr/bin/python

import sys
import getopt
import winrm

def usage():
    print("Usage: %s -i <VM_IPAddress> -a <buildJDKWin_arguments>" % sys.argv[0])
    print("    Use '-b' to run a build or '-t' to run a test")
    sys.exit(1)

def run_winrm(vmIP, buildArgs, mode):
    cmd_str = "Start-Process powershell.exe -Verb runAs; cd C:/tmp; sh C:/vagrant/pbTestScripts/"
    print(mode)
    if mode == 1:
        cmd_str += "buildJDKWin.sh "
    else:
        cmd_str += "testJDKWin.sh "
    cmd_str += buildArgs
    print("Running :      %s" %cmd_str)
    session = winrm.Session(str(vmIP), auth=('vagrant', 'vagrant'))
    session.run_ps(cmd_str, sys.stdout, sys.stderr)

def main(argv):
    # mode refers to whether its running a build or a test
    mode = 1
    print("Running python script")
    inputArgs = ""
    ipAddress = ""
    try:
        opts, args = getopt.getopt(argv, "ha:i:bt")
    except getopt.GetoptError as error:
        print(str(error))
        usage()

    for current_option, current_value in opts:
        if current_option == '-a':
            inputArgs = current_value
        elif current_option == '-i':
            ipAddress = current_value
        elif current_option == '-h':
            usage()
        elif current_option == '-b':
            mode = 1
        elif current_option == '-t':
            mode = 2

    print(" This is what is in the 'inputArgs' var: %s " %str(inputArgs))
    print(" This is what is in the 'ipAddress' var: %s " %str(ipAddress))
    run_winrm(str(ipAddress), str(inputArgs), mode)

if __name__ == "__main__": # Execute only if run as a script
    main(sys.argv[1:])
