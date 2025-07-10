# Enhanced Cordelia-I Communication Module
# Now includes file reading capabilities and proper parameter handling

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This module requires PowerShell 5.0 or newer. Current version: $($PSVersionTable.PSVersion)"
}

class CordeliaConfig {
    [hashtable]$UART
    [hashtable]$SECURITY
    [hashtable]$MQTT
    [hashtable]$FILE_OPERATIONS
    [string]$ConfigPath
    
    CordeliaConfig() {
        $this.UART = @{}
        $this.SECURITY = @{}
        $this.MQTT = @{}
        $this.FILE_OPERATIONS = @{}
    }
    
    [void]LoadFromIni([string]$IniPath) {
        if (-not (Test-Path $IniPath)) { 
            throw "Config file not found: $IniPath" 
        }
        
        $this.ConfigPath = $IniPath
        $ini = Get-Content $IniPath
        $section = ''
        foreach ($line in $ini) {
            $line = $line.Trim()
            if (!$line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
            if ($line -match '^\[(.*)\]$') { 
                $section = $matches[1].ToUpper()
                continue 
            }
            if ($line -match '^(.*?)=(.*)$') {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim()
                if ($section -and $this.PSObject.Properties.Name -contains $section) {
                    $convertedVal = $this.ConvertConfigValue($section, $key, $val)
                    $this.$section[$key] = $convertedVal
                }
            }
        }
        
        $this.SetDefaults()
        $this.ValidateConfig()
    }
    
    [object]ConvertConfigValue([string]$Section, [string]$Key, [string]$Value) {
        $intKeys = @{
            'UART' = @('baudrate', 'databits', 'stopbits', 'timeout')
            'SECURITY' = @('chunk_size', 'max_retries')
            'MQTT' = @('port', 'keepalive')
            'FILE_OPERATIONS' = @('read_chunk_size', 'max_download_size')
        }
        
        if ($intKeys.ContainsKey($Section) -and $intKeys[$Section] -contains $Key) {
            try {
                return [int]$Value
            } catch {
                Write-Warning "Failed to convert $Section.$Key value '$Value' to integer, using as string"
                return $Value
            }
        }
        
        # Handle boolean values
        if ($Value -eq 'true' -or $Value -eq 'false') {
            return [bool]::Parse($Value)
        }
        
        return $Value
    }
    
    [void]SetDefaults() {
        # Define defaults with enhanced file operation settings
        $defaults = @{
            'UART' = @{
                port = 'COM1'
                baudrate = 115200
                databits = 8
                parity = 'N'
                stopbits = 1
                timeout = 30
            }
            'SECURITY' = @{
                certificate_name = 'certificate.pem'
                chunk_size = 512
                encoding = 'base64'
                max_retries = 3
                verify_upload = $true
            }
            'MQTT' = @{
                broker = ''
                port = 8883
                client_id = ''
                use_tls = $true
            }
            'FILE_OPERATIONS' = @{
                confirm_overwrite = $true
                show_progress = $true
                enable_logging = $false
                log_directory = './logs'
                default_download_dir = './downloads'
                read_chunk_size = 1024
                max_download_size = 10485760  # 10MB
            }
        }
        
        # Apply defaults for each section
        foreach ($sectionName in $defaults.Keys) {
            foreach ($key in $defaults[$sectionName].Keys) {
                if (-not $this.$sectionName.ContainsKey($key)) {
                    $this.$sectionName[$key] = $defaults[$sectionName][$key]
                }
            }
        }
    }
    
    [void]ValidateConfig() {
        $validBaudRates = @(9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600)
        if ($validBaudRates -notcontains $this.UART.baudrate) {
            Write-Warning "Unusual baud rate: $($this.UART.baudrate)"
        }
        
        if ($this.SECURITY.chunk_size -lt 64 -or $this.SECURITY.chunk_size -gt 1024) {
            throw "Invalid chunk_size: $($this.SECURITY.chunk_size). Must be between 64 and 1024 bytes (limited by CC3200/CC3220 UART DMA buffer size)."
        }
        
        if ($this.FILE_OPERATIONS.read_chunk_size -lt 64 -or $this.FILE_OPERATIONS.read_chunk_size -gt 4096) {
            Write-Warning "Read chunk size $($this.FILE_OPERATIONS.read_chunk_size) may not be optimal. Recommended: 1024-2048 bytes."
        }
    }
}

class CordeliaUartConnection {
    [System.IO.Ports.SerialPort]$Port
    [hashtable]$Config
    [bool]$IsConnected
    
    CordeliaUartConnection([hashtable]$UartConfig) {
        $this.Config = $UartConfig
        $this.Port = New-Object System.IO.Ports.SerialPort
        $this.IsConnected = $false
        $this.ConfigurePort()
    }
    
    [void]ConfigurePort() {
        $this.Port.PortName = $this.Config.port
        $this.Port.BaudRate = $this.Config.baudrate
        $this.Port.DataBits = $this.Config.databits
        
        switch ($this.Config.parity) {
            'E' { $this.Port.Parity = [System.IO.Ports.Parity]::Even }
            'O' { $this.Port.Parity = [System.IO.Ports.Parity]::Odd }
            default { $this.Port.Parity = [System.IO.Ports.Parity]::None }
        }
        
        switch ($this.Config.stopbits) {
            2 { $this.Port.StopBits = [System.IO.Ports.StopBits]::Two }
            default { $this.Port.StopBits = [System.IO.Ports.StopBits]::One }
        }
        
        $this.Port.ReadTimeout = $this.Config.timeout * 1000
        $this.Port.WriteTimeout = $this.Config.timeout * 1000
    }
    
    [void]Connect() {
        if ($this.IsConnected) {
            Write-Color Yellow "Already connected to $($this.Port.PortName)"
            return
        }
        
        Write-Color Green "Opening $($this.Port.PortName)..."
        $this.Port.Open()
        $this.IsConnected = $true
        Write-Color Green "Serial connection established."
    }
    
    [void]Disconnect() {
        if ($this.Port.IsOpen) {
            $this.Port.Close()
            $this.IsConnected = $false
            Write-Color Green "Serial connection closed."
        }
    }
    
    [string]SendCommand([string]$Command, [string]$ExpectedResponse = 'OK', [int]$TimeoutMs = 5000) {
        if (-not $this.IsConnected) {
            throw "UART connection not established. Call Connect() first."
        }
        
        return Send-AT -Port $this.Port -Cmd $Command -Expect $ExpectedResponse -TimeoutMs $TimeoutMs
    }
    
    [void]Dispose() {
        $this.Disconnect()
        if ($this.Port) {
            $this.Port.Dispose()
        }
    }
}

function Write-Color {
    param(
        [ConsoleColor]$Color,
        [string]$Text,
        [string]$LogFile = $null
    )
    $Host.UI.RawUI.ForegroundColor = $Color
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logMessage = "[$timestamp]`r`n$Text`r`n"
    Write-Host $logMessage
    # Always reset to Cyan to match the batch file's color scheme
    # $Host.UI.RawUI.ForegroundColor = [ConsoleColor]::Cyan
    
    if ($LogFile) {
        # Ensure log directory exists
        $logDir = [IO.Path]::GetDirectoryName($LogFile)
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logMessage -Encoding UTF8
    }
}

function Send-AT {
    param(
        [System.IO.Ports.SerialPort]$Port,
        [string]$Cmd,
        [string]$Expect = 'OK',
        [int]$TimeoutMs = 5000
    )
    
    Write-Color White "$Cmd"
    $Port.DiscardInBuffer()
    Start-Sleep -Milliseconds 50
    $Port.Write("$Cmd`r`n")
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $buf = ''
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if ($Port.BytesToRead -gt 0) {
            $newData = $Port.ReadExisting()
            $buf += $newData
            if ($buf -match $Expect -or $buf -match '(?i)error') { 
                Start-Sleep -Milliseconds 10
                if ($Port.BytesToRead -gt 0) {
                    $buf += $Port.ReadExisting()
                }
                break 
            }
        }
        Start-Sleep -Milliseconds 20
    }
    if ($sw.ElapsedMilliseconds -ge $TimeoutMs) {
        Write-Color Red "$buf"
        throw "Timeout waiting for '$Expect'"
    }
    # Check for error response (case-insensitive)
    if ($buf -ilike "*ERROR: process command,*") {
        # Extract error code using simpler string manipulation (case-insensitive)
        $errorPart = $buf -split "(?i)ERROR: process command," | Select-Object -Last 1
        $errorCode = ($errorPart -split "\r?\n" | Select-Object -First 1).Trim()
        $errorCodeInt = [int]$errorCode
        $errorMessage = Get-ErrorMessage -ErrorCode $errorCodeInt
        throw "$Cmd`r`n($errorCodeInt): $errorMessage"
    }
    return $buf
}

function Get-ErrorMessage {
    param([int]$ErrorCode)
    
    # Comprehensive error message lookup table
    $errorLookup = @{
        # File System Errors
        -10326 = "The file already exists on the module."
        -10341 = "The specified file does not exist."
        -10322 = "Insufficient storage space on the module."
        -10335 = "The file handle is invalid."
        -10336 = "Failed to write to the file."
        -10337 = "The specified offset is out of range."
        -10338 = "Not enough memory to complete the operation."
        -10325 = "Invalid access type specified."
        -10330 = "Invalid file mode specified."
        -10343 = "Invalid arguments provided to the file operation."
        -10324 = "The file system is busy."
        -10323 = "File system initialization was not called."
        -10369 = "The file is already open."
        -10370 = "The file is already open for writing."
        -10351 = "The operation is not supported."
        -10350 = "Failed to read from non-volatile memory."
        -10321 = "Failed to read file system from non-volatile memory."
        -10348 = "No file system exists."
        -10346 = "Unknown file system error."
        -10339 = "Invalid length for read operation."
        -10340 = "Wrong file open flags specified."
        -10342 = "Commit rollback flag is not supported upon creation."
        -10344 = "File is pending commit."
        -10347 = "File name is reserved."
        -10349 = "Invalid magic number in file."
        -10331 = "Failed to read NV file."
        -10332 = "Failed to initialize storage."
        -10333 = "File has no failsafe protection."
        -10334 = "No valid copy exists."
        
        # Security and Certificate Errors
        -10241 = "Extraction will start after reset."
        -10242 = "No certificate store available."
        -10243 = "Image should be authenticated."
        -10244 = "Image should be encrypted."
        -10245 = "Image can't be encrypted."
        -10246 = "Development board wrong MAC."
        -10247 = "Device not secured."
        -10248 = "System file access denied."
        -10273 = "Certificate in the chain revoked - security alert."
        -10274 = "Failed to initialize certificate store."
        -10286 = "File is not secure and signed."
        -10287 = "Root CA is unknown."
        -10289 = "Wrong signature - security alert."
        -10290 = "Wrong signature or certificate name length."
        -10292 = "Certificate chain error - security alert."
        -10300 = "Security alert."
        -10302 = "Invalid token."
        -10304 = "Secure content integrity failure."
        -10305 = "Secure content retrieve asymmetric key error."
        -10345 = "Secure content session already exists."
        -10354 = "Config file checksum error - security alert."
        -10358 = "Certificate store downgrade."
        -10365 = "Invalid token - security alert."
        -10366 = "Not secure."
        -10371 = "Alerts cannot be set on non-secure device."
        -10372 = "Wrong certificate file name."
        
        # Programming and Image Errors
        -10249 = "Image extract expecting user key."
        -10250 = "Image extract failed to close file."
        -10251 = "Image extract failed to write file."
        -10252 = "Image extract failed to open file."
        -10253 = "Image extract failed to get image header."
        -10254 = "Image extract failed to get image info."
        -10255 = "Image extract set ID does not exist."
        -10256 = "Image extract failed to delete file."
        -10257 = "Image extract failed to format filesystem."
        -10258 = "Image extract failed to load filesystem."
        -10259 = "Image extract failed to get device info."
        -10260 = "Image extract failed to delete storage."
        -10261 = "Image extract incorrect image location."
        -10262 = "Image extract failed to create image file."
        -10263 = "Image extract failed to initialize."
        -10264 = "Image extract failed to load file table."
        -10266 = "Image extract illegal command."
        -10267 = "Image extract failed to write FAT."
        -10268 = "Image extract failed to restore factory defaults."
        -10269 = "Image extract failed to read NV."
        -10270 = "Programming image does not exist."
        -10271 = "Programming in process."
        -10272 = "Programming already started."
        -10275 = "Programming illegal file."
        -10276 = "Programming not started."
        -10277 = "Image extract no file system."
        -10359 = "Programming image not valid."
        -10360 = "Programming image not verified."
        -10367 = "Reset during programming."
        
        # Memory and Resource Errors  
        -10278 = "Wrong input size."
        -10288 = "File has not been closed correctly."
        -10291 = "Not 16-byte aligned."
        -10293 = "File name already exists."
        -10294 = "Extended buffer already allocated."
        -10295 = "File system not secured."
        -10296 = "Offset not 16-byte aligned."
        -10297 = "Failed to read NVMEM."
        -10298 = "Wrong file name."
        -10299 = "File system is locked."
        -10301 = "File has invalid size."
        -10303 = "No device is loaded."
        -10306 = "Overlap detection threshold."
        -10307 = "File has reserved NV index."
        -10310 = "File maximum size exceeded."
        -10311 = "Invalid read buffer."
        -10312 = "Invalid write buffer."
        -10313 = "File image is corrupted."
        -10314 = "Size of file extension exceeded."
        -10315 = "Warning: file name not kept."
        -10316 = "Maximum opened file count exceeded."
        -10317 = "Failed to write NVMEM header."
        -10318 = "No available NV index."
        -10319 = "Failed to allocate memory."
        -10320 = "Operation blocked by vendor."
        -10327 = "Program failure."
        -10328 = "No entries available."
        -10329 = "File access is different."
        -10352 = "JTAG is opened - no format to production."
        -10353 = "Config file return read failed."
        -10355 = "Config file does not exist."
        -10356 = "Config file memory allocation failed."
        -10357 = "Image header read failed."
        -10361 = "Reserve size is smaller."
        -10362 = "Wrong allocation table."
        -10363 = "Illegal signature."
        -10364 = "File already opened in pending state."
        -10368 = "Config file return write failed."
        
        # Bundle and File System State Errors
        -10279 = "Bundle file should be created with failsafe."
        -10280 = "Bundle does not contain files."
        -10281 = "Bundle already in state."
        -10282 = "Bundle not in correct state."
        -10283 = "Bundle files are opened."
        -10284 = "Incorrect file state for operation."
        -10285 = "Empty Serial Flash."
        
        # Network and Communication Errors
        -2073 = "Resource temporarily unavailable (EAGAIN) - operation already in progress."
    }
    
    if ($errorLookup.ContainsKey($ErrorCode)) { 
        return $errorLookup[$ErrorCode] 
    } else { 
        return "Unknown error code: $ErrorCode (consult device manual)" 
    }
}

function New-CordeliaConnection {
    param([Parameter(Mandatory)][string]$ConfigPath)
    
    $config = [CordeliaConfig]::new()
    $config.LoadFromIni($ConfigPath)
    
    Write-Color Green "Port: $($config.UART.port), Baud: $($config.UART.baudrate), Timeout: $($config.UART.timeout)s"
    
    return [CordeliaUartConnection]::new($config.UART)
}

function Convert-ToBase64 ([byte[]]$b) { [Convert]::ToBase64String($b) }
function Convert-ToHex    ([byte[]]$b) { ([BitConverter]::ToString($b)) -replace '-' }
function Convert-ToAscii  ([byte[]]$b) { [Text.Encoding]::ASCII.GetString($b) }

function Convert-FromBase64 ([string]$s) { [Convert]::FromBase64String($s) }
function Convert-FromHex    ([string]$s) { 
    $bytes = for ($i = 0; $i -lt $s.Length; $i += 2) {
        [Convert]::ToByte($s.Substring($i, 2), 16)
    }
    return [byte[]]$bytes
}
function Convert-FromAscii  ([string]$s) { [Text.Encoding]::ASCII.GetBytes($s) }

# Enhanced file upload function with better error handling and logging
function CordeliaFileUpload {
    param(
        [Parameter(Mandatory)][CordeliaUartConnection]$Connection,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][hashtable]$SecurityConfig,
        [string]$RemoteFileName = $null,
        [string]$LogFile = $null,
        [switch]$OverwriteExisting = $false
    )
    
    if (-not (Test-Path $FilePath)) { 
        throw "File not found: $FilePath" 
    }
    
    
    $raw = [IO.File]::ReadAllBytes($FilePath)
    $total = $raw.Length
    $remoteName = $SecurityConfig.certificate_name
    if ($RemoteFileName) {
        $remoteName = $RemoteFileName
    }
    
    Write-Color Green "Uploading $FilePath as $remoteName ($total bytes)" -LogFile $LogFile
    
    # Note: We don't need to check if file exists first - FILEOPEN with WRITE|CREATE will handle it
    # If the file exists and device doesn't support overwriting, FILEOPEN will fail with appropriate error
    
    # Create file - add OVERWRITE flag if requested
    $fileFlags = if ($OverwriteExisting) { "OVERWRITE|CREATE" } else { "WRITE|CREATE" }
    $openCmd = "AT+FILEOPEN=`"$remoteName`",$fileFlags,$total"
    
    try {
        $openResponse = $Connection.SendCommand($openCmd, "OK", ($Connection.Config.timeout * 1000))
        
        if ($openResponse -match '\+fileopen\s*:\s*(\d+)') {
            $handle = $matches[1]
            Write-Color Green "File opened with handle: $handle" -LogFile $LogFile
        } else {
            throw "Failed to get file handle from response: $openResponse"
        }
    } catch {
        # Send-AT already handles error code extraction and Get-ErrorMessage lookup
        # Just pass through the properly formatted error message
        throw $_.Exception.Message
    }
    
    # Upload chunks
    $offset = 0
    $chunkIdx = 0
    $totalChunks = [Math]::Ceiling($total / $SecurityConfig.chunk_size)
    
    try {
        while ($offset -lt $total) {
            $endIndex = [Math]::Min($offset + $SecurityConfig.chunk_size - 1, $total - 1)
            $chunk = $raw[$offset..$endIndex]
            
            # Use encoding setting from configuration
            $formatCode = switch ($SecurityConfig.encoding.ToLower()) {
                'base64' { 
                    $encoded = Convert-ToBase64 $chunk
                    1  # Base64 format code
                }
                'ascii' { 
                    $encoded = [System.Text.Encoding]::ASCII.GetString($chunk)
                    0  # ASCII format code
                }
                default { 
                    $encoded = Convert-ToBase64 $chunk
                    1  # Default to Base64
                }
            }
            
            # Print upload progress
            $percent = [Math]::Round(($chunkIdx / $totalChunks) * 100, 1)
            Write-Color White "Uploading chunk $($chunkIdx + 1)/$totalChunks ($($chunk.Length) bytes) - $percent%" -LogFile $LogFile
            
            $writeCmd = "AT+FILEWRITE=$handle,$offset,$formatCode,$($chunk.Length),$encoded"
            $Connection.SendCommand($writeCmd, 'OK', ($Connection.Config.timeout * 3000)) | Out-Null
            
            if ($LogFile) {
                Write-Color Gray "Chunk $($chunkIdx + 1): $($chunk.Length) bytes at offset $offset" -LogFile $LogFile
            }
            
            $offset += $chunk.Length
            $chunkIdx++
        }
        
        Write-Color Green "Upload completed: $remoteName ($total bytes)" -LogFile $LogFile
        
        # Close file - note the double comma for optional parameters
        $closeCmd = "AT+FILECLOSE=$handle,,"
        $Connection.SendCommand($closeCmd, 'OK', ($Connection.Config.timeout * 1000)) | Out-Null
        
        Write-Color Green "Upload complete: $chunkIdx chunks, $total bytes transferred" -LogFile $LogFile
        
    } catch {
        # If upload fails, try to close the file handle to clean up
        try {
            $Connection.SendCommand("AT+FILECLOSE=$handle,,", 'OK', ($Connection.Config.timeout * 1000))
            Write-Color Yellow "File handle cleaned up after upload failure" -LogFile $LogFile
        } catch {
            Write-Color Red "Failed to cleanup file handle after upload error" -LogFile $LogFile
        }
        throw "Upload failed: $($_.Exception.Message)"
    }
}

# New function for reading files from device
function CordeliaFileDownload {
    param(
        [Parameter(Mandatory)][CordeliaUartConnection]$Connection,
        [Parameter(Mandatory)][string]$RemoteFileName,
        [string]$LocalPath = $null,
        [ValidateSet('base64', 'hex', 'ascii')]
        [string]$Format = 'base64',
        [int]$ChunkSize = 1024,
        [string]$LogFile = $null
    )
    
    Write-Color Green "Downloading $RemoteFileName from device" -LogFile $LogFile
    
    # Check if file exists first
    try {
        $infoCmd = "AT+FILEGETINFO=`"$RemoteFileName`","
        $infoResponse = $Connection.SendCommand($infoCmd, "OK", ($Connection.Config.timeout * 1000))
        
        # Clean the response to ensure proper parsing
        $cleanInfoResponse = $infoResponse -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
        
        if ($cleanInfoResponse -match '(?i)\+filegetinfo:([^,]*),(\d+),(\d+),([^,]*),(\d+),(\d+)') {
            $fileSize = [int]$matches[2]
            Write-Color Green "File size: $fileSize bytes" -LogFile $LogFile
        } else {
            throw "Could not parse file info response: $cleanInfoResponse"
        }
    } catch {
        if ($_.Exception.Message -match "-10341") {
            throw "File '$RemoteFileName' does not exist on device"
        } else {
            throw "Failed to get file info: $($_.Exception.Message)"
        }
    }
    
    # Open file for reading - note the trailing comma for optional size parameter
    $openCmd = "AT+FILEOPEN=`"$RemoteFileName`",READ,"
    
    try {
        $openResponse = $Connection.SendCommand($openCmd, "OK", ($Connection.Config.timeout * 1000))
        
        if ($openResponse -match '\+fileopen\s*:\s*(\d+)') {
            $handle = $matches[1]
            Write-Color Green "File opened for reading with handle: $handle" -LogFile $LogFile
        } else {
            throw "Failed to get file handle from response: $openResponse"
        }
    } catch {
        throw "Failed to open file for reading: $($_.Exception.Message)"
    }
    
    # Read file in chunks
    $offset = 0
    $allData = @()
    $chunkIdx = 0
    $totalChunks = [Math]::Ceiling($fileSize / $ChunkSize)
    
    # Format code: 1 for base64, 0 for others
    $formatCode = switch ($Format.ToLower()) {
        'base64' { 1 }
        'hex' { 0 }
        'ascii' { 0 }
        default { 1 }
    }
    
    try {
        while ($offset -lt $fileSize) {
            $remainingBytes = $fileSize - $offset
            $readSize = [Math]::Min($ChunkSize, $remainingBytes)
            
            # Print download progress
            $percent = [Math]::Round(($offset / $fileSize) * 100, 1)
            Write-Color White "Downloading chunk $($chunkIdx + 1)/$totalChunks - $percent%" -LogFile $LogFile
            
            # AT+FILEREAD=handle,offset,length,format
            $readCmd = "AT+FILEREAD=$handle,$offset,$readSize,$formatCode"
            $readResponse = $Connection.SendCommand($readCmd, 'OK', ($Connection.Config.timeout * 3000))
            
            # Parse response: +fileread:actualLength,data
            if ($readResponse -match '(?i)\+fileread:(\d+),(.+)') {
                $actualLength = [int]$matches[1]
                $data = $matches[2].Trim()
                $allData += $data
                $offset += $actualLength
                $chunkIdx++
                
                if ($LogFile) {
                    Write-Color Gray "Read chunk ${chunkIdx}: ${actualLength} bytes at offset ${($offset - $actualLength)}" -LogFile $LogFile
                }
            } else {
                throw "Failed to parse read response: $readResponse"
            }
        }
        
        Write-Color Green "Download completed: $RemoteFileName" -LogFile $LogFile
        
        # Close the file - note the double comma for optional parameters
        $closeCmd = "AT+FILECLOSE=$handle,,"
        $Connection.SendCommand($closeCmd, 'OK', ($Connection.Config.timeout * 1000)) | Out-Null
        
        # Combine all data chunks
        $combinedData = $allData -join ''
        Write-Color Green "Download complete: $chunkIdx chunks, $fileSize bytes received" -LogFile $LogFile
        
        # Convert and save data based on format
        if ($LocalPath) {
            $directory = [IO.Path]::GetDirectoryName($LocalPath)
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            
            switch ($Format.ToLower()) {
                'base64' {
                    $bytes = Convert-FromBase64 $combinedData
                    [IO.File]::WriteAllBytes($LocalPath, $bytes)
                }
                'hex' {
                    $bytes = Convert-FromHex $combinedData
                    [IO.File]::WriteAllBytes($LocalPath, $bytes)
                }
                'ascii' {
                    [IO.File]::WriteAllText($LocalPath, $combinedData, [Text.Encoding]::ASCII)
                }
            }
            Write-Color Green "File saved to: $LocalPath" -LogFile $LogFile
        }
        
        return $combinedData
        
    } catch {
        # Cleanup file handle on error
        try {
            $Connection.SendCommand("AT+FILECLOSE=$handle,,", 'OK', ($Connection.Config.timeout * 1000))
            Write-Color Yellow "File handle cleaned up after download failure" -LogFile $LogFile
        } catch {
            Write-Color Red "Failed to cleanup file handle after download error" -LogFile $LogFile
        }
        throw "Download failed: $($_.Exception.Message)"
    }
}

# Enhanced device information function
function Get-CordeliaDeviceInfo {
    param([Parameter(Mandatory)][CordeliaUartConnection]$Connection)
    
    try {
        # Get basic device info
        $deviceInfo = @{}
        
        # Try to get device identification
        try {
            $response = $Connection.SendCommand("AT+GMI", "OK", ($Connection.Config.timeout * 1000))
            if ($response -match '(\w+)') {
                $deviceInfo.Manufacturer = $matches[1]
            }
        } catch {
            $deviceInfo.Manufacturer = "Unknown"
        }
        
        try {
            $response = $Connection.SendCommand("AT+GMM", "OK", ($Connection.Config.timeout * 1000))
            if ($response -match '(\w+)') {
                $deviceInfo.Model = $matches[1]
            }
        } catch {
            $deviceInfo.Model = "Unknown"
        }
        
        try {
            $response = $Connection.SendCommand("AT+GMR", "OK", ($Connection.Config.timeout * 1000))
            if ($response -match '(\S+)') {
                $deviceInfo.Firmware = $matches[1]
            }
        } catch {
            $deviceInfo.Firmware = "Unknown"
        }
        
        # Get file system info
        try {
            $fileList = $Connection.SendCommand("AT+fileGetFileList", "OK", ($Connection.Config.timeout * 1000))
            $fileCount = ($fileList -split "`n" | Where-Object { $_ -match '\+filegetfilelist:' }).Count
            $deviceInfo.FileCount = $fileCount
        } catch {
            $deviceInfo.FileCount = "Unknown"
        }
        
        return $deviceInfo
        
    } catch {
        throw "Failed to get device information: $($_.Exception.Message)"
    }
}

# Export all enhanced functions
Export-ModuleMember -Function @(
    'Write-Color',
    'Send-AT', 
    'Get-ErrorMessage',
    'New-CordeliaConnection',
    'CordeliaFileUpload',
    'CordeliaFileDownload',
    'Get-CordeliaDeviceInfo',
    'Convert-ToBase64',
    'Convert-ToHex',
    'Convert-ToAscii',
    'Convert-FromBase64',
    'Convert-FromHex',
    'Convert-FromAscii'
)