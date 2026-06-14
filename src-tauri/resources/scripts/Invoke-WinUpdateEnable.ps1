#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

try {
    $steps = @()

    $wuServices = @('wuauserv', 'UsoSvc', 'WaaSMedicSvc')
    foreach ($svcName in $wuServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
            $steps += (Add-Step -Step "win_update" -Success $true -Message "Re-enabled $svcName")
        }
    }

    $auPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    if (Test-Path $auPath) {
        Remove-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $auPath -Name 'AUOptions' -ErrorAction SilentlyContinue
        $steps += (Add-Step -Step "win_update" -Success $true -Message "Removed update policy registry keys")
    }

    $taskRoots = @('\Microsoft\Windows\WindowsUpdate', '\Microsoft\Windows\UpdateOrchestrator')
    foreach ($root in $taskRoots) {
        $tasks = Get-ScheduledTask -TaskPath "$root\" -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            Enable-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue | Out-Null
            $steps += (Add-Step -Step "win_update" -Success $true -Message "Enabled task $($task.TaskName)")
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
