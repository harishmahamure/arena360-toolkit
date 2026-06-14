#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$dryRun = [bool]($config['dryRun'])

try {
    $steps = @()

    function Set-RegValue {
        param($Path, $Name, $Value, $Type = 'DWord')
        if ($dryRun) {
            $script:steps += (Add-Step -Step "win_update" -Success $true -Message "Would set $Path\$Name = $Value")
            return
        }
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        $script:steps += (Add-Step -Step "win_update" -Success $true -Message "Set $Path\$Name = $Value")
    }

    $wuServices = @('wuauserv', 'UsoSvc', 'WaaSMedicSvc')
    foreach ($svcName in $wuServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($dryRun) {
                $steps += (Add-Step -Step "win_update" -Success $true -Message "Would stop and disable $svcName")
            }
            else {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step "win_update" -Success $true -Message "Disabled $svcName")
            }
        }
    }

    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value 1
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AUOptions' -Value 1

    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc' -Name 'Start' -Value 4

    $taskRoots = @('\Microsoft\Windows\WindowsUpdate', '\Microsoft\Windows\UpdateOrchestrator')
    foreach ($root in $taskRoots) {
        $tasks = Get-ScheduledTask -TaskPath "$root\" -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            if ($dryRun) {
                $steps += (Add-Step -Step "win_update" -Success $true -Message "Would disable task $($task.TaskPath)$($task.TaskName)")
            }
            else {
                Disable-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue | Out-Null
                $steps += (Add-Step -Step "win_update" -Success $true -Message "Disabled task $($task.TaskName)")
            }
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
