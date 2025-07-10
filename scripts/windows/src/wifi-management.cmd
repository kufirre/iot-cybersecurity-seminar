@echo off
setlocal enabledelayedexpansion
title Cordelia-I Wi-Fi Management

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

@REM REM Set Unicode-compatible output encoding
@REM powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    Cordelia-I Wi-Fi Management                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select a Wi-Fi operation:
echo.
echo   1. 🔍 Scan Networks            - Discover available access points
echo   2. 🔗 Connect to Network       - Join a Wi-Fi network
echo   3. 🔌 Disconnect               - Leave current network
echo   4. 📊 Connection Status        - Check current Wi-Fi status
echo   5. 📚 Help
echo   6. 🚪 Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto SCAN
if "%choice%"=="2" goto CONNECT
if "%choice%"=="3" goto DISCONNECT
if "%choice%"=="4" goto STATUS
if "%choice%"=="5" goto SHOW_HELP
if "%choice%"=="6" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:SCAN
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔍 Scan Wi-Fi Networks                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Scanning for available Wi-Fi networks...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action Scan
goto SHOW_RESULT

:CONNECT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔗 Connect to Wi-Fi Network                 ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Choose connection method:
echo   1. 📡 Scan and select network
echo   2. ⌨️  Manual network entry
echo.
set /p connect_method="Select method (1-2): "

if "%connect_method%"=="1" goto SCAN_AND_CONNECT
if "%connect_method%"=="2" goto MANUAL_CONNECT

echo Invalid choice. Please try again.
pause
goto CONNECT

:SCAN_AND_CONNECT
echo.
echo 🔍 Scanning for available networks...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action ScanAndConnect
goto SHOW_RESULT

:MANUAL_CONNECT
echo.
set /p ssid="Enter network SSID: "
if "%ssid%"=="" (
    echo SSID is required.
    pause
    goto CONNECT
)

echo.
echo Security Types:
echo   1. OPEN (No password)
echo   2. WPA/WPA2 (Most common)
echo   3. WEP (Legacy)
echo   4. WEP_SHARED (Legacy shared key)
echo   5. WPA_ENT (Enterprise)
echo   6. WPS_PBC (Push button)
echo   7. WPS_PIN (PIN-based)
echo   8. WPA2_PLUS (WPA2+)
echo   9. WPA3 (Latest standard)
echo.
set /p sec_type="Select security type (1-9): "

if "%sec_type%"=="1" set SECURITY_TYPE=OPEN
if "%sec_type%"=="2" set SECURITY_TYPE=WPA_WPA2
if "%sec_type%"=="3" set SECURITY_TYPE=WEP
if "%sec_type%"=="4" set SECURITY_TYPE=WEP_SHARED
if "%sec_type%"=="5" set SECURITY_TYPE=WPA_ENT
if "%sec_type%"=="6" set SECURITY_TYPE=WPS_PBC
if "%sec_type%"=="7" set SECURITY_TYPE=WPS_PIN
if "%sec_type%"=="8" set SECURITY_TYPE=WPA2_PLUS
if "%sec_type%"=="9" set SECURITY_TYPE=WPA3

if not defined SECURITY_TYPE (
    echo Invalid security type.
    pause
    goto CONNECT
)

if "%SECURITY_TYPE%"=="OPEN" (
    echo.
    echo 🔗 Connecting to open network: %ssid%
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action Connect -SSID "%ssid%" -SecurityType %SECURITY_TYPE%
) else (
    set /p password="Enter network password: "
    if "%password%"=="" (
        echo Password is required for secured networks.
        pause
        goto CONNECT
    )
    
    echo.
    echo 🔗 Connecting to secured network: %ssid%
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action Connect -SSID "%ssid%" -SecurityType %SECURITY_TYPE% -SecurityKey "%password%"
)
goto SHOW_RESULT

:DISCONNECT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔌 Disconnect from Wi-Fi                    ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p confirm="Disconnect from current Wi-Fi network? (Y/N): "
if /i "%confirm%" neq "Y" goto MAIN_MENU

echo.
echo 🔌 Disconnecting from Wi-Fi network...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action Disconnect
goto SHOW_RESULT

:STATUS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      📊 Wi-Fi Connection Status                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 📊 Checking Wi-Fi connection status...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0wifi-management.ps1" -Action Status
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                              Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🛠️  CORDELIA-I WI-FI MANAGEMENT
echo.
echo 🔍 NETWORK SCANNING:
echo    • Discovers available access points in range
echo    • Shows network name (SSID), security type, and signal strength
echo    • Displays channel information and encryption details
echo    • Results are sorted by signal strength (strongest first)
echo.
echo 🔗 NETWORK CONNECTION:
echo    • Connects to Wi-Fi networks using various security types
echo    • Supports open networks (no password required)
echo    • Supports WPA/WPA2 (most common home/office networks)
echo    • Supports legacy WEP and enterprise WPA configurations
echo    • Supports modern WPA3 and WPS connection methods
echo.
echo 🔌 NETWORK DISCONNECTION:
echo    • Cleanly disconnects from current Wi-Fi network
echo    • Preserves device network configuration for future use
echo    • Safe to use when switching between networks
echo.
echo 📊 STATUS MONITORING:
echo    • Shows current connection status
echo    • Displays connected network information
echo    • Use this to verify successful connections
echo.
echo 🔧 SUPPORTED SECURITY TYPES:
echo    • OPEN: No encryption (public networks)
echo    • WPA/WPA2: Most common secured networks
echo    • WEP: Legacy encryption (not recommended)
echo    • WPA_ENT: Enterprise networks with authentication server
echo    • WPS_PBC: Wi-Fi Protected Setup with push button
echo    • WPS_PIN: Wi-Fi Protected Setup with PIN code
echo    • WPA2_PLUS: Enhanced WPA2 with additional features
echo    • WPA3: Latest security standard (most secure)
echo.
echo 🔧 REQUIREMENTS:
echo    • Cordelia-I device connected via USB
echo    • Valid configuration in config.ini
echo    • Device must be responsive to AT commands
echo    • Wi-Fi antenna must be properly connected
echo.
echo 💡 TIPS:
echo    • Scan networks before attempting to connect
echo    • Use Status to verify successful connections
echo    • Stronger signal networks provide better performance
echo    • Some networks may require additional setup steps
echo.
echo 🌐 NETWORK SELECTION:
echo    • Choose networks with strong signal strength (above -70 dBm)
echo    • Prefer WPA2/WPA3 networks for better security
echo    • Avoid WEP networks when possible (security risk)
echo    • Consider network congestion on busy channels
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo Press any key to return to main menu...
pause >nul
color 0B
goto MAIN_MENU

:EXIT
echo.
echo Thank you for using Cordelia-I Wi-Fi Management!
timeout /t 2 >nul
exit /b 0