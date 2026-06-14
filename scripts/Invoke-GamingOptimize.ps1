#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$options = $config['options']
if (-not $options) { $options = @{} }
$dryRun = [bool]($config['dryRun'])

try {
    $steps = @()

    function Set-RegValue {
        param($Path, $Name, $Value, $Type = 'DWord')
        if ($dryRun) {
            $script:steps += (Add-Step -Step "gaming" -Success $true -Message "Would set $Path\$Name = $Value")
            return
        }
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        $script:steps += (Add-Step -Step "gaming" -Success $true -Message "Set $Path\$Name")
    }

    if ($options['powerPlan'] -eq 'high_performance' -or -not $options.ContainsKey('powerPlan')) {
        if (-not $dryRun) {
            $ultimate = powercfg -list | Select-String 'Ultimate'
            if ($ultimate) {
                $guid = ($ultimate -split '\s+')[3].Trim('()')
                powercfg -setactive $guid | Out-Null
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Activated Ultimate Performance power plan")
            }
            else {
                powercfg -setactive SCHEME_MIN | Out-Null
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Activated High Performance power plan")
            }
        }
        else {
            $steps += (Add-Step -Step "gaming" -Success $true -Message "Would set High Performance power plan")
        }
    }

    if ($options['gameMode'] -ne $false) {
        Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1
        Set-RegValue -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_GameMode' -Value 1
    }

    if ($options['hags'] -eq $true) {
        Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2
    }

    if ($options['disableMouseAcceleration'] -ne $false) {
        Set-RegValue -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -Type 'String'
        Set-RegValue -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -Type 'String'
        Set-RegValue -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -Type 'String'
    }

    if ($options['disableSysMain'] -ne $false) {
        $svc = Get-Service -Name 'SysMain' -ErrorAction SilentlyContinue
        if ($svc) {
            if ($dryRun) {
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Would disable SysMain")
            }
            else {
                Stop-Service -Name 'SysMain' -Force -ErrorAction SilentlyContinue
                Set-Service -Name 'SysMain' -StartupType Disabled -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Disabled SysMain")
            }
        }
    }

    if ($options['disableSearchIndexing'] -ne $false) {
        $svc = Get-Service -Name 'WSearch' -ErrorAction SilentlyContinue
        if ($svc) {
            if ($dryRun) {
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Would disable Windows Search")
            }
            else {
                Stop-Service -Name 'WSearch' -Force -ErrorAction SilentlyContinue
                Set-Service -Name 'WSearch' -StartupType Disabled -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step "gaming" -Success $true -Message "Disabled Windows Search")
            }
        }
    }

    if ($options['disableDeliveryOptimization'] -ne $false) {
        Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0
    }

    if ($options['disableHibernation'] -ne $false) {
        if (-not $dryRun) {
            powercfg -h off | Out-Null
            $steps += (Add-Step -Step "gaming" -Success $true -Message "Disabled hibernation")
        }
        else {
            $steps += (Add-Step -Step "gaming" -Success $true -Message "Would disable hibernation")
        }
    }

    if ($options['disableBackgroundApps'] -ne $false) {
        Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1
    }

    if ($options['networkTweaks'] -ne $false) {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($adapter.InterfaceGuid)"
            Set-RegValue -Path $path -Name 'TcpAckFrequency' -Value 1
            Set-RegValue -Path $path -Name 'TCPNoDelay' -Value 1
        }
    }

    if ($options['visualEffects'] -eq 'best_performance') {
        Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2
    }

    if ($options['disableTips'] -ne $false) {
        Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-310093Enabled' -Value 0
        Set-RegValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338388Enabled' -Value 0
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
