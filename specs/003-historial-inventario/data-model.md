# Modelo de Datos (Fase 1)

**Funcionalidad**: Historial, mantenimiento e inventario (`003-historial-inventario`)
**Fecha**: 2026-10-13 | **Plan**: [plan.md](plan.md) | **Investigación**: [research.md](research.md)

Base de datos: MySQL local (InnoDB, `utf8mb4`). Esquema versionado en
`database/migrations/`, datos de ejemplo en `database/seeds/`. Este sprint crea 3 tablas
nuevas (`parts`, `maintenance`, `inventory_movements`) y **agrega columnas** a
`order_parts` mediante el script **inmutable** `003_historial_mantenimiento_inventario.sql`;
los scripts `001` y `002` no se modifican (Principio III).

---

## Entidades

### `parts` — Catálogo de refacciones

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `code` | VARCHAR(30) | NOT NULL, **UNIQUE** | Código único de la refacción (FR‑017) |
| `name` | VARCHAR(120) | NOT NULL | Nombre |
| `category` | VARCHAR(80) | NOT NULL | Categoría |
| `brand` | VARCHAR(80) | NULL | Marca |
| `stock_current` | INT | NOT NULL, DEFAULT 0, CHECK ≥ 0 | Stock actual (nunca negativo, RN‑8) |
| `stock_min` | INT | NOT NULL, DEFAULT 0, CHECK ≥ 0 | Stock mínimo (0 = sin alerta, FR‑021) |
| `purchase_price` | DECIMAL(10,2) | NULL, CHECK ≥ 0 | Precio de compra |
| `sale_price` | DECIMAL(10,2) | NULL, CHECK ≥ 0 | Precio de venta |
| `is_active` | TINYINT(1) | NOT NULL, DEFAULT 1 | Desactivada = no usable en órdenes nuevas (FR‑019) |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Alta |
| `updated_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | Última edición |

- **Índices**: `UNIQUE KEY uq_parts_code (code)`; `KEY idx_parts_name (name)` para el
  filtro por nombre/código (FR‑018).
- **Validaciones de servicio** (no solo de esquema): código duplicado → `409
  CODIGO_DUPLICADO`; `stock_current` solo cambia vía movimientos o ajuste, nunca por
  edición directa del precio/nombre.
- **Regla de stock bajo**: no es columna; se calcula `stock_current <= stock_min
  && stock_min > 0` en la consulta (R‑10).

### `maintenance` — Mantenimientos preventivos

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `vehicle_id` | INT | NOT NULL, FK → `vehicles` (`ON DELETE RESTRICT`) | Vehículo |
| `service_type` | VARCHAR(120) | NOT NULL | Tipo de servicio (p. ej. "Cambio de aceite") |
| `last_service_date` | DATE | NULL | Fecha del último servicio realizado |
| `last_service_mileage` | INT | NULL, CHECK ≥ 0 | Kilometraje del último servicio |
| `target_date` | DATE | NULL | Fecha objetivo (uno de los dos objetivos es obligatorio, FR‑009) |
| `target_mileage` | INT | NULL, CHECK ≥ 0 | Kilometraje objetivo |
| `interval_days` | INT | NULL, CHECK > 0 | Intervalo en días con el que se renueva el objetivo (RN‑12) |
| `interval_km` | INT | NULL, CHECK > 0 | Intervalo en kilómetros con el que se renueva el objetivo |
| `advance_days` | INT | NOT NULL, DEFAULT 30, CHECK > 0 | Antelación en días para «próximo» (FR‑011) |
| `advance_km` | INT | NOT NULL, DEFAULT 500, CHECK > 0 | Antelación en km para «próximo» |
| `notes` | VARCHAR(255) | NULL | Recomendaciones del mecánico (FR‑014) |
| `created_by` | INT | NOT NULL, FK → `users` (`ON DELETE RESTRICT`) | Quién lo creó |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Alta |
| `updated_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE | Última edición |

- **Índices**: `UNIQUE KEY uq_maintenance_vehicle_type (vehicle_id, service_type)`
  (un único registro por vehículo y tipo, clarificación 2); `KEY
  idx_maintenance_vehicle (vehicle_id)`.
- **Validaciones de servicio**: sin `target_date` y sin `target_mileage` → `400
  OBJETIVO_REQUERIDO` (FR‑009); duplicado → `409 MANTENIMIENTO_DUPLICADO`; la
  operación «servicio realizado» exige `interval_days` o `interval_km` (o nuevos
  objetivos en el body) → si no, `400 MANTENIMIENTO_SIN_INTERVALO` (R‑05).
- **Estado**: **no se persiste**; `normal | proximo | vencido` se calcula con
  `utils/maintenance-status.js` en cada consulta (R‑04), a partir de la fecha actual y
  de `vehicles.current_mileage`.

### `inventory_movements` — Movimientos de inventario

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `part_id` | INT | NOT NULL, FK → `parts` (`ON DELETE RESTRICT`) | Refacción |
| `movement_type` | ENUM('ENTRADA','SALIDA','AJUSTE') | NOT NULL | Tipo de movimiento (FR‑028) |
| `quantity` | INT | NOT NULL, CHECK > 0 | Cantidad (siempre positiva; el efecto lo define el tipo) |
| `reason` | VARCHAR(255) | NOT NULL para `AJUSTE`, NULL en otro caso | Motivo (FR‑029) |
| `service_order_id` | INT | NULL, FK → `service_orders` (`ON DELETE RESTRICT`) | Orden asociada cuando corresponde (salida/reposición) |
| `stock_after` | INT | NOT NULL, CHECK ≥ 0 | Stock resultante tras el movimiento (SC‑007) |
| `created_by` | INT | NOT NULL, FK → `users` (`ON DELETE RESTRICT`) | Quién lo registró |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Fecha del movimiento |

- **Índices**: `KEY idx_movements_part (part_id, created_at)` para el historial por
  refacción (FR‑030); `KEY idx_movements_order (service_order_id)`.
- **Tipos y quién los registra** (R‑08, FR‑029): `ENTRADA` (reabastecimiento, solo
  ADMIN; también la reposición automática al retirar una refacción de la orden);
  `SALIDA` (uso en orden, generada por la API al agregar refacciones); `AJUSTE`
  (corrección manual, solo ADMIN, `reason` obligatorio).
- **Integridad**: toda escritura en transacción con `SELECT … FOR UPDATE` sobre
  `parts.stock_current`; si `stock_after < 0` → `ROLLBACK` y `409
  STOCK_INSUFICIENTE` (RN‑8). El `CHECK` de la tabla es la segunda barrera.

### `order_parts` — Refacciones usadas en la orden (tabla existente, ALTER en 003)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador (ya existe) |
| `service_order_id` | INT | NOT NULL, FK → `service_orders` (ya existe) | Orden |
| `description` | VARCHAR(120) | NOT NULL (ya existe) | Nombre de la refacción **copiado del catálogo** al agregarla; las filas heredadas conservan su texto libre |
| `quantity` | INT | NOT NULL, DEFAULT 1 (ya existe) | Cantidad usada |
| `part_id` | INT | **NULL**, FK → `parts` (`ON DELETE RESTRICT`) — *columna nueva* | Refacción del catálogo; `NULL` solo en filas heredadas del Sprint 2 (R‑06) |
| `created_at` | DATETIME | NOT NULL (ya existe) | Alta de la fila |

- **ALTER de la migración 003**: `ALTER TABLE order_parts ADD COLUMN part_id INT NULL,
  ADD CONSTRAINT fk_order_parts_part FOREIGN KEY (part_id) REFERENCES parts (id) ON
  DELETE RESTRICT, ADD KEY idx_order_parts_part (part_id);`
- **Validación de servicio**: agregar una fila nueva exige `part_id` de una refacción
  **activa** con stock suficiente (FR‑023/FR‑025); la fila heredada sin `part_id` solo
  es legible.

### Entidad derivada: `vehicle_history` (no es tabla)

Vista consolidada de `service_orders` con `status IN ('TERMINADO','ENTREGADO')` del
vehículo, enriquecida con `order_services`, `order_parts` (unidas a `parts` cuando hay
`part_id`), `diagnosis`, `visit_reason` y `recommendations`, paginada (R‑01). Cada
entrada: `fechaServicio`, `kilometraje`, `orden`, `diagnostico`, `servicios[]`,
`refacciones[]`, `observaciones`, `recomendaciones`.

---

## Relaciones

```text
clients 1 ──── n vehicles ─┬─ n maintenance   (UNIQUE vehicle_id + service_type)
                           ├─ n service_orders ─┬─ n order_services
                           │                    ├─ n order_labor
                           │                    ├─ n order_parts ── n parts (part_id, nullable)
                           │                    └─ n inventory_movements (service_order_id, nullable)
                           └─ (historial = vista de service_orders terminadas)

parts 1 ──── n inventory_movements (part_id)
users 1 ──── n maintenance / inventory_movements (created_by)
```

## Reglas de negocio trazadas

| RN (project-context §13) | Dónde se cumple |
|--------------------------|-----------------|
| RN‑6: refacciones relacionadas con la orden | `order_parts.part_id` NOT NULL de servicio (catálogo activo), R‑06 |
| RN‑7: uso genera salida de inventario | `SALIDA` en la misma transacción que agrega la fila, R‑08 |
| RN‑8: stock nunca negativo | transacción + `FOR UPDATE` + `CHECK`s, R‑08 |
| RN‑10: historial deriva de órdenes | vista sin tabla propia, R‑01 |
| RN‑11: mantenimiento por fecha y/o km | `target_date`/`target_mileage` con al menos uno, FR‑009 |
| RN‑12: intervalos configurables | `interval_days`/`interval_km` por registro, R‑05 |
| RN‑15: permisos en backend | matriz de R‑11 aplicada en `routes` + `service` |
