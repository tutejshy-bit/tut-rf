@echo off
REM This script should be run from mobile_app directory
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "generate_icons.ps1"
pause

