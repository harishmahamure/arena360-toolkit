#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

try {
    $manifestItems = Get-AllBloatManifestItems
    $results = @()

    $appxPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    foreach ($item in $manifestItems) {
        $installed = $false
        $kind = $item.kind

        if ($kind -eq 'appx') {
            foreach ($pkg in $appxPackages) {
                if (Test-PackageMatch -PackageName $pkg.Name -Patterns $item.patterns) {
                    $installed = $true
                    break
                }
            }
            if (-not $installed) {
                foreach ($pkg in $provisioned) {
                    if (Test-PackageMatch -PackageName $pkg.DisplayName -Patterns $item.patterns) {
                        $installed = $true
                        break
                    }
                }
            }
        }
        elseif ($kind -eq 'classic') {
            $uninstallKeys = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )
            foreach ($key in $uninstallKeys) {
                $apps = Get-ItemProperty $key -ErrorAction SilentlyContinue
                foreach ($app in $apps) {
                    if ($app.DisplayName -and (Test-PackageMatch -PackageName $app.DisplayName -Patterns $item.patterns)) {
                        $installed = $true
                        break
                    }
                }
                if ($installed) { break }
            }
        }

        $results += @{
            id        = $item.id
            name      = $item.name
            kind      = $kind
            installed = $installed
            optional  = [bool]$item.optional
            presets   = @($item.presets)
        }
    }

    Write-Result -Success $true -Data @{ items = $results }
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
