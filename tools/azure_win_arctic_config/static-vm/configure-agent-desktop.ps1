<#
.SYNOPSIS
    Configures an already-running Windows VM so a local agent user has a clean interactive desktop
    (console Session 1) for GUI tests such as Corretto Arctic. This is a standalone alternative to
    image-prep.ps1 + jenkins-inbound-init.ps1 for a VM that is NOT going to be generalized/captured.

.DESCRIPTION
    MUST BE RUN ELEVATED (Administrator PowerShell, or SSH as an administrator).

    -AgentUser (the local user that owns the desktop) is required. Every other part is optional; pass
    only the switches you want. Each applied part is checked afterwards.

      -AutoLogon              Winlogon auto-logon for -AgentUser (creates the console desktop on boot).
                              Needs -AgentPassword. The password is validated before it is saved.
      -Desktop                Black background, no wallpaper, no desktop icons, auto-hidden taskbar,
                              Widgets off, Start menu closed, first-logon pop-ups suppressed
                              (privacy screen, first-logon animation, tips/suggestions).
      -Resolution             Sets the display to -Width x -Height (default 1024x768).
      -DisableFirewallNotify  Stops the "Windows Defender Firewall has blocked some features" pop-up
                              when java (or anything else) listens on a port:
                              Set-NetFirewallProfile -Profile Domain,Private,Public -NotifyOnListen False
      -ForwardToConsole       Moves the agent user's RDP session to the physical console (tscon), so
                              the desktop stays unlocked and usable after the RDP client disconnects.
                              WARNING: if you run this from that RDP session, it disconnects you.
      -JenkinsAgent           Registers a Jenkins inbound agent that runs as -AgentUser in its desktop
                              session (TCP inbound, no WebSocket). Needs -JenkinsUrl, -NodeName, -Secret.
      -Verify                 Only report the current state of all of the above; changes nothing.

    -Desktop and -Resolution are per-user, per-session settings. They are applied by a scheduled task
    ("DesktopSettings") that runs as -AgentUser in its desktop session at every logon, and immediately
    if that user is already logged on.

    Nothing secret is written to the log files. The auto-logon password is stored by Windows in the
    Winlogon registry key (required for auto-logon). The Jenkins secret is stored in the JenkinsAgent
    task's arguments, as with jenkins-inbound-init.ps1.

.EXAMPLE
    # Everything, password and secret typed at hidden prompts:
    .\configure-agent-desktop.ps1 -AgentUser <agent-user> -AutoLogon -AgentPassword (Read-Host -AsSecureString 'Agent password') `
        -Desktop -Resolution -DisableFirewallNotify

.EXAMPLE
    # Desktop look and resolution only, 1280x1024:
    .\configure-agent-desktop.ps1 -AgentUser <agent-user> -Desktop -Resolution -Width 1280 -Height 1024

.EXAMPLE
    # After working on the VM over RDP, hand the desktop back to the console:
    .\configure-agent-desktop.ps1 -AgentUser <agent-user> -ForwardToConsole

.EXAMPLE
    .\configure-agent-desktop.ps1 -AgentUser <agent-user> -Verify
#>
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory)][string]$AgentUser,
    [switch]$AutoLogon,
    [System.Security.SecureString]$AgentPassword,
    [switch]$Desktop,
    [switch]$Resolution,
    [ValidateRange(640, 7680)][int]$Width = 1024,
    [ValidateRange(480, 4320)][int]$Height = 768,
    [switch]$DisableFirewallNotify,
    [switch]$ForwardToConsole,
    [switch]$JenkinsAgent,
    [string]$JenkinsUrl,
    [string]$NodeName,
    [System.Security.SecureString]$Secret,
    [string]$Java = 'C:\openjdk\jdk-21\bin\javaw.exe',
    [string]$WorkDir = 'C:\workspace',
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$setupDir = 'C:\DesktopSetup'
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$userId   = "$env:COMPUTERNAME\$AgentUser"

if (-not ($AutoLogon -or $Desktop -or $Resolution -or $DisableFirewallNotify -or $ForwardToConsole -or $JenkinsAgent -or $Verify)) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 1
}
if (-not (Get-LocalUser -Name $AgentUser -ErrorAction SilentlyContinue)) {
    throw "Local user '$AgentUser' does not exist. Create it first, or pass the correct -AgentUser."
}

Add-Type -Namespace DesktopSetupMain -Name Native -MemberDefinition @"
[DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
"@

# Winlogon reads the auto-logon password from the LSA secret "DefaultPassword" first, and
# only falls back to the plaintext Winlogon\DefaultPassword registry value (readable by
# non-admin users) if no secret exists. Store it as the LSA secret; keep the registry value absent.
Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class AutoLogonLsa {
    [StructLayout(LayoutKind.Sequential)] struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public int Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [StructLayout(LayoutKind.Sequential)] struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr system, ref LSA_OBJECT_ATTRIBUTES attrs, uint access, out IntPtr policy);
    [DllImport("advapi32.dll")] static extern uint LsaStorePrivateData(IntPtr policy, ref LSA_UNICODE_STRING key, IntPtr data);
    [DllImport("advapi32.dll")] static extern uint LsaRetrievePrivateData(IntPtr policy, ref LSA_UNICODE_STRING key, out IntPtr data);
    [DllImport("advapi32.dll")] static extern uint LsaFreeMemory(IntPtr buffer);
    [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr policy);
    [DllImport("advapi32.dll")] static extern int LsaNtStatusToWinError(uint status);

    const uint POLICY_GET_PRIVATE_INFORMATION = 0x4, POLICY_CREATE_SECRET = 0x20, STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034;

    static void Check(uint status) { if (status != 0) throw new Win32Exception(LsaNtStatusToWinError(status)); }
    static IntPtr Open() {
        var attrs = new LSA_OBJECT_ATTRIBUTES(); IntPtr h;
        attrs.Length = Marshal.SizeOf(attrs);
        Check(LsaOpenPolicy(IntPtr.Zero, ref attrs, POLICY_GET_PRIVATE_INFORMATION | POLICY_CREATE_SECRET, out h));
        return h;
    }
    static LSA_UNICODE_STRING Name(out IntPtr mem) {
        const string n = "DefaultPassword";
        mem = Marshal.StringToHGlobalUni(n);
        return new LSA_UNICODE_STRING { Length = (ushort)(n.Length * 2), MaximumLength = (ushort)(n.Length * 2 + 2), Buffer = mem };
    }
    // Stores the Winlogon auto-logon password as the LSA secret "DefaultPassword".
    public static void Set(string password) {
        IntPtr h = Open(), nameMem; var name = Name(out nameMem);
        IntPtr dataMem = Marshal.StringToHGlobalUni(password), dataPtr = IntPtr.Zero;
        try {
            var data = new LSA_UNICODE_STRING { Length = (ushort)(password.Length * 2), MaximumLength = (ushort)(password.Length * 2 + 2), Buffer = dataMem };
            dataPtr = Marshal.AllocHGlobal(Marshal.SizeOf(data));
            Marshal.StructureToPtr(data, dataPtr, false);
            Check(LsaStorePrivateData(h, ref name, dataPtr));
        } finally {
            if (dataPtr != IntPtr.Zero) Marshal.FreeHGlobal(dataPtr);
            Marshal.ZeroFreeGlobalAllocUnicode(dataMem); Marshal.FreeHGlobal(nameMem); LsaClose(h);
        }
    }
    // Returns the stored password, or null if no LSA secret exists.
    public static string Get() {
        IntPtr h = Open(), nameMem; var name = Name(out nameMem);
        try {
            IntPtr p; uint s = LsaRetrievePrivateData(h, ref name, out p);
            if (s == STATUS_OBJECT_NAME_NOT_FOUND) return null;
            Check(s);
            try { var d = (LSA_UNICODE_STRING)Marshal.PtrToStructure(p, typeof(LSA_UNICODE_STRING)); return Marshal.PtrToStringUni(d.Buffer, d.Length / 2); }
            finally { LsaFreeMemory(p); }
        } finally { Marshal.FreeHGlobal(nameMem); LsaClose(h); }
    }
}
"@

function Write-Check($name, [bool]$ok, $detail) {
    $c = if ($ok) { 'Green' } else { 'Yellow' }
    Write-Host ("  [{0}] {1}: {2}" -f $(if ($ok) { 'OK ' } else { '!! ' }), $name, $detail) -ForegroundColor $c
}

# Desktop session (explorer.exe) of the agent user, or $null if not logged on interactively.
function Get-AgentSession {
    Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue |
        Where-Object { $_.UserName -like "*\$AgentUser" } | Select-Object -First 1
}

function Set-Dword($key, $name, $value) {
    if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
    Set-ItemProperty $key -Name $name -Value $value -Type DWord
}

# ----------------------------------------------------------------------------- checks
function Test-AutoLogon {
    $wl = Get-ItemProperty $winlogon
    $lsaSet = [bool][AutoLogonLsa]::Get()
    $ok = $wl.AutoAdminLogon -eq '1' -and $wl.DefaultUserName -eq $AgentUser -and $wl.DefaultDomainName -eq '.' -and $lsaSet -and -not $wl.DefaultPassword
    Write-Check 'Auto-logon' $ok ("AutoAdminLogon={0} DefaultUserName={1} DefaultDomainName={2} Password(LSA)={3}{4}" -f `
        $wl.AutoAdminLogon, $wl.DefaultUserName, $wl.DefaultDomainName, $(if ($lsaSet) { 'set' } else { 'MISSING' }),
        $(if ($wl.DefaultPassword) { ' PLAINTEXT registry value present (re-run -AutoLogon to remove)' } else { '' }))
    Write-Check 'AutoLogonIdentity task' ([bool](Get-ScheduledTask AutoLogonIdentity -ErrorAction SilentlyContinue)) 'restores DefaultUserName at shutdown, logon and startup'
    $s = Get-AgentSession
    $console = [DesktopSetupMain.Native]::WTSGetActiveConsoleSessionId()
    if ($s) {
        Write-Check 'Desktop session' $true ("$AgentUser logged on in session $($s.SessionId)" + $(if ($s.SessionId -eq $console) { ' (console)' } else { " (not the console; console is $console - see -ForwardToConsole)" }))
    } else {
        Write-Check 'Desktop session' $false "$AgentUser is not logged on interactively (reboot after -AutoLogon)"
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
    Write-Check 'Resolution' ($cur -eq "${Width}x$Height") "current $cur, wanted ${Width}x$Height"
}

function Test-FirewallNotify {
    $p = Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, NotifyOnListen
    $p | Format-Table -AutoSize | Out-String | Write-Host
    $bad = $p | Where-Object { "$($_.NotifyOnListen)" -ne 'False' }
    Write-Check 'Firewall NotifyOnListen' (-not $bad) $(if ($bad) {
        "still enabled for: $($bad.Name -join ', ') (a Group Policy may override the local setting)" } else { 'False for all profiles' })
}

function Test-JenkinsAgent {
    $t = Get-ScheduledTask JenkinsAgent -ErrorAction SilentlyContinue
    if (-not $t) { Write-Check 'JenkinsAgent task' $false 'not registered'; return }
    $i = $t | Get-ScheduledTaskInfo
    $p = Get-Process javaw -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { $_.UserName -like "*\$AgentUser" } | Select-Object -First 1
    Write-Check 'JenkinsAgent task' ($i.LastTaskResult -eq 267009) "result $($i.LastTaskResult) (267009 = running)"
    Write-Check 'Agent process' ([bool]$p) $(if ($p) { "javaw as $($p.UserName) in session $($p.SessionId)" } else { 'not running' })
    $log = Join-Path $WorkDir 'remoting\logs\remoting.log.0'
    if (Test-Path $log) {
        Copy-Item $log "$env:TEMP\remoting-copy.log" -Force
        Get-Content "$env:TEMP\remoting-copy.log" -Tail 2 | ForEach-Object { Write-Host "      $_" }
    }
}

if ($Verify) {
    Write-Host "State for agent user '$AgentUser':"
    Test-AutoLogon; Test-DesktopTask; Test-Resolution; Test-FirewallNotify; Test-JenkinsAgent
    exit 0
}

New-Item $setupDir -ItemType Directory -Force | Out-Null

# ----------------------------------------------------------------------------- auto-logon
if ($AutoLogon) {
    Write-Host 'Configuring auto-logon...'
    if (-not $AgentPassword) { throw '-AutoLogon needs -AgentPassword (SecureString).' }
    $plain = [Net.NetworkCredential]::new('', $AgentPassword).Password
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $ctx = [DirectoryServices.AccountManagement.PrincipalContext]::new('Machine', $env:COMPUTERNAME)
    if (-not $ctx.ValidateCredentials($AgentUser, $plain)) { $plain = $null; throw "Password is not valid for '$AgentUser' - nothing saved." }
    Enable-LocalUser -Name $AgentUser
    [AutoLogonLsa]::Set($plain)
    Set-ItemProperty $winlogon -Name AutoAdminLogon    -Value '1'
    Set-ItemProperty $winlogon -Name DefaultUserName   -Value $AgentUser
    Set-ItemProperty $winlogon -Name DefaultDomainName -Value '.'      # local machine, survives renames
    Remove-ItemProperty $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue   # plaintext value; password is in the LSA secret
    Remove-ItemProperty $winlogon -Name AutoLogonCount -ErrorAction SilentlyContinue
    $plain = $null

    # Windows can replace DefaultUserName with whichever account last signed in at the console, while
    # the LSA password still belongs to $AgentUser. Restore the agent identity at shutdown/restart, after any logon, and
    # at startup, so the next automatic logon targets the right account. The command is inline (not a
    # script file under C:\DesktopSetup, which non-administrators may be able to modify) because the
    # task runs as SYSTEM.
    $repairCmd = "`$k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " +
        "Set-ItemProperty `$k AutoAdminLogon '1'; " +
        "Set-ItemProperty `$k DefaultUserName '$($AgentUser -replace "'", "''")'; " +
        "Set-ItemProperty `$k DefaultDomainName '.'"
    $repairArg = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' +
        [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($repairCmd))
    $shutdownTrigger = New-CimInstance -ClientOnly -Namespace Root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskEventTrigger -Property @{
        Enabled      = $true
        Subscription = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''User32''] and EventID=1074]]</Select></Query></QueryList>'
    }
    Register-ScheduledTask -TaskName AutoLogonIdentity -Force `
        -Action    (New-ScheduledTaskAction -Execute powershell.exe -Argument $repairArg) `
        -Trigger   @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn), $shutdownTrigger) `
        -Principal (New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest) `
        -Settings  (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                        -ExecutionTimeLimit (New-TimeSpan -Minutes 1)) | Out-Null
    Test-AutoLogon
    if (-not (Get-AgentSession)) { Write-Host '  Reboot for auto-logon to take effect: Restart-Computer' -ForegroundColor Cyan }
}

# ----------------------------------------------------------------------------- firewall pop-ups
if ($DisableFirewallNotify) {
    Write-Host 'Disabling firewall "blocked some features" notifications...'
    Set-NetFirewallProfile -Profile Domain, Private, Public -NotifyOnListen False
    Test-FirewallNotify
}

# ----------------------------------------------------------------------------- Jenkins agent
if ($JenkinsAgent) {
    Write-Host 'Registering Jenkins inbound agent...'
    if (-not $JenkinsUrl -or -not $NodeName -or -not $Secret) { throw '-JenkinsAgent needs -JenkinsUrl, -NodeName and -Secret.' }
    if ($JenkinsUrl -notmatch '^https://') { throw '-JenkinsUrl must use https://' }
    if (-not (Test-Path $Java)) { throw "Java not found: $Java" }
    if (-not $JenkinsUrl.EndsWith('/')) { $JenkinsUrl += '/' }
    New-Item C:\jenkins, $WorkDir -ItemType Directory -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-WebRequest "${JenkinsUrl}jnlpJars/agent.jar" -OutFile C:\jenkins\agent.jar -UseBasicParsing -TimeoutSec 120
    $plainSecret = [Net.NetworkCredential]::new('', $Secret).Password
    # TCP inbound (no -webSocket).
    $arg = "-jar C:\jenkins\agent.jar -url `"$JenkinsUrl`" -name `"$NodeName`" -secret `"$plainSecret`" -workDir `"$WorkDir`""
    $plainSecret = $null
    # Gate agent startup on desktop initialization: when DesktopSettings is configured (now or already
    # registered), it starts JenkinsAgent when it finishes, so JenkinsAgent gets no logon trigger of
    # its own. Without a desktop task the agent simply starts at logon (agent-only setup).
    $gateOnDesktop = $Desktop -or $Resolution -or [bool](Get-ScheduledTask DesktopSettings -ErrorAction SilentlyContinue)
    $reg = @{
        TaskName  = 'JenkinsAgent'
        Force     = $true
        Action    = New-ScheduledTaskAction -Execute $Java -Argument $arg
        Principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
        Settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 `
                        -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    }
    if (-not $gateOnDesktop) { $reg.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId }
    Register-ScheduledTask @reg | Out-Null
    $arg = $null
    # With -Desktop/-Resolution in this run, DesktopSettings (configured below) starts the agent when
    # it finishes. Otherwise start it now, after any DesktopSettings run that is still in progress.
    $deferToDesktop = $Desktop -or $Resolution
    if ($deferToDesktop) {
        Write-Host '  JenkinsAgent starts after DesktopSettings completes.'
    } elseif (Get-AgentSession) {
        if ($gateOnDesktop) {
            for ($i = 0; $i -lt 18 -and (Get-ScheduledTask DesktopSettings).State -eq 'Running'; $i++) { Start-Sleep 5 }
        }
        if (-not $gateOnDesktop -or (Get-ScheduledTask DesktopSettings).State -ne 'Running') {
            Start-ScheduledTask JenkinsAgent; Start-Sleep 20
        } else {
            Write-Host '  DesktopSettings is still running; JenkinsAgent starts when it finishes.' -ForegroundColor Cyan
        }
    }
    if (-not $deferToDesktop) { Test-JenkinsAgent }
}

# ----------------------------------------------------------------------------- desktop + resolution
if ($Desktop -or $Resolution) {
    Write-Host 'Configuring desktop settings task...'

    if ($Desktop) {
        # Machine-wide pop-up suppression (needs elevation, so done here rather than in the user task).
        Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'                  DisablePrivacyExperience       1
        Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' EnableFirstLogonAnimation      0
        Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'          DisableWindowsConsumerFeatures 1
        Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                           AllowNewsAndInterests          0
        # Keep the display and the machine awake.
        powercfg /change monitor-timeout-ac 0; powercfg /change standby-timeout-ac 0
    }

    $common = @'
$ErrorActionPreference = 'SilentlyContinue'
$log  = 'C:\DesktopSetup\desktop.log'
$sess = (Get-Process -Id $PID).SessionId
function Log($m) { "$(Get-Date -Format s) [$env:USERNAME session $sess] $m" | Add-Content $log }
function Set-Dword($k, $n, $v) { if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }; Set-ItemProperty $k -Name $n -Value $v -Type DWord }
Add-Type -Namespace DesktopSetup -Name Native -MemberDefinition @"
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
[DllImport("user32.dll")] public static extern bool SetSysColors(int count, int[] elements, int[] colors);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string name);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
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
# ABS_AUTOHIDE (1) tells the shell to keep the taskbar hidden until the cursor
# reaches the screen edge. SW_HIDE (0) additionally hides the window immediately so
# it cannot pop up during test runs when a Java window is activated near the taskbar.
function Set-TaskbarAutoHide {
    $hwnd = [DesktopSetup.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value)
    $abd = New-Object DesktopSetup.Native+APPBARDATA
    $abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
    $abd.hWnd   = $hwnd
    $abd.lParam = [IntPtr]1                                                 # ABS_AUTOHIDE
    [DesktopSetup.Native]::SHAppBarMessage(0x0A, [ref]$abd) | Out-Null       # ABM_SETSTATE
    [DesktopSetup.Native]::ShowWindow($hwnd, 0) | Out-Null                   # SW_HIDE
}
# At logon the desktop is not ready yet, and Windows 11 opens Start on a first sign-in: wait for both.
Wait-Taskbar
$exp = Get-Process explorer | Where-Object SessionId -eq $sess | Sort-Object StartTime | Select-Object -First 1
if ($exp -and ((Get-Date) - $exp.StartTime).TotalSeconds -lt 90) { Start-Sleep 15 }
'@

    $resolutionBlock = @'
$dm = New-Object DesktopSetup.Native+DEVMODE
$dm.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($dm)
if ([DesktopSetup.Native]::EnumDisplaySettings([NullString]::Value, -1, [ref]$dm)) {   # ENUM_CURRENT_SETTINGS
    if ($dm.dmPelsWidth -ne __WIDTH__ -or $dm.dmPelsHeight -ne __HEIGHT__) {
        $dm.dmPelsWidth = __WIDTH__; $dm.dmPelsHeight = __HEIGHT__; $dm.dmFields = 0x180000   # DM_PELSWIDTH | DM_PELSHEIGHT
        $r = [DesktopSetup.Native]::ChangeDisplaySettings([ref]$dm, 1)                       # CDS_UPDATEREGISTRY
        Log "Resolution set to __WIDTH__x__HEIGHT__ (result $r, 0 = OK)"
    } else { Log 'Resolution already __WIDTH__x__HEIGHT__' }
} else { Log 'Could not read current display settings' }
'@ -replace '__WIDTH__', $Width -replace '__HEIGHT__', $Height

    $desktopBlock = @'
# Solid black: no picture, no Spotlight/slideshow (BackgroundType 1 = solid colour).
Set-ItemProperty 'HKCU:\Control Panel\Colors'  -Name Background -Value '0 0 0'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper  -Value ''
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' BackgroundType 1
Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' HideIcons 1
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
# Apply live (registry alone is not picked up by a running Windows 11 session).
[DesktopSetup.Native]::SetSysColors(1, @(1), @(0)) | Out-Null            # COLOR_DESKTOP -> black
[DesktopSetup.Native]::SystemParametersInfo(0x14, 0, '', 3) | Out-Null   # SPI_SETDESKWALLPAPER none
rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
Set-TaskbarAutoHide
# Restart explorer so HideIcons and StuckRects3 take effect, then re-apply auto-hide and close Start.
Get-Process explorer | Where-Object SessionId -eq $sess | Stop-Process -Force
Start-Sleep 5; Wait-Taskbar; Start-Sleep 5
Set-TaskbarAutoHide
Get-Process StartMenuExperienceHost | Where-Object SessionId -eq $sess | Stop-Process -Force
Log 'Desktop: black background, no icons, taskbar auto-hide applied'
'@

    $script = $common
    if ($Resolution) { $script += "`r`n" + $resolutionBlock }
    if ($Desktop)    { $script += "`r`n" + $desktopBlock }
    # JenkinsAgent has no logon trigger of its own (see the -JenkinsAgent block): start it once the desktop is ready.
    $script += "`r`nLog 'Done'`r`nif (Get-ScheduledTask JenkinsAgent -ErrorAction SilentlyContinue) { Start-ScheduledTask JenkinsAgent; Log 'Started JenkinsAgent after desktop initialization' }`r`n"
    Set-Content "$setupDir\desktop.ps1" -Value $script -Encoding ASCII

    Register-ScheduledTask -TaskName DesktopSettings -Force `
        -Action    (New-ScheduledTaskAction -Execute powershell.exe `
                        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $setupDir\desktop.ps1") `
        -Trigger   (New-ScheduledTaskTrigger -AtLogOn -User $userId) `
        -Principal (New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest) `
        -Settings  (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                        -ExecutionTimeLimit (New-TimeSpan -Minutes 10)) | Out-Null

    # An agent task registered earlier still has its own logon trigger and would race DesktopSettings.
    if (-not $JenkinsAgent) {
        $existing = Get-ScheduledTask JenkinsAgent -ErrorAction SilentlyContinue
        if ($existing -and $existing.Triggers) {
            Write-Warning 'JenkinsAgent still has its own logon trigger and can start before the desktop is ready. Re-run with -JenkinsAgent (and its parameters) to register it without one.'
        }
    }

    if (Get-AgentSession) {
        Start-ScheduledTask DesktopSettings
        Write-Host '  Applying now in the agent user''s session (about 20 s)...'
        Start-Sleep 25
    } else {
        Write-Host "  $AgentUser is not logged on; settings apply at its next logon." -ForegroundColor Cyan
    }
    Test-DesktopTask
    if ($Resolution) { Test-Resolution }
    if ($JenkinsAgent -and (Get-AgentSession)) { Start-Sleep 10; Test-JenkinsAgent }
}

# ----------------------------------------------------------------------------- forward to console
if ($ForwardToConsole) {
    Write-Host 'Forwarding the agent user''s desktop to the console...'
    $s = Get-AgentSession
    $console = [DesktopSetupMain.Native]::WTSGetActiveConsoleSessionId()
    if (-not $s) {
        Write-Check 'Forward to console' $false "$AgentUser has no desktop session to forward"
    } elseif ($s.SessionId -eq $console) {
        Write-Check 'Forward to console' $true "session $($s.SessionId) is already on the console"
    } else {
        # tscon on another user's session needs SYSTEM (otherwise it asks for that user's password).
        $tscon = Join-Path $env:WINDIR 'System32\tscon.exe'
        Register-ScheduledTask -TaskName ForwardToConsole -Force `
            -Action    (New-ScheduledTaskAction -Execute $tscon -Argument "$($s.SessionId) /dest:console") `
            -Principal (New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest) | Out-Null
        Start-ScheduledTask ForwardToConsole
        Start-Sleep 5
        Unregister-ScheduledTask ForwardToConsole -Confirm:$false
        $console = [DesktopSetupMain.Native]::WTSGetActiveConsoleSessionId()
        Write-Check 'Forward to console' ($console -eq $s.SessionId) "session $($s.SessionId) -> console session is now $console"
        # The console may have a different resolution from the RDP client: re-apply the desktop settings.
        if (Get-ScheduledTask DesktopSettings -ErrorAction SilentlyContinue) { Start-ScheduledTask DesktopSettings }
    }
}

Write-Host 'Done.'
