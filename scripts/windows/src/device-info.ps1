<#
.SYNOPSIS
    Get comprehensive information about a connected Cordelia-I device.

.DESCRIPTION
    This utility connects to a Cordelia-I module and retrieves detailed device information
    including firmware versions, device ID, current settings, and file listings.

.PARAMETER ConfigPath
    Path to configuration file. Auto-detects if not specified.

.PARAMETER OutputFile
    Save device information to a file (JSON format).

.PARAMETER ShowFiles
    Include file system listing in the output.

.EXAMPLE
    .\device-info.ps1

.EXAMPLE
    .\device-info.ps1 -OutputFile "device-report.json" -ShowFiles

.NOTES
    Requires utilities.psm1 module.
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [string]$ConfigPath = '',
    [string]$OutputFile = '',
    [switch]$ShowFiles
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

function Get-CordeliaDeviceInfo {
    param([CordeliaUartConnection]$Connection)
    
    $info = @{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Device = @{}
        UART = @{}
        Network = @{}
    }
    
    try {
        # Get version information
        Write-Color Green "Getting device version information..."
        $response = $Connection.SendCommand("AT+get=general,version", "OK", 5000)
        if ($response -match '\+get:([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),(.+)') {
            $info.Device.ChipID = $matches[1].Trim()
            $info.Device.MACVersion = $matches[2].Trim()
            $info.Device.PHYVersion = $matches[3].Trim()
            $info.Device.NWPVersion = $matches[4].Trim()
            $info.Device.ROMVersion = $matches[5].Trim()
            $info.Device.FirmwareVersion = $matches[6].Trim()
        }
        
        # Get device ID
        Write-Color Green "Getting device ID..."
        $response = $Connection.SendCommand("AT+get=iot,deviceid", "OK", 5000)
        if ($response -match '\+get:(.+)') {
            $info.Device.DeviceID = $matches[1].Trim()
        }
        
        # Get UART settings
        Write-Color Green "Getting UART configuration..."
        $uartSettings = @('baudrate', 'parity', 'flowcontrol')
        foreach ($setting in $uartSettings) {
            try {
                $response = $Connection.SendCommand("AT+get=uart,$setting", "OK", 3000)
                if ($response -match '\+get:(.+)') {
                    $info.UART[$setting] = $matches[1].Trim()
                }
            } catch {
                $info.UART[$setting] = "Error: $($_.Exception.Message)"
            }
        }
        
    } catch {
        Write-Warning "Could not retrieve all device information: $($_.Exception.Message)"
    }
    
    return $info
}

function Get-CordeliaFileList {
    param([CordeliaUartConnection]$Connection)
    
    Write-Color Green "Getting file system listing..."
    try {
        $response = $Connection.SendCommand("AT+fileGetFileList", "OK", 10000)
        $files = @()
        
        $lines = $response -split "`r?`n"
        foreach ($line in $lines) {
            if ($line -match '\+FileGetFileList:\[([^\]]+)\],\[(\d+)\],\[([^\]]+)\],\[(\d+)\]') {
                $files += @{
                    Name = $matches[1]
                    MaxSize = [int]$matches[2]
                    Properties = $matches[3] -split ','
                    BlocksAllocated = [int]$matches[4]
                }
            }
        }
        
        return $files
    } catch {
        Write-Warning "Could not retrieve file list: $($_.Exception.Message)"
        return @()
    }
}

try {
    Write-Color Green "Cordelia-I Device Information Tool"
    Write-Color Green "Using configuration: $ConfigPath"

    # Connect to device
    $connection = New-CordeliaConnection -ConfigPath $ConfigPath
    $connection.Connect()

    # Get device information
    $deviceInfo = Get-CordeliaDeviceInfo -Connection $connection

    # Get file listing if requested
    if ($ShowFiles) {
        $deviceInfo.Files = Get-CordeliaFileList -Connection $connection
    }

    # Display information
    Write-Color Green "`n=== DEVICE INFORMATION ==="
    Write-Host "Chip ID:          $($deviceInfo.Device.ChipID)"
    Write-Host "Firmware Version: $($deviceInfo.Device.FirmwareVersion)"
    Write-Host "MAC Version:      $($deviceInfo.Device.MACVersion)"
    Write-Host "PHY Version:      $($deviceInfo.Device.PHYVersion)"
    Write-Host "NWP Version:      $($deviceInfo.Device.NWPVersion)"
    Write-Host "Device ID:        $($deviceInfo.Device.DeviceID)"

    Write-Color Green "`n=== UART SETTINGS ==="
    foreach ($key in $deviceInfo.UART.Keys) {
        Write-Host "$($key.PadRight(12)): $($deviceInfo.UART[$key])"
    }

    if ($ShowFiles -and $deviceInfo.Files) {
        Write-Color Green "`n=== FILE SYSTEM ==="
        Write-Host "Files on device: $($deviceInfo.Files.Count)"
        foreach ($file in $deviceInfo.Files) {
            Write-Host "  $($file.Name.PadRight(30)) $($file.MaxSize.ToString().PadLeft(8)) bytes"
        }
    }

    # Save to file if requested
    if ($OutputFile) {
        $deviceInfo | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Color Green "`nDevice information saved to: $OutputFile"
    }

} catch {
    Write-Color Red "Error: $($_.Exception.Message)"
    exit 1
} finally {
    if ($connection) {
        $connection.Dispose()
    }
}
