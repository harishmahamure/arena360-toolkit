#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$ids = @($config['ids'])
$dryRun = [bool]($config['dryRun'])

try {
    $steps = @()
    $manifestItems = Get-AllBloatManifestItems | Where-Object { $ids -contains $_.id }

    foreach ($item in $manifestItems) {
        if ($item.kind -eq 'appx') {
            $packages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                Where-Object { Test-PackageMatch -PackageName $_.Name -Patterns $item.patterns }

            foreach ($pkg in $packages) {
                if ($dryRun) {
                    $steps += (Add-Step -Step "debloat" -Success $true -Message "Would remove AppX: $($pkg.Name)")
                }
                else {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        $steps += (Add-Step -Step "debloat" -Success $true -Message "Removed AppX: $($pkg.Name)")
                    }
                    catch {
                        $steps += (Add-Step -Step "debloat" -Success $false -Message "Failed $($pkg.Name): $($_.Exception.Message)")
                    }
                }
            }

            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { Test-PackageMatch -PackageName $_.DisplayName -Patterns $item.patterns }

            foreach ($pkg in $provisioned) {
                if ($dryRun) {
                    $steps += (Add-Step -Step "debloat" -Success $true -Message "Would deprovision: $($pkg.DisplayName)")
                }
                else {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
                        $steps += (Add-Step -Step "debloat" -Success $true -Message "Deprovisioned: $($pkg.DisplayName)")
                    }
                    catch {
                        $steps += (Add-Step -Step "debloat" -Success $false -Message "Failed deprovision $($pkg.DisplayName): $($_.Exception.Message)")
                    }
                }
            }
        }
        elseif ($item.id -eq 'onedrive') {
            $odSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
            if (-not (Test-Path $odSetup)) { $odSetup = "$env:SystemRoot\System32\OneDriveSetup.exe" }
            if (Test-Path $odSetup) {
                if ($dryRun) {
                    $steps += (Add-Step -Step "debloat" -Success $true -Message "Would uninstall OneDrive")
                }
                else {
                    Start-Process $odSetup '/uninstall' -Wait -ErrorAction SilentlyContinue
                    $steps += (Add-Step -Step "debloat" -Success $true -Message "OneDrive uninstall initiated")
                }
            }
        }
    }

    if ($steps.Count -eq 0) {
        $steps += (Add-Step -Step "debloat" -Success $true -Message "No matching packages found to remove")
    }

    Write-Result -Success $true -Steps $steps
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
