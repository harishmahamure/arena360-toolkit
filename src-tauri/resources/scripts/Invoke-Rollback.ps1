#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$backupPath = $config['backupPath']

try {
    $steps = @()

    if (-not (Test-Path $backupPath)) {
        Write-Result -Success $false -Message "Backup file not found: $backupPath"
        exit 1
    }

    $snapshot = Get-Content $backupPath -Raw | ConvertFrom-Json

    foreach ($svc in $snapshot.services) {
        try {
            $startMode = $svc.start_mode
            if ($startMode -eq 'Disabled') {
                Set-Service -Name $svc.name -StartupType Disabled -ErrorAction SilentlyContinue
            }
            elseif ($startMode -eq 'Automatic') {
                Set-Service -Name $svc.name -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $svc.name -ErrorAction SilentlyContinue
            }
            elseif ($startMode -eq 'Manual') {
                Set-Service -Name $svc.name -StartupType Manual -ErrorAction SilentlyContinue
            }
            $steps += (Add-Step -Step "rollback" -Success $true -Message "Restored service $($svc.name) to $startMode")
        }
        catch {
            $steps += (Add-Step -Step "rollback" -Success $false -Message "Failed service $($svc.name): $($_.Exception.Message)")
        }
    }

    foreach ($reg in $snapshot.registry) {
        try {
            if (-not (Test-Path $reg.path)) { New-Item -Path $reg.path -Force | Out-Null }
            Set-ItemProperty -Path $reg.path -Name $reg.name -Value $reg.value -Force
            $steps += (Add-Step -Step "rollback" -Success $true -Message "Restored registry $($reg.path)\$($reg.name)")
        }
        catch {
            $steps += (Add-Step -Step "rollback" -Success $false -Message "Failed registry $($reg.name): $($_.Exception.Message)")
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
