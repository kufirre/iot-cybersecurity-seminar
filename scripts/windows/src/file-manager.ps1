# file-manager.ps1 - Unified File Management for Cordelia-I
<#
.SYNOPSIS
    Comprehensive file management for the Cordelia-I device with upload, download, and management capabilities.

.DESCRIPTION
    This unified utility provides all file operations for the Cordelia-I device:
    - List files on device
    - Upload files to device (including certificates)
    - Download files from device  
    - Delete files from device (supports wildcards)
    - Get detailed file information

.PARAMETER Action
    The action to perform: List, Upload, Download, Delete, Info

.PARAMETER FileName
    Name of the file to operate on (required for Download, Delete, Info actions)

.PARAMETER FilePath
    Local path to file for upload (required for Upload action when not using file browser)

.PARAMETER RemoteFileName
    Remote filename for upload (optional, defaults to local filename)

.PARAMETER OutputDir
    Directory to save downloaded files (optional, defaults to current directory)

.PARAMETER Format
    Format for file download: base64, hex, ascii (default: base64)

.PARAMETER ConfigPath
    Path to configuration file (auto-detects if not specified)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER OverwriteExisting
    Allow overwriting existing files on device

.PARAMETER IsCertificate
    Use certificate-specific settings for upload

.PARAMETER LogFile
    Path to log file for detailed logging

.EXAMPLE
    .\file-manager.ps1 -Action List

.EXAMPLE
    .\file-manager.ps1 -Action Upload -FilePath "C:\cert.pem" -IsCertificate

.EXAMPLE
    .\file-manager.ps1 -Action Download -FileName "certificate.pem" -OutputDir "C:\Downloads"

.EXAMPLE
    .\file-manager.ps1 -Action Delete -FileName "*.tmp" -Force

.NOTES
    Requires utilities.psm1 module.
#>

# Import the utilities module
using module ".\utilities.psm1"

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('List', 'Upload', 'Download', 'Delete', 'Info')]
    [string]$Action,
    
    [string]$FileName = '',
    [string]$FilePath = '',
    [string]$RemoteFileName = '',
    [string]$OutputDir = '',
    [ValidateSet('base64', 'hex', 'ascii')]
    [string]$Format = 'base64',
    [string]$ConfigPath = '',
    [switch]$Force,
    [switch]$OverwriteExisting,
    [switch]$IsCertificate,
    [string]$LogFile = ''
)

$ErrorActionPreference = 'Stop'

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This script requires PowerShell 5.0 or newer. Current version: $($PSVersionTable.PSVersion)"
}

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

function Get-FileList {
    param($Connection)
    
    try {
        $response = $Connection.SendCommand("AT+fileGetFileList", "OK", ($Connection.Config.timeout * 1000))
        $files = @()
        
        $lines = $response -split "`r?`n"
        foreach ($line in $lines) {
            if ($line -match '(?i)\+filegetfilelist:([^,]+),(\d+),([^,]*),(\d+)') {
                $properties = @()
                if ($matches[3] -ne '' -and $null -ne $matches[3]) {
                    $properties = $matches[3] -split '\|'
                }
                $files += [PSCustomObject]@{
                    Name = $matches[1]
                    MaxSize = [int]$matches[2]
                    Properties = $properties
                    BlocksAllocated = [int]$matches[4]
                }
            }
        }
        
        return $files
    } catch {
        throw "Failed to get file list: $($_.Exception.Message)"
    }
}

function Get-FileInfo {
    param($Connection, [string]$FileName)
    
    try {
        $infoCmd = "AT+FILEGETINFO=$FileName,"
        $response = $Connection.SendCommand($infoCmd, "OK", ($Connection.Config.timeout * 1000))
        Write-Color White "RESPONSE: $response" -LogFile $LogFile
        
        # Clean the response to ensure proper parsing
        $cleanResponse = $response -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
        
        if ($cleanResponse -match '(?i)\+filegetinfo:([^,]*),(\d+),(\d+),([^,]*),(\d+),(\d+)') {
            $flags = @()
            if ($matches[1] -ne '' -and $null -ne $matches[1]) {  # Fixed syntax here
                $flags = $matches[1] -split '\|'
            }
            return [PSCustomObject]@{
                Name = $FileName
                Flags = $flags
                FileSize = [int]$matches[2]
                AllocatedSize = [int]$matches[3]
                Tokens = $matches[4]
                StorageSize = [int]$matches[5]
                WriteCounter = [int]$matches[6]
            }
        } else {
            throw "Could not parse file info response: $cleanResponse"
        }
        
    } catch {
        throw "Failed to get file info for '$FileName': $($_.Exception.Message)"
    }
}

function Test-FileExists {
    param($Connection, [string]$FileName)
    
    try {
        $infoCmd = "AT+FILEGETINFO=$FileName,"
        Write-Color Green "Checking if file exists: $FileName" -LogFile $LogFile
        
        # $response = $Connection.SendCommand($infoCmd, "OK", ($Connection.Config.timeout * 1000))
        $Connection.SendCommand($infoCmd, "OK", ($Connection.Config.timeout * 1000))
        
        # If we get here without an exception, the file exists
        Write-Color Green "File '$FileName' exists on device" -LogFile $LogFile
        return $true
        
    } catch {
        $errorMsg = $_.Exception.Message
        
        # Check if it's the "file does not exist" error (-10341)
        if ($errorMsg -match "-10341") {
            Write-Color Yellow "File '$FileName' does not exist on device (error -10341)" -LogFile $LogFile
            return $false
        } else {
            # Some other error occurred - log it with proper error lookup
            if ($errorMsg -match "FAILED: \((-?\d+)\):") {
                $errorCode = [int]$matches[1]
                $errorDescription = Get-ErrorMessage -ErrorCode $errorCode
                Write-Color Red "Error checking file existence: ($errorCode) $errorDescription" -LogFile $LogFile
            } else {
                Write-Color Red "Error checking file existence: $errorMsg" -LogFile $LogFile
            }
            return $false
        }
    }
}

function Save-FileContent {
    param(
        [string]$Content,
        [string]$OutputPath,
        [string]$Format = 'ascii'
    )
    
    try {
        switch ($Format.ToLower()) {
            'ascii' {
                # Write content as binary to preserve exact line endings (LF vs CRLF)
                # Use UTF8 encoding without BOM to handle the string data properly
                [IO.File]::WriteAllText($OutputPath, $Content, [Text.UTF8Encoding]::new($false))
            }
            'base64' {
                # Convert content to bytes, then to base64
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
                $base64String = [Convert]::ToBase64String($bytes)
                [IO.File]::WriteAllText($OutputPath, $base64String, [Text.UTF8Encoding]::new($false))
            }
            'hex' {
                # Convert content to bytes, then to hex
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
                $hexString = [BitConverter]::ToString($bytes) -replace '-', ''
                [IO.File]::WriteAllText($OutputPath, $hexString, [Text.UTF8Encoding]::new($false))
            }
        }
    } catch {
        throw "Failed to save file to '$OutputPath': $($_.Exception.Message)"
    }
}

function Read-DeviceFile {
    param(
        $Connection,
        [string]$FileName,
        [string]$OutputPath = $null,
        [string]$Format = 'base64',
        $SecurityConfig = $null,
        $FileOperationsConfig = $null
    )
    
    # Get file info first (checks existence AND gets size in one call)
    Write-Color Green "Getting file information: $FileName" -LogFile $LogFile
    try {
        $fileInfo = Get-FileInfo -Connection $Connection -FileName $FileName
        $fileSize = $fileInfo.FileSize
        Write-Color Green "File exists. Size: $fileSize bytes" -LogFile $LogFile
        
        # Check file size against maximum download limit
        if ($FileOperationsConfig -and $FileOperationsConfig.max_download_size -gt 0 -and $fileSize -gt $FileOperationsConfig.max_download_size) {
            $maxSizeMB = [Math]::Round($FileOperationsConfig.max_download_size / 1MB, 2)
            $fileSizeMB = [Math]::Round($fileSize / 1MB, 2)
            throw "File size ($fileSizeMB MB) exceeds maximum download limit ($maxSizeMB MB). Use a smaller chunk size or increase max_download_size in config."
        }
    } catch {
        if ($_.Exception.Message -match "-10341") {
            throw "File '$FileName' does not exist on device"
        } else {
            throw "Failed to get file info: $($_.Exception.Message)"
        }
    }
    
    # Open file for reading now that we know it exists
    $handle = $null
    try {
        $openCmd = "AT+FILEOPEN=$FileName,READ,$fileSize"
        Write-Color Green "Opening file for reading: $FileName" -LogFile $LogFile
        
        $openResponse = $Connection.SendCommand($openCmd, "OK", ($Connection.Config.timeout * 1000))
        
        if ($openResponse -match '\+fileopen\s*:\s*(\d+)') {
            $handle = $matches[1]
            Write-Color Green "File opened with handle: $handle" -LogFile $LogFile
        } else {
            throw "Failed to get file handle from response: $openResponse"
        }
        
        # Read file in chunks using configured chunk size
        $chunkSize = if ($FileOperationsConfig -and $FileOperationsConfig.read_chunk_size) { 
            $FileOperationsConfig.read_chunk_size 
        } else { 
            1024  # Default fallback if not configured
        }
        $offset = 0
        $allBytes = @()
        
        # Use format code based on configuration encoding (0 for ASCII, 1 for base64)
        $formatCode = if ($SecurityConfig -and $SecurityConfig.encoding.ToLower() -eq 'base64') { 1 } else { 0 }
        
        while ($offset -lt $fileSize) {
            $remainingBytes = $fileSize - $offset
            $readSize = [Math]::Min($chunkSize, $remainingBytes)
            
            # AT+FILEREAD=handle,offset,format,length
            $readCmd = "AT+FILEREAD=$handle,$offset,$formatCode,$readSize"
            Write-Color Green "Reading chunk: offset=$offset, size=$readSize" -LogFile $LogFile
            
            $readResponse = $Connection.SendCommand($readCmd, 'OK', ($Connection.Config.timeout * 3000))  # Increased timeout for file reading
            
            # Parse response: +fileread:format,actualLength,data (data can be multi-line)
            if ($readResponse -match '(?i)\+fileread:(\d+),(\d+),(.*)') {
                $responseFormat = [int]$matches[1]  # Format returned (should match what we requested)
                $actualLength = [int]$matches[2]    # Actual bytes read
                
                # The device reports exactly how many bytes it read ($actualLength)
                # We need to extract exactly that many bytes from the response
                # The format is: +fileread:format,length,<exactly actualLength bytes>
                
                # Find where the data starts after the comma
                $headerPattern = "+fileread:$responseFormat,$actualLength,"
                $headerIndex = $readResponse.IndexOf($headerPattern)
                
                if ($headerIndex -ge 0) {
                    
                    # Extract exactly $actualLength bytes from the response
                    # Convert entire response to bytes to work at byte level
                    $responseBytes = [Text.Encoding]::ASCII.GetBytes($readResponse)
                    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headerPattern)
                    
                    # Find header in bytes
                    $headerByteIndex = -1
                    for ($i = 0; $i -le $responseBytes.Length - $headerBytes.Length; $i++) {
                        $match = $true
                        for ($j = 0; $j -lt $headerBytes.Length; $j++) {
                            if ($responseBytes[$i + $j] -ne $headerBytes[$j]) {
                                $match = $false
                                break
                            }
                        }
                        if ($match) {
                            $headerByteIndex = $i
                            break
                        }
                    }
                    
                    if ($headerByteIndex -ge 0) {
                        $dataByteStart = $headerByteIndex + $headerBytes.Length
                        
                        # Extract exactly $actualLength bytes - no more, no less
                        if ($dataByteStart + $actualLength -le $responseBytes.Length) {
                            $chunkBytes = $responseBytes[$dataByteStart..($dataByteStart + $actualLength - 1)]
                            $allBytes += $chunkBytes
                        } else {
                            throw "Response doesn't contain expected $actualLength bytes of data"
                        }
                    }
                }
                $offset += $actualLength
                
                Write-Color White "Read $actualLength bytes (format: $responseFormat)" -LogFile $LogFile
            } else {
                throw "Failed to parse read response: $readResponse"
            }
        }
        
        # Process the data based on requested output format
        # Convert bytes back to string for display/processing
        $combinedData = [Text.Encoding]::ASCII.GetString($allBytes)
        
        # Info about final bytes
        if ($allBytes.Length -gt 0) {
            $lastByte = $allBytes[-1]
            $lastFewBytes = $allBytes[([Math]::Max(0, $allBytes.Length - 5))..($allBytes.Length - 1)]
            Write-Color White "Total bytes read: $($allBytes.Length), Last byte: $lastByte (0x$($lastByte.ToString('X2'))), Last 5 bytes: $($lastFewBytes -join ',')" -LogFile $LogFile
        }
        
        # Display content (always display for interactive use)
        Write-Host "`nFile Content ($Format format):"
        switch ($Format.ToLower()) {
            'ascii' {
                Write-Host $combinedData
            }
            'base64' {
                $bytes = [Text.Encoding]::ASCII.GetBytes($combinedData)
                $base64String = [Convert]::ToBase64String($bytes)
                Write-Host $base64String.Substring(0, [Math]::Min(200, $base64String.Length))
                if ($base64String.Length -gt 200) {
                    Write-Host "... (truncated, full content available for saving)"
                }
            }
            'hex' {
                $bytes = [Text.Encoding]::ASCII.GetBytes($combinedData)
                $hexString = [BitConverter]::ToString($bytes) -replace '-', ''
                Write-Host $hexString.Substring(0, [Math]::Min(200, $hexString.Length))
                if ($hexString.Length -gt 200) {
                    Write-Host "... (truncated, full content available for saving)"
                }
            }
        }
        
        # Return the raw data for potential saving, along with the raw bytes
        return @{
            StringData = $combinedData
            RawBytes = $allBytes
        }
        
    } catch {
        throw "Failed to read file '$FileName': $($_.Exception.Message)"
    } finally {
        # Always close the file handle if it was opened
        if ($handle) {
            try {
                $closeCmd = "AT+FILECLOSE=$handle,,"
                Write-Color Green "Closing file handle $handle..." -LogFile $LogFile
                $Connection.SendCommand($closeCmd, 'OK', ($Connection.Config.timeout * 1000)) | Out-Null
                Write-Color Green "File handle closed successfully" -LogFile $LogFile
            } catch {
                Write-Color Red "Warning: Failed to close file handle $handle" -LogFile $LogFile
            }
        }
    }
}

function Remove-SingleFile {
    param($Connection, [string]$FileName, [switch]$Force, [switch]$SkipExistenceCheck = $false)
    
    if (-not $SkipExistenceCheck) {
        if (-not (Test-FileExists -Connection $Connection -FileName $FileName)) {
            Write-Color Red "File '$FileName' does not exist on device." -LogFile $LogFile
            return $false
        }
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "Delete '$FileName' from device? This cannot be undone. (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Color Yellow "Delete cancelled for '$FileName'." -LogFile $LogFile
            return $false
        }
    }
    
    try {
        # Note the trailing comma for optional secureToken parameter
        $deleteCmd = "AT+fileDel=$FileName,"
        
        $response = $Connection.SendCommand($deleteCmd, "OK", ($Connection.Config.timeout * 1000))
        
        if ($response -match "(?i)OK" -and $response -notmatch "(?i)ERROR") {
            Write-Color Green "File '$FileName' deleted successfully." -LogFile $LogFile
            return $true
        } else {
            Write-Color Red "Failed to delete '$FileName': Device returned error." -LogFile $LogFile
            return $false
        }
        
    } catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "-10341" -or $errorMsg -match "does not exist") {
            Write-Color Red "File '$FileName' does not exist on device." -LogFile $LogFile
        } else {
            Write-Color Red "Failed to delete file '$FileName': $errorMsg" -LogFile $LogFile
        }
        return $false
    }
}

function Remove-FilesWithWildcard {
    param($Connection, [string]$Pattern, [switch]$Force)
    
    Write-Color Green "Getting file list to match pattern: $Pattern" -LogFile $LogFile
    $allFiles = Get-FileList -Connection $Connection
    
    # Convert wildcard pattern to regex
    $regexPattern = [regex]::Escape($Pattern)
    $regexPattern = $regexPattern -replace '\\\*', '.*'
    $regexPattern = $regexPattern -replace '\\\?', '.'
    $regexPattern = "^$regexPattern$"
    
    $matchingFiles = @()
    foreach ($file in $allFiles) {
        if ($file.Name -match $regexPattern) {
            $matchingFiles += $file
        }
    }
    
    if ($matchingFiles.Count -eq 0) {
        Write-Color Yellow "No files match the pattern '$Pattern'." -LogFile $LogFile
        return 0
    }
    
    Write-Color Green "`nFiles matching pattern '$Pattern' ($($matchingFiles.Count) files):" -LogFile $LogFile
    foreach ($file in $matchingFiles) {
        Write-Host "  $($file.Name)"
    }
    Write-Host ""
    
    if (-not $Force) {
        $confirmation = Read-Host "Delete $($matchingFiles.Count) file(s) listed above? This cannot be undone. (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Color Yellow "Bulk delete cancelled." -LogFile $LogFile
            return 0
        }
    }
    
    $successCount = 0
    $failCount = 0
    
    foreach ($file in $matchingFiles) {
        Write-Color White "Deleting: $($file.Name)" -LogFile $LogFile
        if (Remove-SingleFile -Connection $Connection -FileName $file.Name -Force -SkipExistenceCheck) {
            $successCount++
        } else {
            $failCount++
        }
    }
    
    Write-Color Green "`nDeletion summary: $successCount successful, $failCount failed" -LogFile $LogFile
    return $successCount
}

function Upload-FileToDevice {
    param(
        $Connection,
        [string]$LocalPath = '',
        [string]$RemoteName = '',
        [hashtable]$SecurityConfig,
        [switch]$IsCertificate,
        [switch]$OverwriteExisting
    )
    
    # Handle file selection
    if ([string]::IsNullOrWhiteSpace($LocalPath)) {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object Windows.Forms.OpenFileDialog
        
        if ($IsCertificate) {
            $dlg.InitialDirectory = (Resolve-Path '..\..\resources' -ErrorAction SilentlyContinue).Path
            $dlg.Filter = 'Certificate files (*.pem;*.crt;*.cer;*.der)|*.pem;*.crt;*.cer;*.der|All files (*.*)|*.*'
            $dlg.Title = 'Select Certificate File'
        } else {
            $dlg.Filter = 'All files (*.*)|*.*|Certificate files (*.pem;*.crt;*.cer)|*.pem;*.crt;*.cer|Config files (*.ini;*.cfg;*.conf)|*.ini;*.cfg;*.conf'
            $dlg.Title = 'Select File to Upload'
        }

        if ($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
            Write-Color Red 'No file selected - cancelling upload.' -LogFile $LogFile
            return
        }
        $LocalPath = $dlg.FileName
    }

    # Validate file exists
    if (-not (Test-Path $LocalPath)) {
        throw "File not found: $LocalPath"
    }

    # Determine remote filename
    if ([string]::IsNullOrWhiteSpace($RemoteName)) {
        if ($IsCertificate) {
            $RemoteName = $SecurityConfig.certificate_name
        } else {
            $RemoteName = [IO.Path]::GetFileName($LocalPath)
        }
    }

    # Use the existing CordeliaFileUpload function
    CordeliaFileUpload -Connection $Connection -FilePath $LocalPath -SecurityConfig $SecurityConfig -RemoteFileName $RemoteName -LogFile $LogFile -OverwriteExisting:$OverwriteExisting
}

function Test-WildcardPattern {
    param([string]$Pattern)
    return ($Pattern.Contains('*') -or $Pattern.Contains('?'))
}



try {
    Write-Color Green "Cordelia-I Unified File Manager" -LogFile $LogFile
    Write-Color Green "Action: $Action" -LogFile $LogFile

    # Validate parameters based on action
    switch ($Action) {
        'Upload' {
            # FilePath is optional for Upload (can use file browser)
        }
        'Download' {
            if ([string]::IsNullOrWhiteSpace($FileName)) {
                throw "FileName parameter is required for Download action"
            }
            if ([string]::IsNullOrWhiteSpace($OutputDir)) {
                $OutputDir = $PWD
            }
        }
        'Delete' {
            if ([string]::IsNullOrWhiteSpace($FileName)) {
                throw "FileName parameter is required for Delete action"
            }
        }
        'Info' {
            if ([string]::IsNullOrWhiteSpace($FileName)) {
                throw "FileName parameter is required for Info action"
            }
        }
    }

    # Load configuration first to access FILE_OPERATIONS settings
    $config = [CordeliaConfig]::new()
    $config.LoadFromIni($ConfigPath)
    
    # Auto-enable logging if configured, or use explicit LogFile parameter
    if (-not $LogFile -and $config.FILE_OPERATIONS.enable_logging -eq 'true') {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $LogFile = "$Action-$timestamp.log"
    }
    
    # Use configured log directory if LogFile is specified
    if ($LogFile -and -not [IO.Path]::IsPathRooted($LogFile)) {
        $logDir = $config.FILE_OPERATIONS.log_directory
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $LogFile = Join-Path $logDir $LogFile
    }
    
    # Connect to device
    $connection = New-CordeliaConnection -ConfigPath $ConfigPath
    $connection.Connect()

    switch ($Action) {
        'List' {
            Write-Color Green "Getting file list from device..." -LogFile $LogFile
            $files = Get-FileList -Connection $connection
            
            if ($files.Count -eq 0) {
                Write-Color Yellow "No files found on device." -LogFile $LogFile
            } else {
                Write-Color Green "`nFiles on device ($($files.Count) total):" -LogFile $LogFile
                Write-Host ""
                Write-Host "Name".PadRight(45) + "Size".PadLeft(10) + "  Blocks".PadLeft(8) + "  Properties"
                Write-Host ("-" * 80)
                
                foreach ($file in $files) {
                    $props = if ($file.Properties.Count -gt 0) { $file.Properties -join '|' } else { 'none' }
                    Write-Host "$($file.Name.PadRight(45))$($file.MaxSize.ToString().PadLeft(10))$($file.BlocksAllocated.ToString().PadLeft(8))  $props"
                }
                
                $totalSize = ($files | Measure-Object -Property MaxSize -Sum).Sum
                $totalBlocks = ($files | Measure-Object -Property BlocksAllocated -Sum).Sum
                Write-Host ""
                Write-Color Green "Summary: $($files.Count) files, $totalSize bytes total, $totalBlocks blocks allocated" -LogFile $LogFile
            }
        }
        
        'Upload' {
            Upload-FileToDevice -Connection $connection -LocalPath $FilePath -RemoteName $RemoteFileName -SecurityConfig $config.SECURITY -IsCertificate:$IsCertificate -OverwriteExisting:$OverwriteExisting
        }
        
        'Download' {
            Write-Color Green "Reading file from device: $FileName" -LogFile $LogFile
            
            # First, read and display the file content without saving
            Write-Host "`nReading file content..."
            $fileResult = Read-DeviceFile -Connection $connection -FileName $FileName -Format $Format -SecurityConfig $config.SECURITY -FileOperationsConfig $config.FILE_OPERATIONS
            $fileContent = $fileResult.StringData
            $rawBytes = $fileResult.RawBytes
            
            # Ask user if they want to save the content to a file
            Write-Host "`nFile content displayed above."
            Write-Host "Would you like to save this content to a file? (Y/N): " -NoNewline
            $saveChoice = Read-Host
            
            if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                Write-Host "Enter full path for save file (or just filename for default download directory): " -NoNewline
                $outputPath = Read-Host
                
                # If no path specified, use original filename in configured default directory
                if ([string]::IsNullOrWhiteSpace($outputPath)) {
                    $defaultDir = $config.FILE_OPERATIONS.default_download_dir
                    if ($defaultDir -and -not (Test-Path $defaultDir)) {
                        New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
                        Write-Color Green "Created download directory: $defaultDir" -LogFile $LogFile
                    }
                    $outputPath = Join-Path $defaultDir $FileName
                }
                
                # If only filename given (no path separators), use configured default download directory
                if (-not ($outputPath.Contains('\') -or $outputPath.Contains('/'))) {
                    $defaultDir = $config.FILE_OPERATIONS.default_download_dir
                    if ($defaultDir -and -not (Test-Path $defaultDir)) {
                        New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
                        Write-Color Green "Created download directory: $defaultDir" -LogFile $LogFile
                    }
                    $outputPath = Join-Path $defaultDir $outputPath
                }
                
                # Ensure directory exists
                $directory = Split-Path $outputPath -Parent
                if ($directory -and -not (Test-Path $directory)) {
                    try {
                        New-Item -ItemType Directory -Path $directory -Force | Out-Null
                        Write-Color Green "Created directory: $directory" -LogFile $LogFile
                    } catch {
                        Write-Color Red "Failed to create directory: $directory" -LogFile $LogFile
                        return
                    }
                }
                
                # Check if file exists and handle overwrite
                if (Test-Path $outputPath) {
                    Write-Host "File '$outputPath' already exists. Overwrite? (Y/N): " -NoNewline
                    $overwriteChoice = Read-Host
                    if ($overwriteChoice -ne 'Y' -and $overwriteChoice -ne 'y') {
                        Write-Color Yellow "Save cancelled." -LogFile $LogFile
                        return
                    }
                }
                
                # Save the raw bytes to preserve exact content including line endings
                if ($Format.ToLower() -eq 'ascii') {
                    # For ASCII format, save raw bytes directly to preserve LF/CRLF exactly
                    [IO.File]::WriteAllBytes($outputPath, $rawBytes)
                } else {
                    # For other formats, use the processed string content
                    Save-FileContent -Content $fileContent -OutputPath $outputPath -Format $Format
                }
                Write-Color Green "File saved to: $outputPath" -LogFile $LogFile
            } else {
                Write-Color Green "File content displayed only (not saved)." -LogFile $LogFile
            }
        }
        
        'Delete' {
            if (Test-WildcardPattern -Pattern $FileName) {
                Write-Color Green "Deleting files matching pattern: $FileName" -LogFile $LogFile
                $deletedCount = Remove-FilesWithWildcard -Connection $connection -Pattern $FileName -Force:$Force
                if ($deletedCount -gt 0) {
                    Write-Color Green "Successfully deleted $deletedCount file(s)." -LogFile $LogFile
                }
            } else {
                Write-Color Green "Deleting single file: $FileName" -LogFile $LogFile
                Remove-SingleFile -Connection $connection -FileName $FileName -Force:$Force | Out-Null
            }
        }
        
        'Info' {
            Write-Color Green "Getting information for: $FileName" -LogFile $LogFile
            
            if (-not (Test-FileExists -Connection $connection -FileName $FileName)) {
                Write-Color Red "File '$FileName' does not exist on device." -LogFile $LogFile
                exit 1
            }
            
            $fileInfo = Get-FileInfo -Connection $connection -FileName $FileName
            
            Write-Host ""
            Write-Host "File Information for: $($fileInfo.Name)" -ForegroundColor Green
            Write-Host "===========================================" -ForegroundColor Green
            Write-Host "File Size:       $($fileInfo.FileSize) bytes"
            Write-Host "Allocated Size:  $($fileInfo.AllocatedSize) bytes"
            Write-Host "Storage Size:    $($fileInfo.StorageSize) bytes"
            Write-Host "Write Counter:   $($fileInfo.WriteCounter)"
            Write-Host "Flags:           $($fileInfo.Flags -join ', ')"
            Write-Host "Tokens:          $($fileInfo.Tokens)"
        }
        
    }

} catch {
    Write-Color Red "Error: $($_.Exception.Message)" -LogFile $LogFile
    exit 1
} finally {
    if ($connection) {
        $connection.Dispose()
    }
}
