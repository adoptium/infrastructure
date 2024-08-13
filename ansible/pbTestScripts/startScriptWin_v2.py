#!/usr/bin/env python3

import sys
import getopt
import winrm

def usage():
    print("Usage: {} -i <VM_IPAddress> -a <buildJDKWin_arguments>".format(sys.argv[0]))
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
    print("Running :      {}".format(cmd_str))
    session = winrm.Session(str(vmIP), auth=('vagrant', 'vagrant'))
    result = session.run_ps(cmd_str)

    # Print the standard output and error if there is any
    print(result.std_out.decode('utf-8'))
    if result.std_err:
        print(result.std_err.decode('utf-8'), file=sys.stderr)

def main(argv):
    # mode refers to whether it's running a build or a test
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

    print("This is what is in the 'inputArgs' var: {}".format(str(inputArgs)))
    print("This is what is in the 'ipAddress' var: {}".format(str(ipAddress)))
    run_winrm(str(ipAddress), str(inputArgs), mode)

if __name__ == "__main__": # Execute only if run as a script
    main(sys.argv[1:])
