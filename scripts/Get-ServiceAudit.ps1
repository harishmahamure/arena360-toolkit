#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

try {
    $baselinePath = Get-ManifestPath -Name 'services-baseline.json'
    $baseline = @{}
    if ($baselinePath) {
        $manifest = Get-Content $baselinePath -Raw | ConvertFrom-Json
        foreach ($svc in $manifest.services) {
            $baseline[$svc.name] = $svc
        }
    }

    $services = Get-Service -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        $info = $baseline[$name]
        $category = if ($info) { $info.category } else { 'unknown' }
        $description = if ($info) { $info.description } else { '' }

        $startType = 'Unknown'
        try {
            $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
            if ($cim) { $startType = $cim.StartMode }
        }
        catch { }

        @{
            name         = $name
            display_name = $_.DisplayName
            status       = $_.Status.ToString()
            start_type   = $startType
            category     = $category
            description  = $description
        }
    }

    Write-Result -Success $true -Data @{ services = @($services) }
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
