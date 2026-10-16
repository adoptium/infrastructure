# Static Windows 11 VM Configuration Guide

This folder contains scripts to configure a static or standalone Windows 11 virtual machine (ARM64 or x64) with a clean, interactive desktop in console Session 1 for [Corretto Arctic](https://github.com/corretto/arctic) GUI testing and persistent Jenkins inbound agent connectivity.

Unlike dynamically provisioned agents created from an image template, these scripts are run directly on a newly created or existing long-lived Windows VM.

---

## Scripts in this Folder

| Script | Purpose | When to use |
|---|---|---|
| `standalone-vm-setup.ps1` | All-in-one setup: user verification, Winlogon auto-logon, desktop optimization, power settings, firewall notification suppression, display resolution, and optional Jenkins inbound agent setup | Freshly created standalone Windows 11 VM |
| `configure-agent-desktop.ps1` | Granular switch-based utility: apply individual parts (`-AutoLogon`, `-Desktop`, `-Resolution`, `-DisableFirewallNotify`, `-ForwardToConsole`, `-JenkinsAgent`, `-Verify`) | Existing VM or selective configuration adjustments |

---

## 1. Prerequisites

1. **Operating System**: Windows 11 (ARM64 or x64, Gen2 recommended).
2. **Local User**: An existing local user account (`<agent-user>`) must already be present on the VM.
3. **Elevated Permissions**: Run scripts in an elevated Administrator PowerShell session or via SSH as an administrator.
4. **Java Runtime**: OpenJDK installed (default path: `C:\openjdk\jdk-21\bin\javaw.exe`).
5. **Jenkins Node (if connecting to Jenkins)**:
   - Configured in Jenkins under *Manage Jenkins -> Nodes -> New Node*.
   - Launch method: **Launch agent by connecting it to the controller** (Inbound / JNLP).
   - Note the **Jenkins URL**, **Node Name**, and **Secret**.

---

## 2. Setting Up a Fresh VM with `standalone-vm-setup.ps1`

### 2.1 Copy Script to VM

Copy `standalone-vm-setup.ps1` to the target machine via SSH or file share:

```bash
scp standalone-vm-setup.ps1 <admin-user>@<vm-ip>:C:/Users/<admin-user>/
```

### 2.2 Execution Syntax

Open an elevated PowerShell prompt on the VM and enable script execution:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Users\<admin-user>
```

#### Example A: Full Setup with Jenkins Inbound Agent

```powershell
$pw  = Read-Host -AsSecureString "Agent user password"
$sec = Read-Host -AsSecureString "Jenkins agent secret"

.\standalone-vm-setup.ps1 -AgentUser <agent-user> -AgentPassword $pw `
    -JenkinsUrl https://<jenkins-url>/ -NodeName <node-name> -Secret $sec
```

#### Example B: Standalone VM Setup without Jenkins Agent (Local Testing)

```powershell
$pw = Read-Host -AsSecureString "Agent user password"

.\standalone-vm-setup.ps1 -AgentUser <agent-user> -AgentPassword $pw -SkipJenkinsAgent
```

#### Example C: Custom Resolution (e.g. 1280x1024)

```powershell
$pw  = Read-Host -AsSecureString "Agent user password"
$sec = Read-Host -AsSecureString "Jenkins agent secret"

.\standalone-vm-setup.ps1 -AgentUser <agent-user> -AgentPassword $pw `
    -JenkinsUrl https://<jenkins-url>/ -NodeName <node-name> -Secret $sec `
    -Width 1280 -Height 1024
```

### 2.3 Post-Setup Reboot

After running the script, restart the VM once so Winlogon auto-logs into console Session 1:

```powershell
Restart-Computer
```

---

## 3. Parameter Reference: `standalone-vm-setup.ps1`

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `-AgentUser` | `string` | **Yes** | - | Existing local user account that owns the desktop and runs tests. |
| `-AgentPassword` | `SecureString` | Yes* | - | Password for `-AgentUser`. *Required unless `-SkipAutoLogon` or `-Verify`. |
| `-JenkinsUrl` | `string` | No | - | Jenkins controller URL (must start with `https://`). |
| `-NodeName` | `string` | No | - | Node name configured on Jenkins controller. |
| `-Secret` | `SecureString` | No | - | Shared secret for the inbound Jenkins agent. |
| `-Java` | `string` | No | `C:\openjdk\jdk-21\bin\javaw.exe` | Path to `javaw.exe`. |
| `-WorkDir` | `string` | No | `C:\workspace` | Workspace and remoting log directory. |
| `-Width` | `int` | No | `1024` | Target display width in pixels (640-7680). |
| `-Height` | `int` | No | `768` | Target display height in pixels (480-4320). |
| `-SkipAutoLogon` | `switch` | No | `False` | Skips configuring Winlogon auto-logon. |
| `-SkipJenkinsAgent` | `switch` | No | `False` | Skips Jenkins `agent.jar` download and task registration. |
| `-ForwardToConsole` | `switch` | No | `False` | Forwards the active RDP session to console Session 1. |
| `-Verify` | `switch` | No | `False` | Reports configuration status without making changes. |

---

## 4. Verification and Diagnostics

To check the configuration on an active machine, run over SSH or elevated PowerShell:

```powershell
.\standalone-vm-setup.ps1 -AgentUser <agent-user> -Verify
```

Expected output:
```text
Diagnostic state for agent user 'testagent':
  [OK ] Auto-logon: AutoAdminLogon=1 DefaultUserName=testagent DefaultDomainName=. Password=set
  [OK ] Desktop session: testagent logged on in session 1 (console)
  [OK ] DesktopSettings task: last run ..., result 0
  [OK ] Resolution: current 1024x768, target 1024x768
  [OK ] Firewall NotifyOnListen: False for all profiles
  [OK ] JenkinsAgent task: result 267009 (267009 = running)
  [OK ] Agent process: javaw as TESTVM\testagent in session 1
```

Additional manual checks:
```powershell
# Check console session
qwinsta

# Check agent process and session ID
Get-Process javaw -IncludeUserName | Select-Object UserName, SessionId

# View remoting logs
Get-Content C:\workspace\remoting\logs\remoting.log.0 -Tail 10
```

---

## 5. Remote Session Management (`-ForwardToConsole`)

When debugging a standalone VM using Remote Desktop (RDP), Windows attaches the user to an RDP session rather than physical console Session 1. When the RDP client disconnects, the session may lock.

To hand the desktop session back to the console so Corretto Arctic tests continue running uninterrupted:

```powershell
.\standalone-vm-setup.ps1 -AgentUser <agent-user> -ForwardToConsole
```

> **Note**: Running `-ForwardToConsole` from within an active RDP session will intentionally disconnect the RDP client as the desktop moves to the physical console.

---

## 6. Granular Configuration with `configure-agent-desktop.ps1`

For existing long-lived VMs where only specific parts of the configuration need to be applied or modified, use `configure-agent-desktop.ps1`.

### Switch Summary

| Switch | Action |
|---|---|
| `-AutoLogon` | Configures Winlogon auto-logon (requires `-AgentPassword`). |
| `-Desktop` | Applies black background, hides icons, hides taskbar, disables widgets and animations. |
| `-Resolution` | Sets display resolution (optional `-Width` and `-Height`). |
| `-DisableFirewallNotify` | Sets `NotifyOnListen = False` across firewall profiles. |
| `-ForwardToConsole` | Moves RDP session to physical console (`tscon`). |
| `-JenkinsAgent` | Downloads `agent.jar` and registers `JenkinsAgent` task. |
| `-Verify` | Reports current status of all settings. |

`DesktopSettings` regenerates `C:\DesktopSetup\desktop.ps1` from the switches passed in that run, so a run with only `-Resolution` removes the desktop styling and a run with only `-Desktop` removes the resolution step. Pass every component you want enabled (for example `-Desktop -Resolution`) whenever you re-run it.

When a desktop task is configured, `JenkinsAgent` has no logon trigger of its own. `DesktopSettings` starts it once the desktop is ready, so the agent does not accept jobs while the shell is still being reconfigured. An agent-only setup (no `-Desktop` or `-Resolution`, and no existing `DesktopSettings` task) starts at logon as before.

### Examples

```powershell
# Apply desktop styling and resolution only:
.\configure-agent-desktop.ps1 -AgentUser <agent-user> -Desktop -Resolution -Width 1280 -Height 1024

# Re-register Jenkins agent:
.\configure-agent-desktop.ps1 -AgentUser <agent-user> -JenkinsAgent `
    -JenkinsUrl https://<jenkins-url>/ -NodeName <node-name> -Secret (Read-Host -AsSecureString 'Secret')

# Check current configuration:
.\configure-agent-desktop.ps1 -AgentUser <agent-user> -Verify
```

---

## 7. Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| User not logged into console; `4625 C000006D/C000006A` in Event Log | Password mismatch between local user and the stored auto-logon password (LSA secret) | Re-run setup with the correct password or update local user password. |
| After someone else signed in at the console, the VM does not return to the agent desktop on reboot | Windows replaced `DefaultUserName` with the last account to sign in | The `AutoLogonIdentity` task (SYSTEM) restores `DefaultUserName` at shutdown, logon and startup. If the task is missing, re-run setup (or `configure-agent-desktop.ps1 -AutoLogon`); `-Verify` reports it. |
| `Java executable not found at '...'` | JDK is not installed at the default path | Install OpenJDK or pass `-Java "C:\path\to\bin\javaw.exe"`. |
| Jenkins agent fails with `Failed to connect: Handshake error` | WebSocket mode attempted against controller | Inbound agent uses TCP port. Verify TCP inbound port is enabled in Jenkins controller. |
| Desktop icons or wallpaper visible | `DesktopSettings` task has not completed | Run `Start-ScheduledTask DesktopSettings` or check `C:\DesktopSetup\desktop.log`. |
| Agent offline after logon | `JenkinsAgent` is started by `DesktopSettings`, which has not finished or failed | Check `C:\DesktopSetup\desktop.log` for `Started JenkinsAgent after desktop initialization`; run `Start-ScheduledTask JenkinsAgent` to start it manually. |
| Firewall pop-up blocks automated tests | `NotifyOnListen` active on network profile | Re-run setup or execute: `Set-NetFirewallProfile -Profile Domain,Private,Public -NotifyOnListen False`. |

---

## 8. Security Guidelines

1. **Passwords & Secrets**: Always input credentials via `Read-Host -AsSecureString` or secure environment variables. Never hard-code passwords in scripts or pass plain text on command lines.
2. **Auto-logon password**: The scripts store the auto-logon password as the LSA secret `DefaultPassword` (encrypted; readable only by administrators and SYSTEM), not in the plaintext `DefaultPassword` value under `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`, which non-administrator users can read. Setup deletes any existing plaintext registry value, and `-Verify` reports `PLAINTEXT registry value present` if one is found. Because the agent account is a local administrator, anyone with administrator access to the VM can still recover the password; use a unique password for the agent account.
3. **HTTPS Protocol**: Always supply Jenkins controller URLs using `https://`.
