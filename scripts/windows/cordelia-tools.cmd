@echo off
setlocal enabledelayedexpansion
title Cordelia-I Management Tools

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set Unicode-compatible output encoding
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

REM Check if we're in the right directory
if not exist "%~dp0src\utilities.psm1" (
    echo.
    echo ❌ Error: utilities.psm1 not found in src directory.
    echo    Make sure you're running this from the Cordelia tools folder.
    echo.
    pause
    exit /b 1
)

:MAIN_MENU
cls
color 0B
echo.
echo ╔══════════════════════════════════════════════════════════════════════════════════╗
echo ║                          🛡️  Cordelia-I Management Tools                         ║
echo ║                          Würth Elektronik eiSos Cordelia-I                       ║
echo ╚══════════════════════════════════════════════════════════════════════════════════╝
echo.
echo Welcome! Select a tool to use:
echo.
echo   📋 DEVICE MANAGEMENT
echo   ────────────────────────────────────────────────────────────────────────────────
echo   1. Upload Certificate         - Upload certificates using unified file manager
echo   2. Device Information         - Get device details and status  
echo   3. File Manager               - Manage files on device
echo.
echo   🔧 SYSTEM OPERATIONS
echo   ────────────────────────────────────────────────────────────────────────────────
echo   4. System Management          - Reboot device, factory reset
echo   5. Wi-Fi Management           - Scan, connect, disconnect Wi-Fi
echo.
echo   🌐 CONNECTIVITY ^& IOT
echo   ────────────────────────────────────────────────────────────────────────────────
echo   6. MQTT Management            - Connect to MQTT brokers (TCP/TLS/mTLS)
echo   7. IoT Operations             - Device provisioning and platform integration
echo.
echo   ⚙️  CONFIGURATION ^& TESTING
echo   ────────────────────────────────────────────────────────────────────────────────
echo   8. Configuration Validator    - Test settings and connection
echo   9. Setup Wizard               - First-time setup assistance
echo   10. System Check              - Verify system requirements
echo   11. Create Shortcuts          - Desktop shortcuts for tools
echo.
echo   📖 HELP ^& DOCUMENTATION
echo   ────────────────────────────────────────────────────────────────────────────────
echo   12. Quick Start Guide         - Step-by-step instructions
echo   13. Troubleshooting           - Common issues and solutions
echo   14. About                     - Version and system information
echo.
echo   15. 🚪 Exit
echo.
set /p choice="Enter your choice (1-15): "

if "%choice%"=="1" goto UPLOAD_CERT
if "%choice%"=="2" goto DEVICE_INFO
if "%choice%"=="3" goto FILE_MANAGER
if "%choice%"=="4" goto SYSTEM_MANAGEMENT
if "%choice%"=="5" goto WIFI_MANAGEMENT
if "%choice%"=="6" goto MQTT_MANAGEMENT
if "%choice%"=="7" goto IOT_OPERATIONS
if "%choice%"=="8" goto CONFIG_VALIDATOR
if "%choice%"=="9" goto SETUP_WIZARD
if "%choice%"=="10" goto SYSTEM_CHECK
if "%choice%"=="11" goto CREATE_SHORTCUTS
if "%choice%"=="12" goto QUICK_START
if "%choice%"=="13" goto TROUBLESHOOTING
if "%choice%"=="14" goto ABOUT
if "%choice%"=="15" goto EXIT

echo ❌ Invalid choice. Please try again.
timeout /t 2 >nul
goto MAIN_MENU

:UPLOAD_CERT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                          📜 Certificate Upload                         ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting Certificate Upload Tool...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\file-manager.ps1" -Action Upload -IsCertificate
goto RETURN_TO_MENU

:DEVICE_INFO
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                         📊 Device Information                          ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting Device Information Tool...
echo.
start /wait cmd /c ""%~dp0src\device-info.cmd""
goto RETURN_TO_MENU

:FILE_MANAGER
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                            📁 File Manager                             ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting File Manager...
echo.
start /wait cmd /c ""%~dp0src\file-manager.cmd""
goto RETURN_TO_MENU

:SYSTEM_MANAGEMENT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                         🔧 System Management                           ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting System Management Tool...
echo.
start /wait cmd /c ""%~dp0src\system-management.cmd""
goto RETURN_TO_MENU

:WIFI_MANAGEMENT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                          📡 Wi-Fi Management                           ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting Wi-Fi Management Tool...
echo.
start /wait cmd /c ""%~dp0src\wifi-management.cmd""
goto RETURN_TO_MENU

:MQTT_MANAGEMENT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                          🌐 MQTT Management                            ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting MQTT Management Tool...
echo.
start /wait cmd /c ""%~dp0src\mqtt-management.cmd""
goto RETURN_TO_MENU

:IOT_OPERATIONS
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                           🔗 IoT Operations                            ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting IoT Operations Tool...
echo.
start /wait cmd /c ""%~dp0src\iot-operations.cmd""
goto RETURN_TO_MENU

:CONFIG_VALIDATOR
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                       ⚙️  Configuration Validator                      ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🚀 Starting Configuration Validator...
echo.
start /wait cmd /c ""%~dp0src\config-validator.cmd""
goto RETURN_TO_MENU

:SETUP_WIZARD
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                            🚀 Setup Wizard                             ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🎯 CORDELIA-I FIRST-TIME SETUP:
echo.
echo This wizard will help you set up your Cordelia-I device for the first time.
echo.
echo 🔌 Step 1: Check Hardware Connection
echo ────────────────────────────────────────────────────────────────────
echo ✅ Connect your Cordelia-I device to your computer via USB
echo ✅ Make sure the device is powered on
echo ✅ Install device drivers if prompted by Windows
echo.
echo 🔍 Step 2: Find COM Port
echo ────────────────────────────────────────────────────────────────────
echo Scanning for USB serial devices...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host 'USB Serial Devices (likely Cordelia-I candidates):'; Write-Host '════════════════════════════════════════════════════════════════'; Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Caption -match 'COM\d+' -and ($_.Caption -match 'USB' -or $_.Caption -match 'Serial' -or $_.Caption -match 'UART' -or $_.Caption -match 'CP210' -or $_.Caption -match 'FTDI' -or $_.Caption -match 'CH340') } | ForEach-Object { $comPort = if ($_.Caption -match '(COM\d+)') { $matches[1] } else { 'Unknown' }; Write-Host \"   🔌 $comPort - $($_.Caption)\"; try { if ($_.HardwareID) { Write-Host \"      Hardware ID: $($_.HardwareID[0])\"; if ($_.HardwareID[0] -match 'VID_10C4' -or $_.HardwareID[0] -match 'CP210') { Write-Host \"      ✅ Silicon Labs CP210x - Common for Cordelia-I\" } elseif ($_.HardwareID[0] -match 'VID_0403' -or $_.HardwareID[0] -match 'FTDI') { Write-Host \"      ✅ FTDI Chip - Alternative driver\" } } } catch { } }"
echo.
echo 📌 Please select your Cordelia-I COM port:
echo ────────────────────────────────────────────────────────────────────
echo.
echo All Available COM ports:
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ports = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object; if ($ports.Count -gt 0) { for ($i = 0; $i -lt $ports.Count; $i++) { Write-Host \"   $($i + 1). $($ports[$i])\" } } else { Write-Host '   No COM ports detected' }"
echo.
echo 0. Manual entry (type COM port name)
echo.
set /p port_choice="Enter your choice (1-9 or 0): "

REM Get the selected port
if "%port_choice%"=="0" (
    set /p selected_port="Enter the COM port for your Cordelia-I device (e.g., COM3): "
    if "!selected_port!"=="" (
        echo ⚠️  No port entered. Using COM1 as default.
        set selected_port=COM1
    )
) else (
    REM Use PowerShell to get the port based on selection
    for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ports = [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object; $choice = [int]'%port_choice%' - 1; if ($choice -ge 0 -and $choice -lt $ports.Count) { $ports[$choice] } else { 'COM1' }"') do set selected_port=%%i
)

echo ✅ Selected COM port: %selected_port%
echo.
echo If your Cordelia-I device doesn't appear above, try:
echo   • Reconnecting the USB cable
echo   • Installing the device driver
echo   • Checking Device Manager for unknown devices
echo.
echo ⚙️  Step 3: Create Configuration
echo ────────────────────────────────────────────────────────────────────
echo.
echo 📋 Selected COM port: %selected_port%
echo.
set /p create_config="Would you like to create/update a configuration file? (Y/N): "
if /i "%create_config%"=="Y" (
    echo.
    echo 🔍 Checking for existing configuration files...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\setup-config.ps1" -SelectedPort "%selected_port%"
)
echo.
echo 🧪 Step 4: Test Connection
echo ────────────────────────────────────────────────────────────────────
set /p test_conn="Would you like to test the connection now? (Y/N): "
if /i "%test_conn%"=="Y" (
    echo.
    echo Testing connection using the configuration validator...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\config-validator.ps1" -TestConnection
)
echo.
echo ✨ Setup wizard completed!
echo.
echo 📋 Configuration Summary:
echo ────────────────────────────────────────────────────────────────────
echo ✅ COM Port: %selected_port%
echo ✅ Configuration file: Created/updated with default settings
echo.
echo 📝 Next Steps:
echo   • Your configuration file has been created with recommended defaults
echo   • You can customize settings by editing the config.ini file if needed
echo   • Common settings to customize: MQTT broker, certificates, file paths
echo   • Use the Configuration Validator (option 8) to review your settings
echo.
echo You can now use the other tools to manage your Cordelia-I device.
echo.
pause
goto MAIN_MENU

:SYSTEM_CHECK
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                           🔍 System Requirements Check                 ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Checking system requirements...
echo.

echo ⚙️  PowerShell Version:
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ($PSVersionTable.PSVersion.Major -ge 5) { Write-Host '   ✅ PowerShell version: ' -NoNewline; Write-Host $PSVersionTable.PSVersion } else { Write-Host '   ❌ PowerShell version too old: ' -NoNewline; Write-Host $PSVersionTable.PSVersion; Write-Host '   Please update PowerShell to 5.1 or later' }"

echo.
echo 🔌 .NET Framework Serial Port Support:
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [System.IO.Ports.SerialPort] | Out-Null; Write-Host '   ✅ .NET Framework - SerialPort class available' } catch { Write-Host '   ❌ .NET Framework issue - SerialPort class not available' }"

echo.
echo 📂 Required Files:
if exist "src\utilities.psm1" (echo    ✅ utilities.psm1) else (echo    ❌ utilities.psm1 MISSING)
if exist "src\file-manager.ps1" (echo    ✅ file-manager.ps1) else (echo    ❌ file-manager.ps1 MISSING)  
if exist "src\device-info.ps1" (echo    ✅ device-info.ps1) else (echo    ❌ device-info.ps1 MISSING)
if exist "src\config-validator.ps1" (echo    ✅ config-validator.ps1) else (echo    ❌ config-validator.ps1 MISSING)

echo.
echo 🔌 Available COM Ports with Details:
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host 'USB Serial Devices:'; Write-Host '──────────────────────────────────────────────────────────'; Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Caption -match 'COM\d+' } | ForEach-Object { $comPort = if ($_.Caption -match '(COM\d+)') { $matches[1] } else { 'Unknown' }; Write-Host \"   🔌 $comPort - $($_.Caption)\"; try { if ($_.HardwareID) { Write-Host \"      Hardware ID: $($_.HardwareID[0])\"; if ($_.HardwareID[0] -match 'VID_10C4' -or $_.HardwareID[0] -match 'CP210') { Write-Host \"      ✅ Silicon Labs CP210x - Common for Cordelia-I\" } elseif ($_.HardwareID[0] -match 'VID_0403' -or $_.HardwareID[0] -match 'FTDI') { Write-Host \"      ✅ FTDI Chip - Alternative driver\" } } } catch { } }; Write-Host ''; Write-Host 'All COM Ports:'; Write-Host '──────────────────────────────────────────────────────────'; $allPorts = [System.IO.Ports.SerialPort]::GetPortNames(); if ($allPorts.Count -gt 0) { $allPorts | ForEach-Object { Write-Host \"   📍 $_\" } } else { Write-Host '   ⚠️  No COM ports detected' }"

echo.
echo 📋 PowerShell Module Test:
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Import-Module '.\src\utilities.psm1' -Force; Write-Host '   ✅ PowerShell module loads successfully'; Remove-Module utilities -ErrorAction SilentlyContinue } catch { Write-Host '   ❌ PowerShell module failed to load:'; Write-Host '      ' $_.Exception.Message }"

echo.
goto RETURN_TO_MENU

:CREATE_SHORTCUTS
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                           🔗 Create Desktop Shortcuts                  ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo This will create convenient desktop shortcuts for quick access to tools.
echo.
echo 🔗 Shortcuts to be created:
echo    • Cordelia-I Tools.lnk        - Main menu launcher
echo    • Upload Certificate.lnk      - Direct certificate upload
echo    • Device Information.lnk      - Device status and info
echo    • File Manager.lnk            - Device file management
echo.
set /p create_shortcuts="Create desktop shortcuts? (Y/N): "
if /i "%create_shortcuts%"=="Y" (
    echo.
    echo 📝 Creating desktop shortcuts...
    
    REM Create main launcher shortcut
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Cordelia-I Tools.lnk'); $Shortcut.TargetPath = '%~dp0cordelia-tools.cmd'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.Description = 'Cordelia-I Management Tools'; $Shortcut.Save()"
    echo    ✅ Cordelia-I Tools.lnk
    
    REM Create certificate upload shortcut
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Upload Certificate.lnk'); $Shortcut.TargetPath = '%~dp0src\file-manager.cmd'; $Shortcut.Arguments = '2'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.Description = 'Upload Certificate to Cordelia-I'; $Shortcut.Save()"
    echo    ✅ Upload Certificate.lnk
    
    REM Create device info shortcut
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Device Information.lnk'); $Shortcut.TargetPath = '%~dp0src\device-info.cmd'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.Description = 'Cordelia-I Device Information'; $Shortcut.Save()"
    echo    ✅ Device Information.lnk
    
    REM Create file manager shortcut
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\File Manager.lnk'); $Shortcut.TargetPath = '%~dp0src\file-manager.cmd'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.Description = 'Cordelia-I File Manager'; $Shortcut.Save()"
    echo    ✅ File Manager.lnk
    
    echo.
    echo ✨ Desktop shortcuts created successfully!
    echo You can now access tools directly from your desktop.
) else (
    echo.
    echo ℹ️  Shortcut creation cancelled.
)
echo.
goto RETURN_TO_MENU

:QUICK_START
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                           📚 Quick Start Guide                         ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🎯 GETTING STARTED WITH CORDELIA-I:
echo.
echo 1️⃣ HARDWARE SETUP:
echo    • Connect Cordelia-I device to PC via USB cable
echo    • Ensure device is powered on (LED indicators active)
echo    • Install drivers if prompted by Windows
echo.
echo 2️⃣ FIRST TIME CONFIGURATION:
echo    • Run "Setup Wizard" from main menu (option 5)
echo    • Or manually edit config.ini with correct COM port
echo.
echo 3️⃣ VERIFY CONNECTION:
echo    • Use "Configuration Validator" (option 4)
echo    • Select "Test connection" option
echo.
echo 4️⃣ UPLOAD CERTIFICATES:
echo    • Use "Upload Certificate" tool (option 1) or File Manager (option 3)
echo    • Select your .pem, .crt, .cer, or .der file
echo    • Choose upload mode and follow on-screen prompts
echo.
echo 5️⃣ MANAGE DEVICE:
echo    • Use "Device Information" to check status
echo    • Use "File Manager" to manage stored files
echo.
echo 📄 SUPPORTED FILE FORMATS:
echo • .pem (Privacy Enhanced Mail)
echo • .crt (Certificate file)  
echo • .cer (Certificate file)
echo • .der (Distinguished Encoding Rules)
echo.
pause
goto MAIN_MENU

:TROUBLESHOOTING
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                           🔍 Troubleshooting                           ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🆘 COMMON ISSUES AND SOLUTIONS:
echo.
echo 🔴 "COM port not available" or "Access denied"
echo    💡 Solutions:
echo    • Check device is connected and powered on
echo    • Close other applications that might use the COM port
echo    • Try a different USB port
echo    • Reinstall device drivers
echo    • Use Configuration Validator to list available ports
echo.
echo 🔴 "Timeout waiting for response"
echo    💡 Solutions:
echo    • Verify correct COM port in config.ini
echo    • Check baud rate setting (should be 115200)
echo    • Try increasing timeout value in config.ini
echo    • Check USB cable quality
echo.
echo 🔴 "File already exists on device"
echo    💡 Solutions:
echo    • Use "Overwrite existing files" option in File Manager
echo    • Delete existing file using File Manager first
echo    • Use different filename for upload
echo.
echo 🔴 "Device not responding to AT commands"
echo    💡 Solutions:
echo    • Check device is in correct mode (not in sleep/hibernate)
echo    • Verify firmware compatibility
echo    • Try power cycling the device
echo    • Check for firmware updates
echo.
echo 🔴 "PowerShell execution policy errors"
echo    💡 Solutions:
echo    • Run as Administrator if needed
echo    • Use the .cmd files (they bypass execution policy)
echo    • Manually set: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
echo.
echo For more help, check the README.md file or device manual.
echo.
pause
goto MAIN_MENU

:ABOUT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                         ℹ️  About ^& System Info                       ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo 🛡️  CORDELIA-I POWERSHELL MANAGEMENT TOOLS
echo Version: 1.0
echo.
echo 🔧 Compatible Devices:
echo • Würth Elektronik eiSos Cordelia-I (2610011025010)
echo • WLAN modules with AT command interface
echo.
echo 💻 System Requirements:
echo • Windows 7/8/10/11
echo • PowerShell 5.1 or later
echo • .NET Framework 4.0 or later
echo • USB serial drivers for device
echo.
echo 📦 Tool Components:
echo • utilities.psm1 - Core PowerShell module
echo • file-manager.ps1 - Unified file system management
echo • device-info.ps1 - Device information retrieval
echo • config-validator.ps1 - Configuration validation
echo.
echo 📊 Current System Information:
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host '🐍 PowerShell Version: ' -NoNewline; $PSVersionTable.PSVersion; Write-Host '💻 OS Version: ' -NoNewline; (Get-WmiObject Win32_OperatingSystem).Caption; Write-Host '🔌 Available COM Ports: ' -NoNewline; ([System.IO.Ports.SerialPort]::GetPortNames() -join ', ')"
echo.
echo 🆘 For support and documentation:
echo • Check README.md file
echo • Visit Würth Elektronik eiSos website
echo • Contact technical support for device issues
echo.
pause
goto MAIN_MENU

:RETURN_TO_MENU
echo.
echo Press any key to return to main menu...
pause >nul
color 0B
goto MAIN_MENU

:EXIT
cls
echo.
echo ╔════════════════════════════════════════════════════════════════════════╗
echo ║                    🙏 Thank you for using Cordelia-I Tools             ║
echo ╚════════════════════════════════════════════════════════════════════════╝
echo.
echo ✨ Tools session ended.
echo.
timeout /t 3 >nul
exit /b 0
