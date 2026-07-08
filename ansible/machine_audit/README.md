# Machine Audit

This directory contains the tooling used to audit Adoptium build and test infrastructure. Audits collect information about each machine's OS, architecture, and installed packages, writing the result to a JSON file on the machine. A backend aggregation step (which currently runs on the nagios server) then pulls those files back to a central host for review.

## Directory Structure

```
machine_audit/
├── linux_aix_audit.yml       # Playbook: audits Linux and AIX build/test nodes
├── static_docker_audit.yml   # Playbook: audits static Docker containers on dockerhost nodes
├── windows_audit.yml         # Playbook: audits Windows build/test nodes
│
├── platform/                 # Per-platform audit scripts (deployed and run on target machines)
│   ├── linux.py              # Collects OS/package info on Linux; writes /var/log/machine_info.json
│   ├── aix.py                # Collects OS/package info on AIX;   writes /var/log/machine_info.json
│   └── windows.ps1           # Collects OS/package info on Windows; writes C:\machine_info.json
│
├── packages/                 
│   ├── linux                 # Build and test package list for Linux nodes
│   ├── aix                   # Build and test package list for AIX nodes
│   └── windows               # Build and test package list for Windows nodes
│
└── backend/                  # Aggregation tooling: runs on a central host (e.g. Nagios server)
    ├── nagios_aggregate.yml  # Playbook: deploys and runs main.py on the aggregation host
    ├── main.py               # Orchestrator: collects machine_info.json from each machine listed in jenkins
    ├── getNodeList.py        # Queries Jenkins API to produce a list of Adoptium build and test machines
    ├── requirements.txt      # Python dependencies (python-dotenv, python-jenkins)
```

## What does the audit look like?

A small snippet of the `machine_info.json` file created after an audit of a AIX build node:
```
{
  "timestamp": "2026-05-11T15:38:20Z",
  "hostname": "adopt02",
  "os": {
    "name": "AIX",
    "version": "7.2.0.0",
    "kernel": "7.2",
    "technology_level": "7200-02-02-1810",
    "architecture": "powerpc"
  },
  "packages": {
    "build_packages": {
      "JDK8": {
        "installed": true,
        "path": "/usr/java8_64/bin/java"
      },
      "JDK10": {
        "installed": true,
        "path": "/usr/java10_64/bin/java"
      },
      "JDK11": {
        "installed": true,
        "path": "/usr/java11_64/bin/java"
      },
      "JDK17": {
        "installed": true,
        "path": "/usr/java17_64/bin/java"
      },
      "JDK21": {
        "installed": true,
        "path": "/usr/java21_64/bin/java"
      },
      "JDK24": {
        "installed": false,
        "path": null
      },
      "JDK25": {
        "installed": false,
        "path": null
      },
      "gcc": {
        "installed": false,
        "path": null
      }
...
```

## Schedule
The audit playbooks, linux_aix_audit.yml, static_docker_audit.yml and windows_audit.yml, are executed on a **weekly schedule** in AWX. Each run targets the full machine inventory for the relevant platform. The `backend/nagios_aggregate.yml` playbook is also scheduled weekly (after the audit playbooks complete) to pull the resulting `machine_info.json` files back to the central aggregation host.

To run the audits manually outside of the scheduled AWX jobs, see [Running the Platform Scripts Manually](#running-the-platform-scripts-manually) below.

---

## Running the Platform Scripts Manually

The scripts in [`platform/`](platform/) can be run directly on a target machine without Ansible, which is useful for testing or one-off audits.

> **Note:** The packages manifest must be placed at `packages/linux`, `packages/aix`, or `packages\windows` relative to the script's own directory. The scripts resolve the manifest path using their own file location, so keep the `packages/` subdirectory alongside the script when copying files to a target machine.

### Linux — `platform/linux.py`

The script must be run as a user with write access to `/var/log/` (typically `root`).

```bash
# Copy the script and packages manifest to the target machine
scp platform/linux.py  <user>@<host>:/tmp/machine_audit/linux.py
scp packages/linux     <user>@<host>:/tmp/machine_audit/packages/linux

# SSH into the machine and run the script
ssh <user>@<host>
sudo python3 /tmp/machine_audit/linux.py

# The result is written to:
#   /var/log/machine_info.json
```

### AIX — `platform/aix.py`

Identical steps to Linux. The script requires write access to `/var/log/`.

```bash
scp platform/aix.py  <user>@<host>:/tmp/machine_audit/aix.py
scp packages/aix     <user>@<host>:/tmp/machine_audit/packages/aix

ssh <user>@<host>
sudo python3 /tmp/machine_audit/aix.py

# The result is written to:
#   /var/log/machine_info.json
```

### Windows — `platform/windows.ps1`

The script must be run in a PowerShell session with write access to `C:\`. Running as Administrator is recommended.

Copy the script and packages manifest to the target machine so the directory layout looks like:

```
C:\temp\machine_audit\
├── windows.ps1
└── packages\
    └── windows
```

Then open an elevated PowerShell prompt and run:

```powershell
Set-Location "C:\temp\machine_audit"
powershell.exe -ExecutionPolicy Bypass -File ".\windows.ps1"

# The result is written to:
#   C:\machine_info.json
```

## Running the backend scripts manually

The backend scripts run on the central aggregation host (the Nagios server). They can also be run locally for development or debugging.

### Prerequisites

Install the Python dependencies from [`backend/requirements.txt`](backend/requirements.txt):

```bash
cd ansible/machine_audit/backend
pip install -r requirements.txt
```

Create a `.env` file in the `backend/` directory with your Jenkins credentials:

```ini
url=https://<jenkins-host>:80
username=<jenkins-username>
password=<jenkins-api-token>
```

### `backend/main.py`

Runs the full collection pipeline: refreshes `machine.list` from Jenkins, then SCPs `machine_info.json` from every node in the list into `backend/collectedInfo/`.

```bash
cd ansible/machine_audit/backend
python3 main.py

# Collected files are written to:
#   backend/collectedInfo/<node_name>_machine_info.json
```

> **Note:** `main.py` connects as the `nagios` user via SCP. The host you run it from must have passwordless SSH access to each node as `nagios`. The script currently skips windows and most dynamic nodes.

---

*Documentation generated with the assistance of IBM Bob*
