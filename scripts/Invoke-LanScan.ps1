#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$subnetBase = $config['subnetBase']
$startHost = if ($config['startHost']) { [int]$config['startHost'] } else { 1 }
$endHost = if ($config['endHost']) { [int]$config['endHost'] } else { 254 }
$excludeIps = @($config['excludeIps'])

if (-not $subnetBase) {
    $subResult = & (Join-Path $PSScriptRoot 'Get-SubnetConfig.ps1')
    $sub = $subResult | ConvertFrom-Json
    if (-not $sub.success) {
        Write-Result -Success $false -Message 'Could not detect subnet'
        exit 1
    }
    $octets = $sub.current_ip.Split('.')
    $subnetBase = "$($octets[0]).$($octets[1]).$($octets[2])"
    if ($config['usePool']) {
        $startHost = [int]($sub.pool_start.Split('.')[-1])
        $endHost = [int]($sub.pool_end.Split('.')[-1])
    }
}

try {
    $devices = @()
    $arpTable = arp -a 2>$null
    $selfIps = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' } |
        Select-Object -ExpandProperty IPAddress)

    $jobs = @()
    for ($i = $startHost; $i -le $endHost; $i++) {
        $ip = "$subnetBase.$i"
        if ($excludeIps -contains $ip -or $selfIps -contains $ip) { continue }
        $jobs += [PSCustomObject]@{ IP = $ip }
    }

    $total = $jobs.Count
    $found = 0

    foreach ($target in $jobs) {
        $ip = $target.IP
        $reachable = $false
        try {
            $reachable = Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
        }
        catch { }

        if (-not $reachable) { continue }
        $found++

        $mac = ''
        foreach ($line in $arpTable) {
            if ($line -match "$ip\s+([0-9a-f\-]+)") {
                $mac = $Matches[1].Replace('-', ':').ToUpper()
                break
            }
        }

        $hostname = ''
        try {
            $resolved = [System.Net.Dns]::GetHostEntry($ip)
            if ($resolved.HostName -and $resolved.HostName -ne $ip) {
                $hostname = $resolved.HostName.Split('.')[0]
            }
        }
        catch { }

        $devices += @{
            ip_address      = $ip
            mac_address     = $mac
            hostname        = $hostname
            device_type     = 'unknown'
            connection_type = 'unknown'
            is_reachable    = $true
            winrm_enabled   = $false
            adapter_name    = ''
        }
    }

    Write-Result -Success $true -Data @{
        devices = $devices
        scanned = $total
        found   = $found
    }
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
