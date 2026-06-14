#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$hostname = $config['hostname']
$username = $config['username']
$password = $config['password']

try {
    $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $secPassword)

    $result = Test-WSMan -ComputerName $hostname -Credential $cred -ErrorAction Stop
    $reachable = $null -ne $result

    @{ success = $true; reachable = $reachable } | ConvertTo-Json -Compress
}
catch {
    @{ success = $true; reachable = $false; message = $_.Exception.Message } | ConvertTo-Json -Compress
}
