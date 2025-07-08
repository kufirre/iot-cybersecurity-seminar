<#
.SYNOPSIS
    Validate and test Cordelia-I configuration files and connections.

.DESCRIPTION
    This utility validates configuration files, tests serial port connectivity,
    and can generate template configuration files. It helps troubleshoot
    connection issues and ensures proper setup.

.PARAMETER ConfigPath
    Path to configuration file to validate. Auto-detects if not specified.

.PARAMETER TestConnection
    Test actual connection to the device (requires device to be connected).

.PARAMETER CreateTemplate
    Create a template configuration file.

.PARAMETER TemplateFile
    Output path for template file (default: config-template.ini).

.PARAMETER ListPorts
    List available COM ports on the system.

.PARAMETER ViewConfig
    Display current configuration settings with detailed formatting.

.EXAMPLE
    .\config-validator.ps1

.EXAMPLE
    .\config-validator.ps1 -TestConnection

.EXAMPLE
    .\config-validator.ps1 -ViewConfig

.EXAMPLE
    .\config-validator.ps1 -CreateTemplate -TemplateFile "my-config.ini"

.EXAMPLE
    .\config-validator.ps1 -ListPorts

.NOTES
    Requires utilities.psm1 module.
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [string]$ConfigPath = '',
    [switch]$TestConnection,
    [switch]$CreateTemplate,
    [string]$TemplateFile = 'config-template.ini',
    [switch]$ListPorts,
    [switch]$ViewConfig
)

$ErrorActionPreference = 'Stop'

function Get-AvailablePorts {
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
        return $ports
    } catch {
        Write-Warning "Could not enumerate COM ports: $($_.Exception.Message)"
        return @()
    }
}

function Test-PortAvailability {
    param([string]$PortName)
    
    $availablePorts = Get-AvailablePorts
    return $availablePorts -contains $PortName
}

function Test-ConfigurationFile {
    param([string]$ConfigPath)
    
    $issues = @()
    $warnings = @()
    
    Write-Color Green "Validating configuration file: $ConfigPath"
    
    if (-not (Test-Path $ConfigPath)) {
        $issues += "Configuration file not found: $ConfigPath"
        return $issues, $warnings
    }
    
    try {
        $config = [CordeliaConfig]::new()
        $config.LoadFromIni($ConfigPath)
        
        # Check required UART settings
        $requiredUart = @('port', 'baudrate', 'timeout')
        foreach ($key in $requiredUart) {
            if (-not $config.UART.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($config.UART[$key])) {
                $issues += "Missing or empty UART setting: $key"
            }
        }
        
        # Check required SECURITY settings
        $requiredSecurity = @('certificate_name', 'chunk_size')
        foreach ($key in $requiredSecurity) {
            if (-not $config.SECURITY.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($config.SECURITY[$key])) {
                $issues += "Missing or empty SECURITY setting: $key"
            }
        }
        
        # Validate specific values
        if ($config.UART.ContainsKey('baudrate')) {
            $validBaudRates = @(9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600)
            if ($validBaudRates -notcontains $config.UART.baudrate) {
                $warnings += "Unusual baud rate: $($config.UART.baudrate). Standard rates: $($validBaudRates -join ', ')"
            }
        }
        
        if ($config.UART.ContainsKey('parity')) {
            $validParity = @('N', 'E', 'O', 'none', 'even', 'odd')
            if ($validParity -notcontains $config.UART.parity) {
                $issues += "Invalid parity setting: $($config.UART.parity). Valid values: $($validParity -join ', ')"
            }
        }
        
        if ($config.SECURITY.ContainsKey('chunk_size')) {
            if ($config.SECURITY.chunk_size -lt 64 -or $config.SECURITY.chunk_size -gt 1460) {
                $issues += "Invalid chunk_size: $($config.SECURITY.chunk_size). Must be between 64 and 1460"
            }
        }
        
        if ($config.SECURITY.ContainsKey('encoding')) {
            $validEncodings = @('base64', 'hex', 'ascii')
            if ($validEncodings -notcontains $config.SECURITY.encoding) {
                $warnings += "Unusual encoding: $($config.SECURITY.encoding). Recommended: $($validEncodings -join ', ')"
            }
        }
        
        # Check FILE_OPERATIONS settings if present
        if ($config.ContainsKey('FILE_OPERATIONS')) {
            # Validate boolean settings
            $booleanSettings = @('confirm_overwrite', 'show_progress', 'enable_logging')
            foreach ($key in $booleanSettings) {
                if ($config.FILE_OPERATIONS.ContainsKey($key)) {
                    $validBooleans = @('true', 'false', 'yes', 'no', '1', '0')
                    if ($validBooleans -notcontains $config.FILE_OPERATIONS[$key].ToLower()) {
                        $issues += "Invalid FILE_OPERATIONS ${key}: $($config.FILE_OPERATIONS[$key]). Must be true/false"
                    }
                }
            }
            
            # Validate numeric settings
            if ($config.FILE_OPERATIONS.ContainsKey('read_chunk_size')) {
                $readChunkSize = [int]$config.FILE_OPERATIONS.read_chunk_size
                if ($readChunkSize -lt 64 -or $readChunkSize -gt 8192) {
                    $warnings += "read_chunk_size: $readChunkSize. Recommended range: 512-2048 bytes"
                }
            }
            
            if ($config.FILE_OPERATIONS.ContainsKey('max_download_size')) {
                $maxSize = [int]$config.FILE_OPERATIONS.max_download_size
                if ($maxSize -lt 1024) {
                    $warnings += "max_download_size is very small: $maxSize bytes. Consider increasing for practical use"
                }
            }
            
            # Validate directory paths
            if ($config.FILE_OPERATIONS.ContainsKey('log_directory')) {
                $logDir = $config.FILE_OPERATIONS.log_directory
                if ($logDir -and $logDir -match '[<>:"|?*]') {
                    $issues += "Invalid characters in log_directory path: $logDir"
                }
            }
            
            if ($config.FILE_OPERATIONS.ContainsKey('default_download_dir')) {
                $downloadDir = $config.FILE_OPERATIONS.default_download_dir
                if ($downloadDir -and $downloadDir -match '[<>:"|?*]') {
                    $issues += "Invalid characters in default_download_dir path: $downloadDir"
                }
            }
        }
        
        # Check MQTT settings if present
        if ($config.ContainsKey('MQTT')) {
            if ($config.MQTT.ContainsKey('port')) {
                $mqttPort = [int]$config.MQTT.port
                if ($mqttPort -lt 1 -or $mqttPort -gt 65535) {
                    $issues += "Invalid MQTT port: $mqttPort. Must be between 1 and 65535"
                }
            }
            
            if ($config.MQTT.ContainsKey('use_tls')) {
                $validBooleans = @('true', 'false', 'yes', 'no', '1', '0')
                if ($validBooleans -notcontains $config.MQTT.use_tls.ToLower()) {
                    $issues += "Invalid MQTT use_tls: $($config.MQTT.use_tls). Must be true/false"
                }
            }
            
            if ($config.MQTT.ContainsKey('keepalive')) {
                $keepalive = [int]$config.MQTT.keepalive
                if ($keepalive -lt 10 -or $keepalive -gt 300) {
                    $warnings += "MQTT keepalive: $keepalive seconds. Recommended range: 30-120 seconds"
                }
            }
        }
        
        # Check port availability
        if ($config.UART.ContainsKey('port')) {
            if (-not (Test-PortAvailability -PortName $config.UART.port)) {
                $availablePorts = Get-AvailablePorts
                if ($availablePorts.Count -gt 0) {
                    $warnings += "COM port not available: $($config.UART.port). Available ports: $($availablePorts -join ', ')"
                } else {
                    $warnings += "COM port not available: $($config.UART.port). No COM ports detected on system."
                }
            }
        }
        
    } catch {
        $issues += "Configuration parse error: $($_.Exception.Message)"
    }
    
    return $issues, $warnings
}

function Test-DeviceConnection {
    param([string]$ConfigPath)
    
    Write-Color Green "Testing device connection..."
    
    try {
        $connection = New-CordeliaConnection -ConfigPath $ConfigPath
        $connection.Connect()
        
        Write-Color Green "✓ Serial connection established"
        
        # Test basic AT command
        try {
            $connection.SendCommand("AT+test", "OK", 3000) | Out-Null
            Write-Color Green "✓ Device responds to AT commands"
            
            # Try to get version info
            try {
                $response = $connection.SendCommand("AT+get=general,version", "OK", 5000)
                if ($response -match '\+get:.*,.*,.*,.*,.*,(.+)') {
                    $firmwareVersion = $matches[1].Trim()
                    Write-Color Green "✓ Device firmware version: $firmwareVersion"
                }
            } catch {
                Write-Color Yellow "⚠ Could not get device version: $($_.Exception.Message)"
            }
            
        } catch {
            Write-Color Red "✗ Device not responding to AT commands: $($_.Exception.Message)"
            return $false
        }
        
        $connection.Dispose()
        Write-Color Green "✓ Connection test completed successfully"
        return $true
        
    } catch {
        Write-Color Red "✗ Connection test failed: $($_.Exception.Message)"
        return $false
    }
}

function New-ConfigTemplate {
    param([string]$OutputPath)
    
    $template = @"
# Cordelia-I Configuration File
# Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

[UART]
# Serial port settings
port=COM1
baudrate=115200
databits=8
parity=N
stopbits=1
timeout=30

[SECURITY]
# File upload and security settings
certificate_name=certificate.pem
chunk_size=512
encoding=base64
max_retries=3
verify_upload=true

[FILE_OPERATIONS]
# File operation preferences and limits
confirm_overwrite=true
show_progress=false
enable_logging=false
log_directory=./logs
default_download_dir=../downloads
read_chunk_size=1024
max_download_size=10485760

[MQTT]
# MQTT broker settings (optional)
broker=
port=8883
client_id=
use_tls=true
keepalive=60
"@
    
    try {
        $template | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Color Green "Configuration template created: $OutputPath.`r`nPlease edit the template with your specific settings."
    } catch {
        throw "Failed to create template file: $($_.Exception.Message)"
    }
}

function Show-Configuration {
    param([string]$ConfigPath)
    
    try {
        $config = [CordeliaConfig]::new()
        $config.LoadFromIni($ConfigPath)
        
        Write-Host "`n⚙️  Current Configuration:" -ForegroundColor Green
        Write-Host "═══════════════════════════" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "UART Settings" -ForegroundColor Cyan
        Write-Host "  📍 Port:       $($config.UART.port)"
        Write-Host "  ⚡ Baud Rate:   $($config.UART.baudrate)"
        Write-Host "  📊 Data Bits:   $($config.UART.databits)"
        Write-Host "  🔧 Parity:      $($config.UART.parity)"
        Write-Host "  ⏹️ Stop Bits:   $($config.UART.stopbits)"
        Write-Host "  ⏱️ Timeout:     $($config.UART.timeout) seconds"
        Write-Host ""
        
        Write-Host "Security Settings" -ForegroundColor Cyan
        Write-Host "  📜 Certificate: $($config.SECURITY.certificate_name)"
        Write-Host "  📦 Chunk Size:  $($config.SECURITY.chunk_size) bytes"
        Write-Host "  🔐 Encoding:    $($config.SECURITY.encoding)"
        Write-Host "  🔄 Max Retries: $($config.SECURITY.max_retries)"
        Write-Host "  ✅ Verify:      $($config.SECURITY.verify_upload)"
        Write-Host ""
        
        if ($config.ContainsKey('FILE_OPERATIONS')) {
            Write-Host "File Operations:" -ForegroundColor Cyan
            if ($config.FILE_OPERATIONS.ContainsKey('confirm_overwrite')) {
                Write-Host "  ✅ Confirm Overwrite: $($config.FILE_OPERATIONS.confirm_overwrite)"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('show_progress')) {
                Write-Host "  📊 Show Progress:     $($config.FILE_OPERATIONS.show_progress)"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('enable_logging')) {
                Write-Host "  📝 Enable Logging:    $($config.FILE_OPERATIONS.enable_logging)"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('log_directory')) {
                Write-Host "  📂 Log Directory:     $($config.FILE_OPERATIONS.log_directory)"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('default_download_dir')) {
                Write-Host "  💾 Download Dir:      $($config.FILE_OPERATIONS.default_download_dir)"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('read_chunk_size')) {
                Write-Host "  📖 Read Chunk Size:   $($config.FILE_OPERATIONS.read_chunk_size) bytes"
            }
            if ($config.FILE_OPERATIONS.ContainsKey('max_download_size')) {
                Write-Host "  📏 Max Download Size: $([Math]::Round($config.FILE_OPERATIONS.max_download_size / 1MB, 1)) MB"
            }
            Write-Host ""
        }
        
        if ($config.ContainsKey('MQTT') -and ($config.MQTT.ContainsKey('broker') -and $config.MQTT.broker)) {
            Write-Host "MQTT Settings:" -ForegroundColor Cyan
            if ($config.MQTT.ContainsKey('broker')) {
                Write-Host "  🏢 Broker:      $($config.MQTT.broker)"
            }
            if ($config.MQTT.ContainsKey('port')) {
                Write-Host "  🔌 Port:        $($config.MQTT.port)"
            }
            if ($config.MQTT.ContainsKey('client_id')) {
                Write-Host "  🆔 Client ID:   $($config.MQTT.client_id)"
            }
            if ($config.MQTT.ContainsKey('use_tls')) {
                Write-Host "  🔒 Use TLS:     $($config.MQTT.use_tls)"
            }
            if ($config.MQTT.ContainsKey('keepalive')) {
                Write-Host "  ⏱️ Keepalive:   $($config.MQTT.keepalive) seconds"
            }
            Write-Host ""
        }
        
        Write-Host "📄 Config File: " -NoNewline -ForegroundColor Green
        Write-Host $ConfigPath -ForegroundColor White
        
    } catch {
        Write-Color Red "❌ Failed to load configuration: $($_.Exception.Message)"
    }
}

try {
    Write-Color Green "Cordelia-I Configuration Validator"
    
    if ($ListPorts) {
        Write-Color Green "`nAvailable COM ports:"
        $ports = Get-AvailablePorts
        if ($ports.Count -gt 0) {
            foreach ($port in $ports) {
                Write-Host "  $port"
            }
        } else {
            Write-Color Yellow "No COM ports detected on this system."
        }
        Write-Host ""
        exit 0
    }
    
    if ($CreateTemplate) {
        New-ConfigTemplate -OutputPath $TemplateFile
        exit 0
    }
    
    if ($ViewConfig) {
        # Find config file if not specified
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
            $configCandidates = @(
                (Join-Path $PSScriptRoot '..\..\common\config.ini'),
                (Join-Path $PSScriptRoot '..\common\config.ini'),
                (Join-Path $PSScriptRoot 'config.ini'),
                (Join-Path $PSScriptRoot '..\config.ini')
            )
            $ConfigPath = $configCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            
            if (-not $ConfigPath) {
                Write-Color Red "❌ No configuration file found in standard locations:"
                $configCandidates | ForEach-Object { Write-Host "  $_" }
                exit 1
            }
        }
        
        Show-Configuration -ConfigPath $ConfigPath
        exit 0
    }
    
    # Find config file if not specified
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $configCandidates = @(
            (Join-Path $PSScriptRoot '..\..\common\config.ini'),
            (Join-Path $PSScriptRoot '..\common\config.ini'),
            (Join-Path $PSScriptRoot 'config.ini'),
            (Join-Path $PSScriptRoot '..\config.ini')
        )
        $ConfigPath = $configCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        
        if (-not $ConfigPath) {
            Write-Color Yellow "No configuration file found in standard locations:"
            $configCandidates | ForEach-Object { Write-Host "  $_" }
            Write-Color Yellow "`nUse -CreateTemplate to generate a template configuration file."
            exit 1
        }
    }
    
    # Validate configuration
    $issues, $warnings = Test-ConfigurationFile -ConfigPath $ConfigPath
    
    # Display results
    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Color Green "✓ Configuration validation passed with no issues."
    } else {
        if ($issues.Count -gt 0) {
            Write-Color Red "`n✗ Configuration Issues Found:"
            foreach ($issue in $issues) {
                Write-Color Red "  • $issue"
            }
        }
        
        if ($warnings.Count -gt 0) {
            Write-Color Yellow "`n⚠ Configuration Warnings:"
            foreach ($warning in $warnings) {
                Write-Color Yellow "  • $warning"
            }
        }
    }
    
    # Test connection if requested and config is valid
    if ($TestConnection) {
        if ($issues.Count -gt 0) {
            Write-Color Red "`nSkipping connection test due to configuration issues."
            exit 1
        } else {
            Write-Host ""
            $connectionOk = Test-DeviceConnection -ConfigPath $ConfigPath
            if (-not $connectionOk) {
                exit 1
            } else {
                exit 0
            }
        }
    }
    
    # Final status
    if ($issues.Count -gt 0) {
        Write-Color Red "`nConfiguration validation failed. Please fix the issues above."
        exit 1
    } elseif ($warnings.Count -gt 0) {
        Write-Color Yellow "`nConfiguration validation completed with warnings."
        exit 0
    } else {
        Write-Color Green "`nConfiguration validation passed successfully."
        exit 0
    }

} catch {
    Write-Color Red "Error: $($_.Exception.Message)"
    exit 1
}
