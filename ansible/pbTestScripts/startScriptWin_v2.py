#!/usr/bin/env python3

import sys
import getopt
import winrm
import logging

def setup_logging():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def print_usage():
    print(f"Usage: {sys.argv[0]} -i <VM_IPAddress> -a <buildJDKWin_arguments>")
    print("    Use '-b' to run a build or '-t' to run a test")
    sys.exit(1)

def run_command_over_winrm(vm_ip, command_args, mode):
    command_base = "Start-Process powershell.exe -Verb runAs; cd C:/tmp; bash C:/vagrant/pbTestScripts/"
    command = command_base + ("buildJDKWin.sh " if mode == 1 else "testJDKWin.sh ") + command_args

    logging.info(f"Executing command: {command} on VM: {vm_ip}")

    try:
        session = winrm.Session(vm_ip, auth=('vagrant', 'vagrant'))
        result = session.run_ps(command)

        stdout = result.std_out.decode().strip()
        stderr = result.std_err.decode().strip()

        if stdout:
            logging.info(f"Command Output: {stdout}")
        if stderr:
            logging.error(f"Command Error: {stderr}")

        return result.status_code
    except Exception as e:
        logging.error(f"Failed to execute command: {str(e)}")
        sys.exit(1)

def main(argv):
    setup_logging()

    mode = 1  # Default mode is build
    command_args = ""
    vm_ip_address = ""

    try:
        opts, _ = getopt.getopt(argv, "ha:i:bt")
    except getopt.GetoptError as error:
        logging.error(f"Argument parsing error: {str(error)}")
        print_usage()

    for option, value in opts:
        if option == '-a':
            command_args = value
        elif option == '-i':
            vm_ip_address = value
        elif option == '-h':
            print_usage()
        elif option == '-b':
            mode = 1
        elif option == '-t':
            mode = 2

    if not vm_ip_address or not command_args:
        logging.error("VM IP address and command arguments are required.")
        print_usage()

    logging.info(f"Command Arguments: {command_args}")
    logging.info(f"VM IP Address: {vm_ip_address}")
    run_command_over_winrm(vm_ip_address, command_args, mode)

if __name__ == "__main__":
    main(sys.argv[1:])
