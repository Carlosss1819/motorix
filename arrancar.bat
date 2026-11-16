@echo off
rem  Arranca Motorix completo. Doble clic para usarlo.
rem  Abre el backend y el frontend en ventanas aparte, y el navegador.
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arrancar.ps1" %*
