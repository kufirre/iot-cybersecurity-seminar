<#
.SYNOPSIS
    Upload a certificate to the Cordelia-I module over its AT-command UART.

.DESCRIPTION
    – Reads UART / security settings from ..\common\config.ini (or ..\config.ini)  
    – Opens the file on the module with AT+FILEOPEN  
    – Streams the data in chunks with AT+FILEWRITE  
    – Closes the handle with AT+FILECLOSE  

.NOTES
    Cordelia default UART settings are 115200-8-N-1 :contentReference[oaicite:0]{index=0}
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$CertificatePath = ''
)

$ErrorActionPreference = 'Stop'

function Write-Color {
    param(
        [ConsoleColor]$Color,
        [string]$Text
    )
    $old = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.ForegroundColor = $old
}

function Send-AT {
    param(
        [System.IO.Ports.SerialPort]$Port,
        [string]$Cmd,
        [string]$Expect = 'OK',
        [int]$TimeoutMs = 5000
    )

    Write-Color Magenta "--> $Cmd"
    $Port.DiscardInBuffer()                 # flush stale bytes
    Start-Sleep -Milliseconds 50            # give device time to be ready
    $Port.Write("$Cmd`r")                   # send CR only

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $buf = ''

    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if ($Port.BytesToRead) {
            $newData = $Port.ReadExisting()
            $buf += $newData
            if ($buf -match $Expect) { 
                Start-Sleep -Milliseconds 10  # let any remaining data arrive
                if ($Port.BytesToRead) {
                    $buf += $Port.ReadExisting()  # grab any final data
                }
                break 
            }
        }
        Start-Sleep -Milliseconds 20
    }

    $clean = $buf -replace '\r\n', ' | ' -replace '\r', ' | ' -replace '\n', ' | '
    Write-Color DarkCyan "<-- $clean"
    if ($sw.ElapsedMilliseconds -ge $TimeoutMs) {
        throw "Timeout waiting for '$Expect'"
    }
    return $buf
}

function Convert-ToBase64 ([byte[]]$b) { [Convert]::ToBase64String($b) }
function Convert-ToHex    ([byte[]]$b) { ([BitConverter]::ToString($b)) -replace '-' }
function Convert-ToAscii  ([byte[]]$b) { [Text.Encoding]::ASCII.GetString($b) }

#--- Certificate path prompt ---------------------------------------------------
if ([string]::IsNullOrWhiteSpace($CertificatePath)) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = (Resolve-Path '..\..\resources').Path
    $dlg.Filter           = 'Certificate files (*.pem;*.crt;*.cer;*.der)|*.pem;*.crt;*.cer;*.der'
    $dlg.Title            = 'Select Certificate File'

    if ($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
        Write-Color Red 'No certificate selected – exiting.' ; exit 1
    }
    $CertificatePath = $dlg.FileName
}
Write-Color Cyan "Certificate: $CertificatePath"
if (-not (Test-Path $CertificatePath)) { throw "File not found." }

#--- Config file ---------------------------------------------------------------
$config = @{ UART = @{}; SECURITY = @{} }
$iniPath = @(Resolve-Path '..\common\config.ini','..\config.ini' | Where-Object { Test-Path $_ })[0]
$ini    = Get-Content $iniPath
$section = ''
foreach ($l in $ini) {
    $line = $l.Trim()
    if (!$line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
    if ($line -match '^[\[](.*)[\]]$') { $section = $matches[1].ToUpper(); continue }
    if ($line -match '^(.*?)=(.*)$') {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim()
        if ($section -and $config.ContainsKey($section)) {
            $config[$section][$key] = $val
        }
    }
}

# defaults (no null-coalescing, no ternary, no switch expressions)
$uartConf = @{
    port     = if ($config['UART'].ContainsKey('port'))     { $config['UART']['port'] }     else { 'COM1' }
    baudrate = if ($config['UART'].ContainsKey('baudrate')) { [int]$config['UART']['baudrate'] } else { 115200 }
    databits = if ($config['UART'].ContainsKey('databits')) { [int]$config['UART']['databits'] } else { 8 }
    parity   = if ($config['UART'].ContainsKey('parity'))   { $config['UART']['parity'].ToUpper() } else { 'N' }
    stopbits = if ($config['UART'].ContainsKey('stopbits')) { [int]$config['UART']['stopbits'] } else { 1 }
    timeout  = if ($config['UART'].ContainsKey('timeout'))  { [int]$config['UART']['timeout'] }  else { 30 }
}
$secConf = @{
    certificate_name = if ($config['SECURITY'].ContainsKey('certificate_name')) { $config['SECURITY']['certificate_name'] } else { 'certificate.pem' }
    chunk_size       = if ($config['SECURITY'].ContainsKey('chunk_size'))       { [int]$config['SECURITY']['chunk_size'] }       else { 512 }
    encoding         = if ($config['SECURITY'].ContainsKey('encoding'))         { $config['SECURITY']['encoding'].ToLower() }    else { 'base64' }
}

Write-Color Yellow "Port $($uartConf.port)  Baud $($uartConf.baudrate)  Chunk $($secConf.chunk_size) bytes  Encoding $($secConf.encoding)"

#--- Read file -----------------------------------------------------------------
$raw = [IO.File]::ReadAllBytes($CertificatePath)
$total = $raw.Length
Write-Color Yellow "Local file size: $total byte(s)"

#--- Serial port ---------------------------------------------------------------
$port = New-Object System.IO.Ports.SerialPort
$port.PortName     = $uartConf.port
$port.BaudRate     = $uartConf.baudrate
$port.DataBits     = $uartConf.databits
switch ($uartConf.parity) {
    'E' { $port.Parity = [System.IO.Ports.Parity]::Even }
    'O' { $port.Parity = [System.IO.Ports.Parity]::Odd }
    default { $port.Parity = [System.IO.Ports.Parity]::None }
}
switch ($uartConf.stopbits) {
    2 { $port.StopBits = [System.IO.Ports.StopBits]::Two }
    default { $port.StopBits = [System.IO.Ports.StopBits]::One }
}
$port.ReadTimeout  = $uartConf.timeout * 1000
$port.WriteTimeout = $uartConf.timeout * 1000
$port.NewLine      = "`r"                              # CR ends lines

Write-Color Yellow "Opening $($port.PortName)..."
$port.Open()
Write-Color Green  "Serial open."

try {
    # 1) FILEOPEN -------------------------------------------------------------
    Write-Color Yellow "DEBUG: secConf.certificate_name = '$($secConf.certificate_name)'"
    Write-Color Yellow "DEBUG: total = '$total'"
    Write-Color Yellow "DEBUG: About to send: AT+FILEOPEN=`"$($secConf.certificate_name)`",WRITE|CREATE,$total"
    Write-Color Yellow "DEBUG: Timeout: $($uartConf.timeout*1000)"
    $open = Send-AT -Port $port -Cmd "AT+FILEOPEN=`"$($secConf.certificate_name)`",WRITE|CREATE,$total" -Expect 'OK' -TimeoutMs ($uartConf.timeout*1000)
    if ($open -notmatch '(?i)\+fileopen\s*:\s*(\d+)\s*,\s*0') {
        throw "Handle not returned by +FILEOPEN"
    }
    $handle = $matches[1]
    Write-Color Green "File opened with handle: $handle"

    # 2) FILEWRITE loop -------------------------------------------------------
    $offset = 0; $chunkIdx = 0
    while ($offset -lt $total) {
        $endIndex = [Math]::Min($offset + $secConf.chunk_size - 1, $total - 1)
        $chunk = $raw[$offset..$endIndex]
        $encoded = switch ($secConf.encoding) {
            'hex'    { Convert-ToHex   $chunk }
            'ascii'  { Convert-ToAscii $chunk }
            default  { Convert-ToBase64 $chunk }
        }

        # Send FILEWRITE command with data included
        $cmd = "AT+FILEWRITE=$handle,$offset,$($chunk.Length),$encoded"
        Write-Color Yellow "DEBUG: Sending FILEWRITE command with data (length: $($encoded.Length) encoded, $($chunk.Length) raw bytes)"
        Send-AT $port $cmd 'OK' ($uartConf.timeout*1000)

        $offset   += $chunk.Length
        ++$chunkIdx
        $pct = [int](100 * $offset / $total)
        Write-Progress -Activity 'Upload' -Status "$pct % ($offset / $total)" -PercentComplete $pct
    }
    Write-Progress -Activity 'Upload' -Completed

    # 3) FILECLOSE ------------------------------------------------------------
    Send-AT $port "AT+FILECLOSE=$handle,," 'OK' 5000
    Write-Color Green "Upload complete - $chunkIdx chunk(s), $total byte(s)."
}
finally {
    if ($port.IsOpen) { $port.Close() ; Write-Color Green 'Serial closed.' }
}