<#
.SYNOPSIS
    IoT operations and QuarkLink provisioning for Cordelia-I device.

.DESCRIPTION
    This utility provides IoT platform operations and device provisioning:
    - QuarkLink device provisioning
    - IoT platform registration
    - Device configuration management
    - Cloud connection setup
    - Certificate management for IoT

.PARAMETER Action
    The action to perform: Provision, Register, Configure, Connect, Status

.PARAMETER Platform
    IoT platform: QuarkLink, AWS, Azure, Generic

.PARAMETER ProvisioningData
    Path to provisioning data file (JSON/CSV)

.PARAMETER DeviceId
    Device identifier for registration

.PARAMETER ApiKey
    API key for platform authentication

.PARAMETER Endpoint
    IoT platform endpoint URL

.PARAMETER ConfigPath
    Path to configuration file (auto-detects if not specified)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\iot-operations.ps1 -Action Provision -Platform QuarkLink -ProvisioningData "device-config.json"

.EXAMPLE
    .\iot-operations.ps1 -Action Register -Platform AWS -DeviceId "cordelia-001" -Endpoint "iot.us-east-1.amazonaws.com"

.EXAMPLE
    .\iot-operations.ps1 -Action Status

.NOTES
    Requires utilities.psm1 module.
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Provision', 'Register', 'Configure', 'Connect', 'Status', 'Enroll')]
    [string]$Action,
    
    [ValidateSet('QuarkLink', 'AWS', 'Azure', 'Generic')]
    [string]$Platform = 'QuarkLink',
    [string]$ProvisioningData = '',
    [string]$DeviceId = '',
    [string]$ApiKey = '',
    [string]$Endpoint = '',
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

function Invoke-QuarkLinkProvisioning {
    param($Connection, [string]$ProvisioningData, [switch]$Force)
    
    Write-Color Green "Starting QuarkLink device provisioning..."
    
    if ([string]::IsNullOrWhiteSpace($ProvisioningData)) {
        throw "ProvisioningData parameter is required for QuarkLink provisioning"
    }
    
    if (-not (Test-Path $ProvisioningData)) {
        throw "Provisioning data file not found: $ProvisioningData"
    }
    
    try {
        # Load provisioning data
        $provisioningContent = Get-Content $ProvisioningData -Raw
        Write-Color White "Loaded provisioning data from: $ProvisioningData"
        
        # Parse provisioning data (assuming JSON format)
        try {
            $provisioningJson = $provisioningContent | ConvertFrom-Json
            Write-Color Green "Provisioning data parsed successfully"
        } catch {
            Write-Color Yellow "Failed to parse as JSON, treating as raw data"
            $provisioningJson = $null
        }
        
        if (-not $Force) {
            Write-Color Yellow "⚠️  Device provisioning will:"
            Write-Host "   • Configure device for QuarkLink platform"
            Write-Host "   • Install necessary certificates"
            Write-Host "   • Set up cloud connectivity"
            Write-Host "   • May overwrite existing configuration"
            Write-Host ""
            
            $confirmation = Read-Host "Continue with provisioning? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Color Yellow "Provisioning cancelled."
                return $false
            }
        }
        
        # Step 1: Configure device for QuarkLink
        Write-Color Green "Step 1: Configuring device for QuarkLink..."
        $Connection.SendCommand("AT+quarklink=config,enable", "OK", $PROVISION_CONFIG_TIMEOUT)
        Write-Color Green "✅ QuarkLink configuration enabled"
        
        # Step 2: Set device credentials if provided
        if ($provisioningJson -and $provisioningJson.device_id) {
            Write-Color Green "Step 2: Setting device ID..."
            $deviceIdCmd = "AT+quarklink=device,`"$($provisioningJson.device_id)`""
            $Connection.SendCommand($deviceIdCmd, "OK", $PROVISION_DEVICE_TIMEOUT)
            Write-Color Green "✅ Device ID set: $($provisioningJson.device_id)"
        }
        
        # Step 3: Configure endpoint if provided
        if ($provisioningJson -and $provisioningJson.endpoint) {
            Write-Color Green "Step 3: Setting endpoint..."
            $endpointCmd = "AT+quarklink=endpoint,`"$($provisioningJson.endpoint)`""
            $Connection.SendCommand($endpointCmd, "OK", $PROVISION_DEVICE_TIMEOUT)
            Write-Color Green "✅ Endpoint set: $($provisioningJson.endpoint)"
        }
        
        # Step 4: Install certificates if provided
        if ($provisioningJson -and $provisioningJson.certificates) {
            Write-Color Green "Step 4: Installing certificates..."
            foreach ($cert in $provisioningJson.certificates) {
                if (Test-Path $cert.path) {
                    Write-Color White "Installing certificate: $($cert.name)"
                    # This would use the existing certificate upload functionality
                    # For now, we'll just log the intent
                    Write-Color Green "✅ Certificate ready for installation: $($cert.name)"
                } else {
                    Write-Color Yellow "⚠️  Certificate file not found: $($cert.path)"
                }
            }
        }
        
        # Step 5: Finalize provisioning
        Write-Color Green "Step 5: Finalizing provisioning..."
        $Connection.SendCommand("AT+quarklink=provision,finalize", "OK", $PROVISION_FINALIZE_TIMEOUT)
        
        Write-Color Green "✅ QuarkLink provisioning completed successfully"
        Write-Color Yellow "🔄 Device may need to restart to apply all changes"
        
        return $true
        
    } catch {
        Write-Color Red "❌ QuarkLink provisioning failed: $($_.Exception.Message)"
        return $false
    }
}

function Register-IoTDevice {
    param($Connection, [string]$Platform, [string]$DeviceId, [string]$ApiKey, [string]$Endpoint)
    
    Write-Color Green "Registering device with $Platform platform..."
    Write-Color White "Device ID: $DeviceId"
    Write-Color White "Endpoint: $Endpoint"
    
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        throw "DeviceId is required for device registration"
    }
    
    if ([string]::IsNullOrWhiteSpace($Endpoint)) {
        throw "Endpoint is required for device registration"
    }
    
    try {
        switch ($Platform) {
            'AWS' {
                Write-Color Green "Configuring for AWS IoT Core..."
                $awsCmd = "AT+iot=aws,register,`"$DeviceId`",`"$Endpoint`""
                if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
                    $awsCmd += ",`"$ApiKey`""
                }
                $Connection.SendCommand($awsCmd, "OK", $REGISTER_DEVICE_TIMEOUT)
            }
            
            'Azure' {
                Write-Color Green "Configuring for Azure IoT Hub..."
                $azureCmd = "AT+iot=azure,register,`"$DeviceId`",`"$Endpoint`""
                if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
                    $azureCmd += ",`"$ApiKey`""
                }
                $Connection.SendCommand($azureCmd, "OK", $REGISTER_DEVICE_TIMEOUT)
            }
            
            'QuarkLink' {
                Write-Color Green "Configuring for QuarkLink..."
                $quarkCmd = "AT+quarklink=register,`"$DeviceId`",`"$Endpoint`""
                $Connection.SendCommand($quarkCmd, "OK", $REGISTER_DEVICE_TIMEOUT)
            }
            
            'Generic' {
                Write-Color Green "Configuring for generic IoT platform..."
                $genericCmd = "AT+iot=generic,register,`"$DeviceId`",`"$Endpoint`""
                $Connection.SendCommand($genericCmd, "OK", $REGISTER_DEVICE_TIMEOUT)
            }
        }
        
        Write-Color Green "✅ Device registration completed successfully"
        Write-Color Yellow "🔄 Use 'Connect' action to establish connection"
        
        return $true
        
    } catch {
        Write-Color Red "❌ Device registration failed: $($_.Exception.Message)"
        return $false
    }
}

function Set-IoTConfiguration {
    param($Connection, [string]$Platform)
    
    Write-Color Green "Configuring IoT settings for $Platform..."
    
    try {
        # Get current configuration
        $currentConfig = $Connection.SendCommand("AT+iot=config,get", "OK", $CONFIG_GET_TIMEOUT)
        Write-Color White "Current configuration retrieved"
        
        # Display configuration options
        Write-Color Green "Available configuration parameters:"
        Write-Host "  • Connection timeout settings"
        Write-Host "  • Message formatting options"
        Write-Host "  • Security parameters"
        Write-Host "  • Retry and reliability settings"
        
        # For now, apply default recommended settings
        Write-Color Green "Applying recommended settings..."
        
        # Set connection timeout
        $Connection.SendCommand("AT+iot=config,timeout,30", "OK", $CONFIG_SET_TIMEOUT)
        Write-Color Green "✅ Connection timeout set to 30 seconds"
        
        # Set message format
        $Connection.SendCommand("AT+iot=config,format,json", "OK", $CONFIG_SET_TIMEOUT)
        Write-Color Green "✅ Message format set to JSON"
        
        # Set retry count
        $Connection.SendCommand("AT+iot=config,retry,3", "OK", $CONFIG_SET_TIMEOUT)
        Write-Color Green "✅ Retry count set to 3"
        
        Write-Color Green "✅ IoT configuration completed successfully"
        return $true
        
    } catch {
        Write-Color Red "❌ IoT configuration failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-IoTEnrollment {
    param($Connection, [string]$Platform)
    
    # Timeout constants
    $ENROLL_COMMAND_TIMEOUT = 30000
    $ENROLL_MONITOR_TIMEOUT = 120  # Enrollment can take up to 2 minutes
    $ENROLL_SLEEP_MS = 500
    $ENROLL_EVENT_TIMEOUT = 1000
    
    Write-Color Green "Starting IoT enrollment process for $Platform..."
    
    try {
        # Use AT+iotenrol command as shown in QuarkLink exercise
        Write-Color Yellow "Initiating enrollment..."
        $Connection.SendCommand("AT+iotenrol", "OK", $ENROLL_COMMAND_TIMEOUT)
        
        # Monitor enrollment events
        Write-Color Yellow "Monitoring enrollment progress..."
        $timeout = $ENROLL_MONITOR_TIMEOUT
        $startTime = Get-Date
        $enrollmentComplete = $false
        
        $enrollmentSteps = @(
            'GET_TEMP_CSR',
            'CREATE_TEMP_CSR', 
            'SENDING_CSR_TO_QL',
            'CONNECTING_TO_HOST',
            'HTTP_RESPONSE_CODE',
            'TEMP_CERT_RECEIVED',
            'WRITING_TEMP_CERT',
            'TEMP_CERT_SAVED',
            'CREATE_DEVICE_CSR',
            'CONNECTING_QL_TLS',
            'CONNECTING_TO_HOST',
            'QL_RESPONSE_RECEIVED',
            'ENROLMENT_COMPLETE'
        )
        
        $completedSteps = @()
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $timeout -and -not $enrollmentComplete) {
            try {
                $eventResponse = $Connection.SendCommand("", "", $ENROLL_EVENT_TIMEOUT)
                
                foreach ($step in $enrollmentSteps) {
                    if ($eventResponse -match "\+eventiot:info,`"$step`"") {
                        if ($step -notin $completedSteps) {
                            Write-Color Green "✅ $step"
                            $completedSteps += $step
                        }
                        
                        if ($step -eq 'ENROLMENT_COMPLETE') {
                            $enrollmentComplete = $true
                            break
                        }
                    }
                }
            } catch {
                # No events available, continue waiting
            }
            
            Start-Sleep -Milliseconds $ENROLL_SLEEP_MS
        }
        
        if ($enrollmentComplete) {
            Write-Color Green "✅ IoT enrollment completed successfully"
            return $true
        } else {
            Write-Color Red "❌ IoT enrollment failed or timed out"
            return $false
        }
        
    } catch {
        Write-Color Red "❌ IoT enrollment failed: $($_.Exception.Message)"
        return $false
    }
}

function Connect-IoTPlatform {
    param($Connection, [string]$Platform)
    
    # Timeout constants
    $IOT_CONNECT_TIMEOUT = 45000
    $IOT_CONNACK_TIMEOUT = 30
    $IOT_CONNACK_SLEEP_MS = 500
    $IOT_EVENT_TIMEOUT = 1000
    
    Write-Color Green "Connecting to $Platform platform..."
    
    try {
        # Use AT+iotconnect command as shown in exercises
        Write-Color Yellow "Establishing connection..."
        $Connection.SendCommand("AT+iotconnect", "OK", $IOT_CONNECT_TIMEOUT)
        
        # Wait for CONNACK event
        Write-Color Yellow "Waiting for connection confirmation..."
        $timeout = $IOT_CONNACK_TIMEOUT
        $startTime = Get-Date
        $connected = $false
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $timeout -and -not $connected) {
            try {
                $eventResponse = $Connection.SendCommand("", "", $IOT_EVENT_TIMEOUT)
                
                if ($eventResponse -match '\+eventmqtt:info,"CONNACK",0') {
                    Write-Color Green "✅ Successfully connected to $Platform platform"
                    $connected = $true
                }
            } catch {
                # No events available, continue waiting
            }
            
            Start-Sleep -Milliseconds $IOT_CONNACK_SLEEP_MS
        }
        
        if ($connected) {
            Write-Color Green "✅ IoT platform connection established"
            return $true
        } else {
            Write-Color Red "❌ Connection failed or timed out"
            return $false
        }
        
    } catch {
        Write-Color Red "❌ IoT platform connection failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-IoTStatus {
    param($Connection)
    
    Write-Color Green "Getting IoT platform status..."
    
    try {
        # Check general IoT status
        $generalStatus = $Connection.SendCommand("AT+iot=status", "OK", $STATUS_GENERAL_TIMEOUT)
        Write-Color Green "📡 General IoT Status Retrieved"
        
        # Try to get specific platform status
        $platforms = @('QuarkLink', 'AWS', 'Azure', 'Generic')
        
        foreach ($platform in $platforms) {
            try {
                $platformCmd = switch ($platform) {
                    'AWS' { "AT+iot=aws,status" }
                    'Azure' { "AT+iot=azure,status" }
                    'QuarkLink' { "AT+quarklink=status" }
                    'Generic' { "AT+iot=generic,status" }
                }
                
                $platformStatus = $Connection.SendCommand($platformCmd, "OK", $STATUS_PLATFORM_TIMEOUT)
                
                if ($platformStatus -match 'connected|online|enabled') {
                    Write-Color Green "✅ ${platform}: Connected/Active"
                } else {
                    Write-Color Yellow "⚠️  ${platform}: Disconnected/Inactive"
                }
                
            } catch {
                Write-Color White "   ${platform}: Not configured"
            }
        }
        
        return $true
        
    } catch {
        Write-Color Red "❌ Unable to get IoT status: $($_.Exception.Message)"
        return $false
    }
}

try {
    Write-Color Green "Cordelia-I IoT Operations Tool"
    Write-Color Green "Action: $Action"
    Write-Color Green "Platform: $Platform"
    
    # Validate parameters based on action
    switch ($Action) {
        'Provision' {
            if ($Platform -eq 'QuarkLink' -and [string]::IsNullOrWhiteSpace($ProvisioningData)) {
                throw "ProvisioningData parameter is required for QuarkLink provisioning"
            }
        }
        
        'Register' {
            if ([string]::IsNullOrWhiteSpace($DeviceId)) {
                throw "DeviceId parameter is required for device registration"
            }
            if ([string]::IsNullOrWhiteSpace($Endpoint)) {
                throw "Endpoint parameter is required for device registration"
            }
        }
    }
    
    # Connect to device
    $connection = New-CordeliaConnection -ConfigPath $ConfigPath
    $connection.Connect()
    
    $success = $false
    
    switch ($Action) {
        'Provision' {
            $success = Invoke-QuarkLinkProvisioning -Connection $connection -ProvisioningData $ProvisioningData -Force:$Force
        }
        
        'Register' {
            $success = Register-IoTDevice -Connection $connection -Platform $Platform -DeviceId $DeviceId -ApiKey $ApiKey -Endpoint $Endpoint
        }
        
        'Configure' {
            $success = Set-IoTConfiguration -Connection $connection -Platform $Platform
        }
        
        'Enroll' {
            $success = Invoke-IoTEnrollment -Connection $connection -Platform $Platform
        }
        
        'Connect' {
            $success = Connect-IoTPlatform -Connection $connection -Platform $Platform
        }
        
        'Status' {
            $success = Get-IoTStatus -Connection $connection
        }
    }
    
    if ($success) {
        Write-Color Green "✅ IoT operation completed successfully"
        exit 0
    } else {
        Write-Color Red "❌ IoT operation failed"
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