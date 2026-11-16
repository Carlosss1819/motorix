<#
.SYNOPSIS
    Arranca Motorix completo con un solo ejecutable.

.DESCRIPTION
    Hace 4 cosas, en este orden:
      1. Enciende MySQL si esta apagado.
      2. Abre una ventana con el BACKEND  (API en el puerto 3000).
      3. Abre una ventana con el FRONTEND (servidor web en el puerto 8080).
      4. Abre el navegador en http://localhost:8080.

    Cada servicio corre en SU PROPIA ventana, para que puedas ver sus
    mensajes y cerrar cualquiera por separado.

.PARAMETER SinNavegador
    Arranca todo pero NO abre el navegador.

.PARAMETER RebuildWeb
    Antes de arrancar, recompila el build de Flutter web
    (util si tocaste codigo del cliente).

.EXAMPLE
    .\arrancar.ps1

.EXAMPLE
    .\arrancar.ps1 -RebuildWeb
#>
param(
    [switch]$SinNavegador,
    [switch]$RebuildWeb
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------
# Rutas: todo se resuelve respecto a donde vive este script,
# así que funciona aunque muevas la carpeta del proyecto.
# ---------------------------------------------------------------
$RAIZ   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SERVER = Join-Path $RAIZ 'server'
$WEB    = Join-Path $RAIZ 'scripts\web-server.cjs'
$BUILD  = Join-Path $RAIZ 'client\build\web'

$PUERTO_BACKEND = 3000
$PUERTO_WEB     = 8080

function Titulo($texto) {
    Write-Host ""
    Write-Host "  $texto" -ForegroundColor Cyan
}

# ---------------------------------------------------------------
# 0. Comprobaciones basicas
# ---------------------------------------------------------------
Titulo "Comprobando requisitos..."

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  [ERROR] No se encontro Node.js. Instalalo desde https://nodejs.org" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Node.js $(& node --version)"

if (-not (Test-Path (Join-Path $SERVER 'server.js'))) {
    Write-Host "  [ERROR] No se encontro server\server.js" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $SERVER '.env'))) {
    Write-Host "  [ERROR] Falta server\.env  (copia .env.example y completa tus valores)" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------
# 1. MySQL
# ---------------------------------------------------------------
Titulo "Revisando MySQL..."

$mysql = Get-Service -Name 'MySQL80' -ErrorAction SilentlyContinue
if (-not $mysql) {
    Write-Host "  [AVISO] No se encontro el servicio MySQL80. Asumo que MySQL ya corre en otro lado." -ForegroundColor Yellow
}
elseif ($mysql.Status -ne 'Running') {
    Write-Host "  MySQL esta detenido. Intentando encenderlo..." -ForegroundColor Yellow
    try {
        Start-Service MySQL80
        # Espera hasta 20 segundos a que este realmente listo
        $mysql.WaitForStatus('Running', '00:00:20') | Out-Null
        Write-Host "  [OK] MySQL encendido." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] No pude encender MySQL. Encendelo manualmente desde servicios.msc" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  [OK] MySQL ya esta corriendo."
}

# ---------------------------------------------------------------
# 2. Build web (opcional)
# ---------------------------------------------------------------
if ($RebuildWeb) {
    Titulo "Recompilando el build de Flutter web (esto tarda)..."
    $flutter = 'flutter'
    try {
        Push-Location (Join-Path $RAIZ 'client')
        & $flutter build web
        if ($LASTEXITCODE -ne 0) { throw "flutter build web fallo" }
    }
    catch {
        Write-Host "  [ERROR] No se pudo generar el build web: $_" -ForegroundColor Red
        exit 1
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path (Join-Path $BUILD 'index.html'))) {
    Write-Host "  [ERROR] No hay build web en: $BUILD" -ForegroundColor Red
    Write-Host "         Genera uno con:  .\arrancar.ps1 -RebuildWeb" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------
# 3. Puertos libres
# ---------------------------------------------------------------
Titulo "Revisando puertos..."

foreach ($p in @($PUERTO_BACKEND, $PUERTO_WEB)) {
    $ocupado = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($ocupado) {
        $procId = $ocupado[0].OwningProcess
        $nombre = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
        Write-Host "  [AVISO] El puerto $p ya esta en uso por '$nombre' (PID $procId)." -ForegroundColor Yellow
        Write-Host "          Puede ser una instancia anterior; sigo igual. Si algo falla, cierra esa ventana." -ForegroundColor Yellow
    }
    else {
        Write-Host "  [OK] Puerto $p libre."
    }
}

# ---------------------------------------------------------------
# 4. Arrancar backend y frontend, cada uno en su ventana
# ---------------------------------------------------------------
Titulo "Arrancando servicios..."

# Ventana del backend
Start-Process powershell -ArgumentList @(
    '-NoExit', '-NoLogo',
    '-Command',
    "Set-Location '$SERVER'; Write-Host 'Motorix BACKEND (puerto $PUERTO_BACKEND)' -ForegroundColor Magenta; npm start"
)

# Ventana del frontend
Start-Process powershell -ArgumentList @(
    '-NoExit', '-NoLogo',
    '-Command',
    "Write-Host 'Motorix FRONTEND (puerto $PUERTO_WEB)' -ForegroundColor Magenta; node '$WEB'"
)

Write-Host "  [OK] Ventanas de backend y frontend abiertas." -ForegroundColor Green

# ---------------------------------------------------------------
# 5. Esperar a que el backend responda
# ---------------------------------------------------------------
Titulo "Esperando a que el backend este listo..."

$listo = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Milliseconds 1000
    try {
        # Cualquier respuesta HTTP (aunque sea 401/404) significa que la API vive.
        Invoke-WebRequest -Uri "http://127.0.0.1:$PUERTO_BACKEND/api/auth/login" `
            -Method GET -UseBasicParsing -TimeoutSec 2 | Out-Null
        $listo = $true; break
    }
    catch {
        if ($_.Exception.Response) { $listo = $true; break }
        Write-Host -NoNewline "."
    }
}

if ($listo) {
    Write-Host " [OK]" -ForegroundColor Green
}
else {
    Write-Host " [AVISO]" -ForegroundColor Yellow
    Write-Host "  El backend no respondio en 30s. Revisa la ventana del backend por errores." -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 6. Abrir navegador
# ---------------------------------------------------------------
if ($SinNavegador) {
    Titulo "Listo (sin abrir navegador)."
}
else {
    Titulo "Abriendo el navegador..."
    Start-Process "http://localhost:$PUERTO_WEB"
}

Write-Host ""
Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host "   Motorix corriendo:" -ForegroundColor Green
Write-Host "     Backend  ->  http://localhost:$PUERTO_BACKEND/api"
Write-Host "     Frontend ->  http://localhost:$PUERTO_WEB   <-- abre este"
Write-Host ""
Write-Host "   Usuario:  admin    Clave: Admin2026!"
Write-Host ""
Write-Host "   Para DETENER: cierra las ventanas 'BACKEND' y 'FRONTEND'," -ForegroundColor DarkGray
Write-Host "   o ejecuta .\detener.ps1" -ForegroundColor DarkGray
Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
