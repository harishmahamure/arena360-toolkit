#Requires -Version 5.1
param([string]$ConfigJson = '{}')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_Common.ps1')

$config = Get-Config -Json $ConfigJson
$devices = @($config['devices'])
$username = $config['username']
$password = $config['password']

try {
    $classified = @()

    foreach ($device in $devices) {
        $ip = $device.ip_address
        $deviceType = 'other'
        $connectionType = 'unknown'
        $winrmEnabled = $false
        $adapterName = ''

        # Port checks
        $ports = @{ 445 = $false; 3389 = $false; 5985 = $false }
        foreach ($port in $ports.Keys) {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $async = $tcp.BeginConnect($ip, $port, $null, $null)
                $wait = $async.AsyncWaitHandle.WaitOne(500, $false)
                if ($wait -and $tcp.Connected) {
                    $ports[$port] = $true
                }
                $tcp.Close()
            }
            catch { }
        }

        if ($ports[445]) { $deviceType = 'windows' }
        if ($ports[5985]) { $winrmEnabled = $true }

        if ($username -and $password -and $deviceType -eq 'windows') {
            try {
                $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential($username, $secPassword)
                $null = Test-WSMan -ComputerName $ip -Credential $cred -ErrorAction Stop
                $winrmEnabled = $true
            }
            catch { }
        }
        elseif ($deviceType -eq 'windows') {
            try {
                $null = Test-WSMan -ComputerName $ip -ErrorAction Stop
                $winrmEnabled = $true
            }
            catch { }
        }

        # Guess connection from hostname patterns or default wired for Windows gaming PCs
        if ($deviceType -eq 'windows') {
            $connectionType = 'wired'
        }

        $classified += @{
            ip_address       = $ip
            mac_address      = $device.mac_address
            hostname         = $device.hostname
            device_type      = $deviceType
            connection_type  = $connectionType
            is_reachable     = $true
            winrm_enabled    = $winrmEnabled
            adapter_name     = $adapterName
            ports_open       = @($ports.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key })
        }
    }

    Write-Result -Success $true -Data @{ devices = $classified }
}
catch {
    Write-Result -Success $false -Message $_.Exception.Message
    exit 1
}
