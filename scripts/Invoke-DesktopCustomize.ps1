#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$wallpaperPath = $config['wallpaperPath']
if (-not $wallpaperPath) {
    $wallpaperPath = 'C:\ProgramData\GameZoneOptimizer\wallpaper.jpg'
}
$removeShortcuts = if ($null -ne $config['removeShortcuts']) { [bool]$config['removeShortcuts'] } else { $true }
$setWallpaper = if ($null -ne $config['setWallpaper']) { [bool]$config['setWallpaper'] } else { $true }
$dryRun = [bool]($config['dryRun'])

$desktopRegPath = 'Control Panel\Desktop'
$policyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$skipUserDirs = @('Default', 'Public', 'All Users', 'Default User', 'DefaultAppPool')

function Set-WallpaperRegistry {
    param([string]$HiveRoot, [string]$Path, [string]$Wallpaper)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name 'Wallpaper' -Value $Wallpaper -Force
    Set-ItemProperty -Path $Path -Name 'WallpaperStyle' -Value '10' -Force
    Set-ItemProperty -Path $Path -Name 'TileWallpaper' -Value '0' -Force
}

function Invoke-RefreshWallpaper {
    param([string]$Wallpaper)
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WallpaperHelper {
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@ -ErrorAction SilentlyContinue
    [WallpaperHelper]::SystemParametersInfo(20, 0, $Wallpaper, 3) | Out-Null
}

function Set-UserHiveWallpaper {
    param([string]$NtUserPath, [string]$Wallpaper, [string]$Label)
    $hiveName = "GZO_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $loaded = $false
    try {
        if ($dryRun) {
            return (Add-Step -Step 'wallpaper' -Success $true -Message "Would set wallpaper for $Label")
        }
        $result = reg load "HKU\$hiveName" $NtUserPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            return (Add-Step -Step 'wallpaper' -Success $false -Message "Could not load hive for ${Label}: $result")
        }
        $loaded = $true
        $path = "Registry::HKU\$hiveName\$desktopRegPath"
        Set-WallpaperRegistry -HiveRoot $hiveName -Path $path -Wallpaper $Wallpaper
        reg unload "HKU\$hiveName" 2>&1 | Out-Null
        $loaded = $false
        return (Add-Step -Step 'wallpaper' -Success $true -Message "Set wallpaper for $Label")
    }
    catch {
        if ($loaded) { reg unload "HKU\$hiveName" 2>&1 | Out-Null }
        return (Add-Step -Step 'wallpaper' -Success $false -Message "Failed ${Label}: $($_.Exception.Message)")
    }
}

function Remove-DesktopShortcutsFromPath {
    param([string]$DesktopPath)
    $removed = 0
    if (-not (Test-Path $DesktopPath)) { return 0 }
    foreach ($pattern in @('*.lnk', '*.url')) {
        Get-ChildItem -Path $DesktopPath -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $dryRun) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
            $removed++
        }
    }
    return $removed
}

try {
    $steps = @()

    if ($setWallpaper) {
        if (-not (Test-Path $wallpaperPath)) {
            Write-Result -Success $false -Message "Wallpaper not found: $wallpaperPath"
            exit 1
        }

        $resolvedWallpaper = (Resolve-Path $wallpaperPath).Path

        $defaultNtUser = 'C:\Users\Default\NTUSER.DAT'
        if (Test-Path $defaultNtUser) {
            $steps += Set-UserHiveWallpaper -NtUserPath $defaultNtUser -Wallpaper $resolvedWallpaper -Label 'Default user template'
        }

        Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirName = $_.Name
            if ($skipUserDirs -contains $dirName) { return }
            $ntUser = Join-Path $_.FullName 'NTUSER.DAT'
            if (Test-Path $ntUser) {
                $steps += Set-UserHiveWallpaper -NtUserPath $ntUser -Wallpaper $resolvedWallpaper -Label $dirName
            }
        }

        if (-not $dryRun) {
            if (-not (Test-Path $policyPath)) {
                New-Item -Path $policyPath -Force | Out-Null
            }
            Set-ItemProperty -Path $policyPath -Name 'Wallpaper' -Value $resolvedWallpaper -Force
            Set-ItemProperty -Path $policyPath -Name 'WallpaperStyle' -Value '10' -Force
            try {
                Invoke-RefreshWallpaper -Wallpaper $resolvedWallpaper
                $steps += (Add-Step -Step 'wallpaper' -Success $true -Message 'Refreshed active desktop session')
            }
            catch {
                $steps += (Add-Step -Step 'wallpaper' -Success $true -Message 'HKLM policy set; active session refresh skipped')
            }
        }
        else {
            $steps += (Add-Step -Step 'wallpaper' -Success $true -Message 'Would set HKLM wallpaper policy and refresh desktop')
        }
    }

    if ($removeShortcuts) {
        $totalRemoved = 0
        $paths = @('C:\Users\Public\Desktop')
        Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($skipUserDirs -contains $_.Name) { return }
            $desktop = Join-Path $_.FullName 'Desktop'
            if (Test-Path $desktop) { $paths += $desktop }
        }

        foreach ($desktopPath in ($paths | Select-Object -Unique)) {
            $count = Remove-DesktopShortcutsFromPath -DesktopPath $desktopPath
            $totalRemoved += $count
            if ($count -gt 0) {
                $verb = if ($dryRun) { 'Would remove' } else { 'Removed' }
                $steps += (Add-Step -Step 'shortcuts' -Success $true -Message "$verb $count shortcuts from $desktopPath")
            }
        }

        if ($totalRemoved -eq 0) {
            $steps += (Add-Step -Step 'shortcuts' -Success $true -Message 'No desktop shortcuts found to remove')
        }
        else {
            $verb = if ($dryRun) { 'Would remove' } else { 'Removed' }
            $steps += (Add-Step -Step 'shortcuts' -Success $true -Message "$verb $totalRemoved desktop shortcuts total")
        }
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
