@echo off
setlocal enabledelayedexpansion
title Cordelia-I System Management

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set Unicode-compatible output encoding
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    Cordelia-I System Management                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select a system operation:
echo.
echo   1. 🔄 Reboot Device            - Software restart
echo   2. 🏭 Factory Reset            - Restore to factory defaults
echo   3. 📚 Help
echo   4. 🚪 Exit
echo.
set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" goto REBOOT
if "%choice%"=="2" goto FACTORY_RESET
if "%choice%"=="3" goto SHOW_HELP
if "%choice%"=="4" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:REBOOT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                          🔄 Device Reboot                        ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo This will perform a software reset of the Cordelia-I device.
echo The device will restart automatically.
echo.
set /p confirm="Proceed with reboot? (Y/N): "
if /i "%confirm%" neq "Y" goto MAIN_MENU

echo.
echo 🔄 Rebooting device...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system-management.ps1" -Action Reboot
goto SHOW_RESULT

:FACTORY_RESET
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                        🏭 Factory Reset                          ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo ⚠️  WARNING: This is a DESTRUCTIVE operation!
echo.
echo Factory Reset will:
echo   • Erase ALL files on the device
echo   • Reset ALL network configurations  
echo   • Restore device to factory defaults
echo   • Take up to 90 seconds to complete
echo.
echo ⚠️  CRITICAL: DO NOT power cycle during the reset!
echo    Interrupting may cause permanent damage!
echo.
echo Reset options:
echo   Y - Proceed with factory reset (with confirmation)
echo   F - Force factory reset (skip confirmation)
echo   N - Cancel and return to menu
echo.
set /p reset_choice="Select option (Y/F/N): "

if /i "%reset_choice%"=="N" goto MAIN_MENU
if /i "%reset_choice%"=="Y" goto FACTORY_RESET_CONFIRM
if /i "%reset_choice%"=="F" goto FACTORY_RESET_FORCE

echo Invalid choice.
pause
goto FACTORY_RESET

:FACTORY_RESET_CONFIRM
echo.
echo 🏭 Starting factory reset with confirmation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system-management.ps1" -Action FactoryReset
goto SHOW_RESULT

:FACTORY_RESET_FORCE
echo.
echo 🏭 Starting factory reset (forced)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system-management.ps1" -Action FactoryReset -Force
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                              Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🛠️  CORDELIA-I SYSTEM MANAGEMENT
echo.
echo 🔄 DEVICE REBOOT:
echo    • Performs a software reset of the device
echo    • Network processor enters hibernate then restarts
echo    • Safer than toggling the physical reset pin
echo    • Device will reconnect automatically
echo.
echo 🏭 FACTORY RESET:
echo    • Restores entire file system to factory state
echo    • Resets ALL network processor configuration
echo    • Takes up to 90 seconds to complete
echo    • ⚠️  NEVER power cycle during factory reset!
echo    • Device will show startup banner when complete
echo.
echo 🔧 REQUIREMENTS:
echo    • Cordelia-I device connected via USB
echo    • Valid configuration in config.ini
echo    • Device must be responsive to AT commands
echo.
echo 💡 TIPS:
echo    • Use reboot for soft recovery from issues
echo    • Use factory reset only when necessary
echo    • Always wait for operations to complete
echo    • Check device status after operations
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✅ System operation completed successfully!
) else (
    echo ❌ System operation failed (exit code %PS_EXIT_CODE%)
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
echo Thank you for using Cordelia-I System Management!
timeout /t 2 >nul
exit /b 0