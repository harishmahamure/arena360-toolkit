#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

try {
    $steps = @()

    try {
        Checkpoint-Computer -Description 'Game Zone Optimizer' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        $steps += (Add-Step -Step "restore_point" -Success $true -Message "System restore point created")
    }
    catch {
        $steps += (Add-Step -Step "restore_point" -Success $false -Message "Restore point failed (may be disabled): $($_.Exception.Message)")
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
