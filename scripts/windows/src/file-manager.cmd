REM Unified Cordelia-I File Manager
@echo off
setlocal enabledelayedexpansion
title Cordelia-I File Manager

REM Enable UTF-8 code page for Unicode support
chcp 65001 >nul 2>&1

color 0B

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                     Cordelia-I File Manager                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Select an operation:
echo.
echo   1. List all files on device
echo   2. Upload file to device
echo   3. Read file from device
echo   4. Get file information
echo   5. Delete file(s) from device
echo   6. Help
echo   7. Exit
echo.
set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" goto LIST_FILES
if "%choice%"=="2" goto UPLOAD_FILE
if "%choice%"=="3" goto DOWNLOAD_FILE
if "%choice%"=="4" goto FILE_INFO
if "%choice%"=="5" goto DELETE_FILES
if "%choice%"=="6" goto SHOW_HELP
if "%choice%"=="7" goto EXIT
echo Invalid choice. Please try again.
pause
goto MAIN_MENU

:LIST_FILES
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                          List Files                             ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Retrieving file list from device...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" -Action List
goto SHOW_RESULT

:UPLOAD_FILE
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         Upload File                              ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Upload options:
echo.
echo   F - File browser (select file to upload)
echo   P - Specify file path directly
echo   C - Certificate upload (pre-configured settings)
echo   B - Back to main menu
echo.
set /p upload_choice="Select upload method (F/P/C/B): "

if /i "%upload_choice%"=="B" goto MAIN_MENU
if /i "%upload_choice%"=="F" goto UPLOAD_BROWSE
if /i "%upload_choice%"=="P" goto UPLOAD_PATH
if /i "%upload_choice%"=="C" goto UPLOAD_CERTIFICATE
echo Invalid choice. Please try again.
pause
goto UPLOAD_FILE

:UPLOAD_BROWSE
echo.
echo Opening file browser...
echo.
echo Additional options:
echo   O - Overwrite existing files on device
echo   N - No additional options (default)
echo.
set /p options="Select options (O/N): "

set PS_PARAMS=-Action Upload
if /i "%options%"=="O" set PS_PARAMS=%PS_PARAMS% -OverwriteExisting

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
goto SHOW_RESULT

:UPLOAD_PATH
echo.
set /p filepath="Enter full path to file: "
if not exist "%filepath%" (
    echo.
    echo ✗ File not found: %filepath%
    echo.
    pause
    goto UPLOAD_FILE
)

echo.
echo Additional options:
echo   O - Overwrite existing files on device
echo   N - No additional options (default)
echo.
set /p options="Select options (O/N): "

echo.
set /p remotename="Remote filename (press Enter for auto): "

set PS_PARAMS=-Action Upload -FilePath "%filepath%"
if not "%remotename%"=="" set PS_PARAMS=%PS_PARAMS% -RemoteFileName "%remotename%"
if /i "%options%"=="O" set PS_PARAMS=%PS_PARAMS% -OverwriteExisting

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
goto SHOW_RESULT

:UPLOAD_CERTIFICATE
echo.
echo Certificate upload mode - using pre-configured settings...
echo.
echo Additional options:
echo   O - Overwrite existing certificate
echo   N - No additional options (default)
echo.
set /p options="Select options (O/N): "

set PS_PARAMS=-Action Upload -IsCertificate
if /i "%options%"=="O" set PS_PARAMS=%PS_PARAMS% -OverwriteExisting

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
goto SHOW_RESULT

:DOWNLOAD_FILE
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         Read File                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p filename="Enter filename to read: "
if "%filename%"=="" (
    echo No filename specified.
    pause
    goto MAIN_MENU
)

echo.
echo Display format:
echo   B - Base64 (default, safest for binary files)
echo   H - Hexadecimal
echo   A - ASCII (text files only)
echo.
set /p format="Select format (B/H/A): "

set PS_PARAMS=-Action Download -FileName "%filename%"
if /i "%format%"=="H" set PS_PARAMS=%PS_PARAMS% -Format hex
if /i "%format%"=="A" set PS_PARAMS=%PS_PARAMS% -Format ascii
if /i not "%format%"=="H" if /i not "%format%"=="A" set PS_PARAMS=%PS_PARAMS% -Format base64

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
goto SHOW_RESULT

:FILE_INFO
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                        File Information                          ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p filename="Enter filename to get info: "
if "%filename%"=="" (
    echo No filename specified.
    pause
    goto MAIN_MENU
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" -Action Info -FileName "%filename%"
goto SHOW_RESULT

:DELETE_FILES
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         Delete Files                             ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo ⚠ WARNING: File deletion cannot be undone!
echo.
echo Enter the filename or pattern to delete:
echo.
echo Examples:
echo   certificate.pem            (delete single file)
echo   mosquitto*.pem             (delete all files starting with 'mosquitto' and ending with '.pem')
echo   mosquitto-??.org.pem       (delete files like mosquitto-01.org.pem, mosquitto-22.org.pem, etc.)
echo   *.tmp                      (delete all .tmp files)
echo.
set /p filename="File or pattern to delete: "

if "%filename%"=="" (
    echo No filename specified.
    pause
    goto MAIN_MENU
)

echo.
echo You are about to delete: %filename%
echo.
echo Delete options:
echo   Y - Delete with confirmation prompt
echo   F - Force delete without confirmation
echo   N - Cancel deletion
echo.
set /p delete_mode="Select option (Y/F/N): "

if /i "%delete_mode%"=="N" goto MAIN_MENU

set PS_PARAMS=-Action Delete -FileName "%filename%"
if /i "%delete_mode%"=="F" set PS_PARAMS=%PS_PARAMS% -Force

if /i "%delete_mode%"=="Y" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
    goto SHOW_RESULT
)
if /i "%delete_mode%"=="F" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0file-manager.ps1" %PS_PARAMS%
    goto SHOW_RESULT
)
echo Invalid option.
pause
goto DELETE_FILES



:SHOW_HELP
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                              Help                                ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo CORDELIA-I FILE MANAGER:
echo.
echo This unified tool manages all file operations on your Cordelia-I device:
echo.
echo FILE OPERATIONS:
echo.
echo • LIST FILES - Shows all files with sizes and properties
echo • UPLOAD FILE - Upload any file type (certificates, configs, firmware)
echo • READ FILE - Read and display files from device (with optional save)
echo • FILE INFO - Get detailed information about a specific file
echo • DELETE FILES - Remove files (supports wildcards)
echo.
echo UPLOAD MODES:
echo.
echo • File Browser - Graphical file selection
echo • Direct Path - Type file path manually
echo • Certificate Mode - Pre-configured certificate upload
echo.
echo DISPLAY FORMATS:
echo.
echo • Base64 - Safe for all file types (default)
echo • Hexadecimal - Raw hex representation  
echo • ASCII - Text files only
echo.
echo WILDCARD PATTERNS:
echo.
echo • *           matches any number of characters
echo • ?           matches exactly one character
echo • *.pem       matches all .pem files
echo • test-?.txt  matches test-1.txt, test-a.txt, etc.
echo.
echo SAFETY FEATURES:
echo.
echo • File existence verification before operations
echo • Wildcard match preview before deletion
echo • Overwrite protection with confirmation
echo • Automatic logging (controlled by config.ini)
echo.
echo REQUIREMENTS:
echo.
echo • Cordelia-I device connected via USB
echo • Correct COM port configured in config.ini
echo • Device powered on and responsive
echo.
pause
goto MAIN_MENU

:SHOW_RESULT
set PS_EXIT_CODE=%ERRORLEVEL%
echo.
echo ══════════════════════════════════════════════════════════════════
if %PS_EXIT_CODE% equ 0 (
    echo ✓ Operation completed successfully!
) else (
    echo ✗ Operation failed ^(exit code %PS_EXIT_CODE%^)
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
echo Thank you for using Cordelia-I File Manager!
timeout /t 2 >nul
exit /b 0
