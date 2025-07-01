@echo off
rem Windows wrapper script for certificate upload
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\upload_cert.ps1" %*
set PS_EXIT_CODE=%ERRORLEVEL%

if %PS_EXIT_CODE% equ 0 (
    echo.
    echo Certificate upload completed successfully.
) else (
    echo.
    echo Certificate upload FAILED with exit code %PS_EXIT_CODE%. Please check the messages above.
    pause
    exit /b %PS_EXIT_CODE%
)

pause 