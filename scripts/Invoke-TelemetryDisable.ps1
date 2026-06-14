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
            $script:steps += (Add-Step -Step "telemetry" -Success $true -Message "Would set $Path\$Name = $Value")
            return
        }
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        $script:steps += (Add-Step -Step "telemetry" -Success $true -Message "Set $Path\$Name = $Value")
    }

    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0
    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DisableTelemetry' -Value 1
    Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1
    Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0
    Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0
    Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0
    Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0

    $telemetryServices = @('DiagTrack', 'dmwappushservice')
    foreach ($svcName in $telemetryServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($dryRun) {
                $steps += (Add-Step -Step "telemetry" -Success $true -Message "Would disable service $svcName")
            }
            else {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step "telemetry" -Success $true -Message "Disabled service $svcName")
            }
        }
    }

    $taskPaths = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
    )
    foreach ($taskPath in $taskPaths) {
        $task = Get-ScheduledTask -TaskPath (Split-Path $taskPath -Parent) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
        if ($task) {
            if ($dryRun) {
                $steps += (Add-Step -Step "telemetry" -Success $true -Message "Would disable task $taskPath")
            }
            else {
                Disable-ScheduledTask -TaskPath (Split-Path $taskPath -Parent) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue | Out-Null
                $steps += (Add-Step -Step "telemetry" -Success $true -Message "Disabled task $taskPath")
            }
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
