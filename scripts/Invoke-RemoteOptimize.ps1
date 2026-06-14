#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$targets = @($config['targets'])
$options = $config['options']

try {
    $results = @()
    $scriptBlock = {
        param($OptionsJson)
        $scriptRoot = $using:PSScriptRoot
        $opts = $OptionsJson | ConvertFrom-Json

        $profileScript = Join-Path $scriptRoot 'Invoke-GamingOptimize.ps1'
        $steps = @()

        if ($opts.apply_gaming_tweaks) {
            $gamingResult = & $profileScript -ConfigJson (@{ options = $opts; dryRun = $opts.dry_run } | ConvertTo-Json -Compress)
            $parsed = $gamingResult | ConvertFrom-Json
            if ($parsed.steps) { $steps += $parsed.steps }
        }

        if ($opts.disable_telemetry) {
            $telScript = Join-Path $scriptRoot 'Invoke-TelemetryDisable.ps1'
            $telResult = & $telScript -ConfigJson (@{ dryRun = $opts.dry_run } | ConvertTo-Json -Compress)
            $parsed = $telResult | ConvertFrom-Json
            if ($parsed.steps) { $steps += $parsed.steps }
        }

        if ($opts.disable_win_update) {
            $wuScript = Join-Path $scriptRoot 'Invoke-WinUpdateDisable.ps1'
            $wuResult = & $wuScript -ConfigJson (@{ dryRun = $opts.dry_run } | ConvertTo-Json -Compress)
            $parsed = $wuResult | ConvertFrom-Json
            if ($parsed.steps) { $steps += $parsed.steps }
        }

        return @{ steps = $steps; success = $true }
    }

    $optionsJson = $options | ConvertTo-Json -Depth 5 -Compress

    foreach ($target in $targets) {
        $hostname = $target.hostname
        $secPassword = ConvertTo-SecureString $target.password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($target.username, $secPassword)

        try {
            $remoteResult = Invoke-Command -ComputerName $hostname -Credential $cred -ScriptBlock $scriptBlock -ArgumentList $optionsJson -ErrorAction Stop

            foreach ($step in $remoteResult.steps) {
                $results += @{
                    hostname = $hostname
                    step     = $step.step
                    success  = $step.success
                    message  = $step.message
                }
            }

            if (-not $remoteResult.steps -or $remoteResult.steps.Count -eq 0) {
                $results += @{
                    hostname = $hostname
                    step     = 'remote'
                    success  = $true
                    message  = 'Profile applied successfully'
                }
            }
        }
        catch {
            $results += @{
                hostname = $hostname
                step     = 'remote'
                success  = $false
                message  = $_.Exception.Message
            }
        }
    }

    @{ success = $true; results = $results } | ConvertTo-Json -Depth 10 -Compress
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
