#Requires -Version 5.1
param(
    [switch]$Elevated
)
<#
.SYNOPSIS
    Enables WinRM on a gaming PC for remote optimization from the admin station.
    Prompts for administrator elevation when needed.
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_Common.ps1')

if (-not $Elevated -and -not (Test-IsAdministrator)) {
    Request-AdministratorElevation -ScriptPath $PSCommandPath -Reason 'WinRM setup requires administrator privileges to configure remoting and firewall rules.'
}

Write-Host 'Enabling WinRM...' -ForegroundColor Cyan

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force

$ruleName = 'Game Zone Optimizer WinRM'
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 | Out-Null
}

Restart-Service WinRM -Force

Write-Host 'WinRM is ready.' -ForegroundColor Green
