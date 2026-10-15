# image-prep.ps1
# Run manually (elevated) on the temporary update VM AFTER Windows updates (script 5)
# and BEFORE sysprep (script 6).
#
# Prepares the image so a Jenkins INBOUND agent can run in the interactive console
# session (Session 1) of a local auto-logged-in user:
#   1. Local agent user exists, is enabled, is in Administrators
#   2. Auto-logon for that user (creates the console session on boot)
#   3. Power settings so the display/system never sleeps or locks while idle
#   4. Auto-logon is RE-APPLIED on every VM created from the image, because sysprep /
#      Azure provisioning clears the Winlogon values (seen on VMs from version 0.0.1):
#        - C:\ImageSetup\autologon.ps1 + agent.pw (ACL: SYSTEM and Administrators only)
#        - SetupComplete.cmd hook: applies before the first logon screen (no reboot)
#        - "ImageAutoLogon" startup task (SYSTEM): fallback; applies at every boot and
#          reboots once per machine only if it had to change something and nobody is
#          logged on to the console
#
# sshd is NOT modified. The inbound agent is started per node by
# jenkins-inbound-init.ps1 (Jenkins template init script).
#
# The password must be the real password of the agent user. If the Jenkins template
# admin credential uses the same username, Azure sets that password at provisioning,
# so use the same password here.
#
# Usage (-AgentUser is required):
#   $pw = Read-Host -AsSecureString "Agent password"
#   .\image-prep.ps1 -AgentUser <agent-user> -AgentPassword $pw   # apply
#   .\image-prep.ps1 -AgentUser <agent-user> -Verify              # after reboot

param(
    [Parameter(Mandatory)][string]$AgentUser,
    [System.Security.SecureString]$AgentPassword,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$setupDir = 'C:\ImageSetup'

if ($Verify) {
    $wl = Get-ItemProperty $winlogon
    Write-Host "AutoAdminLogon    : $($wl.AutoAdminLogon)   (expected 1)"
    Write-Host "DefaultUserName   : $($wl.DefaultUserName)   (expected $AgentUser)"
    Write-Host "DefaultDomainName : $($wl.DefaultDomainName)   (expected .)"
    Write-Host "DefaultPassword   : $(if ($wl.DefaultPassword) {'set'} else {'MISSING'})"
    Write-Host "Image files       : $(Test-Path "$setupDir\autologon.ps1") / $(Test-Path "$setupDir\agent.pw")   (expected True / True)"
    Write-Host "Startup task      : $([bool](Get-ScheduledTask ImageAutoLogon -ErrorAction SilentlyContinue))   (expected True)"
    Write-Host "Logged-on sessions:"
    quser 2>&1
    $explorer = Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue |
        Where-Object { $_.UserName -like "*\$AgentUser" }
    if ($wl.AutoAdminLogon -eq '1' -and $explorer) {
        Write-Host "PASS - $AgentUser has an interactive desktop (explorer.exe, session $($explorer[0].SessionId))" -ForegroundColor Green
        exit 0
    }
    Write-Host "FAIL - $AgentUser is not logged on interactively" -ForegroundColor Red
    exit 1
}

if (-not $AgentPassword) {
    throw "-AgentPassword (SecureString) is required unless -Verify is used."
}

# Plain-text copy needed for the Winlogon registry value and the protected file.
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AgentPassword)
try { $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

Write-Host "Configuring local user $AgentUser..."
if (-not (Get-LocalUser -Name $AgentUser -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $AgentUser -Password $AgentPassword -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
    Write-Host "  Created $AgentUser"
} else {
    Set-LocalUser -Name $AgentUser -Password $AgentPassword -PasswordNeverExpires $true
    Write-Host "  Updated password for $AgentUser"
}
Add-LocalGroupMember -Group 'Administrators' -Member $AgentUser -ErrorAction SilentlyContinue
Enable-LocalUser -Name $AgentUser

Write-Host "Installing first-boot auto-logon files in $setupDir..."
New-Item $setupDir -ItemType Directory -Force | Out-Null
# Lock the folder down before writing the password: SYSTEM + Administrators only, no inheritance.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in 'S-1-5-18', 'S-1-5-32-544') {   # SYSTEM, BUILTIN\Administrators
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
        (New-Object Security.Principal.SecurityIdentifier $sid), 'FullControl',
        'ContainerInherit,ObjectInherit', 'None', 'Allow')))
}
Set-Acl $setupDir $acl

Set-Content "$setupDir\agent.user" -Value $AgentUser -NoNewline -Encoding UTF8
Set-Content "$setupDir\agent.pw"   -Value $plainPassword -NoNewline -Encoding UTF8
# Per-machine reboot markers from this build VM must not be baked into the image.
Remove-Item "$setupDir\rebooted-*" -Force -ErrorAction SilentlyContinue

@'
# C:\ImageSetup\autologon.ps1 - installed by image-prep.ps1. Runs as SYSTEM.
# Idempotently (re)applies Winlogon auto-logon for the agent user. Never logs the password.
param([switch]$RebootIfChanged)
$ErrorActionPreference = 'Stop'
$dir = 'C:\ImageSetup'
$log = "$dir\autologon.log"
function Log($m) { "$(Get-Date -Format s) [$env:COMPUTERNAME] $m" | Add-Content $log }
try {
    $user = (Get-Content "$dir\agent.user" -Raw -Encoding UTF8).Trim()
    $pw   = Get-Content "$dir\agent.pw" -Raw -Encoding UTF8
    $wl   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $cur  = Get-ItemProperty $wl
    $changed = $cur.AutoAdminLogon -ne '1' -or $cur.DefaultUserName -ne $user -or
               $cur.DefaultDomainName -ne '.' -or $cur.DefaultPassword -ne $pw -or
               $null -ne $cur.AutoLogonCount
    if ($changed) {
        Set-ItemProperty $wl -Name AutoAdminLogon    -Value '1'
        Set-ItemProperty $wl -Name DefaultUserName   -Value $user
        Set-ItemProperty $wl -Name DefaultDomainName -Value '.'
        Set-ItemProperty $wl -Name DefaultPassword   -Value $pw -Type String
        Remove-ItemProperty $wl -Name AutoLogonCount -ErrorAction SilentlyContinue
        Log 'Winlogon auto-logon values applied'
    } else {
        Log 'Winlogon auto-logon values already correct'
    }
    $pw = $null
    Enable-LocalUser -Name $user -ErrorAction SilentlyContinue

    # Suppress machine-wide first-logon UI that covers the desktop (the "Choose privacy
    # settings for your device" screen, the first-logon animation, consumer content).
    # Applied before the auto-logon on every boot, so it also holds after sysprep.
    foreach ($p in @(
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE',                     'DisablePrivacyExperience',       1),
        @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',    'EnableFirstLogonAnimation',      0),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',             'DisableWindowsConsumerFeatures', 1))) {
        if (-not (Test-Path $p[0])) { New-Item $p[0] -Force | Out-Null }
        Set-ItemProperty $p[0] -Name $p[1] -Value $p[2] -Type DWord
    }

    if ($changed -and $RebootIfChanged) {
        # Do not reboot while the Jenkins init script (Custom Script Extension) is running:
        # a restart interrupts it and the extension does not re-run it afterwards.
        # Wait until a CSE status file written since this boot reports success/error,
        # or give up after $waitMin minutes (e.g. VM not created by Jenkins).
        $waitMin  = 15
        $boot     = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $deadline = (Get-Date).AddMinutes($waitMin)
        $cseState = 'none'
        while ((Get-Date) -lt $deadline) {
            $st = Get-ChildItem 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Status\*.status' -ErrorAction SilentlyContinue |
                  Where-Object LastWriteTime -gt $boot | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($st) {
                try { $cseState = (Get-Content $st.FullName -Raw | ConvertFrom-Json)[0].status.status } catch { $cseState = 'unreadable' }
                if ($cseState -in 'success', 'error') { break }
            }
            Start-Sleep 10
        }
        Log "Init script (CSE) state before reboot: $cseState"

        $consoleUser = (Get-CimInstance Win32_ComputerSystem).UserName
        $marker = "$dir\rebooted-$env:COMPUTERNAME"
        if (-not $consoleUser -and -not (Test-Path $marker)) {
            New-Item $marker -ItemType File -Force | Out-Null
            Log 'Nobody on console - rebooting once so auto-logon takes effect'
            Restart-Computer -Force
        } else {
            Log "No reboot (console user: '$consoleUser', marker present: $(Test-Path $marker))"
        }
    }
} catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
'@ | Set-Content "$setupDir\autologon.ps1" -Encoding ASCII

$applyCmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ImageSetup\autologon.ps1'

Write-Host "Registering ImageAutoLogon startup task (SYSTEM)..."
Register-ScheduledTask -TaskName ImageAutoLogon -Force `
    -Action    (New-ScheduledTaskAction -Execute powershell.exe `
                    -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\ImageSetup\autologon.ps1 -RebootIfChanged') `
    -Trigger   (New-ScheduledTaskTrigger -AtStartup) `
    -Principal (New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest) `
    -Settings  (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit (New-TimeSpan -Minutes 20)) | Out-Null

Write-Host "Adding SetupComplete.cmd hook..."
$scDir = 'C:\Windows\Setup\Scripts'
$sc    = "$scDir\SetupComplete.cmd"
New-Item $scDir -ItemType Directory -Force | Out-Null
# Append (never overwrite) so any existing SetupComplete.cmd content is kept.
if (-not ((Test-Path $sc) -and (Select-String -Path $sc -SimpleMatch 'C:\ImageSetup\autologon.ps1' -Quiet))) {
    Add-Content $sc -Value $applyCmd -Encoding ASCII
}

Write-Host "Configuring auto-logon on this VM..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$setupDir\autologon.ps1"
if ($LASTEXITCODE -ne 0) { throw "autologon.ps1 failed - see $setupDir\autologon.log" }
$plainPassword = $null

Write-Host "Disabling display/system sleep..."
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

Write-Host ""
Write-Host "Done. Reboot, wait ~1 minute, then run: .\image-prep.ps1 -Verify"
Write-Host "Before sysprep, delete any reboot markers: Remove-Item C:\ImageSetup\rebooted-*"
