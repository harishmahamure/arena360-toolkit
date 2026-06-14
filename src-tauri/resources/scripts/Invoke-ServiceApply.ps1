#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$serviceNames = @($config['serviceNames'])
$action = $config['action']
$dryRun = [bool]($config['dryRun'])

$essential = @('RpcSs', 'PlugPlay', 'Winmgmt', 'EventLog', 'Dhcp', 'Dnscache', 'LSM', 'Power', 'ProfSvc', 'SamSs', 'SystemEventsBroker')

try {
    $steps = @()

    foreach ($name in $serviceNames) {
        if ($essential -contains $name) {
            $steps += (Add-Step -Step "services" -Success $false -Message "Skipped essential service: $name")
            continue
        }

        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) {
            $steps += (Add-Step -Step "services" -Success $true -Message "Service not found: $name")
            continue
        }

        if ($dryRun) {
            $steps += (Add-Step -Step "services" -Success $true -Message "Would $action service $name")
            continue
        }

        try {
            if ($action -eq 'disable') {
                Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $name -StartupType Disabled
                $steps += (Add-Step -Step "services" -Success $true -Message "Disabled $name")
            }
            elseif ($action -eq 'enable') {
                Set-Service -Name $name -StartupType Automatic
                Start-Service -Name $name -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step "services" -Success $true -Message "Enabled $name")
            }
        }
        catch {
            $steps += (Add-Step -Step "services" -Success $false -Message "Failed $name`: $($_.Exception.Message)")
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
