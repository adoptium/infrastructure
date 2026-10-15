# jenkins-inbound-init.ps1
# Jenkins Azure VM Agents "Initialization script" for the INBOUND launch method.
# The plugin passes three positional arguments:
#   1. Jenkins URL (with trailing slash)
#   2. VM / node name
#   3. Shared secret
#
# Unlike the plugin's sample (WinSW service = Session 0), this registers a scheduled
# task that runs the agent as the auto-logged-in user, i.e. in the interactive
# console session (Session 1).
#
# The plugin prepends its own lines to this script, so a param() block would no
# longer be the first statement and PowerShell rejects it. Use $args instead.
#
# REQUIRED: set $AgentUser to the agent user name passed to image-prep.ps1 -AgentUser.
$JenkinsUrl = [string]$args[0]
$VmName     = [string]$args[1]
$Secret     = [string]$args[2]
$AgentUser  = '<agent-user>'

$ErrorActionPreference = 'Stop'
if (-not $AgentUser -or $AgentUser -eq '<agent-user>') {
    throw 'Set $AgentUser at the top of this script to the agent user name used with image-prep.ps1.'
}
if (-not $JenkinsUrl -or -not $VmName -or -not $Secret) {
    throw "Expected 3 arguments (Jenkins URL, VM name, secret); got $($args.Count)."
}
# javaw.exe (not java.exe) so no console window appears on the interactive desktop.
$java = 'C:\openjdk\jdk-21\bin\javaw.exe'
if (-not $JenkinsUrl.EndsWith('/')) { $JenkinsUrl += '/' }

New-Item C:\jenkins, C:\workspace -ItemType Directory -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-WebRequest "${JenkinsUrl}jnlpJars/agent.jar" -OutFile C:\jenkins\agent.jar -UseBasicParsing

# Machine-wide policy: disable Widgets / "News for you" on the taskbar.
# Must be applied here (elevated init script) not in blank-desktop.ps1 (agent user session).
$dshKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
if (-not (Test-Path $dshKey)) { New-Item $dshKey -Force | Out-Null }
Set-ItemProperty $dshKey -Name AllowNewsAndInterests -Value 0 -Type DWord

# TCP inbound (no -webSocket): the WebSocket handshake failed during testing; re-test if you move to a different controller.
$arg = "-jar C:\jenkins\agent.jar -url `"$JenkinsUrl`" -name `"$VmName`" -secret `"$Secret`" -workDir C:\workspace"
$user = "$env:COMPUTERNAME\$AgentUser"

Register-ScheduledTask -TaskName JenkinsAgent -Force `
    -Action    (New-ScheduledTaskAction -Execute $java -Argument $arg) `
    -Trigger   (New-ScheduledTaskTrigger -AtLogOn -User $user) `
    -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest) `
    -Settings  (New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
                    -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) `
                    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null

# If the user is already logged on this starts immediately; otherwise the AtLogOn trigger fires.
Start-ScheduledTask -TaskName JenkinsAgent -ErrorAction SilentlyContinue
Write-Host "JenkinsAgent task registered for $user"

# ---------------------------------------------------------------------------
# Blank desktop: solid black background, no wallpaper, no desktop icons,
# auto-hide taskbar, no first-logon nag screens. These are per-user (HKCU)
# settings, so they must be applied by a task running as the agent user in the
# console session, at every logon. (Machine-wide first-logon UI such as the
# "Choose privacy settings" screen is suppressed by the image, see image-prep.ps1.)
# ---------------------------------------------------------------------------
@'
$ErrorActionPreference = 'SilentlyContinue'
function Set-Dword($k, $n, $v) {
    if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
    Set-ItemProperty $k -Name $n -Value $v -Type DWord
}

# Solid black: no picture, no Spotlight/slideshow (BackgroundType 1 = solid colour).
Set-ItemProperty 'HKCU:\Control Panel\Colors'  -Name Background -Value '0 0 0'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper  -Value ''
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' BackgroundType 1
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideIcons -Value 1
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' TaskbarBadges 0
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' TaskbarFlashing 0

# No "Let's finish setting up your device", welcome experience, tips or suggestions.
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'SubscribedContent-310093Enabled', 'SubscribedContent-338389Enabled',
               'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled') { Set-Dword $cdm $n 0 }

# Write StuckRects3 so explorer reads auto-hide from the registry on every restart,
# making the setting survive Start menu interactions and focus changes permanently.
# Byte 8 (0-indexed) of the binary value is the state flags: 0x03 = auto-hide, 0x02 = normal.
$srKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
if (Test-Path $srKey) {
    $sr = (Get-ItemProperty $srKey).Settings
    if ($sr -and $sr.Count -ge 9) { $sr[8] = 0x03; Set-ItemProperty $srKey -Name Settings -Value $sr }
}

Add-Type -Namespace BlankDesktop -Name Native -MemberDefinition @"
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
[DllImport("user32.dll")] public static extern bool SetSysColors(int count, int[] elements, int[] colors);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string name);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int left; public int top; public int right; public int bottom; }
[StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }
[DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
"@

# This runs at logon, before the desktop exists. Wait for the taskbar window, then
# give first-logon UI (Windows 11 opens Start on a user's first sign-in) time to appear.
function Wait-Taskbar {
    for ($i = 0; $i -lt 60; $i++) {
        if ([BlankDesktop.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value) -ne [IntPtr]::Zero) { return }
        Start-Sleep 2
    }
}
# Auto-hide + hidden via the shell API: persists across explorer restarts.
# ABS_AUTOHIDE (1) tells the shell to keep the taskbar hidden until the cursor
# reaches the screen edge. SW_HIDE (0) additionally hides the window immediately so
# it cannot pop up during test runs when a Java window is activated near the taskbar.
function Set-TaskbarAutoHide {
    $hwnd = [BlankDesktop.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value)
    $abd = New-Object BlankDesktop.Native+APPBARDATA
    $abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
    $abd.hWnd   = $hwnd
    $abd.lParam = [IntPtr]1                                                 # ABS_AUTOHIDE
    [BlankDesktop.Native]::SHAppBarMessage(0x0A, [ref]$abd) | Out-Null       # ABM_SETSTATE
    [BlankDesktop.Native]::ShowWindow($hwnd, 0) | Out-Null                   # SW_HIDE
}
Wait-Taskbar
Start-Sleep 15

# Apply the black background immediately (registry alone is not picked up live on Windows 11).
[BlankDesktop.Native]::SetSysColors(1, @(1), @(0)) | Out-Null            # COLOR_DESKTOP -> black
[BlankDesktop.Native]::SystemParametersInfo(0x14, 0, '', 3) | Out-Null   # SPI_SETDESKWALLPAPER none, persist + broadcast
rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
Set-TaskbarAutoHide

# Restart explorer so HideIcons and StuckRects3 take effect (it relaunches itself), then re-apply auto-hide.
Stop-Process -Name explorer -Force
Start-Sleep 5
Wait-Taskbar
Start-Sleep 5
Set-TaskbarAutoHide

# Close the Start menu if it is open (it relaunches on demand).
Stop-Process -Name StartMenuExperienceHost -Force
'@ | Set-Content C:\jenkins\blank-desktop.ps1 -Encoding ASCII

Register-ScheduledTask -TaskName BlankDesktop -Force `
    -Action    (New-ScheduledTaskAction -Execute powershell.exe `
                    -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\jenkins\blank-desktop.ps1') `
    -Trigger   (New-ScheduledTaskTrigger -AtLogOn -User $user) `
    -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest) `
    -Settings  (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) | Out-Null

Start-ScheduledTask -TaskName BlankDesktop -ErrorAction SilentlyContinue
Write-Host "BlankDesktop task registered for $user"
