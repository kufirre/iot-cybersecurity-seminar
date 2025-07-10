<#
.SYNOPSIS
    System management operations for Cordelia-I device (reboot, factory reset).

.DESCRIPTION
    This utility provides system maintenance operations:
    - Device reboot (software reset)
    - Factory reset (restores file system and NWP configuration)

.PARAMETER Action
    The action to perform: Reboot, FactoryReset

.PARAMETER ConfigPath
    Path to configuration file (auto-detects if not specified)

.PARAMETER Force
    Skip confirmation prompts for destructive operations

.EXAMPLE
    .\system-management.ps1 -Action Reboot

.EXAMPLE
    .\system-management.ps1 -Action FactoryReset -Force

.NOTES
    Requires utilities.psm1 module.
    Factory reset takes up to 90 seconds - DO NOT power cycle during this time!
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Reboot', 'FactoryReset')]
    [string]$Action,
    
    [string]$ConfigPath = '',
    [switch]$Force
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

function Invoke-DeviceReboot {
    param($Connection)
    
    Write-Color Green "Initiating device reboot..."
    Write-Color Yellow "The device will perform a software reset and restart."
    
    try {
        $Connection.SendCommand("AT+reboot", "OK", 10000)
        Write-Color Green "✅ Reboot command sent successfully"
        Write-Color Yellow "⏳ Device is rebooting... Please wait for reconnection."
        return $true
    } catch {
        Write-Color Red "❌ Reboot failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-FactoryReset {
    param($Connection, [switch]$Force)
    
    if (-not $Force) {
        Write-Color Yellow "⚠️  WARNING: FACTORY RESET WILL:"
        Write-Host "   • Erase ALL files on the device"
        Write-Host "   • Reset ALL network configurations"
        Write-Host "   • Restore device to factory defaults"
        Write-Host "   • Take up to 90 seconds to complete"
        Write-Host ""
        Write-Color Yellow "⚠️  CRITICAL: DO NOT power cycle during the 90-second reset window!"
        Write-Color Yellow "   Interrupting factory reset may cause permanent damage!"
        Write-Host ""
        
        $confirmation = Read-Host "Type 'FACTORY RESET' to confirm this destructive operation"
        if ($confirmation -ne 'FACTORY RESET') {
            Write-Color Yellow "Factory reset cancelled."
            return $false
        }
    }
    
    Write-Color Green "Initiating factory reset..."
    Write-Color Yellow "⏳ This will take up to 90 seconds. Please wait..."
    
    try {
        # Factory reset can take up to 90 seconds
        $Connection.SendCommand("AT+factoryreset", "OK", 95000)
        Write-Color Green "✅ Factory reset completed successfully"
        Write-Color Green "🔄 Device has been restored to factory defaults"
        return $true
    } catch {
        if ($_.Exception.Message -match "Timeout") {
            Write-Color Yellow "⏳ Factory reset is still in progress..."
            Write-Color Yellow "Please wait for the device startup banner to appear."
            return $true
        } else {
            Write-Color Red "❌ Factory reset failed: $($_.Exception.Message)"
            return $false
        }
    }
}

try {
    Write-Color Green "Cordelia-I System Management Tool"
    Write-Color Green "Action: $Action"
    
    # Connect to device
    $connection = New-CordeliaConnection -ConfigPath $ConfigPath
    $connection.Connect()
    
    switch ($Action) {
        'Reboot' {
            $success = Invoke-DeviceReboot -Connection $connection
        }
        
        'FactoryReset' {
            $success = Invoke-FactoryReset -Connection $connection -Force:$Force
        }
    }
    
    if ($success) {
        Write-Color Green "✅ System operation completed successfully"
        exit 0
    } else {
        Write-Color Red "❌ System operation failed"
        exit 1
    }
    
} catch {
    Write-Color Red "Error: $($_.Exception.Message)"
    exit 1
} finally {
    if ($connection) {
        # Don't try to disconnect gracefully after reboot/factory reset
        if ($Action -eq 'Reboot' -or $Action -eq 'FactoryReset') {
            $connection.Port.Dispose()
        } else {
            $connection.Dispose()
        }
    }
}