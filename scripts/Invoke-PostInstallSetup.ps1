#Requires -Version 5.1
param(
    [switch]$Elevated
)
<#
.SYNOPSIS
    Post-install setup: enable WinRM and copy scripts to ProgramData.
    Run automatically by NSIS installer hook on gaming PCs.
    Prompts for administrator elevation (UAC / admin credentials) when needed.
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_Common.ps1')

if (-not $Elevated -and -not (Test-IsAdministrator)) {
    Request-AdministratorElevation -ScriptPath $PSCommandPath -Reason @(
        'Post-install setup will:'
        '  - Copy setup scripts to ProgramData'
        '  - Enable WinRM for remote management'
    ) -join "`n"
}

$installRoot = Join-Path $env:ProgramData 'GameZoneOptimizer'
$scriptsDir = Join-Path $installRoot 'scripts'
$manifestsDir = Join-Path $installRoot 'manifests'
$winrmReady = $false
$setupError = $null

try {
    foreach ($dir in @($scriptsDir, $manifestsDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    $scriptSources = @(
        $PSScriptRoot,
        (Join-Path $env:ProgramFiles 'Game Zone Optimizer\resources\scripts'),
        (Join-Path ${env:ProgramFiles(x86)} 'Game Zone Optimizer\resources\scripts'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Game Zone Optimizer\resources\scripts')
    )

    $manifestSources = @(
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'manifests'),
        (Join-Path $env:ProgramFiles 'Game Zone Optimizer\resources\manifests'),
        (Join-Path ${env:ProgramFiles(x86)} 'Game Zone Optimizer\resources\manifests'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Game Zone Optimizer\resources\manifests')
    )

    foreach ($src in $scriptSources) {
        if (Test-Path $src) {
            Get-ChildItem -Path $src -Filter '*.ps1' -ErrorAction SilentlyContinue |
                Copy-Item -Destination $scriptsDir -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($src in $manifestSources) {
        if (Test-Path $src) {
            Get-ChildItem -Path $src -Filter '*.json' -ErrorAction SilentlyContinue |
                Copy-Item -Destination $manifestsDir -Force -ErrorAction SilentlyContinue
        }
    }

    $enableScript = Join-Path $PSScriptRoot 'Enable-WinRM.ps1'
    if (-not (Test-Path $enableScript)) {
        $enableScript = Join-Path $scriptsDir 'Enable-WinRM.ps1'
    }
    if (Test-Path $enableScript) {
        & $enableScript -Elevated
        $winrmReady = $true
    }
}
catch {
    $setupError = $_.Exception.Message
    Write-Host "Post-install setup failed: $setupError" -ForegroundColor Red
}

@{
    installed_at = (Get-Date -Format 'o')
    version      = '0.1.0'
    winrm_ready  = $winrmReady
    setup_error  = $setupError
} | ConvertTo-Json | Set-Content (Join-Path $installRoot 'install-state.json') -Encoding UTF8

if ($setupError) {
    exit 1
}

Write-Host 'Game Zone Optimizer post-install setup complete.' -ForegroundColor Green
