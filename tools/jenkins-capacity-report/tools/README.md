# Jenkins Tools

This directory contains utility scripts for Jenkins administration and configuration management.

## Files

- **extract_clouds_config.sh** - Script to extract clouds configuration from Jenkins
- **clouds.xml.example** - Example clouds configuration showing various cloud providers
- **README.md** - This documentation file

## Scripts

### extract_clouds_config.sh

Extracts the clouds configuration from Jenkins `config.xml` file for use by the Jenkins Capacity Analyzer.

#### Purpose
This script extracts the `<clouds>` section from the Jenkins configuration file, which contains all cloud provider configurations (AWS, Azure, Docker, Kubernetes, Orka, etc.) used for dynamic agent provisioning. The extracted configuration enables cloud capacity reporting in both the CLI tool and web dashboard.

#### Use Case
The Jenkins Capacity Analyzer uses this extracted configuration to:
- Display cloud provider capacity limits and instance caps
- Show template configurations for each cloud provider
- Analyze executor capacity across cloud templates
- Report on OS types and architectures available in cloud templates
- Provide insights into dynamic agent provisioning capabilities

#### Usage

**For Jenkins Capacity Analyzer (Recommended):**
```bash
# On Jenkins controller, extract to the capacity analyzer directory
cd /path/to/jenkins-capacity-report/tools
./extract_clouds_config.sh -o ../data/clouds.xml.live

# Then update your .env file to reference this file:
# CLOUD_CONFIG_FILE=./data/clouds.xml.live
```

**Basic Usage (On Jenkins Controller):**
```bash
cd /path/to/jenkins-capacity-report/tools
./extract_clouds_config.sh
```

**With Analysis:**
```bash
./extract_clouds_config.sh --analyze
```

**Custom Output File:**
```bash
./extract_clouds_config.sh -o my_clouds.xml
```

**With Custom Jenkins Home:**
```bash
JENKINS_HOME=/var/lib/jenkins ./extract_clouds_config.sh --analyze
```

**All Options:**
```bash
./extract_clouds_config.sh --analyze --output custom_clouds.xml
```

**Remote Extraction (Copy to Local Machine):**
```bash
# On Jenkins server
cd /path/to/jenkins-capacity-report/tools
./extract_clouds_config.sh -o /tmp/clouds.xml.live

# On your local machine
scp jenkins-server:/tmp/clouds.xml.live ./jenkins-capacity-report/data/
```

#### Requirements
- Must be run on the Jenkins controller server
- Read access to Jenkins `config.xml` file
- `sed` command available (standard on Linux/Unix systems)

#### Output
- Creates `clouds.xml` in the current directory
- Contains the complete `<clouds>` section from Jenkins configuration
- Displays file statistics and preview of extracted content

#### Default Paths
- Jenkins Home: `/home/jenkins/.jenkins`
- Config File: `${JENKINS_HOME}/config.xml`
- Output File: `./clouds.xml`

#### Command Line Options

- `-a, --analyze` - Analyze the extracted configuration and show statistics
- `-o, --output FILE` - Specify custom output file name (default: clouds.xml)
- `-h, --help` - Show help message

#### Features
- ✅ Validates Jenkins config.xml exists before extraction
- ✅ Colored output for better readability
- ✅ Error handling and informative messages
- ✅ File size and line count statistics
- ✅ Preview of extracted content
- ✅ Handles cases where no clouds configuration exists
- ✅ **NEW:** Analyze cloud configurations (counts providers and templates)
- ✅ **NEW:** Custom output file support
- ✅ **NEW:** Command-line argument parsing

#### Exit Codes
- `0` - Success (configuration extracted or no clouds found)
- `1` - Error (config.xml not found or extraction failed)

#### Example Output

**Basic Extraction:**
```
[INFO] Checking Jenkins environment...
[INFO] Found Jenkins config.xml at: /home/jenkins/.jenkins/config.xml
[INFO] Extracting clouds configuration...
[INFO] Successfully extracted clouds configuration to: clouds.xml
[INFO] File size: 63396 bytes
[INFO] Line count: 1202 lines
[INFO] Preview (first 10 lines):
----------------------------------------
  <clouds>
    <io.jenkins.plugins.orka.OrkaCloud plugin="macstadium-orka@2.09">
      <actions/>
      <name>orka</name>
      <credentialsId>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</credentialsId>
      <endpoint>http://10.0.0.1</endpoint>
      <instanceCap>2147483647</instanceCap>
      <instanceCapSetting></instanceCapSetting>
      <timeout>600</timeout>
      <httpTimeout>300</httpTimeout>
----------------------------------------
[INFO] Extraction complete!
[INFO] Output file: /path/to/clouds.xml

[INFO] Tip: Use -a or --analyze flag to analyze the configuration
```

**With Analysis:**
```
[INFO] Checking Jenkins environment...
[INFO] Found Jenkins config.xml at: /home/jenkins/.jenkins/config.xml
[INFO] Extracting clouds configuration...
[INFO] Successfully extracted clouds configuration to: clouds.xml
[INFO] File size: 63396 bytes
[INFO] Line count: 1202 lines
[INFO] Preview (first 10 lines):
----------------------------------------
  <clouds>
    <io.jenkins.plugins.orka.OrkaCloud plugin="macstadium-orka@2.09">
      ...
----------------------------------------

[INFO] Analyzing clouds configuration...

Cloud Providers Found:
======================
  • Orka (MacStadium): 2
  • Azure: 12

Total Cloud Configurations: 14

  • Orka Templates: 14
  • Azure Templates: 20

[INFO] Extraction complete!
[INFO] Output file: /path/to/clouds.xml
```

#### Notes
- The script uses `sed` to extract content between `<clouds>` and `</clouds>` tags
- Preserves XML formatting and indentation
- Safe to run multiple times (overwrites previous output)
- Does not modify the original Jenkins configuration

### clouds.xml.example

Example clouds configuration file showing various cloud provider configurations.

#### Purpose
Provides a reference template for Jenkins cloud configurations including:
- **Orka/MacStadium** - macOS build agents
- **Azure** - Azure VM agents
- **AWS EC2** - EC2 instance agents
- **Kubernetes** - Kubernetes pod agents

#### Contents
- Sanitized configuration examples (no real credentials or IPs)
- Common configuration patterns for each cloud type
- Template structures for agent provisioning
- Network and security settings examples

#### Usage
Use this file as a reference when:
- Setting up new cloud configurations
- Understanding cloud configuration structure
- Troubleshooting existing configurations
- Comparing with extracted configurations

**Note:** All credentials IDs, IP addresses, and sensitive data in this file are dummy values for example purposes only.

## Future Tools

Additional utility scripts may be added to this directory for:
- Node configuration extraction
- Plugin management
- Backup automation
- Configuration validation