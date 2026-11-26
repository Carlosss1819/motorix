# Modelo de datos: Reportes y configuración del taller

Migración `database/migrations/008_configuracion_terminos_bitacora.sql` (solo DDL, aditiva: crea 5 tablas y agrega 1 columna nullable). Seed `database/seeds/007_ejemplos_configuracion_terminos.sql` (ids 70001 a 70099, `INSERT IGNORE` / `ON DUPLICATE KEY UPDATE`).

## settings (nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| setting_key | VARCHAR(60) PK | `shop.name`, `shop.address`, `shop.phone`, `maintenance.advance_days`, `maintenance.advance_km` |
| setting_value | VARCHAR(255) NOT NULL | validado por el servicio según la clave (FR-001, FR-004) |
| updated_by | INT NULL → users.id | quién guardó |
| updated_at | DATETIME | `ON UPDATE CURRENT_TIMESTAMP` |

Respaldo sin fila: `Motorix` / `Av. Ejemplo 123, Col. Centro` / `55-0000-0000` / 30 / 500.

## service_types (nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| id | INT PK | seed 70001+ |
| name | VARCHAR(120) NOT NULL, UNIQUE | único sin distinguir mayúsculas (colación `unicode_ci`) |
| interval_days | INT NULL | 1–3650 |
| interval_km | INT NULL | 1–500000 |
| is_active | TINYINT(1) DEFAULT 1 | desactivar = ocultar, nunca borrar |
| created_at, updated_at | DATETIME | |

`CHECK (interval_days IS NOT NULL OR interval_km IS NOT NULL)`.

## order_services (existente, columna nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| service_type_id | INT NULL → service_types.id (RESTRICT) | opcional; las filas existentes quedan `NULL` |

## terms_versions (nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| id | INT PK | seed 70001 = versión `1.0` |
| version | VARCHAR(20) UNIQUE | |
| published_at | DATETIME NOT NULL | |
| terms_text | TEXT NOT NULL | términos y condiciones |
| privacy_text | TEXT NOT NULL | aviso de privacidad (elementos mínimos LFPDPPP + nota de plantilla académica) |
| is_current | TINYINT(1) DEFAULT 0 | vigente = la más reciente con `is_current = 1` |

## terms_acceptances (nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| id | INT PK | |
| user_id | INT → users.id | |
| terms_version_id | INT → terms_versions.id | |
| accepted_at | DATETIME DEFAULT CURRENT_TIMESTAMP | |

`UNIQUE (user_id, terms_version_id)` (aceptar dos veces es idempotente).

## audit_log (nueva)

| Campo | Tipo | Reglas |
|-------|------|--------|
| id | BIGINT PK | |
| created_at | DATETIME DEFAULT CURRENT_TIMESTAMP | índice |
| user_id | INT NULL → users.id (SET NULL) | NULL en login fallido sin usuario |
| action | VARCHAR(40) NOT NULL | lista cerrada (research R-06); índice con fecha |
| entity_type | VARCHAR(40) NULL | `user`, `settings`, `service_type`, `part`, `payment`, `terms` |
| entity_id | INT NULL | |
| detail | VARCHAR(255) NULL | nunca contraseñas, hashes, tokens ni tarjetas |

Sin rutas de edición ni de borrado; sin borrado automático.

## tickets.content (existente, sin cambio de esquema)

La copia v2 agrega, solo en tickets nuevos, `proximosServicios: [{ tipoServicio, fecha | null, kilometraje | null }]`. `taller` sale de `settings` al emitir.

## Seed 007 (Entrega A)

- `settings`: los 5 valores con los mismos datos del respaldo (para no alterar tickets ni pruebas existentes).
- `service_types` 70001–70005: Cambio de aceite (180 días, 5,000 km), Afinación (365, 20,000), Rotación de llantas (180, 10,000), Revisión de frenos (365, sin km), Cambio de anticongelante (730, 40,000).
- `terms_versions` 70001: versión `1.0`, vigente.
- Entrega B (T061): cliente, vehículo y refacciones 70001–70002, órdenes 70001–70003 entregadas en el mes en curso con su historial (70001–70012), servicios y mano de obra 70001–70004, líneas de refacción 70001–70003, pagos 70001–70004 (tres `PAGADO`, uno `ANULADO`) y movimientos 70001–70005. Las fechas son relativas a `CURDATE()` y no salen del mes. Las cifras esperadas están en el comentario del seed.
