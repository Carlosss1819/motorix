<#
.SYNOPSIS
    Detiene los servicios de Motorix (backend y frontend).

.DESCRIPTION
    Cierra los procesos node que estan corriendo el backend (server.js)
    y el servidor web auxiliar (web-server.cjs). No toca MySQL ni nada mas.

.EXAMPLE
    .\detener.ps1
#>

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "  Deteniendo servicios de Motorix..." -ForegroundColor Cyan

$detenidos = 0

# Cerramos por la linea de comando para distinguir bien que es cosa nuestra
# y no matar otros procesos de node que puedas tener abiertos.
$procesos = Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
    Where-Object { $_.CommandLine -match 'server\.js|web-server\.cjs|motorix-web\.cjs' }

foreach ($p in $procesos) {
    $nombre = if ($p.CommandLine -match 'server\.js') { 'backend ' } else { 'frontend' }
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        Write-Host "  [OK] Detenido $nombre (PID $($p.ProcessId))" -ForegroundColor Green
        $detenidos++
    }
    catch {
        Write-Host "  [ERROR] No pude detener el PID $($p.ProcessId): $_" -ForegroundColor Red
    }
}

if ($detenidos -eq 0) {
    Write-Host "  No habia ningun servicio de Motorix corriendo." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  MySQL sigue encendido (no lo toque)." -ForegroundColor DarkGray
Write-Host "  Listo." -ForegroundColor Cyan
Write-Host ""
