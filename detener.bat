@echo off
rem  Detiene el backend y el frontend de Motorix.
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0detener.ps1"
pause
