#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'

function ConvertTo-HashtableRecursive {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-HashtableRecursive -InputObject $InputObject[$key]
        }
        return $result
    }
    if ($InputObject -is [System.Array]) {
        return @($InputObject | ForEach-Object { ConvertTo-HashtableRecursive -InputObject $_ })
    }
    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $result[$prop.Name] = ConvertTo-HashtableRecursive -InputObject $prop.Value
        }
        return $result
    }
    return $InputObject
}

function Get-Config {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return @{} }
    try {
        $obj = $Json | ConvertFrom-Json
        $hash = ConvertTo-HashtableRecursive -InputObject $obj
        if ($null -eq $hash) { return @{} }
        return $hash
    }
    catch {
        return @{}
    }
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

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdministratorElevation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string]$Reason = 'Game Zone Optimizer needs administrator privileges to complete setup.'
    )

    if ([Environment]::UserInteractive) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            [void][System.Windows.Forms.MessageBox]::Show(
                "$Reason`n`nPlease approve the UAC prompt. If you are not an administrator, enter admin credentials when prompted.",
                'Administrator Required',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            Write-Host $Reason -ForegroundColor Yellow
            Write-Host 'Approve the UAC prompt, or enter administrator credentials when prompted.' -ForegroundColor Yellow
        }
    }
    else {
        Write-Host $Reason -ForegroundColor Yellow
    }

    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-WindowStyle', 'Normal',
        '-File', "`"$ScriptPath`"",
        '-Elevated'
    )

    try {
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait -PassThru -ErrorAction Stop
        exit $proc.ExitCode
    }
    catch {
        Write-Host "Administrator elevation was cancelled or failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Export-ModuleMember -Function *
