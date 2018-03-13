/* (C) Copyright IBM Corporation 2018.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
 limitations under the License.
*/


import jenkins.model.Jenkins;
import hudson.model.Computer;
import hudson.util.RemotingDiagnostics;
import hudson.remoting.Channel;
import hudson.slaves.DumbSlave;
import hudson.slaves.CommandLauncher;
import hudson.model.Slave;
import hudson.model.Node.Mode;
import hudson.plugins.sshslaves.SSHLauncher;

class  NodeHelper {

    // TODO: Move strings out to a config file

    /* Java Web Start (Windows)
        - Internal data directory: remoting
       SSH (most linux machines)
        - Host: of the machine
        - Credentials
        - Host key verfication strategy: Non
       Command launcer 
        - only for machines that need to be reached via a proxy
        - just one string with the machine ip
     */

    /**
     * Adds a new node to jenkins.
     *
     * @param newNodeName         the name for the new node
     * @param newNodeDescription  the description for the new node
     * @param newNodeRemoteFS     the remote file structure
     * @param newNodeNumExecutors the max number of executors allowed
     * @param newNodeMode         the Hudson control constants which
     *                            dictate how that control how much
     *                            the node gets utilized. 
     *                            Normal, use it as much as possible. 
     *                            Exclusive, used it only for jobs that 
     *                            specify this node as the assigned node
     * @param newNodeLabelString  the labels to be added to the node. 
     *                            Each label should be seperated by space
     * @param launcher            the agent launcher for the node. Examples:
     *                             - hudson.plugins.sshslaves.SSHLauncher
     *                             - hudson.slaves.CommandLauncher
     *
     * @return name of the node that have just been created
     *         <code>INVALID_NODE_NAME</code> if the node name
     *         passed doesn't meet the required criteria.
     */
    public String addNewNode(
        String newNodeName,
        String newNodeDescription,
        String newNodeRemoteFS,
        int newNodeNumExecutors,
        Mode newNodeMode,
        String newNodeLabelString,
        def launcher
        ) {

        String ret = "INVALID_NODE_NAME";

        if (newNodeName.length() > 2) { // TODO: Some sort of validation for node names
            DumbSlave newSlave = new DumbSlave(
                        newNodeName,
                        newNodeRemoteFS,
                        launcher
                        );

            newSlave.setNumExecutors(newNodeNumExecutors);
            newSlave.setNodeDescription(newNodeDescription);
            ((Slave)newSlave).setMode(newNodeMode);
            newSlave.setLabelString(newNodeLabelString);

            (Jenkins.getInstance()).addNode(newSlave);

            (Jenkins.getInstance().getComputer(newMachineName)).connect(false);

            ret = newNodeName;
        }

        return ret;
    } 

    /**
     * Overwrites the existing labels with the ones passed
     * in. Labels should be seperated by spaces.
     *
     * @param computerName the computer whose labels need to be updated
     * @param label        the net label(s) for the computer
     *
     * @return string of labels set on the computer
     */
    public String addLabel(String computerName, String label) {
        String ret = "addLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            computer.getNode().setLabelString(label.toLowerCase());
            ret = getLabels(computer.getName());
        }

        return ret;
    }

    /**
     * Appends label(s) to the set of existing labels. Labels
     * should be seperated by spaces
     *
     * @param computerName the computer whose labels need to be updated
     * @param label        the net label(s) for the computer
     *
     * @return string of labels set on the computer
     */
    public String appendLabel(String computerName, String label) {
        String ret = "appendLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = addLabel(computer.getName(), getLabels(computer.getName()) + " " + label);
        }

        return ret;
    }

    /**
     * A helper function that gets the labels from the
     * computer
     *
     * @param compterName computer for which labels are needed
     *
     * @return labels as string seperated by space
     */
    public String getLabels(String computerName) {
        String ret = "getLabels:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = (computer.getNode()).getLabelString();
        }

        return ret;
    }

    /**
     * Creates jenkins labels. Labels are seperated by
     * spaces. At the moment, it will add os, architecture
     * and kernel labels. Endian lable will only be added
     * if running on ppc.
     *
     * @param compterName computer for which labels are needed
     *
     * @return label string
     */
    public String constructLabels(String computerName) {
        /* Procedure for adding support for new labels
         * Create a construct<label/> function
         *  here if needed call other specialized functions
         *  construct<label/> function should only be doing
         *  the part of appending the neccessary prefix
         *  try to keep the logic in a seperate function
         *
         * add the function call for the new construct<label/>
         * along with the rest below
         */
        String ret = "constructLabels:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = constructOsLabel(computer.getName());
            if (getOsArch(computer.getName()).contains("ppc")
                && getOsKernelInfo(computer.getName()).get(0).equalsIgnoreCase("linux")) {
                /* Only care about Endianness if it's plinux
                 * because ppc is the only one that supports
                 * both big and little endian
                 */
                ret += " " + constructEndianLabel(computer.getName());
            }
            ret += " " + constructArchLabel(computer.getName());
            if (getOsKernelInfo(computer.getName()).get(0).equalsIgnoreCase("linux")) {
                /* We add kernel because we want to be able to get a linux machine
                 * regardless of the OS name and version
                 */
                ret += " " + constructKernelLabel(computer.getName());
            }
        }

        return ret;
    }

    /**
     * Constructs the os labels. One with the version and one
     * without the version. sw.os.ubuntu, sw.os.ubuntu14
     * 
     * @param computerName name of the node for which labels
     *                     are required
     *
     * @return the os labels seperated by space
     */
    public String constructOsLabel(String computerName) {
        String ret = "constructOsLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            def osInfo = getOsInfo(computer.getName());
            String osVersion = osInfo.get(1);

            ret = "sw.os." + osInfo.get(0) + osVersion;
            ret += " sw.os." + osInfo.get(0);
        }

        return ret.toLowerCase();
    }

    /**
     * Constructs a endian label. hw.endian.le or hw.endian.be
     * 
     * @param computerName name of the node for which labels
     *                     are required
     *
     * @return the endian label
     */
    public String constructEndianLabel(String computerName) {
        String ret = "constructEndianLabel:COMPUTER_NOT_FOUND";
        
        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = "hw.endian." + getEndian(computer.getName());
        }

        return ret.toLowerCase();
    }

    public String constructPlatformLabel(String computerName) {
        String ret = "constructPlatformLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            def kernelInfo = getOsKernelInfo(computer.getName());

            switch(kernelInfo.get(0)) {
                case "linux":
                    ret = getPlatformString(getOsArch(computer.getName())) + kernelInfo.get(0);
                    break;
                case "windows":
                    ret = "win";
                    break;
                case "mac":
                case "aix":
                case "zos":
                    ret = kernelInfo.get(0);
                    break;
            }

            ret = "hw.platform." + ret;
        }

        return ret.toLowerCase();
    }

    private String getPlatformString(String value) {
        String ret = "getPlatformString:INVALID_PLATFORM ${value}";

        if (value.length() > 1) {
            switch (value) {
                case "amd64":
                    ret = "x";
                    break;
                case "ppc64":
                case "ppc64le":
                    ret = "p";
                    break;
                case "s390x":
                    ret = "z";
                case "arm":
                    ret = "arm";
                    break;
            }
        }

        return ret;
    }

    public String constructArchLabel(String computerName) {
        String ret = "constructArchLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            String arch = getOsArch(computer.getName());

            switch (arch) {
                case "x86_64":
                case "amd64":
                    ret = "x86";
                    break;
                case "ppc64":
                case "ppc64le":
                    ret = "ppc";
                    break;
                case "s390x":
                    ret = "s390";
                    break;
                case "arm":
                    ret = arch;
                    break;
                default:
                    ret = "INVALID_ARCH";
                    break;
            }
            ret = "hw.arch." + ret;
        }


        return ret.toLowerCase();
    }

    public String constructKernelLabel(String computerName) {
        String ret = "constructKernelLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            def kernelInfo = getOsKernelInfo(computer.getName());
            ret = "sw.os." + kernelInfo.get(0);
        }

        return ret;
    }

    public String constructHypervisorLabel(String computerName) {
        String ret = "constructHypervisorLabel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = "hw.hypervisor.";// TODO: finish implementation, get something
        }

        return ret.toLowerCase();
    }

    
    public Tuple getOsInfo(String computerName) {
        def ret;

        Computer computer = getComputer(computerName);
        if (computer != null) {
            def osInfo
            switch (getOsKernelInfo(computer.getName()).get(0)) {
                case "linux":
                    ret = getLinuxOsInfo(computer);
                    break;
                case "windows":
                    ret = getWindowsOsInfo(computer);
                    break;
                default:
                    ret = new Tuple("NOT_IMPLEMENTED_YET","NOT_IMPLEMENTED_YET");
                    break;
            }
        }

        return ret;
    }

    private Tuple getWindowsOsInfo(Computer computer) {
        String osName = "getWindowsOsInfo:COMPUTER_NOT_FOUND";
        String osVersion = "getWindowsOsInfo:COMPUTER_NOT_FOUND";

        if (computer != null) {
            osName = "getWindowsOsInfo:UNSUCCESSFUL_EXECUTION";
            osVersion = "getWindowsOsInfo:UNSUCCESSFUL_EXECUTION";

            Tuple osInfo;
            int index = 0;

            String cmdResult = execGroovy("wmic os get Caption /value", computer);

            if (!cmdResult.equals("error")) {
                osName = "WIN";
                String osString = cmdResult.split("=")[1].replace("Microsoft Windows ", "");
                osVersion = osString.replace("Server", "").trim().split(" ")[0];
            }

        }

        return new Tuple(osName,osVersion);
    }

    private Tuple getLinuxOsInfo(Computer computer) {
        String osName = "getLinuxOsInfo:COMPUTER_NOT_FOUND";
        String osVersion = "getLinuxOsInfo:COMPUTER_NOT_FOUND";

        if (computer != null) {
            /* Here we iterate over a list of commands
             * with the hope that one will work
             * The index of the command in the array
             * corresponds to the parse method that
             * needs to be called
             */
            osName = "UNSUCCESSFUL_EXECUTION";
            osVersion = "UNSUCCESSFUL_EXECUTION";
            def osInfo;

            int index = 0;
            
            // TODO: ls on the /etc and get anything with os in it
            // TODO: guess the execution based on key chars in the machine name
            String[] cmds = ["lsb_release -a", "cat /etc/*release", "cat /etc/redhat-release", "cat /etc/centos-release", "cat /etc/os-release"];
            
            String cmdResult;

            while (index < cmds.length && osInfo == null) {
                cmdResult = execGroovy(cmds[index], computer);

                if (!cmdResult.equals("error")) {
                    switch(index){
                        case 0:
                            osInfo = parseOsInfoString(cmdResult);
                            osName = osInfo.get(0);
                            osVersion = osInfo.get(1);
                            break;
                        case 1:
                        case 2:
                        case 3:
                            /* As of now, cases 1-3 should work with
                             * parseRedHatOsInfoString
                             */
                            osInfo = parseRedHatOsInfoString(cmdResult);
                            break;
                        case 4:
                            osInfo = parseSuseOsInfoString(cmdResult);
                            break;
                    }
                }

                if (!osInfo.equals(null)) {
                    osName = osInfo.get(0);
                    osVersion = osInfo.get(1);
                }

                index++;
            }
        }

        return new Tuple(osName,osVersion);
    }

    private Tuple parseSuseOsInfoString(String rawValue) {
        String osName = "parseSuseOsInfoString:INVALID_INPUT ${rawValue}";
        String osVersion = "parseSuseOsInfoString:INVALID_INPUT ${rawValue}";

        /* Sample raw value
         * NAME="SLES"
           VERSION="11.4"
           VERSION_ID="11.4"
           PRETTY_NAME="SUSE Linux Enterprise Server 11 SP4"
           ID="sles"
           ANSI_COLOR="0;32"
           CPE_NAME="cpe:/o:suse:sles:11:4"
         */

        if (rawValue.length() > 0) {
            rawValue = rawValue.trim();

            String[] rawValueArray = rawValue.split("\\n");
            int index = 0;
            String tmpLine;

            while ((index) < rawValueArray.length 
                    && (osName.contains("parseSuseOsInfoString:INVALID_INPUT") 
                            || osVersion.contains("parseSuseOsInfoString:INVALID_INPUT"))) {

                if (rawValueArray[index].matches("^ID=.*")) {
                    tmpLine = rawValueArray[index].replace("\"","");
                    osName = ((tmpLine.split("="))[1]);
                } else if (rawValueArray[index].matches("^VERSION=.*")) {
                    
                    tmpLine = rawValueArray[index].replace("\"","");
                    osVersion = ((tmpLine.split("="))[1]);

                    if (osVersion.contains(" ")) {
                        /* This deals with a edge case when
                         * the osVersion is "8 (something)".
                         * It works on the hope that the major
                         * version number will not be seperated
                         * by space.
                         */
                        osVersion = osVersion.split(" ")[0];
                    } 

                    if (osVersion.contains("-SP")) {
                        osVersion = osVersion.substring(0,osVersion.indexOf("-SP"));
                    }
                    if (osVersion.contains(".")) {
                        osVersion = osVersion.substring(0,osVersion.indexOf("."));
                    }

                }

                index++;
            }
        }

        return new Tuple(osName,osVersion);
    }

    private Tuple parseRedHatOsInfoString(String rawValue) {
        String osName = "parseRedHatOsInfoString:INVALID_INPUT";
        String osVersion = "parseRedHatOsInfoString:INVALID_INPUT";

        /* Sample raw values
         * CentOS Linux release 7.2.1511 (Core)
         * Red Hat Enterprise Linux Server release 7.4 (Maipo)
        */

        if (rawValue.length() > 0) {
            rawValue = rawValue.trim();
            
            String[] rawValueSplit = rawValue.split("release");

            if (rawValueSplit[0].contains("CentOS")) {
                osName = "cent";
            } else if (rawValueSplit[0].contains("Red")) {
                osName = "rhel";
            }

            osVersion = rawValueSplit[1].trim();
            if (!osVersion.equals("")) {
                osVersion = osVersion.substring(0,osVersion.indexOf(".")); // Removes the subversion
            }
        }

        return new Tuple(osName,osVersion);
    }

    private Tuple parseOsInfoString(String rawValue) {
        String osName = "parseOsInfoString:INVALID_INPUT";
        String osVersion = "parseOsInfoString:INVALID_INPUT";

        /* Sample raw value
         * Distributor ID:  Raspbian
           Description: Raspbian GNU/Linux 8.0 (jessie)
           Release: 8.0
           Codename:    jessie
         */

        if (rawValue.length() > 0) {
            rawValue = rawValue.trim();

            String[] rawValueArray = rawValue.split("\\n");
            int index = 0;
            while ((index) < rawValueArray.length 
                    && (osName.equals("parseOsInfoString:INVALID_INPUT") 
                        || osVersion.equals("parseOsInfoString:INVALID_INPUT"))) {

                if (rawValueArray[index].matches("^Distributor ID:\\s+.*")) {
                    if (rawValueArray[index].contains("Red")) {
                        osName = "rhel";
                    } else {
                        osName = ((rawValueArray[index].split(":\\s"))[1]);
                    }
                } else if (rawValueArray[index].matches("^Release:\\s+.*")) {
                    osVersion = ((rawValueArray[index].split(":\\s"))[1]);
                    osVersion = osVersion.substring(0,osVersion.indexOf(".")); // Removes the subversion
                }

                index++;
            }
        }

        return new Tuple(osName,osVersion);
    }

    /**
     * Gets the kernel info, version and name.
     * First index in the tuple is type, followed
     * by the versio in the second index
     * 
     * @param compterName computer for which labels are needed
     *
     * @return tuple containing kernel name and version
     *         in that order
     */
    public Tuple getOsKernelInfo(String computerName) {
        String retKernelType = "getOsKernelInfo:COMPUTER_NOT_FOUND";
        String retKernelVersion = "getOsKernelInfo:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            retKernelType = (computer.getSystemProperties()).get('os.name');
            if (retKernelType != null && !retKernelType.isEmpty()) {
                retKernelType = retKernelType.split(" ")[0].toLowerCase();

                if (retKernelType.toLowerCase().contains("z/os")) {
                    // This is to remove the slash for z/os
                    retKernelType = retKernelType.replace("/","");
                }
            }
            
            retKernelVersion = (computer.getSystemProperties()).get('os.version');
            if (retKernelVersion != null && !retKernelVersion.isEmpty()) {
                retKernelVersion = retKernelVersion.toLowerCase();
            }
        }

        return new Tuple(retKernelType,retKernelVersion);
    }

    /**
     * Gets the os architecture, 64 or 32 bit
     * 
     * @param compterName computer for which labels are needed
     * 
     * @return architecture of the os as string
     */
    public String getOsArch(String computerName) {
        String ret = "getOsArch:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = (computer.getSystemProperties()).get('os.arch');
        }

        return ret.toLowerCase();
    }

    /**
     * Gets the os patch version
     * 
     * @param compterName computer for which labels are needed
     * 
     * @return os patch version as string
     */
    public String getOsPatchLevel(String computerName) {
        String ret = "getOsPatchLevel:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = (computer.getSystemProperties()).get('sun.os.patch.level');
        }

        return ret;
    }

    /**
     * Gets which endian is being used
     * 
     * @param compterName computer for which endianness is needed
     * 
     * @return sequential order in which bytes are arranged
     */
    public String getEndian(String computerName) {
        String ret = "getEndian:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            switch ((computer.getSystemProperties()).get('sun.cpu.endian')) {
                case "little":
                    ret = "le";
                    break;
                case "big":
                    ret = "be";
                    break;
                default:
                    ret = "INVALID_ENDIAN";
                    break;
            }
        }    

        return ret;
    }

    /**
     * Gets the machine location from jenkins. 
     * This is the country the machine is located in.
     *
     * @param compterName computer whose location is needed
     *
     * @return machine location as string
     */
    public String getLocation(String computerName) {
        String ret = "getLocation:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = (computer.getSystemProperties()).get('user.country');
        }

        return ret;
    }

    /**
     * Gets the machine description from jenkins
     *
     * @param compterName computer whose location is needed
     *
     * @return machine description as string
     */
    public String getDescription(String computerName) {
        String ret = "getDescription:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            ret = computer.getDescription();
        }

        return ret;
    }

    /**
     * Gets cpu count via exec on the computer passed
     * in.
     *
     * @param compterName computer for which CPU count is needed
     *
     * @return number of CPUs on the machine as int.
     *         -1 if computer not found and 
     *         -2 if command was unsuccessful
     */
    public String getCpuCount(String computerName) {
        String ret = "getCpuCout: COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            switch (getOsKernelInfo(computer.getName()).get(0)) {
                case "linux":
                    ret = getCpuCountFromLinux(computer);
                    break;
                case "windows":
                    ret = getCpuCountFromWindows(computer);
                    break;
                default:
                    ret = "getCpuCout: INVALID_OS_KERNEL/NOT_IMPLEMENTED_YET";
                    break;
            }
        }

        return ret;
    }

    private String getCpuCountFromLinux(Computer computer) {
        String ret = "getCpuCountFromLinux: COMPUTER_NOT_FOUND";

        if (computer != null) {
            /* Probably should add more error checking
             * if is used somewhere else besides getCpuCount
             */
            ret = "getCpuCountFromLinux: UNSUCCESSFUL_EXECUTION";
            String cmdResult = execGroovy('lscpu', computer);

            if (cmdResult.length() > 0 && !cmdResult.equals("error")) {
                String[] cmdResultArray = cmdResult.split("\\n");

                int index = 0;
                while (index < cmdResultArray.length && !cmdResultArray[index].matches("^CPU\\(s\\):\\s{2,}.*")) {
                    // if (cmdResultArray[index].matches("^CPU\\(s\\):\\s{2,}.*")) {
                    //     ret = (cmdResultArray[index].split("^CPU\\(s\\):\\s{2,}"))[1];
                    // }
                    index++;
                }
                ret = (cmdResultArray[index].split("^CPU\\(s\\):\\s{2,}"))[1];
            }
        }

        return ret;
    }

    private String getCpuCountFromWindows(Computer computer) {
        String ret = "getCpuCountFromWindows: COMPUTER_NOT_FOUND";

        if (computer != null) {
            ret = -2;
            
            /* Below is the code with the right way to get CPU count
             * But due to a bug in setting up the environment variables on windows
             * this returns an inaccurate result.
             * This has to be fixed by the person who did the setup for the virtual
             * machines.
             * As of right now, we do not know how to fix the bug.
             */
            // To get number of logical processors add "NumberOfLogicalProcessors" after get
            // String cmdResult = execGroovy('wmic computersystem get NumberOfProcessors /Format:List', computer);

            // if (cmdResult.length() > 0 && !cmdResult.equals("error")) {
            //  String[] cmdResultArray = cmdResult.split("\\n");

            //  int index = 0;
            //  int numberOfProcessors = 1;
            //  int numberOfLogicalProcessors;
            //  while (index < cmdResultArray.length && ret < 0) {
            //      // TODO: the numbers don't match with what's on jenkins
            //      numberOfProcessors *= Integer.parseInt((cmdResultArray[index].split("="))[1].trim());
            //      index++;
            //  }
            //  ret = numberOfProcessors;
            // }

            // Here's the hack approach
            String cmdResult = execGroovy("wmic cpu get SocketDesignation", computer);
            if (cmdResult.length() > 0 && !cmdResult.equals("error")) {
                // The -1 is to account for header row
                ret = cmdResult.split("\\n").length - 1;
            }
        }

        return ret;
    }

    /**
     * Gets the physical free and total memory
     *
     * @param compterName computer for which memory info is needed
     *
     * @return tuple containing total and available memory
     *         as long
     */
    public Tuple getMemory(String computerName) {
        String totalMemory = "getMemory:COMPUTER_NOT_FOUND";
        String freeMemory = "getMemory:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {

            Map<String, Object> monitoringData = computer.getMonitorData(); 
            def memoryMonitor = monitoringData.get('hudson.node_monitors.SwapSpaceMonitor');
            if (memoryMonitor != null) {
                freeMemory = convertToHumanReadableByteCount(memoryMonitor.getAvailablePhysicalMemory());               
                totalMemory = convertToHumanReadableByteCount(memoryMonitor.getTotalPhysicalMemory());
                if (freeMemory.contains("-1")){
                    freeMemory = "MEMORY_INFO_NOT_AVAILABLE";
                }
                if (totalMemory.contains("-1")) {
                    totalMemory = "MEMORY_INFO_NOT_AVAILABLE";
                }
            } else {
                // TODO: Maybe do a system exec to get the info, as a last resort?
                freeMemory = "MONITORING_DATA_NOT_FOUND";
                totalMemory = "MONITORING_DATA_NOT_FOUND";
            }
        }

        return new Tuple(totalMemory,freeMemory);
    }

    /**
     * Gets the remaining space in the remote FS root
     *
     * @param compterName computer for which space info is needed
     *
     * @return remaining empty space as string
     */
    public String getSpaceLeftInGb(String computerName) {
        String ret = "getSpaceLeftInGb:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {
            Map<String, Object> monitoringData = computer.getMonitorData();         
            ret = monitoringData.get('hudson.node_monitors.DiskSpaceMonitor').getGbLeft();
        }

        return ret;
    }

    public String getTotalSpace(String computerName) {
        String ret = "getTotalSpace:COMPUTER_NOT_FOUND";

        Computer computer = getComputer(computerName);
        if (computer != null) {

            long totalSpace = computer.getNode().getRootPath().getTotalDiskSpace();
            if (totalSpace > 0) {
                ret = convertToHumanReadableByteCount(totalSpace);
            } else {
                ret = "SPACE_INFO_NOT_FOUND";
            }
        }

        return ret;
    }

    private String execGroovy(String cmd, Computer computer) { // TODO: Also check for invalid command (?)
        String ret = "execGroovy:INVALID_COMMAND";

        if (cmd.length() > 1 && computer != null) {
                /* Since we can't get everything from the JVM
                 * we use this method.
                 * It takes the command passed in and executes it
                 * on the desired remote computer.
                 * If the command fails it returns "error" as string
                 */
                Channel computerChannel = computer.getChannel();
                
                /* TODO: maybe have a list of commands that someone call call in a config file outside
                 *       somewhere
                 */
                StringBuilder command = new StringBuilder();
                command.append("Process cmd = Runtime.getRuntime().exec(\"$cmd\");\n");
                // command.append("cmd.inputStream.eachLine {println it}"); // < try this if .text fails
                command.append("println cmd.text");


                String result = RemotingDiagnostics.executeGroovy(command.toString(), computerChannel).trim();

                // TODO: maybe we should be returning the exception type?
                if (result.equals("") 
                    || result.contains("error") 
                    || result.contains("exception") 
                    || result.contains("management")) {
                    /* TODO: Probably should make a list of errors somwhere to look 
                     *       out for when dealing with command output
                     */
                    ret = "error";
                } else {
                    ret = result;
                }
            }

        return ret;
    }

    /**
     * Converts bytes to easily readable format.
     * This code is a modified version of the original.
     *
     * @param rawBytes
     * 
     * @see http://programming.guide/java/formatting-byte-size-to-human-readable-format.html
     * 
     * @return human readable format as string
     */
    public String convertToHumanReadableByteCount(long rawBytes) {

        int unit = 1024;
        if (rawBytes < unit) return rawBytes + " B";
        int exp = (int) (Math.log(rawBytes) / Math.log(unit));
        String pre = ("kMGTPE").charAt(exp-1);
        double humanReadable = rawBytes / Math.pow(unit, exp - 1);

        /* It's divided by 1000 here to avoid inaccuracy due to
         * conversion
         * TODO: round up after every conversion step(?)
         *       i.e. bytes -> mbytes round up
         *            mbytes -> kbytes round up
         */
        humanReadable = humanReadable/1000;

        return String.format("%d%sB", (Math.rint(humanReadable)).intValue(), pre);
    }

    /**
     * Validates computer names.
     *
     * @param computerName
     *
     * @return null if computer is not found and computer object
     *         otherwise
     */
    private Computer getComputer(String computerName) {
        Computer ret = null;

        // TODO: Maybe use this function to enforce conputer name guidelines in future(?)
        if (computerName.length() > 2) {
            /* It didn't make sense to check just for 0 or 1, hence
             * the 2
             */
            ret = Jenkins.getInstance().getComputer(computerName);
            if (ret == null) {
                // tries to search for computer without the domain
                ret = Jenkins.getInstance().getComputer(computerName.substring(0,ret.indexOf(".")));
            }
        }

        return ret;
    }

    private boolean isValidDouble(String input) {
        boolean ret = false;

        if (input.length() > 0) {
            double parsedValue = 0;

            try {
                parsedValue = Double.parseDouble(input);
                ret = true;
            } catch (NumberFormatException e) {
                /* Don't really need to do anything
                 * just pass back false
                 */
            }
        }

        return ret;
    }
}
