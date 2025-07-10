<#
.SYNOPSIS
    Setup wizard configuration file creation and updating helper.

.DESCRIPTION
    This script handles configuration file creation and updating for the setup wizard.
    It can create new configuration files or update existing ones with the selected COM port.

.PARAMETER SelectedPort
    The COM port selected by the user in the setup wizard.

.EXAMPLE
    .\setup-config.ps1 -SelectedPort "COM3"

.NOTES
    This script is called by the setup wizard in cordelia-tools.cmd.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$SelectedPort
)

$ErrorActionPreference = 'Stop'

# Configuration file search paths
$configPaths = @(
    '..\..\common\config.ini',
    '..\common\config.ini',
    'config.ini',
    '..\config.ini'
)

# Find existing configuration file
$existingConfig = $configPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($existingConfig) {
    Write-Host "📄 Found existing config: $existingConfig" -ForegroundColor Green
    Write-Host "🔄 Updating COM port to $SelectedPort..." -ForegroundColor Yellow
    
    try {
        $content = Get-Content $existingConfig
        $updated = $false
        $newContent = @()
        
        # First pass: try to update existing port setting
        foreach ($line in $content) {
            if ($line -match '^port\s*=') {
                $newContent += "port=$SelectedPort"
                $updated = $true
                Write-Host "   ✅ Updated port setting" -ForegroundColor Green
            } else {
                $newContent += $line
            }
        }
        
        # Second pass: if no port setting found, add it to UART section
        if (-not $updated) {
            Write-Host "   ⚠️  No existing port setting found, adding to UART section" -ForegroundColor Yellow
            $inUart = $false
            $newContent = @()
            $uartSectionFound = $false
            
            foreach ($line in $content) {
                if ($line -match '^\[UART\]') {
                    $inUart = $true
                    $uartSectionFound = $true
                    $newContent += $line
                    $newContent += "port=$SelectedPort"
                    $updated = $true
                } elseif ($line -match '^\[') {
                    $inUart = $false
                    $newContent += $line
                } else {
                    $newContent += $line
                }
            }
            
            # If no UART section found, add it at the beginning
            if (-not $uartSectionFound) {
                $newContent = @('[UART]', "port=$SelectedPort", '') + $newContent
                $updated = $true
                Write-Host "   ✅ Added UART section with port setting" -ForegroundColor Green
            }
        }
        
        # Write updated content back to file
        $newContent | Out-File -FilePath $existingConfig -Encoding UTF8
        Write-Host "✅ Configuration updated: $existingConfig" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to update configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
} else {
    Write-Host "📝 Creating new configuration file..." -ForegroundColor Yellow
    
    $configPath = '..\common\config.ini'
    
    # Try to use existing common/config.ini as template
    $templatePaths = @(
        '..\..\common\config.ini',
        '..\common\config.ini'
    )
    
    $templateConfig = $templatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if ($templateConfig) {
        Write-Host "📄 Using existing config as template: $templateConfig" -ForegroundColor Green
        
        # Read template and update port
        $templateContent = Get-Content $templateConfig
        $content = @()
        
        foreach ($line in $templateContent) {
            if ($line -match '^port\s*=') {
                $content += "port=$SelectedPort"
            } else {
                $content += $line
            }
        }
    } else {
        Write-Host "📝 Creating config with default values..." -ForegroundColor Yellow
        
        # Create default configuration content
        $content = @(
            '[UART]',
            "port=$SelectedPort",
            'baudrate=115200',
            'databits=8',
            'parity=N',
            'stopbits=1',
            'timeout=30',
            '',
            '[SECURITY]',
            'certificate_name=certificate.pem',
            'chunk_size=512',
            'encoding=ascii',
            'max_retries=3',
            'verify_upload=true',
            '',
            '[FILE_OPERATIONS]',
            'confirm_overwrite=true',
            'show_progress=false',
            'enable_logging=true',
            'log_directory=./logs',
            'default_download_dir=../downloads',
            'read_chunk_size=512',
            'max_download_size=10485760',
            '',
            '[MQTT]',
            'broker=your-mqtt-broker.com',
            'port=8883',
            'client_id=cordelia-device-001',
            'use_tls=true',
            'keepalive=60'
        )
    }
    
    try {
        # Create directory if it doesn't exist
        $configDir = Split-Path $configPath -Parent
        if ($configDir -and -not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Write configuration file
        $content | Out-File -FilePath $configPath -Encoding UTF8
        Write-Host "✅ Configuration file created: $configPath" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to create configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

exit 0