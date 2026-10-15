<#
.SYNOPSIS
    Configures a standalone newly created Windows 11 VM for interactive GUI testing
    (console Session 1) such as Corretto Arctic, and optionally connects it as a persistent
    Jenkins inbound agent.

.DESCRIPTION
    MUST BE RUN ELEVATED (Administrator PowerShell, or SSH as an administrator).

    This script performs complete setup on a standalone Windows 11 VM:
      1. Verifies the existing local agent user account (-AgentUser) and ensures administrator privileges.
      2. Configures Winlogon auto-logon so the agent user logs into console Session 1 upon boot.
      3. Suppresses first-logon pop-ups, privacy screens, animations, consumer features, and widgets.
      4. Disables display/monitor and system sleep timeouts.
      5. Disables firewall "blocked some features" notifications on listen.
      6. Configures display resolution (default 1024x768).
      7. Installs and registers the DesktopSettings logon task (solid black background, hidden icons,
         auto-hidden taskbar, closed Start menu).
      8. (Optional) Downloads agent.jar and registers the JenkinsAgent logon task (TCP inbound) if
         -JenkinsUrl, -NodeName, and -Secret are provided.
      9. (Optional) Forwards an existing RDP session to the physical console via -ForwardToConsole.
     10. (Optional) Checks and reports the state of all components via -Verify.

.PARAMETER AgentUser
    Required. The existing local username that owns the desktop and runs tests/agent.

.PARAMETER AgentPassword
    SecureString. The password for -AgentUser. Required when configuring auto-logon.

.PARAMETER JenkinsUrl
    Optional. The Jenkins controller URL (must start with https://).

.PARAMETER NodeName
    Optional. The Jenkins agent/node name matching the controller configuration.

.PARAMETER Secret
    Optional. SecureString. The shared secret for the inbound Jenkins agent.

.PARAMETER Java
    Path to javaw.exe for running the Jenkins agent. Default: 'C:\openjdk\jdk-21\bin\javaw.exe'.

.PARAMETER WorkDir
    Agent workspace directory. Default: 'C:\workspace'.

.PARAMETER Width
    Display width in pixels. Default: 1024. Range: 640 - 7680.

.PARAMETER Height
    Display height in pixels. Default: 768. Range: 480 - 4320.

.PARAMETER SkipAutoLogon
    Switch. Skips Winlogon auto-logon configuration.

.PARAMETER SkipJenkinsAgent
    Switch. Skips Jenkins inbound agent download and task registration.

.PARAMETER ForwardToConsole
    Switch. Moves the agent user's active RDP session to the physical console (tscon).

.PARAMETER Verify
    Switch. Reports current system configuration and status without making changes.

.EXAMPLE
    # Full standalone setup with Jenkins inbound agent:
    $pw = Read-Host -AsSecureString "Agent password"
    $sec = Read-Host -AsSecureString "Jenkins agent secret"
    .\standalone-vm-setup.ps1 -AgentUser <agent-user> -AgentPassword $pw `
        -JenkinsUrl https://<jenkins-url>/ -NodeName <node-name> -Secret $sec

.EXAMPLE
    # Desktop and auto-logon setup only (no Jenkins agent):
    $pw = Read-Host -AsSecureString "Agent password"
    .\standalone-vm-setup.ps1 -AgentUser <agent-user> -AgentPassword $pw -SkipJenkinsAgent

.EXAMPLE
    # Verify current machine configuration:
    .\standalone-vm-setup.ps1 -AgentUser <agent-user> -Verify

.EXAMPLE
    # Move RDP session to console after maintenance:
    .\standalone-vm-setup.ps1 -AgentUser <agent-user> -ForwardToConsole
#>
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory)][string]$AgentUser,
    [System.Security.SecureString]$AgentPassword,
    [string]$JenkinsUrl,
    [string]$NodeName,
    [System.Security.SecureString]$Secret,
    [string]$Java = 'C:\openjdk\jdk-21\bin\javaw.exe',
    [string]$WorkDir = 'C:\workspace',
    [ValidateRange(640, 7680)][int]$Width = 1024,
    [ValidateRange(480, 4320)][int]$Height = 768,
    [switch]$SkipAutoLogon,
    [switch]$SkipJenkinsAgent,
    [switch]$ForwardToConsole,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$setupDir = 'C:\DesktopSetup'
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$userId   = "$env:COMPUTERNAME\$AgentUser"

Add-Type -Namespace StandaloneSetupMain -Name Native -MemberDefinition @"
[DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
"@

function Write-Check($name, [bool]$ok, $detail) {
    $c = if ($ok) { 'Green' } else { 'Yellow' }
    Write-Host ("  [{0}] {1}: {2}" -f $(if ($ok) { 'OK ' } else { '!! ' }), $name, $detail) -ForegroundColor $c
}

function Get-AgentSession {
    Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue |
        Where-Object { $_.UserName -like "*\$AgentUser" } | Select-Object -First 1
}

function Set-Dword($key, $name, $value) {
    if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
    Set-ItemProperty $key -Name $name -Value $value -Type DWord
}

function Convert-SecureStringToPlain([System.Security.SecureString]$secStr) {
    if (-not $secStr) { return $null }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secStr)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ----------------------------------------------------------------------------- Diagnostics
function Test-AutoLogon {
    $wl = Get-ItemProperty $winlogon -ErrorAction SilentlyContinue
    $ok = $wl -and $wl.AutoAdminLogon -eq '1' -and $wl.DefaultUserName -eq $AgentUser -and $wl.DefaultDomainName -eq '.' -and [bool]$wl.DefaultPassword
    Write-Check 'Auto-logon' $ok ("AutoAdminLogon={0} DefaultUserName={1} DefaultDomainName={2} Password={3}" -f `
        $wl.AutoAdminLogon, $wl.DefaultUserName, $wl.DefaultDomainName, $(if ($wl.DefaultPassword) { 'set' } else { 'MISSING' }))
    $s = Get-AgentSession
    $console = [StandaloneSetupMain.Native]::WTSGetActiveConsoleSessionId()
    if ($s) {
        Write-Check 'Desktop session' $true ("$AgentUser logged on in session $($s.SessionId)" + $(if ($s.SessionId -eq $console) { ' (console)' } else { " (not console; console is $console - see -ForwardToConsole)" }))
    } else {
        Write-Check 'Desktop session' $false "$AgentUser is not logged on interactively (reboot after setup)"
    }
}

function Test-DesktopTask {
    $t = Get-ScheduledTask DesktopSettings -ErrorAction SilentlyContinue
    if (-not $t) { Write-Check 'DesktopSettings task' $false 'not registered'; return }
    $i = $t | Get-ScheduledTaskInfo
    Write-Check 'DesktopSettings task' ($i.LastTaskResult -in 0, 267009) "last run $($i.LastRunTime), result $($i.LastTaskResult)"
    if (Test-Path "$setupDir\desktop.log") {
        Get-Content "$setupDir\desktop.log" -Tail 4 | ForEach-Object { Write-Host "      $_" }
    }
}

function Test-Resolution {
    $v = Get-CimInstance Win32_VideoController | Where-Object CurrentHorizontalResolution | Select-Object -First 1
    $cur = if ($v) { "$($v.CurrentHorizontalResolution)x$($v.CurrentVerticalResolution)" } else { 'unknown' }
    Write-Check 'Resolution' ($cur -eq "${Width}x$Height") "current $cur, target ${Width}x$Height"
}

function Test-FirewallNotify {
    $p = Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, NotifyOnListen
    $bad = $p | Where-Object { "$($_.NotifyOnListen)" -ne 'False' }
    Write-Check 'Firewall NotifyOnListen' (-not $bad) $(if ($bad) {
        "still enabled for: $($bad.Name -join ', ') (Group Policy may override)" } else { 'False for all profiles' })
}

function Test-JenkinsAgent {
    $t = Get-ScheduledTask JenkinsAgent -ErrorAction SilentlyContinue
    if (-not $t) { Write-Check 'JenkinsAgent task' $false 'not registered (or skipped)'; return }
    $i = $t | Get-ScheduledTaskInfo
    $p = Get-Process javaw -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { $_.UserName -like "*\$AgentUser" } | Select-Object -First 1
    Write-Check 'JenkinsAgent task' ($i.LastTaskResult -eq 267009) "result $($i.LastTaskResult) (267009 = running)"
    Write-Check 'Agent process' ([bool]$p) $(if ($p) { "javaw as $($p.UserName) in session $($p.SessionId)" } else { 'not running' })
    $log = Join-Path $WorkDir 'remoting\logs\remoting.log.0'
    if (Test-Path $log) {
        Copy-Item $log "$env:TEMP\remoting-check.log" -Force
        Get-Content "$env:TEMP\remoting-check.log" -Tail 2 | ForEach-Object { Write-Host "      $_" }
    }
}

if ($Verify) {
    Write-Host "Diagnostic state for agent user '$AgentUser':"
    Test-AutoLogon
    Test-DesktopTask
    Test-Resolution
    Test-FirewallNotify
    Test-JenkinsAgent
    exit 0
}

# ----------------------------------------------------------------------------- ForwardToConsole
if ($ForwardToConsole) {
    Write-Host "Forwarding $AgentUser desktop session to the physical console..."
    $s = Get-AgentSession
    $console = [StandaloneSetupMain.Native]::WTSGetActiveConsoleSessionId()
    if (-not $s) {
        Write-Check 'Forward to console' $false "$AgentUser has no desktop session to forward"
    } elseif ($s.SessionId -eq $console) {
        Write-Check 'Forward to console' $true "session $($s.SessionId) is already on the console"
    } else {
        $tscon = Join-Path $env:WINDIR 'System32\tscon.exe'
        Register-ScheduledTask -TaskName ForwardToConsole -Force `
            -Action    (New-ScheduledTaskAction -Execute $tscon -Argument "$($s.SessionId) /dest:console") `
            -Principal (New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest) | Out-Null
        Start-ScheduledTask ForwardToConsole
        Start-Sleep 5
        Unregister-ScheduledTask ForwardToConsole -Confirm:$false
        $console = [StandaloneSetupMain.Native]::WTSGetActiveConsoleSessionId()
        Write-Check 'Forward to console' ($console -eq $s.SessionId) "session $($s.SessionId) -> console session is now $console"
        if (Get-ScheduledTask DesktopSettings -ErrorAction SilentlyContinue) { Start-ScheduledTask DesktopSettings }
    }
    exit 0
}

# ----------------------------------------------------------------------------- Pre-flight checks
New-Item $setupDir -ItemType Directory -Force | Out-Null

$configureJenkins = (-not $SkipJenkinsAgent) -and ($JenkinsUrl -or $NodeName -or $Secret)
if ($configureJenkins) {
    if (-not $JenkinsUrl -or -not $NodeName -or -not $Secret) {
        throw "Configuring Jenkins agent requires -JenkinsUrl, -NodeName, and -Secret (or pass -SkipJenkinsAgent)."
    }
    if ($JenkinsUrl -notmatch '^https://') {
        throw "-JenkinsUrl must use https://"
    }
    if (-not (Test-Path $Java)) {
        throw "Java executable not found at '$Java'. Please install JDK or pass correct -Java path."
    }
    if (-not $JenkinsUrl.EndsWith('/')) { $JenkinsUrl += '/' }
}

# ----------------------------------------------------------------------------- Local User Verification
Write-Host "1. Verifying local agent user '$AgentUser'..."
if (-not (Get-LocalUser -Name $AgentUser -ErrorAction SilentlyContinue)) {
    throw "Local user '$AgentUser' does not exist. Create it first, or pass the correct -AgentUser."
}
Set-LocalUser -Name $AgentUser -PasswordNeverExpires $true -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group 'Administrators' -Member $AgentUser -ErrorAction SilentlyContinue
Enable-LocalUser -Name $AgentUser
Write-Host "   Verified '$AgentUser' exists, ensured administrator privileges, and enabled account."

# ----------------------------------------------------------------------------- Winlogon Auto-Logon
if (-not $SkipAutoLogon) {
    Write-Host "2. Configuring Winlogon auto-logon..."
    if (-not $AgentPassword) {
        throw "-AgentPassword (SecureString) is required to configure auto-logon (or pass -SkipAutoLogon)."
    }
    $plainPw = Convert-SecureStringToPlain $AgentPassword
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $ctx = [DirectoryServices.AccountManagement.PrincipalContext]::new('Machine', $env:COMPUTERNAME)
    if (-not $ctx.ValidateCredentials($AgentUser, $plainPw)) {
        $plainPw = $null
        throw "Provided password is invalid for user '$AgentUser'. Auto-logon aborted."
    }

    Set-ItemProperty $winlogon -Name AutoAdminLogon    -Value '1'
    Set-ItemProperty $winlogon -Name DefaultUserName   -Value $AgentUser
    Set-ItemProperty $winlogon -Name DefaultDomainName -Value '.'      # '.' survives Azure machine renames
    Set-ItemProperty $winlogon -Name DefaultPassword   -Value $plainPw -Type String
    Remove-ItemProperty $winlogon -Name AutoLogonCount -ErrorAction SilentlyContinue
    $plainPw = $null
    Write-Host "   Auto-logon configured for user '$AgentUser'."
} else {
    Write-Host "2. Skipping auto-logon configuration (-SkipAutoLogon specified)."
}

# ----------------------------------------------------------------------------- Machine Policies & Power
Write-Host "3. Applying machine policies and power settings..."
Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'                  DisablePrivacyExperience       1
Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\System' EnableFirstLogonAnimation      0
Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'          DisableWindowsConsumerFeatures 1
Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                           AllowNewsAndInterests          0

powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
Write-Host "   Suppressed OOBE privacy screens, animations, consumer features, and disabled power sleep."

# ----------------------------------------------------------------------------- Firewall Notification Suppression
Write-Host "4. Suppressing firewall listen notifications..."
Set-NetFirewallProfile -Profile Domain, Private, Public -NotifyOnListen False
Write-Host "   Set NotifyOnListen to False across Domain, Private, and Public profiles."

# ----------------------------------------------------------------------------- Desktop & Resolution Script
Write-Host "5. Setting up desktop configuration script and scheduled task..."
$desktopScript = @'
$ErrorActionPreference = 'SilentlyContinue'
$log  = 'C:\DesktopSetup\desktop.log'
$sess = (Get-Process -Id $PID).SessionId
function Log($m) { "$(Get-Date -Format s) [$env:USERNAME session $sess] $m" | Add-Content $log }
function Set-Dword($k, $n, $v) { if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }; Set-ItemProperty $k -Name $n -Value $v -Type DWord }

Add-Type -Namespace DesktopSetup -Name Native -MemberDefinition @"
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
[DllImport("user32.dll")] public static extern bool SetSysColors(int count, int[] elements, int[] colors);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string name);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int left; public int top; public int right; public int bottom; }
[StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }
[DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct DEVMODE {
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
  public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra; public int dmFields;
  public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
  public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
  public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
  public int dmDisplayFlags; public int dmDisplayFrequency; public int dmICMMethod; public int dmICMIntent;
  public int dmMediaType; public int dmDitherType; public int dmReserved1; public int dmReserved2;
  public int dmPanningWidth; public int dmPanningHeight; }
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);
"@

function Wait-Taskbar {
    for ($i = 0; $i -lt 60; $i++) {
        if ([DesktopSetup.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value) -ne [IntPtr]::Zero) { return }
        Start-Sleep 2
    }
}

function Set-TaskbarAutoHide {
    $abd = New-Object DesktopSetup.Native+APPBARDATA
    $abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
    $abd.hWnd   = [DesktopSetup.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value)
    $abd.lParam = [IntPtr]1                                                 # ABS_AUTOHIDE
    [DesktopSetup.Native]::SHAppBarMessage(0x0A, [ref]$abd) | Out-Null       # ABM_SETSTATE
}

Wait-Taskbar
$exp = Get-Process explorer | Where-Object SessionId -eq $sess | Sort-Object StartTime | Select-Object -First 1
if ($exp -and ((Get-Date) - $exp.StartTime).TotalSeconds -lt 90) { Start-Sleep 15 }

# Set Resolution
$dm = New-Object DesktopSetup.Native+DEVMODE
$dm.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($dm)
if ([DesktopSetup.Native]::EnumDisplaySettings([NullString]::Value, -1, [ref]$dm)) {
    if ($dm.dmPelsWidth -ne __WIDTH__ -or $dm.dmPelsHeight -ne __HEIGHT__) {
        $dm.dmPelsWidth = __WIDTH__; $dm.dmPelsHeight = __HEIGHT__; $dm.dmFields = 0x180000
        $r = [DesktopSetup.Native]::ChangeDisplaySettings([ref]$dm, 1)
        Log "Resolution set to __WIDTH__x__HEIGHT__ (result $r, 0 = OK)"
    } else { Log 'Resolution already __WIDTH__x__HEIGHT__' }
} else { Log 'Could not read current display settings' }

# Desktop Style: Solid Black, No Icons, Auto-hide Taskbar
Set-ItemProperty 'HKCU:\Control Panel\Colors'  -Name Background -Value '0 0 0'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper  -Value ''
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' BackgroundType 1
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' HideIcons 1

Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'SubscribedContent-310093Enabled', 'SubscribedContent-338389Enabled',
               'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled') { Set-Dword $cdm $n 0 }

[DesktopSetup.Native]::SetSysColors(1, @(1), @(0)) | Out-Null
[DesktopSetup.Native]::SystemParametersInfo(0x14, 0, '', 3) | Out-Null
rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
Set-TaskbarAutoHide

Stop-Process -Name explorer -Force
Start-Sleep 5; Wait-Taskbar; Start-Sleep 5
Set-TaskbarAutoHide
Stop-Process -Name StartMenuExperienceHost -Force
Log 'Desktop: black background, no icons, taskbar auto-hide applied'
Log 'Done'
'@ -replace '__WIDTH__', $Width -replace '__HEIGHT__', $Height

Set-Content "$setupDir\desktop.ps1" -Value $desktopScript -Encoding ASCII

Register-ScheduledTask -TaskName DesktopSettings -Force `
    -Action    (New-ScheduledTaskAction -Execute powershell.exe `
                    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $setupDir\desktop.ps1") `
    -Trigger   (New-ScheduledTaskTrigger -AtLogOn -User $userId) `
    -Principal (New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest) `
    -Settings  (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)) | Out-Null
Write-Host "   Registered DesktopSettings scheduled task for '$userId'."

if (Get-AgentSession) {
    Start-ScheduledTask DesktopSettings
    Write-Host "   Applying desktop settings in active session (waiting 20s)..."
    Start-Sleep 20
}

# ----------------------------------------------------------------------------- Jenkins Inbound Agent
if ($configureJenkins) {
    Write-Host "6. Configuring Jenkins inbound agent..."
    New-Item C:\jenkins, $WorkDir -ItemType Directory -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

    Write-Host "   Downloading agent.jar from ${JenkinsUrl}jnlpJars/agent.jar..."
    Invoke-WebRequest "${JenkinsUrl}jnlpJars/agent.jar" -OutFile C:\jenkins\agent.jar -UseBasicParsing -TimeoutSec 120

    $plainSec = Convert-SecureStringToPlain $Secret
    $arg = "-jar C:\jenkins\agent.jar -url `"$JenkinsUrl`" -name `"$NodeName`" -secret `"$plainSec`" -workDir `"$WorkDir`""
    $plainSec = $null

    Register-ScheduledTask -TaskName JenkinsAgent -Force `
        -Action    (New-ScheduledTaskAction -Execute $Java -Argument $arg) `
        -Trigger   (New-ScheduledTaskTrigger -AtLogOn -User $userId) `
        -Principal (New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest) `
        -Settings  (New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 `
                        -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null
    $arg = $null
    Write-Host "   Registered JenkinsAgent scheduled task for '$userId'."

    if (Get-AgentSession) {
        Start-ScheduledTask JenkinsAgent
        Write-Host "   Started JenkinsAgent task in active session."
        Start-Sleep 15
    }
} else {
    Write-Host "6. Skipping Jenkins inbound agent setup."
}

# ----------------------------------------------------------------------------- Verification Summary
Write-Host "`n========================================================"
Write-Host "Configuration complete. Verifying current system state:"
Write-Host "========================================================"
Test-AutoLogon
Test-DesktopTask
Test-Resolution
Test-FirewallNotify
if ($configureJenkins) { Test-JenkinsAgent }

Write-Host "`nSetup finished successfully."
if (-not (Get-AgentSession)) {
    Write-Host "NOTE: Please reboot the VM (Restart-Computer) so auto-logon logs into console Session 1." -ForegroundColor Cyan
}
