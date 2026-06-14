#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Post-install setup: enable WinRM and copy scripts to ProgramData.
    Run automatically by NSIS installer hook on gaming PCs.
#>
$ErrorActionPreference = 'Stop'

$installRoot = Join-Path $env:ProgramData 'GameZoneOptimizer'
$scriptsDir = Join-Path $installRoot 'scripts'

if (-not (Test-Path $scriptsDir)) {
    New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
}

# Copy bundled scripts from install location if present
$bundlePaths = @(
    (Join-Path $PSScriptRoot '..'),
    (Join-Path $env:ProgramFiles 'Game Zone Optimizer\resources\scripts'),
    (Join-Path ${env:ProgramFiles(x86)} 'Game Zone Optimizer\resources\scripts')
)

foreach ($bundle in $bundlePaths) {
    if (Test-Path $bundle) {
        Get-ChildItem -Path $bundle -Filter '*.ps1' -ErrorAction SilentlyContinue |
            Copy-Item -Destination $scriptsDir -Force -ErrorAction SilentlyContinue
    }
}

# Enable WinRM for remote admin
$enableScript = Join-Path $PSScriptRoot 'Enable-WinRM.ps1'
if (Test-Path $enableScript) {
    & $enableScript
}

# Write install marker
@{
    installed_at = (Get-Date -Format 'o')
    version      = '0.1.0'
    winrm_ready  = $true
} | ConvertTo-Json | Set-Content (Join-Path $installRoot 'install-state.json') -Encoding UTF8

Write-Host 'Game Zone Optimizer post-install setup complete.' -ForegroundColor Green
