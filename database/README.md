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
- Las pruebas usan la base `motorix_v2_test`, jamás la base principal.

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
| 5 | Sin tablas nuevas. `order_parts.unit_price`, `tickets.content`, `tickets.format_version`, `payments.cancellation_reason`; la unicidad de `tickets` pasa de la orden al pago |

## Sprint 5: migraciones 005 y 006

- `005_precios_congelados_tickets_por_pago.sql` (**solo esquema**):
  - `order_parts.unit_price DECIMAL(10,2) NULL`: precio de venta congelado al
    agregar la refacción a la orden (`NULL` = sin precio registrado).
  - `tickets.content JSON NULL` y `tickets.format_version SMALLINT NULL`: copia
    del comprobante y su versión (`1` = formato anterior, `2` = Sprint 5).
  - `payments.cancellation_reason VARCHAR(30) NULL`: `IMPORTE_DESFASADO` o `MANUAL`.
  - Índices de `tickets`: se agrega `idx_tickets_service_order`, se quita
    `uq_tickets_service_order` y se agrega `uq_tickets_payment` (un ticket por pago).
- `006_datos_precio_congelado_copia_tickets.sql` (**solo datos**, en una
  transacción y repetible): congela el precio de las líneas existentes con el
  precio de venta del momento y genera la copia versión 1 de los tickets
  existentes (`total` = lo cobrado; nota si el desglose no coincide).
- `seeds/005_ejemplos_precios_congelados.sql`: completa las filas del seed 004
  (por id) y agrega ejemplos con ids desde 9001 y folios `D009001-2026` a
  `D009003-2026`.

**El 005 es la primera migración que reemplaza una restricción** (la unicidad
de `tickets`). No borra ni modifica datos: no elimina filas ni columnas, solo
cambia qué combinación debe ser única.

**Antes de aplicarla en una base con datos, el respaldo es obligatorio**:

```powershell
mysqldump -u motorix_app -p --single-transaction --routines --no-tablespaces motorix_v2 > respaldo-motorix_v2-antes-005.sql
```

Guarda el respaldo fuera del repositorio y comprueba que esta consulta
devuelva 0 filas (si devuelve filas, no apliques el 005):

```sql
SELECT payment_id, COUNT(*) AS n FROM tickets GROUP BY payment_id HAVING n > 1;
```

Pasos de verificación y recuperación: `specs/005-precios-refacciones-cobro/quickstart.md`.
