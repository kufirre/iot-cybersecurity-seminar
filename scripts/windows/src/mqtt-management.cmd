@echo off
setlocal enabledelayedexpansion
title Cordelia-I MQTT Management

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set Unicode-compatible output encoding
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    Cordelia-I MQTT Management                    ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select an MQTT operation:
echo.
echo   1. 🔗 Connect to Broker        - Establish MQTT connection
echo   2. 📡 Subscribe to Topic       - Listen for messages
echo   3. 📤 Publish Message          - Send message to topic
echo   4. 🔌 Disconnect               - Close MQTT connection
echo   5. 📊 Connection Status        - Check current status
echo   6. 📚 Help
echo   7. 🚪 Exit
echo.
set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" goto CONNECT
if "%choice%"=="2" goto SUBSCRIBE
if "%choice%"=="3" goto PUBLISH
if "%choice%"=="4" goto DISCONNECT
if "%choice%"=="5" goto STATUS
if "%choice%"=="6" goto SHOW_HELP
if "%choice%"=="7" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:CONNECT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔗 Connect to MQTT Broker                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Connection Types:
echo   1. TCP (Standard, unencrypted)
echo   2. TLS (Encrypted with server certificate)
echo   3. mTLS (Mutual TLS with client certificate)
echo.
set /p conn_type="Select connection type (1-3): "

if "%conn_type%"=="1" set CONNECTION_TYPE=TCP
if "%conn_type%"=="2" set CONNECTION_TYPE=TLS
if "%conn_type%"=="3" set CONNECTION_TYPE=mTLS

if not defined CONNECTION_TYPE (
    echo Invalid connection type.
    pause
    goto CONNECT
)

echo.
echo Configuration for %CONNECTION_TYPE% connection:
echo.
set /p broker="Enter broker hostname/IP: "
if "%broker%"=="" (
    echo Broker is required.
    pause
    goto CONNECT
)

set /p port="Enter port (press Enter for default): "
set /p client_id="Enter client ID (press Enter for auto-generate): "
set /p username="Enter username (optional): "
set /p password="Enter password (optional): "

echo.
echo 🔗 Connecting to %broker% (%CONNECTION_TYPE%)...

if "%port%"=="" (
    if "%CONNECTION_TYPE%"=="TCP" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Connect -ConnectionType %CONNECTION_TYPE% -Broker "%broker%" -ClientId "%client_id%" -Username "%username%" -Password "%password%"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Connect -ConnectionType %CONNECTION_TYPE% -Broker "%broker%" -Port 8883 -ClientId "%client_id%" -Username "%username%" -Password "%password%"
    )
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Connect -ConnectionType %CONNECTION_TYPE% -Broker "%broker%" -Port %port% -ClientId "%client_id%" -Username "%username%" -Password "%password%"
)
goto SHOW_RESULT

:SUBSCRIBE
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      📡 Subscribe to MQTT Topic                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p topic="Enter topic to subscribe to: "
if "%topic%"=="" (
    echo Topic is required.
    pause
    goto SUBSCRIBE
)

echo.
echo Quality of Service (QoS) levels:
echo   0 - At most once (fire and forget)
echo   1 - At least once (acknowledged delivery)
echo   2 - Exactly once (assured delivery)
echo.
set /p qos="Enter QoS level (0-2, default 0): "
if "%qos%"=="" set qos=0

echo.
echo 📡 Subscribing to topic: %topic%
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Subscribe -Topic "%topic%" -QoS %qos%
goto SHOW_RESULT

:PUBLISH
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      📤 Publish MQTT Message                     ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p topic="Enter topic to publish to: "
if "%topic%"=="" (
    echo Topic is required.
    pause
    goto PUBLISH
)

set /p message="Enter message content: "
if "%message%"=="" (
    echo Message is required.
    pause
    goto PUBLISH
)

echo.
echo Quality of Service (QoS) levels:
echo   0 - At most once (fire and forget)
echo   1 - At least once (acknowledged delivery)
echo   2 - Exactly once (assured delivery)
echo.
set /p qos="Enter QoS level (0-2, default 0): "
if "%qos%"=="" set qos=0

echo.
echo 📤 Publishing message to topic: %topic%
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Publish -Topic "%topic%" -Message "%message%" -QoS %qos%
goto SHOW_RESULT

:DISCONNECT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔌 Disconnect from MQTT Broker              ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p confirm="Disconnect from MQTT broker? (Y/N): "
if /i "%confirm%" neq "Y" goto MAIN_MENU

echo.
echo 🔌 Disconnecting from MQTT broker...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Disconnect
goto SHOW_RESULT

:STATUS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      📊 MQTT Connection Status                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 📊 Checking MQTT connection status...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mqtt-management.ps1" -Action Status
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                              Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🛠️  CORDELIA-I MQTT MANAGEMENT
echo.
echo 🔗 MQTT CONNECTION TYPES:
echo    • TCP: Standard unencrypted connection (port 1883)
echo    • TLS: Encrypted with server certificate (port 8883)
echo    • mTLS: Mutual TLS with client certificate (port 8883)
echo.
echo 📡 MQTT OPERATIONS:
echo    • Connect: Establish connection to MQTT broker
echo    • Subscribe: Listen for messages on specific topics
echo    • Publish: Send messages to topics
echo    • Disconnect: Close connection to broker
echo    • Status: Check current connection status
echo.
echo 🔧 QUALITY OF SERVICE (QoS):
echo    • QoS 0: At most once delivery (fire and forget)
echo    • QoS 1: At least once delivery (acknowledged)
echo    • QoS 2: Exactly once delivery (assured)
echo.
echo 🔧 REQUIREMENTS:
echo    • Cordelia-I device connected via USB
echo    • Valid configuration in config.ini
echo    • Device must be responsive to AT commands
echo    • For TLS/mTLS: Certificates must be installed on device
echo.
echo 💡 TIPS:
echo    • Use Status to check connection before other operations
echo    • Subscribe before publishing to test message flow
echo    • Use appropriate QoS level for your use case
echo    • Topics can use wildcards for subscription (+ for single level, # for multi-level)
echo.
echo 🌐 COMMON MQTT BROKERS:
echo    • Eclipse Mosquitto (test.mosquitto.org)
echo    • AWS IoT Core
echo    • Azure IoT Hub
echo    • Google Cloud IoT Core
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✅ MQTT operation completed successfully!
) else (
    echo ❌ MQTT operation failed (exit code %PS_EXIT_CODE%)
    color 0C
)
echo ══════════════════════════════════════════════════════════════════
echo.
echo Press any key to return to main menu...
pause >nul
color 0B
goto MAIN_MENU

:EXIT
echo.
echo Thank you for using Cordelia-I MQTT Management!
timeout /t 2 >nul
exit /b 0