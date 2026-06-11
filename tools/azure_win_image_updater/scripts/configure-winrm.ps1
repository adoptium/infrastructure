# Configure WinRM for Ansible
# This script downloads and runs Ansible's ConfigureRemotingForAnsible.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$logFile = "C:\winrm-config.log"

# Start logging
Start-Transcript -Path $logFile -Append

Write-Output "=== WinRM Configuration Started ==="
Write-Output "Timestamp: $(Get-Date)"
Write-Output "Computer: $env:COMPUTERNAME"
Write-Output ""

try {
    Write-Output "Downloading ConfigureRemotingForAnsible.ps1..."
    $url = "https://raw.githubusercontent.com/ansible/ansible-documentation/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
    $output = "C:\ConfigureRemotingForAnsible.ps1"
    
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
    Write-Output "Download complete: $output"
    Write-Output ""
    
    Write-Output "Running ConfigureRemotingForAnsible.ps1 with parameters:"
    Write-Output "  -CertValidityDays 9999"
    Write-Output "  -EnableCredSSP"
    Write-Output "  -ForceNewSSLCert"
    Write-Output "  -SkipNetworkProfileCheck"
    Write-Output ""
    
    & $output -CertValidityDays 9999 -EnableCredSSP -ForceNewSSLCert -SkipNetworkProfileCheck
    
    Write-Output ""
    Write-Output "=== WinRM Configuration Complete ==="
    Write-Output ""
    Write-Output "Verifying WinRM listeners..."
    winrm enumerate winrm/config/listener
    
    Write-Output ""
    Write-Output "SUCCESS: WinRM configured for Ansible"
    
} catch {
    Write-Output ""
    Write-Output "ERROR: WinRM configuration failed"
    Write-Output "Error: $_"
    Write-Output "Stack Trace: $($_.ScriptStackTrace)"
    throw
} finally {
    Stop-Transcript
}

# Made with Bob
