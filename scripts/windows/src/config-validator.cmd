@echo off
setlocal enabledelayedexpansion
title Cordelia-I Configuration Validator

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

REM Set Unicode-compatible output encoding
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8" 2>nul

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                ⚙️  Configuration Validator                       ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select an option:
echo.
echo   🔍 1. Validate configuration
echo   👀 2. View current configuration
echo   🔌 3. Test device connection
echo   📋 4. List available COM ports
echo   📄 5. Create configuration template
echo   📚 6. Help
echo   🚪 7. Exit
echo.
set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" goto VALIDATE_CONFIG
if "%choice%"=="2" goto VIEW_CONFIG
if "%choice%"=="3" goto TEST_CONNECTION
if "%choice%"=="4" goto LIST_PORTS
if "%choice%"=="5" goto CREATE_TEMPLATE
if "%choice%"=="6" goto SHOW_HELP
if "%choice%"=="7" goto EXIT
echo ❌ Invalid choice. Please try again.
timeout /t 2 >nul
goto MAIN_MENU

:VALIDATE_CONFIG
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    🔍 Validate Configuration                     ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Validating configuration file...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1"
goto SHOW_RESULT

:VIEW_CONFIG
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                    👀 View Configuration                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1" -ViewConfig
goto SHOW_RESULT

:TEST_CONNECTION
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                     🔌 Test Connection                           ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo 🔍 Testing connection to Cordelia-I device...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1" -TestConnection
goto SHOW_RESULT

:LIST_PORTS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      Available COM Ports                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1" -ListPorts
goto SHOW_RESULT

:CREATE_TEMPLATE
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                   📄 Create Configuration Template               ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set filename=config-template.ini
echo 📄 Default filename: %filename%
echo.
set /p custom_name="Enter custom filename (or press Enter for default): "
if not "%custom_name%"=="" set filename=%custom_name%

echo.
echo 📄 Creating configuration template...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0config-validator.ps1" -CreateTemplate -TemplateFile "%filename%"
goto SHOW_RESULT

:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                           📚 Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo ⚙️  CORDELIA-I CONFIGURATION VALIDATOR
echo.
echo 🔍 VALIDATE CONFIG:
echo    • ✅ Check configuration file syntax
echo    • ⚠️  Identify potential issues
echo    • 🔧 Verify COM port availability
echo.
echo 👀 VIEW CONFIG:
echo    • 📊 Display current settings with formatting
echo    • 🔌 UART, Security, and File operation settings
echo    • 🌐 MQTT broker configuration (if configured)
echo.
echo 🔌 TEST CONNECTION:
echo    • 📡 Test actual device communication
echo    • ✅ Verify serial port functionality
echo    • 🔍 Validate device responses
echo.
echo 📋 LIST PORTS:
echo    • 🔌 Show all available COM ports
echo    • 💻 System-detected serial interfaces
echo.
echo 📄 CREATE TEMPLATE:
echo    • 📝 Generate sample configuration file
echo    • ⚙️  Pre-filled with recommended defaults
echo    • 🔧 Ready for customization
echo.
echo 💡 TIPS:
echo    • 🔧 Always validate after making changes
echo    • 🔌 Test connection before device operations
echo    • 📄 Keep backup copies of working configs
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✅ Operation completed successfully!
    color 0A
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
echo 🙏 Thank you for using Cordelia-I Configuration Validator!
echo 👋 Goodbye!
timeout /t 2 >nul
exit /b 0