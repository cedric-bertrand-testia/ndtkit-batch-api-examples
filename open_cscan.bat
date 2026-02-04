@echo off
echo Launching PowerShell Script...

:: "ExecutionPolicy Bypass" is required to allow the script to run without security errors
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open_cscan.ps1"

echo.
pause