#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$label = $config['label']

try {
    $backupRoot = Join-Path $env:APPDATA 'GameZoneOptimizer\backups'
    if (-not (Test-Path $backupRoot)) { New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null }

    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $backupFile = Join-Path $backupRoot "backup_$timestamp.json"

    $snapshot = @{
        created_at = (Get-Date -Format 'o')
        label      = $label
        services   = @()
        registry   = @()
        tasks      = @()
    }

    $trackedServices = @('wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'DiagTrack', 'dmwappushservice', 'SysMain', 'WSearch')
    foreach ($name in $trackedServices) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) {
            $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
            $snapshot.services += @{
                name       = $name
                start_mode = if ($cim) { $cim.StartMode } else { 'Unknown' }
                status     = $svc.Status.ToString()
            }
        }
    }

    $regPaths = @(
        @{ path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; names = @('AllowTelemetry', 'DisableTelemetry') },
        @{ path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; names = @('NoAutoUpdate', 'AUOptions') },
        @{ path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; names = @('DisableWindowsConsumerFeatures') }
    )
    foreach ($entry in $regPaths) {
        if (Test-Path $entry.path) {
            foreach ($prop in $entry.names) {
                $val = Get-ItemProperty -Path $entry.path -Name $prop -ErrorAction SilentlyContinue
                if ($null -ne $val) {
                    $snapshot.registry += @{
                        path  = $entry.path
                        name  = $prop
                        value = $val.$prop
                    }
                }
            }
        }
    }

    $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $backupFile -Encoding UTF8

    @{
        success    = $true
        path       = $backupFile
        created_at = $snapshot.created_at
        steps      = @((Add-Step -Step "backup" -Success $true -Message "Backup saved to $backupFile"))
    } | ConvertTo-Json -Depth 10 -Compress
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
