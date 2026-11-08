@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Start-Instance.ps1" -Role Client
if errorlevel 1 pause
