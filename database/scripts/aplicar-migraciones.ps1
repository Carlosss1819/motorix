<#
.SYNOPSIS
  Aplica las migraciones SQL de Motorix de forma idempotente con registro en
  schema_migrations; con -Seeds aplica tambien los datos de ejemplo.

.DESCRIPTION
  Los scripts de migrations/ son inmutables: solo se aplican los que falten.
  Los seeds/ son idempotentes: pueden ejecutarse varias veces sin duplicar datos.

.EXAMPLE
  ./aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>'

.EXAMPLE
  ./aplicar-migraciones.ps1 -DbPassword '<contraseña>' -Seeds
#>
[CmdletBinding()]
param(
  [string]$MysqlPath = "$env:ProgramFiles\MySQL\MySQL Server 8.0\bin\mysql.exe",
  [string]$DbHost = 'localhost',
  [string]$DbPort = '3306',
  [string]$DbUser = 'motorix_app',
  [string]$DbPassword = $env:MOTORIX_DB_PASSWORD,
  [string]$DbName = 'motorix_v2',
  [switch]$Seeds,
  [string]$MigrationsDir,
  [string]$SeedsDir
)

$ErrorActionPreference = 'Stop'

if (-not $MigrationsDir) { $MigrationsDir = Join-Path $PSScriptRoot '..\migrations' }
if (-not $SeedsDir) { $SeedsDir = Join-Path $PSScriptRoot '..\seeds' }

if (-not (Test-Path $MysqlPath)) {
  throw "No se encontró mysql.exe en '$MysqlPath'. Usa -MysqlPath para indicar la ruta correcta."
}
if (-not $DbPassword) {
  $DbPassword = Read-Host "Contraseña de $DbUser"
}

$previousPwd = $env:MYSQL_PWD
$env:MYSQL_PWD = $DbPassword

function Invoke-SqlFile([string]$RutaArchivo) {
  $ruta = ($RutaArchivo -replace '\\', '/')
  & $MysqlPath --default-character-set=utf8mb4 -u $DbUser -h $DbHost -P $DbPort $DbName -e "SOURCE `"$ruta`""
  if ($LASTEXITCODE -ne 0) {
    throw "Error al aplicar '$RutaArchivo' (código $LASTEXITCODE)."
  }
}

try {
  # Tabla de control de migraciones
  & $MysqlPath --default-character-set=utf8mb4 -u $DbUser -h $DbHost -P $DbPort $DbName -e @"
CREATE TABLE IF NOT EXISTS schema_migrations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_schema_migrations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"@
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear schema_migrations. Verifica que la base exista y la contraseña sea correcta.' }

  # Migraciones pendientes, en orden numérico
  $migraciones = Get-ChildItem -Path $MigrationsDir -Filter '*.sql' | Sort-Object Name
  foreach ($migracion in $migraciones) {
    $registrada = & $MysqlPath --default-character-set=utf8mb4 -u $DbUser -h $DbHost -P $DbPort $DbName -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE name = '$($migracion.Name.Replace("'", "''"))';"
    if ([int]$registrada -gt 0) {
      Write-Host "  [omitida] $($migracion.Name) ya aplicada" -ForegroundColor DarkGray
      continue
    }
    Invoke-SqlFile $migracion.FullName
    $nombre = $migracion.Name.Replace("'", "''")
    & $MysqlPath --default-character-set=utf8mb4 -u $DbUser -h $DbHost -P $DbPort $DbName -e "INSERT INTO schema_migrations (name) VALUES ('$nombre');"
    Write-Host "  [aplicada] $($migracion.Name)" -ForegroundColor Green
  }

  # Seeds (idempotentes)
  if ($Seeds) {
    $listaSeeds = Get-ChildItem -Path $SeedsDir -Filter '*.sql' | Sort-Object Name
    foreach ($archivoSeed in $listaSeeds) {
      Invoke-SqlFile $archivoSeed.FullName
      Write-Host "  [seed] $($archivoSeed.Name)" -ForegroundColor Green
    }
  }

  Write-Host "Base '$DbName' al día." -ForegroundColor Green
}
finally {
  $env:MYSQL_PWD = $previousPwd
}
