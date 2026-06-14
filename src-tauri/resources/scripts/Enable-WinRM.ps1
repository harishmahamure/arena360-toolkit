#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Enables WinRM on a gaming PC for remote optimization from the admin station.
#>
$ErrorActionPreference = 'Stop'

Write-Host 'Enabling WinRM...' -ForegroundColor Cyan

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force

$ruleName = 'Game Zone Optimizer WinRM'
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 | Out-Null
}

Restart-Service WinRM -Force

Write-Host 'WinRM is ready.' -ForegroundColor Green
