@echo off
setlocal enabledelayedexpansion
title Cordelia-I IoT Operations

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set Unicode-compatible output encoding
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    Cordelia-I IoT Operations                     ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select an IoT operation:
echo.
echo   1. 🔧 Device Provisioning     - Configure device for IoT platform
echo   2. 📋 Device Registration     - Register with IoT platform
echo   3. ⚙️  Platform Configuration  - Configure IoT settings
echo   4. 🔐 Device Enrollment       - Enroll device with QuarkLink
echo   5. 🌐 Connect to Platform     - Establish IoT connection
echo   6. 📊 Connection Status       - Check IoT platform status
echo   7. 📚 Help
echo   8. 🚪 Exit
echo.
set /p choice="Enter your choice (1-8): "

if "%choice%"=="1" goto PROVISION
if "%choice%"=="2" goto REGISTER
if "%choice%"=="3" goto CONFIGURE
if "%choice%"=="4" goto ENROLL
if "%choice%"=="5" goto CONNECT
if "%choice%"=="6" goto STATUS
if "%choice%"=="7" goto SHOW_HELP
if "%choice%"=="8" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:PROVISION
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔧 Device Provisioning                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo IoT Platforms:
echo   1. QuarkLink (Würth Elektronik)
echo   2. AWS IoT Core
echo   3. Azure IoT Hub
echo   4. Generic IoT Platform
echo.
set /p platform_choice="Select platform (1-4): "

if "%platform_choice%"=="1" set PLATFORM=QuarkLink
if "%platform_choice%"=="2" set PLATFORM=AWS
if "%platform_choice%"=="3" set PLATFORM=Azure
if "%platform_choice%"=="4" set PLATFORM=Generic

if not defined PLATFORM (
    echo Invalid platform selection.
    pause
    goto PROVISION
)

if "%PLATFORM%"=="QuarkLink" (
    echo.
    echo QuarkLink Provisioning:
    set /p prov_data="Enter path to provisioning data file (JSON): "
    if "%prov_data%"=="" (
        echo Provisioning data file is required for QuarkLink.
        pause
        goto PROVISION
    )
    
    echo.
    echo ⚠️  WARNING: This will configure the device for QuarkLink platform
    echo    and may overwrite existing configuration.
    echo.
    set /p confirm="Continue with provisioning? (Y/N): "
    if /i "%confirm%" neq "Y" goto MAIN_MENU
    
    echo.
    echo 🔧 Provisioning device for QuarkLink...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Provision -Platform %PLATFORM% -ProvisioningData "%prov_data%" -Force
) else (
    echo.
    echo %PLATFORM% Provisioning:
    echo This will configure the device for %PLATFORM% platform.
    echo.
    set /p confirm="Continue with provisioning? (Y/N): "
    if /i "%confirm%" neq "Y" goto MAIN_MENU
    
    echo.
    echo 🔧 Provisioning device for %PLATFORM%...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Provision -Platform %PLATFORM% -Force
)
goto SHOW_RESULT

:REGISTER
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      📋 Device Registration                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo IoT Platforms:
echo   1. QuarkLink (Würth Elektronik)
echo   2. AWS IoT Core
echo   3. Azure IoT Hub
echo   4. Generic IoT Platform
echo.
set /p platform_choice="Select platform (1-4): "

if "%platform_choice%"=="1" set PLATFORM=QuarkLink
if "%platform_choice%"=="2" set PLATFORM=AWS
if "%platform_choice%"=="3" set PLATFORM=Azure
if "%platform_choice%"=="4" set PLATFORM=Generic

if not defined PLATFORM (
    echo Invalid platform selection.
    pause
    goto REGISTER
)

echo.
echo %PLATFORM% Registration:
echo.
set /p device_id="Enter device ID: "
if "%device_id%"=="" (
    echo Device ID is required.
    pause
    goto REGISTER
)

set /p endpoint="Enter platform endpoint: "
if "%endpoint%"=="" (
    echo Endpoint is required.
    pause
    goto REGISTER
)

set /p api_key="Enter API key (optional): "

echo.
echo 📋 Registering device with %PLATFORM%...
echo Device ID: %device_id%
echo Endpoint: %endpoint%

if "%api_key%"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Register -Platform %PLATFORM% -DeviceId "%device_id%" -Endpoint "%endpoint%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Register -Platform %PLATFORM% -DeviceId "%device_id%" -Endpoint "%endpoint%" -ApiKey "%api_key%"
)
goto SHOW_RESULT

:CONFIGURE
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    ⚙️  Platform Configuration                    ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo IoT Platforms:
echo   1. QuarkLink (Würth Elektronik)
echo   2. AWS IoT Core
echo   3. Azure IoT Hub
echo   4. Generic IoT Platform
echo.
set /p platform_choice="Select platform (1-4): "

if "%platform_choice%"=="1" set PLATFORM=QuarkLink
if "%platform_choice%"=="2" set PLATFORM=AWS
if "%platform_choice%"=="3" set PLATFORM=Azure
if "%platform_choice%"=="4" set PLATFORM=Generic

if not defined PLATFORM (
    echo Invalid platform selection.
    pause
    goto CONFIGURE
)

echo.
echo ⚙️  Configuring IoT settings for %PLATFORM%...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Configure -Platform %PLATFORM%
goto SHOW_RESULT

:ENROLL
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔐 Device Enrollment                        ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo IoT Platforms:
echo   1. QuarkLink (Würth Elektronik)
echo   2. AWS IoT Core
echo   3. Azure IoT Hub
echo   4. Generic IoT Platform
echo.
set /p platform_choice="Select platform (1-4): "

if "%platform_choice%"=="1" set PLATFORM=QuarkLink
if "%platform_choice%"=="2" set PLATFORM=AWS
if "%platform_choice%"=="3" set PLATFORM=Azure
if "%platform_choice%"=="4" set PLATFORM=Generic

if not defined PLATFORM (
    echo Invalid platform selection.
    pause
    goto ENROLL
)

echo.
echo 🔐 Starting device enrollment with %PLATFORM%...
echo.
echo ⚠️  This process may take up to 2 minutes.
echo    Please be patient and do not interrupt the process.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Enroll -Platform %PLATFORM%
goto SHOW_RESULT

:CONNECT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    🌐 Connect to IoT Platform                    ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo IoT Platforms:
echo   1. QuarkLink (Würth Elektronik)
echo   2. AWS IoT Core
echo   3. Azure IoT Hub
echo   4. Generic IoT Platform
echo.
set /p platform_choice="Select platform (1-4): "

if "%platform_choice%"=="1" set PLATFORM=QuarkLink
if "%platform_choice%"=="2" set PLATFORM=AWS
if "%platform_choice%"=="3" set PLATFORM=Azure
if "%platform_choice%"=="4" set PLATFORM=Generic

if not defined PLATFORM (
    echo Invalid platform selection.
    pause
    goto CONNECT
)

echo.
echo 🌐 Connecting to %PLATFORM% platform...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Connect -Platform %PLATFORM%
goto SHOW_RESULT

:STATUS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    📊 IoT Platform Status                       ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 📊 Checking IoT platform status...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iot-operations.ps1" -Action Status
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                              Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🛠️  CORDELIA-I IOT OPERATIONS
echo.
echo 🔧 DEVICE PROVISIONING:
echo    • Configures device for specific IoT platform
echo    • Installs necessary certificates and keys
echo    • Sets up platform-specific settings
echo    • ⚠️  May overwrite existing configuration
echo.
echo 📋 DEVICE REGISTRATION:
echo    • Registers device with IoT platform
echo    • Requires device ID and platform endpoint
echo    • May require API keys for authentication
echo    • Creates device identity in platform
echo.
echo ⚙️  PLATFORM CONFIGURATION:
echo    • Configures IoT-specific settings
echo    • Sets message formats and protocols
echo    • Configures timeouts and retry logic
echo    • Applies platform best practices
echo.
echo 🌐 PLATFORM CONNECTION:
echo    • Establishes connection to IoT platform
echo    • Requires prior registration/provisioning
echo    • Maintains persistent connection for messaging
echo    • Handles authentication and encryption
echo.
echo 🏢 SUPPORTED PLATFORMS:
echo    • QuarkLink: Würth Elektronik IoT platform
echo    • AWS IoT Core: Amazon Web Services IoT
echo    • Azure IoT Hub: Microsoft Azure IoT
echo    • Generic: Standard MQTT/HTTP IoT platforms
echo.
echo 🔧 REQUIREMENTS:
echo    • Cordelia-I device connected via USB
echo    • Valid configuration in config.ini
echo    • Device must be responsive to AT commands
echo    • Platform-specific certificates (for secure connections)
echo.
echo 💡 TIPS:
echo    • Complete provisioning before registration
echo    • Use Status to verify connections
echo    • Keep provisioning data files secure
echo    • Test connectivity before production use
echo.
echo 📋 WORKFLOW:
echo    1. Provision device for target platform
echo    2. Register device with platform
echo    3. Configure platform-specific settings
echo    4. Connect to platform
echo    5. Verify status and connectivity
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✅ IoT operation completed successfully!
) else (
    echo ❌ IoT operation failed (exit code %PS_EXIT_CODE%)
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
echo Thank you for using Cordelia-I IoT Operations!
timeout /t 2 >nul
exit /b 0