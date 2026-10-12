# Base de datos de Motorix

Esquema y datos de ejemplo del MVP, versionados y recreables desde cero.

## Estructura

```text
database/
├── migrations/   # Scripts SQL numerados e inmutables (nunca se editan tras aplicarse)
├── seeds/        # Datos de ejemplo idempotentes (sin contraseñas en texto plano)
├── scripts/      # Scripts de automatización (entorno, migraciones, reinicio)
├── data/         # Datos físicos de MySQL (ignorados por Git)
└── README.md     # Este archivo
```

## Reglas

- Los cambios de esquema se agregan como **nuevos** scripts numerados
  (`002_...`, `003_...`); NO se editan scripts de sprints ya aplicados.
- Los archivos físicos de datos (`data/`) **nunca** se versionan (están en `.gitignore`).
- La conexión se configura solo con variables de entorno (`DB_HOST`, `DB_PORT`,
  `DB_USER`, `DB_PASSWORD`, `DB_NAME`) desde `server/.env`.
- La aplicación usa el usuario dedicado `motorix_app`; **nunca** `root`.
- Motor InnoDB, llaves foráneas y codificación `utf8mb4`.
- Las pruebas usan la base `motorix_test`, jamás la base principal.

## Crear el entorno local

```powershell
# 1. Crear bases y usuario dedicado (pide la contraseña de administrador de MySQL)
./scripts/crear-entorno.ps1 -AdminPassword '<contraseña de root>'

# 2. Aplicar migraciones (idempotente, registro en schema_migrations)
./scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>'

# 3. Sembrar datos de ejemplo (idempotente)
./scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>' -Seeds
```

## Tablas por sprint

| Sprint | Tablas |
|--------|--------|
| 1 | `users`, `clients`, `vehicles` |
| 2 | `appointments`, `service_orders` y tablas relacionadas |
| 3 | `parts`, `inventory_movements`, `maintenance` |
| 4 | `payments`, `tickets` |
