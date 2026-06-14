#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'

function Get-Config {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return @{} }
    try { return $Json | ConvertFrom-Json -AsHashtable } catch { return @{} }
}

function Write-Result {
    param(
        [bool]$Success = $true,
        [object]$Data = $null,
        [string]$Message = '',
        [array]$Steps = @()
    )
    $out = @{
        success = $Success
        message = $Message
        steps   = $Steps
    }
    if ($null -ne $Data) {
        foreach ($key in $Data.Keys) {
            $out[$key] = $Data[$key]
        }
    }
    $out | ConvertTo-Json -Depth 10 -Compress
}

function Add-Step {
    param([string]$Step, [bool]$Success, [string]$Message)
    return @{ step = $Step; success = $Success; message = $Message }
}

function Get-ManifestPath {
    param([string]$Name)
    $base = Split-Path -Parent $PSScriptRoot
    $paths = @(
        (Join-Path $base "manifests\$Name"),
        (Join-Path (Split-Path -Parent $base) "manifests\$Name")
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-PackageMatch {
    param([string]$PackageName, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($PackageName -like $pattern) { return $true }
    }
    return $false
}

function Get-AllBloatManifestItems {
    $items = @()
    foreach ($file in @('bloatware-apps.json', 'bloatware-appx.json')) {
        $path = Get-ManifestPath -Name $file
        if ($path) {
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $items += $manifest.items
        }
    }
    # Deduplicate by id
    $seen = @{}
    $unique = @()
    foreach ($item in $items) {
        if (-not $seen.ContainsKey($item.id)) {
            $seen[$item.id] = $true
            $unique += $item
        }
    }
    return $unique
}

Export-ModuleMember -Function *
