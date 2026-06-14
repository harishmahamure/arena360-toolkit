#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

function Get-NetworkBase {
    param([string]$Ip, [int]$Prefix)
    $octets = $Ip.Split('.')
    if ($octets.Count -ne 4) { return $Ip }
    if ($Prefix -ge 24) {
        return "$($octets[0]).$($octets[1]).$($octets[2])"
    }
    return "$($octets[0]).$($octets[1])"
}

try {
    $config = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPv4DefaultGateway -ne $null -and
            $_.NetAdapter.Status -eq 'Up'
        } |
        Sort-Object @{
            Expression = {
                if ($_.NetAdapter.MediaType -eq 0) { 0 } else { 1 }
            }
        } |
        Select-Object -First 1

    if (-not $config) {
        Write-Result -Success $false -Message 'No active IPv4 adapter with gateway found'
        exit 1
    }

    $ip = $config.IPv4Address.IPAddress
    $prefix = $config.IPv4Address.PrefixLength
    $gateway = $config.IPv4DefaultGateway.NextHop
    $dns = @($config.DNSServer.ServerAddresses | Where-Object { $_ -match '^\d' })
    $iface = $config.InterfaceAlias
    $base = Get-NetworkBase -Ip $ip -Prefix $prefix

    $poolStart = "$base.100"
    $poolEnd = "$base.200"

    @{
        success        = $true
        subnet         = "$base.0"
        prefix_length  = $prefix
        gateway        = $gateway
        dns_servers    = $dns
        interface_name = $iface
        current_ip     = $ip
        pool_start     = $poolStart
        pool_end       = $poolEnd
    } | ConvertTo-Json -Compress
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
