

REM device-info.cmd - Interactive Device Information
@echo off
setlocal enabledelayedexpansion
title Cordelia-I Device Information Tool

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set a Unicode-compatible font if possible
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    Cordelia-I Device Information                 ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select an option:
echo.
echo   1. 📊 Get device information
echo   2. 💾 Save device report to file  
echo   3. 🔌 Test device connection
echo   4. 📚 Help
echo   5. 🚪 Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto DEVICE_INFO
if "%choice%"=="2" goto SAVE_REPORT
if "%choice%"=="3" goto TEST_CONNECTION
if "%choice%"=="4" goto SHOW_HELP
if "%choice%"=="5" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:DEVICE_INFO
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    📊 Device Information                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Retrieving device information...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0device-info.ps1"
goto SHOW_RESULT

:SAVE_REPORT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                     💾 Save Device Report                        ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"') do set timestamp=%%i
set filename=device-report-%timestamp%.json
echo 📄 Default filename: %filename%
echo.
set /p custom_name="Enter custom filename (or press Enter for default): "
if not "%custom_name%"=="" set filename=%custom_name%

echo.
echo 💾 Generating device report...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0device-info.ps1" -OutputFile "%filename%"
goto SHOW_RESULT

:TEST_CONNECTION
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      🔌 Test Device Connection                   ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Testing connection to Cordelia-I device...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1" -TestConnection
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                           📚 Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🛡️  CORDELIA-I DEVICE INFORMATION TOOL
echo.
echo 📊 DEVICE INFO:
echo    • 🔧 Firmware version and hardware details
echo    • 🆔 Device ID and configuration settings  
echo    • ⚡ Current UART and network status
echo.
echo 💾 SAVE REPORT:
echo    • 📄 Export device information to JSON file
echo    • 📅 Timestamped filenames for tracking
echo.
echo 🔌 TEST CONNECTION:
echo    • ✅ Verify USB and serial communication
echo    • 🌐 Check device responsiveness
echo    • 🔍 Validate configuration settings
echo.
echo ⚠️  REQUIREMENTS:
echo    • 🔌 Cordelia-I device connected via USB
echo    • ⚙️  Correct COM port in config.ini
echo    • 🔋 Device powered on and responsive
echo.
echo 🆘 TROUBLESHOOTING:
echo    • 🔗 Connection failed → check USB cable and COM port
echo    • 📡 Device not responding → verify device is powered on  
echo    • 🚫 Permission denied → close other apps using COM port
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✅ Operation completed successfully!
    @REM color 0B
) else (
    echo ❌ Operation failed ^(exit code %PS_EXIT_CODE%^)
    color 0C
)
echo ══════════════════════════════════════════════════════════════════
echo.
echo 🔙 Press any key to return to main menu...
pause >nul
color 0B
goto MAIN_MENU

:EXIT
echo.
echo 🙏 Thank you for using Cordelia-I Device Information Tool!
echo 👋 Goodbye!
timeout /t 2 >nul
exit /b 0
