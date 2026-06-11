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
    
    # Verify checksum for supply-chain security
    $expectedChecksum = "EBA72DF06E3E77709595F75D1D5B4D95B06602429DD2A3F7867406DF875B0C70"
    $actualChecksum = (Get-FileHash -Path $output -Algorithm SHA256).Hash
    if ($actualChecksum -ne $expectedChecksum) {
        throw "Checksum mismatch for ConfigureRemotingForAnsible.ps1. Actual: $actualChecksum Expected: $expectedChecksum"
    }
    Write-Output "Download complete: $output"
    Write-Output "Checksum verified: $actualChecksum"
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
