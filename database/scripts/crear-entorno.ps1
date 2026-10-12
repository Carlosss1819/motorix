<#
.SYNOPSIS
  Crea las bases de datos locales de Motorix y el usuario dedicado motorix_app.

.DESCRIPTION
  Idempotente: puede ejecutarse de nuevo sin efectos secundarios.
  Las contraseñas NUNCA se escriben en el script: se pasan por parámetro o por las
  variables de entorno MYSQL_ROOT_PASSWORD y MOTORIX_DB_PASSWORD.

.EXAMPLE
  ./crear-entorno.ps1 -AdminPassword '<contraseña de root>'
#>
[CmdletBinding()]
param(
  [string]$MysqlPath = "$env:ProgramFiles\MySQL\MySQL Server 8.0\bin\mysql.exe",
  [string]$AdminUser = 'root',
  [string]$AdminPassword = $env:MYSQL_ROOT_PASSWORD,
  [string]$DbHost = 'localhost',
  [string]$DbPort = '3306',
  [string]$DbName = 'motorix',
  [string]$TestDbName = 'motorix_test',
  [string]$AppUser = 'motorix_app',
  [string]$AppPassword = $env:MOTORIX_DB_PASSWORD
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $MysqlPath)) {
  throw "No se encontró mysql.exe en '$MysqlPath'. Usa -MysqlPath para indicar la ruta correcta."
}
if (-not $AdminPassword) {
  $AdminPassword = Read-Host 'Contraseña de administrador de MySQL (root)'
}
if (-not $AppPassword) {
  $AppPassword = Read-Host 'Contraseña para el usuario dedicado motorix_app (solo local)'
}

$escapedAppPassword = $AppPassword.Replace("'", "''")

$sql = @'
CREATE DATABASE IF NOT EXISTS `__DB__` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `__TEST_DB__` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '__APP_USER__'@'localhost' IDENTIFIED BY '__APP_PASSWORD__';
ALTER USER '__APP_USER__'@'localhost' IDENTIFIED BY '__APP_PASSWORD__';
GRANT ALL PRIVILEGES ON `__DB__`.* TO '__APP_USER__'@'localhost';
GRANT ALL PRIVILEGES ON `__TEST_DB__`.* TO '__APP_USER__'@'localhost';
FLUSH PRIVILEGES;
'@.Replace('__DB__', $DbName).
    Replace('__TEST_DB__', $TestDbName).
    Replace('__APP_USER__', $AppUser).
    Replace('__APP_PASSWORD__', $escapedAppPassword)

$previousPwd = $env:MYSQL_PWD
try {
  $env:MYSQL_PWD = $AdminPassword
  & $MysqlPath --default-character-set=utf8mb4 -u $AdminUser -h $DbHost -P $DbPort -e $sql
  if ($LASTEXITCODE -ne 0) {
    throw "MySQL devolvió el código $LASTEXITCODE al crear el entorno."
  }
}
finally {
  $env:MYSQL_PWD = $previousPwd
}

Write-Host "Entorno local listo:" -ForegroundColor Green
Write-Host "  - Bases creadas: $DbName y $TestDbName (InnoDB, utf8mb4)"
Write-Host "  - Usuario dedicado: $AppUser (nunca root para la aplicación)"
