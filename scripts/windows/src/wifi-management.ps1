<#
.SYNOPSIS
    Wi-Fi management operations for Cordelia-I device.

.DESCRIPTION
    This utility provides Wi-Fi connectivity management:
    - Scan for available access points
    - Connect to Wi-Fi networks
    - Disconnect from current network
    - Show connection status

.PARAMETER Action
    The action to perform: Scan, Connect, Disconnect, Status

.PARAMETER SSID
    Network SSID for connect operations

.PARAMETER SecurityType
    Security type: OPEN, WEP, WEP_SHARED, WPA_WPA2, WPA_ENT, WPS_PBC, WPS_PIN, WPA2_PLUS, WPA3

.PARAMETER SecurityKey
    Network password/key for secured connections

.PARAMETER ConfigPath
    Path to configuration file (auto-detects if not specified)

.EXAMPLE
    .\wifi-management.ps1 -Action Scan

.EXAMPLE
    .\wifi-management.ps1 -Action Connect -SSID "MyNetwork" -SecurityType WPA_WPA2 -SecurityKey "mypassword"

.EXAMPLE
    .\wifi-management.ps1 -Action Disconnect

.NOTES
    Requires utilities.psm1 module.
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Scan', 'Connect', 'Disconnect', 'Status', 'ScanAndConnect')]
    [string]$Action,
    
    [string]$SSID = '',
    [ValidateSet('OPEN', 'WEP', 'WEP_SHARED', 'WPA_WPA2', 'WPA_ENT', 'WPS_PBC', 'WPS_PIN', 'WPA2_PLUS', 'WPA3')]
    [string]$SecurityType = 'WPA_WPA2',
    [string]$SecurityKey = '',
    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'

# Find config file
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $configCandidates = @(
        (Join-Path $PSScriptRoot '..\..\common\config.ini'),
        (Join-Path $PSScriptRoot '..\common\config.ini'),
        (Join-Path $PSScriptRoot 'config.ini'),
        (Join-Path $PSScriptRoot '..\config.ini')
    )
    $ConfigPath = $configCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $ConfigPath) {
        throw "Could not find config.ini"
    }
}

function Invoke-WifiScan {
    param($Connection)
    
    # Timeout constants
    $SCAN_TIMEOUT_INITIAL = 10000
    $SCAN_TIMEOUT_RESULTS = 15000
    $SCAN_WAIT_SECONDS = 2
    
    Write-Color Green "Scanning for Wi-Fi networks..."
    
    try {
        # First scan call typically returns EAGAIN error
        try {
            $Connection.SendCommand("AT+wlanScan=0,30", "OK", $SCAN_TIMEOUT_INITIAL)
        } catch {
            # Extract error code from exception message and use lookup table
            if ($_.Exception.Message -match "\((-?\d+)\):") {
                $errorCode = [int]$matches[1]
                $errorMessage = Get-ErrorMessage -ErrorCode $errorCode
                
                # Check if this is the expected "resource temporarily unavailable" error
                if ($errorCode -eq -2073) {
                    Write-Color Green "Initial scan started, retrieving results..."
                } else {
                    Write-Color Red "🔍 Scan error: ($errorCode): $errorMessage"
                    throw
                }
            } elseif ($_.Exception.Message -match "EAGAIN") {
                # Fallback for legacy text matching
                Write-Color Green "Initial scan started, retrieving results..."
            } else {
                Write-Color Red "🔍 Scan error: $($_.Exception.Message)"
                throw
            }
        }
        
        # Wait a moment for scan to complete
        Write-Color Green "Waiting for scan to complete..."
        Start-Sleep -Seconds $SCAN_WAIT_SECONDS
        
        # Second call to get results
        $response = $Connection.SendCommand("AT+wlanScan=0,30", "OK", $SCAN_TIMEOUT_RESULTS)
        
        Write-Color Green "🔍 Scan response received: $($response.Length) characters"
        
        # Parse scan results
        $networks = @()
        $lines = $response -split "`r?`n"
        
        foreach ($line in $lines) {
            if ($line -match '^\+wlanscan:(.+)') {
                $networkData = $matches[1].Split(',')
                if ($networkData.Count -ge 8) {
                    $networks += [PSCustomObject]@{
                        SSID = $networkData[0].Trim('"')
                        BSSID = $networkData[1]
                        RSSI = [int]$networkData[2]
                        Channel = [int]$networkData[3]
                        Security = $networkData[4]
                        Hidden = $networkData[5]
                        Cipher = $networkData[6]
                        KeyMgmt = $networkData[7]
                    }
                }
            }
        }
        
        if ($networks.Count -eq 0) {
            Write-Color Green "No Wi-Fi networks found."
        } else {
            Write-Color Green "`nFound $($networks.Count) Wi-Fi networks:"
            Write-Host ""
            Write-Host "SSID".PadRight(32) + "Security".PadRight(15) + "RSSI".PadRight(8) + "Channel".PadRight(10) + "BSSID"
            Write-Host ("-" * 80)
            
            foreach ($network in $networks | Sort-Object RSSI -Descending) {
                # $signalStrength = if ($network.RSSI -gt -50) { "Excellent" } 
                #                  elseif ($network.RSSI -gt -60) { "Good" }
                #                  elseif ($network.RSSI -gt -70) { "Fair" }
                #                  else { "Weak" }
                
                Write-Host "$($network.SSID.PadRight(32))$($network.Security.PadRight(15))$("$($network.RSSI) dBm".PadRight(8))$($network.Channel.ToString().PadRight(10))$($network.BSSID)"
            }
        }
        
        return $networks
        
    } catch {
        Write-Color Red "❌ Wi-Fi scan failed: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-WifiConnect {
    param($Connection, [string]$SSID, [string]$SecurityType, [string]$SecurityKey)
    
    # Timeout constants
    $CONNECT_TIMEOUT_COMMAND = 30000
    $CONNECT_TIMEOUT_EVENTS = 30
    $CONNECT_SLEEP_MS = 500
    $CONNECT_PROGRESS_INTERVAL = 5
    
    if ([string]::IsNullOrWhiteSpace($SSID)) {
        throw "SSID is required for connection"
    }
    
    Write-Color Green "Connecting to Wi-Fi network: $SSID"
    Write-Color Green "Security Type: $SecurityType"
    if (-not [string]::IsNullOrWhiteSpace($SecurityKey)) {
        Write-Color Green "Password: $('*' * $SecurityKey.Length)"
    }
    
    try {
        # Build connect command based on exercise format: AT+wlanconnect=SSID,,SecurityType,Password,,,
        # Note: Using lowercase 'wlanconnect' as shown in exercises
        $connectCmd = "AT+wlanconnect=$SSID,,$SecurityType"
        
        if ($SecurityType -ne 'OPEN' -and -not [string]::IsNullOrWhiteSpace($SecurityKey)) {
            $connectCmd += ",$SecurityKey"
        } else {
            $connectCmd += ","
        }
        
        # Add empty parameters for enterprise settings (ExtUser, ExtAnonUser, ExtEapMethod)
        $connectCmd += ",,,"
        
        Write-Color Green "Attempting connection..."
        $Connection.SendCommand($connectCmd, "OK", $CONNECT_TIMEOUT_COMMAND)
        
        Write-Color Green "✅ Connection command sent successfully"
        
        # Wait for connection events
        Write-Color Green "Waiting for connection confirmation..."
        Write-Color Green "🔍 Monitoring for events: +eventwlan:connect and +eventnetapp:ipv4_acquired"
        
        # Monitor for connection events for up to 30 seconds
        $timeout = $CONNECT_TIMEOUT_EVENTS
        $startTime = Get-Date
        $connected = $false
        $ipAcquired = $false
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $timeout -and (-not $connected -or -not $ipAcquired)) {
            try {
                # Try to read any pending events from the device
                # Using a very short timeout to avoid blocking
                $eventResponse = $Connection.Port.ReadLine()
                
                if (-not [string]::IsNullOrWhiteSpace($eventResponse)) {
                    Write-Color Green "🔍 Event received: $eventResponse"
                    
                    # Check for connection event
                    if ($eventResponse -match '\+eventwlan:connect') {
                        Write-Color Green "✅ Wi-Fi connection established"
                        $connected = $true
                    }
                    
                    # Check for IP acquisition event
                    if ($eventResponse -match '\+eventnetapp:ipv4_acquired,([^,]+),([^,]+),([^,]+)') {
                        $ipAddress = $matches[1]
                        $gateway = $matches[2]
                        $dns = $matches[3]
                        Write-Color Green "✅ IP address acquired: $ipAddress"
                        Write-Color Green "   Gateway: $gateway"
                        Write-Color Green "   DNS: $dns"
                        $ipAcquired = $true
                    }
                }
            } catch {
                # No events available, continue waiting
                # This is expected when no events are pending
            }
            
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -gt 0 -and ($elapsed % $CONNECT_PROGRESS_INTERVAL) -eq 0) {
                $remaining = [int]($timeout - $elapsed)
                Write-Color Green "⏱️  Still waiting for connection... ($remaining seconds remaining)"
            }
            
            Start-Sleep -Milliseconds $CONNECT_SLEEP_MS
        }
        
        if ($connected -and $ipAcquired) {
            return $true
        } elseif ($connected) {
            Write-Color Green "⚠️  Connected to Wi-Fi but no IP address acquired yet"
            return $true
        } else {
            Write-Color Red "❌ Wi-Fi connection failed or timed out"
            return $false
        }
        
    } catch {
        Write-Color Red "❌ Wi-Fi connection failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-WifiDisconnect {
    param($Connection)
    
    # Timeout constants
    $DISCONNECT_TIMEOUT = 10000
    
    Write-Color Green "Disconnecting from Wi-Fi network..."
    
    try {
        $Connection.SendCommand("AT+wlanDisconnect", "OK", $DISCONNECT_TIMEOUT)
        Write-Color Green "✅ Wi-Fi disconnection successful"
        return $true
        
    } catch {
        Write-Color Red "🔍 Disconnect error: $($_.Exception.Message)"
        Write-Color Red "❌ Wi-Fi disconnection failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-ScanAndConnect {
    param($Connection)
    
    Write-Color Green "Scanning for available networks..."
    
    # First perform a scan
    $networks = Invoke-WifiScan -Connection $Connection
    
    if ($networks.Count -eq 0) {
        Write-Color Red "❌ No networks found. Cannot proceed with connection."
        return $false
    }
    
    # Display numbered list of networks
    Write-Host "`nAvailable Networks:"
    Write-Host "══════════════════════════════════════════════════════════════════"
    
    for ($i = 0; $i -lt $networks.Count; $i++) {
        $network = $networks[$i]
        $signalStrength = if ($network.RSSI -gt -50) { "Excellent" } 
                         elseif ($network.RSSI -gt -60) { "Good" }
                         elseif ($network.RSSI -gt -70) { "Fair" }
                         else { "Weak" }
        
        $securityDisplay = if ($network.Security -eq 'OPEN') { "Open" } else { "Secured ($($network.Security))" }
        
        Write-Host "  $($i + 1). $($network.SSID.PadRight(25)) | $($signalStrength.PadRight(10)) | $securityDisplay"
    }
    
    Write-Host "══════════════════════════════════════════════════════════════════"
    
    # Get user selection
    do {
        Write-Host "`nEnter network number (1-$($networks.Count)) or 0 to cancel: " -NoNewline
        $selection = Read-Host
        
        if ($selection -eq '0') {
            Write-Color Yellow "Connection cancelled."
            return $false
        }
        
        $networkIndex = [int]$selection - 1
        
        if ($networkIndex -ge 0 -and $networkIndex -lt $networks.Count) {
            $selectedNetwork = $networks[$networkIndex]
            break
        } else {
            Write-Color Red "Invalid selection. Please try again."
        }
    } while ($true)
    
    # Display selected network
    Write-Color Green "`nSelected Network: $($selectedNetwork.SSID)"
    Write-Color Green "Security: $($selectedNetwork.Security)"
    Write-Color Green "Signal Strength: $($selectedNetwork.RSSI) dBm"
    
    # Get password if needed
    $password = ""
    if ($selectedNetwork.Security -ne 'OPEN') {
        Write-Host "`nEnter password for $($selectedNetwork.SSID): " -NoNewline
        $password = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($password)) {
            Write-Color Red "Password is required for secured networks."
            return $false
        }
    }
    
    # Map security type from scan result to connection format
    $connectionSecurityType = switch ($selectedNetwork.Security) {
        'WPA_WPA2' { 'WPA_WPA2' }
        'WPA2' { 'WPA_WPA2' }
        'WPA' { 'WPA_WPA2' }
        'WEP' { 'WEP' }
        'OPEN' { 'OPEN' }
        'NONE' { 'OPEN' }
        default { 'WPA_WPA2' }  # Default to most common type
    }
    
    Write-Color Green "🔍 Security type mapping: $($selectedNetwork.Security) -> $connectionSecurityType"
    
    # Attempt connection
    Write-Color Green "`nAttempting to connect to $($selectedNetwork.SSID)..."
    return Invoke-WifiConnect -Connection $Connection -SSID $selectedNetwork.SSID -SecurityType $connectionSecurityType -SecurityKey $password
}

function Set-CountryCode {
    param($Connection, [string]$CountryCode = 'EU')
    
    # Timeout constants
    $COUNTRY_CODE_TIMEOUT = 5000
    
    Write-Color Green "Setting country code to: $CountryCode"
    
    try {
        $countryCmd = "AT+wlanSet=general,country_code,$CountryCode"
        $Connection.SendCommand($countryCmd, "OK", $COUNTRY_CODE_TIMEOUT)
        Write-Color Green "✅ Country code set successfully"
        return $true
    } catch {
        Write-Color Red "🔍 Country code error: $($_.Exception.Message)"
        Write-Color Red "❌ Failed to set country code: $($_.Exception.Message)"
        return $false
    }
}

function Get-WifiStatus {
    param($Connection)
    
    # Timeout constants
    $STATUS_TIMEOUT = 5000
    
    Write-Color Green "Getting Wi-Fi connection status..."
    
    $wifiStatus = @{
        Connected = $false
        SSID = ""
        IPAddress = ""
        Gateway = ""
        DNS = ""
        SignalStrength = ""
    }
    
    try {
        # Check Wi-Fi connection status
        Write-Color Green "Checking Wi-Fi connection state..."
        try {
            $response = $Connection.SendCommand("AT+get=wlan,ssid", "OK", $STATUS_TIMEOUT)
            if ($response -match '\+get:(.+)' -and -not [string]::IsNullOrWhiteSpace($matches[1].Trim())) {
                $wifiStatus.SSID = $matches[1].Trim().Trim('"')
                $wifiStatus.Connected = $true
                Write-Color Green "📡 Connected to Wi-Fi network: $($wifiStatus.SSID)"
            }
        } catch {
            # Try alternative command for SSID
            try {
                $response = $Connection.SendCommand("AT+get=netapp,ssid", "OK", $STATUS_TIMEOUT)
                if ($response -match '\+get:(.+)' -and -not [string]::IsNullOrWhiteSpace($matches[1].Trim())) {
                    $wifiStatus.SSID = $matches[1].Trim().Trim('"')
                    $wifiStatus.Connected = $true
                    Write-Color Green "📡 Connected to Wi-Fi network: $($wifiStatus.SSID)"
                }
            } catch {
                Write-Color Yellow "⚠️  Could not retrieve current SSID"
            }
        }
        
        # Get IP configuration if connected
        if ($wifiStatus.Connected) {
            Write-Color Green "Getting IP configuration..."
            try {
                $response = $Connection.SendCommand("AT+get=netapp,ipv4", "OK", $STATUS_TIMEOUT)
                # Expected format: +get:ip,gateway,dns or similar
                if ($response -match '\+get:([^,]+),([^,]+),(.+)') {
                    $wifiStatus.IPAddress = $matches[1].Trim()
                    $wifiStatus.Gateway = $matches[2].Trim()
                    $wifiStatus.DNS = $matches[3].Trim()
                    Write-Color Green "🌐 IP Address: $($wifiStatus.IPAddress)"
                    Write-Color Green "   Gateway: $($wifiStatus.Gateway)"
                    Write-Color Green "   DNS: $($wifiStatus.DNS)"
                } elseif ($response -match '\+get:(.+)') {
                    $wifiStatus.IPAddress = $matches[1].Trim()
                    Write-Color Green "🌐 IP Address: $($wifiStatus.IPAddress)"
                }
            } catch {
                Write-Color Yellow "⚠️  Could not retrieve IP configuration"
            }
            
            # Try to get signal strength
            try {
                $response = $Connection.SendCommand("AT+get=wlan,rssi", "OK", $STATUS_TIMEOUT)
                if ($response -match '\+get:(.+)') {
                    $wifiStatus.SignalStrength = $matches[1].Trim()
                    Write-Color Green "📶 Signal Strength: $($wifiStatus.SignalStrength) dBm"
                }
            } catch {
                # Signal strength might not be available
            }
        } else {
            Write-Color Red "❌ Wi-Fi is not connected to any network"
            # Check if device is responding (fallback check)
            try {
                $Connection.SendCommand("AT+get=general,version", "OK", $STATUS_TIMEOUT)
                Write-Color Green "✅ Device is responding to commands"
            } catch {
                Write-Color Red "❌ Device is not responding to commands"
                return $false
            }
        }
        
        return $wifiStatus.Connected
        
    } catch {
        Write-Color Red "❌ Unable to get Wi-Fi status: $($_.Exception.Message)"
        return $false
    }
}

try {
    Write-Color Green "Cordelia-I Wi-Fi Management Tool"
    Write-Color Green "Action: $Action"
    
    # Validate parameters for connect action
    if ($Action -eq 'Connect') {
        if ([string]::IsNullOrWhiteSpace($SSID)) {
            throw "SSID parameter is required for Connect action"
        }
        if ($SecurityType -ne 'OPEN' -and [string]::IsNullOrWhiteSpace($SecurityKey)) {
            throw "SecurityKey parameter is required for secured networks"
        }
    }
    
    # Connect to device
    Write-Color Green "🔍 Initializing connection to device..."
    $connection = New-CordeliaConnection -ConfigPath $ConfigPath
    $connection.Connect()
    Write-Color Green "✅ Device connection established"
    
    # Set country code for Wi-Fi operations (required after reboot)
    Write-Color Green "🔍 Setting country code for Wi-Fi compliance..."
    $null = Set-CountryCode -Connection $connection -CountryCode 'EU'
    
    $success = $false
    
    switch ($Action) {
        'Scan' {
            $networks = Invoke-WifiScan -Connection $connection
            $success = $networks.Count -ge 0
        }
        
        'Connect' {
            $success = Invoke-WifiConnect -Connection $connection -SSID $SSID -SecurityType $SecurityType -SecurityKey $SecurityKey
        }
        
        'ScanAndConnect' {
            $success = Invoke-ScanAndConnect -Connection $connection
        }
        
        'Disconnect' {
            $success = Invoke-WifiDisconnect -Connection $connection
        }
        
        'Status' {
            $success = Get-WifiStatus -Connection $connection
        }
    }
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
    
} catch {
    Write-Color Red "Error: $($_.Exception.Message)"
    exit 1
} finally {
    if ($connection) {
        $connection.Dispose()
    }
}