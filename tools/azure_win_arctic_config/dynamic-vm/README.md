# Dynamic Windows 11 VM Provisioning Guide

This folder contains scripts to build and provision dynamic Azure Windows 11 virtual machines (ARM64 or x64) with a clean, interactive desktop in console Session 1 for [Corretto Arctic](https://github.com/corretto/arctic) GUI testing in Jenkins.

---

## Scripts in this Folder

| Script | Purpose | Where it runs |
|---|---|---|
| `image-prep.ps1` | Prepares a temporary build VM before sysprep (auto-logon persistence, machine policies, power settings) | Build VM (elevated, before sysprep) |
| `jenkins-inbound-init.ps1` | Jenkins template **Initialization script** that downloads `agent.jar` and registers Session 1 logon tasks | Dynamically created VMs (run by Azure VM Agents plugin) |

---

## 1. Architecture & Provisioning Lifecycle

```text
Build VM (Temporary)
  |  Base OS + Updates + OpenSSH + JDK
  v
Run image-prep.ps1
  |- Creates local agent user & stores encrypted credentials in C:\ImageSetup
  |- Registers ImageAutoLogon SYSTEM startup task (re-applies auto-logon on every boot)
  |- Suppresses OOBE privacy screens, animations, and sleep timeouts
  v
Sysprep & Capture -> Azure Compute Gallery Image Version
  v
Jenkins Azure VM Agents Plugin creates VM
  |
  +-- Boot 1: ImageAutoLogon task starts, waits for Custom Script Extension (CSE)
  |           CSE runs jenkins-inbound-init.ps1 -> downloads agent.jar, registers tasks
  |           ImageAutoLogon reboots machine once
  |
  +-- Boot 2: Winlogon auto-logs into console Session 1 as <agent-user>
              BlankDesktop task cleans desktop (black wallpaper, no icons, hides taskbar)
              JenkinsAgent task starts javaw agent.jar in Session 1
  v
Node online in Jenkins (~4-5 mins after VM creation); tests execute in Session 1
```

---

## 2. Using `image-prep.ps1` (Image Build Phase)

### 2.1 Build Machine Prerequisites

1. Create a base Windows 11 VM (`Standard_D4plds_v6` for ARM64 or `Standard_D4s_v5` for x64, Gen2).
2. Complete the standard Adoptium Windows playbook (install OpenSSH Server, deploy `administrators_authorized_keys`).
3. Ensure JDK 21 is installed at `C:\openjdk\jdk-21\bin\javaw.exe`.
4. Apply all pending Windows Updates.

### 2.2 Run `image-prep.ps1`

Copy `image-prep.ps1` to the build VM:

```bash
scp image-prep.ps1 <admin-user>@<vm-ip>:C:/Users/<admin-user>/
```

In an elevated PowerShell prompt on the build VM:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Users\<admin-user>

# Prompt for agent password (never hard-code or pass plain text):
$pw = Read-Host -AsSecureString "Agent user password"
.\image-prep.ps1 -AgentUser <agent-user> -AgentPassword $pw
```

### 2.3 Verify and Clean Up

Restart the build VM, reconnect over SSH, and verify:

```powershell
Restart-Computer
# Wait ~1 minute, reconnect via SSH:
Set-ExecutionPolicy -Scope Process Bypass -Force
.\image-prep.ps1 -AgentUser <agent-user> -Verify
```

*Expected output*: `PASS - <agent-user> has an interactive desktop (explorer.exe, session 1)`.

Clean up temporary build artifacts before running sysprep:

```powershell
Remove-Item C:\ImageSetup\rebooted-*, C:\ImageSetup\autologon.log -ErrorAction SilentlyContinue
Remove-Item C:\Users\<admin-user>\image-prep.ps1
```

### 2.4 Generalize and Capture

1. Execute sysprep:
   ```cmd
   C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown
   ```
2. Capture the generalized VM to your Azure Compute Gallery as a new image version.
3. Replicate the image version to your target deployment regions.

---

## 3. Using `jenkins-inbound-init.ps1` (Jenkins Template Configuration)

### 3.1 Script Preparation

Open `jenkins-inbound-init.ps1` and set `$AgentUser` near the top to match the `-AgentUser` used during image preparation:

```powershell
$AgentUser = '<agent-user>'   # Replace <agent-user> with your actual agent username
```

### 3.2 Jenkins Agent Template Settings

Configure under *Manage Jenkins -> Clouds -> (Azure cloud) -> Agent templates*:

| Setting | Value | Notes |
|---|---|---|
| **OS type** | `Windows` | |
| **VM size** | `Standard_D4plds_v6` (ARM64) or `Standard_D4s_v5` (x64) | Must match image architecture |
| **Image** | Azure Compute Gallery image definition | Pin specific image version |
| **Launch method** | **Inbound** | Do NOT use SSH |
| **Initialization script** | Full content of `jenkins-inbound-init.ps1` | Set `$AgentUser` and paste **only** this script |
| **Remote root** | `C:\workspace` | Matches `-workDir` in script |
| **Admin credentials** | Username with password credential | Password must match image password if username matches agent user |
| **Launch timeout** | `10` minutes or higher | Allows time for auto-logon reboot |
| **Inbound TCP Port** | Enabled on Jenkins controller | Required for JNLP connection |

---

## 4. Checking Provisioned Dynamic Agents

Allow 4-5 minutes after VM creation for the provisioning sequence and single reboot. Connect over SSH:

```powershell
# 1. Inspect auto-logon log
Get-Content C:\ImageSetup\autologon.log

# 2. Check console session (must show <agent-user> Active on console)
qwinsta

# 3. Check agent process session (must show SessionId 1)
Get-Process javaw -IncludeUserName | Select-Object UserName, SessionId

# 4. Check scheduled tasks
Get-ScheduledTask JenkinsAgent, BlankDesktop | Get-ScheduledTaskInfo | Select-Object TaskName, LastTaskResult

# 5. Check Jenkins remoting connection
Copy-Item C:\workspace\remoting\logs\remoting.log.0 $env:TEMP\r.log -Force
Get-Content $env:TEMP\r.log -Tail 5
```

---

## 5. Troubleshooting Dynamic Agents

| Symptom | Cause | Solution |
|---|---|---|
| Console has no user; Event 4625 `C000006D/C000006A` | Template credential password does not match `agent.pw` | Ensure Jenkins template credentials and image password match. |
| `autologon.log` has no `Init script (CSE) state` line | Still waiting for Custom Script Extension to finish | Wait up to 15 minutes; check CSE status. |
| Init script status `error`: "interrupted by a VM restart" | Auto-logon reboot hit before init script completed | Rebuild image with current `image-prep.ps1` containing CSE wait logic. |
| Init script status `error`: `Set $AgentUser at the top...` | Placeholder `<agent-user>` not replaced | Set `$AgentUser` in template initialization script. |
| `Failed to connect: Handshake error` | WebSocket mode enabled | Use TCP inbound port; verify inbound TCP port is open on controller. |
| Pop-ups or taskbar visible on desktop | `BlankDesktop` task in progress | Allow 30 seconds after logon for desktop cleanup. |

---

## 6. Security Guidelines

1. **Stored Passwords**: The password is kept in `C:\ImageSetup\agent.pw`, protected with ACLs limited to SYSTEM and Administrators. At boot, `autologon.ps1` stores it as the LSA secret `DefaultPassword` (encrypted; readable only by administrators and SYSTEM) and deletes the plaintext Winlogon `DefaultPassword` registry value, which non-administrator users can read. Because the agent account is a local administrator, anyone with administrator access to the VM can still recover the password; use a unique password for the agent account.
2. **Password Rotation**: Rotate agent credentials by updating the password and capturing a new image version.
3. **Transport Security**: Jenkins controller URLs must use `https://`.
