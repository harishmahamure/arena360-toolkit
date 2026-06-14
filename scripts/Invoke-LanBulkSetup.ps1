#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$targets = @($config['targets'])
$username = $config['username']
$password = $config['password']
$action = $config['action']  # enable_winrm | copy_setup | optimize | desktop_customize
$wallpaperSourcePath = $config['wallpaperSourcePath']
$removeShortcuts = if ($null -ne $config['removeShortcuts']) { [bool]$config['removeShortcuts'] } else { $true }
$setWallpaper = if ($null -ne $config['setWallpaper']) { [bool]$config['setWallpaper'] } else { $true }
$dryRun = [bool]($config['dryRun'])

$installRoot = Join-Path $env:ProgramData 'GameZoneOptimizer'
$scriptRoot = $PSScriptRoot

try {
    $steps = @()
    $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $secPassword)

    foreach ($target in $targets) {
        $ip = if ($target -is [string]) { $target } else {
            if ($target.ip_address) { $target.ip_address } else { $target.hostname }
        }

        if ($action -eq 'enable_winrm') {
            $remoteScript = @'
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
$ruleName = 'Game Zone Optimizer WinRM'
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 | Out-Null
}
Restart-Service WinRM -Force
'@
            try {
                Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock {
                    param($Script)
                    Invoke-Expression $Script
                } -ArgumentList $remoteScript -ErrorAction Stop
                $steps += (Add-Step -Step 'lan_setup' -Success $true -Message "WinRM enabled on $ip")
            }
            catch {
                $steps += (Add-Step -Step 'lan_setup' -Success $false -Message "WinRM failed on ${ip}: $($_.Exception.Message)")
            }
        }
        elseif ($action -eq 'copy_setup') {
            $remoteDir = "\\$ip\C$\ProgramData\GameZoneOptimizer"
            try {
                if (-not (Test-Path $remoteDir)) {
                    New-Item -Path $remoteDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path (Join-Path $scriptRoot 'Enable-WinRM.ps1') -Destination $remoteDir -Force -ErrorAction Stop
                Copy-Item -Path (Join-Path $scriptRoot '*.ps1') -Destination $remoteDir -Force -ErrorAction SilentlyContinue
                $steps += (Add-Step -Step 'lan_copy' -Success $true -Message "Setup files copied to $ip")
            }
            catch {
                $steps += (Add-Step -Step 'lan_copy' -Success $false -Message "Copy failed on ${ip}: $($_.Exception.Message)")
            }
        }
        elseif ($action -eq 'optimize') {
            $optimizeScript = Join-Path $scriptRoot 'Invoke-RemoteOptimize.ps1'
            $opts = @{
                targets = @(@{ hostname = $ip; username = $username; password = $password })
                options = @{
                    dry_run                     = $false
                    debloat_preset              = 'standard'
                    disable_win_update          = $true
                    disable_telemetry           = $true
                    disable_recommended_services = $true
                    apply_gaming_tweaks         = $true
                    create_restore_point        = $false
                }
            }
            try {
                $result = & $optimizeScript -ConfigJson ($opts | ConvertTo-Json -Depth 5 -Compress)
                $parsed = $result | ConvertFrom-Json
                if ($parsed.results) {
                    foreach ($r in $parsed.results) {
                        $steps += (Add-Step -Step 'lan_optimize' -Success $r.success -Message "$($r.hostname): $($r.message)")
                    }
                }
                else {
                    $steps += (Add-Step -Step 'lan_optimize' -Success $true -Message "Optimized $ip")
                }
            }
            catch {
                $steps += (Add-Step -Step 'lan_optimize' -Success $false -Message "Optimize failed on ${ip}: $($_.Exception.Message)")
            }
        }
        elseif ($action -eq 'desktop_customize') {
            $remoteDir = "\\$ip\C$\ProgramData\GameZoneOptimizer"
            $remoteScriptsDir = "\\$ip\C$\ProgramData\GameZoneOptimizer\scripts"
            $remoteWallpaperPath = 'C:\ProgramData\GameZoneOptimizer\wallpaper.jpg'

            try {
                if (-not (Test-Path $remoteDir)) {
                    New-Item -Path $remoteDir -ItemType Directory -Force | Out-Null
                }
                if (-not (Test-Path $remoteScriptsDir)) {
                    New-Item -Path $remoteScriptsDir -ItemType Directory -Force | Out-Null
                }

                if ($setWallpaper) {
                    if (-not $wallpaperSourcePath -or -not (Test-Path $wallpaperSourcePath)) {
                        $steps += (Add-Step -Step 'desktop_customize' -Success $false -Message "Wallpaper source missing for $ip")
                        continue
                    }
                    Copy-Item -Path $wallpaperSourcePath -Destination (Join-Path $remoteDir 'wallpaper.jpg') -Force -ErrorAction Stop
                    $steps += (Add-Step -Step 'desktop_customize' -Success $true -Message "Wallpaper copied to $ip")
                }

                Copy-Item -Path (Join-Path $scriptRoot 'Invoke-DesktopCustomize.ps1') -Destination $remoteScriptsDir -Force -ErrorAction Stop
                Copy-Item -Path (Join-Path $scriptRoot '_Common.ps1') -Destination $remoteScriptsDir -Force -ErrorAction Stop

                $customizeConfig = @{
                    wallpaperPath   = $remoteWallpaperPath
                    removeShortcuts = $removeShortcuts
                    setWallpaper    = $setWallpaper
                    dryRun          = $dryRun
                } | ConvertTo-Json -Compress

                $remoteResult = Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock {
                    param($ConfigJson)
                    $scriptPath = 'C:\ProgramData\GameZoneOptimizer\scripts\Invoke-DesktopCustomize.ps1'
                    $output = & $scriptPath -ConfigJson $ConfigJson
                    $output | ConvertFrom-Json
                } -ArgumentList $customizeConfig -ErrorAction Stop

                if ($remoteResult.steps) {
                    foreach ($s in $remoteResult.steps) {
                        $steps += (Add-Step -Step $s.step -Success $s.success -Message "${ip}: $($s.message)")
                    }
                }
                else {
                    $steps += (Add-Step -Step 'desktop_customize' -Success $true -Message "Desktop customized on $ip")
                }
            }
            catch {
                $steps += (Add-Step -Step 'desktop_customize' -Success $false -Message "Desktop customize failed on ${ip}: $($_.Exception.Message)")
            }
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
