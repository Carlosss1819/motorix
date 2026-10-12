# Modelo de Datos (Fase 1)

**Funcionalidad**: Gestión de Citas y Órdenes de Servicio (`002-citas-ordenes-servicio`)
**Fecha**: 2026-10-12 | **Plan**: [plan.md](plan.md) | **Investigación**: [research.md](research.md)

Base de datos: MySQL local (InnoDB, `utf8mb4`). Esquema versionado en
`database/migrations/`, datos de ejemplo en `database/seeds/`. Este sprint crea 6 tablas
nuevas mediante el script **inmutable** `002_citas_ordenes_servicio.sql`; la migración
`001_esquema_inicial.sql` (`users`, `clients`, `vehicles`) no se modifica.

---

## Entidades

### `appointments` — Citas de recepción

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `client_id` | INT | NOT NULL, FK → `clients` (`ON DELETE RESTRICT`) | Cliente de la cita |
| `vehicle_id` | INT | NOT NULL, FK → `vehicles` (`ON DELETE RESTRICT`) | Vehículo de la cita |
| `appointment_date` | DATE | NOT NULL | Fecha de la cita |
| `appointment_time` | TIME | NOT NULL | Hora de la cita |
| `reason` | VARCHAR(255) | NOT NULL | Motivo de la visita (FR‑005) |
| `status` | ENUM | NOT NULL, default `PROGRAMADA`, valores `PROGRAMADA` / `RECIBIDA` / `CANCELADA` / `NO_PRESENTADA` | Estado de la cita |
| `cancel_reason` | VARCHAR(255) | NULL | Motivo de cancelación (opcional, aclaración 2026‑10‑11) |
| `created_by` | INT | NOT NULL, FK → `users` | Recepcionista que la registró |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Alta |
| `updated_at` | DATETIME | NOT NULL, al actualizar | Última modificación |

- **Índices**: `idx_appointments_date_time (appointment_date, appointment_time)` para la
  vista del día; `idx_appointments_status (status)` para filtros.
- **Reglas de validación**: cliente y vehículo existentes y **el vehículo debe pertenecer
  al cliente** elegido (RN‑01, RN‑02); motivo, fecha y hora obligatorios (FR‑005); para
  avisar de conflicto se busca otra cita con la misma fecha, hora y vehículo en
  `PROGRAMADA`/`RECIBIDA` (FR‑008, R‑05).
- **Transiciones de estado**:

  ```text
  PROGRAMADA --(recepcionista la recibe)----------------------------------> RECIBIDA
  PROGRAMADA --(recepcionista la cancela; motivo opcional)-----------------> CANCELADA
  PROGRAMADA --(automático al consultar: fecha+hora ya pasados)------------> NO_PRESENTADA
  RECIBIDA / CANCELADA / NO_PRESENTADA --> (sin transiciones; no se editan)
  ```

  Solo `PROGRAMADA` admite cancelación o recepción; `RECIBIDA` habilita la creación de
  la orden derivada y `CANCELADA` deja de aparecer como cita activa del día (escenarios
  2‑4 de la HU2, FR‑006).
- **Relación con la orden**: no guarda FK hacia la orden. El enlace vive en
  `service_orders.appointment_id` (UNIQUE), de modo que una cita no puede derivar en dos
  órdenes; el detalle de la cita resuelve la orden por esa misma llave (R‑05, FR‑007).

### `service_orders` — Órdenes de servicio

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `client_id` | INT | NOT NULL, FK → `clients` (`ON DELETE RESTRICT`) | Cliente (obligatorio, FR‑001/FR‑002) |
| `vehicle_id` | INT | NOT NULL, FK → `vehicles` (`ON DELETE RESTRICT`) | Vehículo (obligatorio, RN‑02) |
| `appointment_id` | INT | NULL, UNIQUE, FK → `appointments` (`ON DELETE RESTRICT`) | Cita de origen, si la hubo (FR‑007) |
| `status` | ENUM | NOT NULL, default `RECIBIDO`, valores `RECIBIDO` / `DIAGNOSTICO` / `EN_REPARACION` / `ESPERANDO_REFACCION` / `TERMINADO` / `ENTREGADO` | Estado (FR‑014) |
| `visit_reason` | VARCHAR(255) | NOT NULL | Motivo de visita (obligatorio, escenario 2 HU1) |
| `entry_date` | DATE | NOT NULL | Fecha de ingreso |
| `entry_mileage` | INT | NOT NULL, ≥ 0 | Kilometraje de entrada (RN‑03, FR‑018) |
| `mechanic_id` | INT | NULL, FK → `users` (`ON DELETE RESTRICT`) | Mecánico asignado (opcional, FR‑009) |
| `diagnosis` | TEXT | NULL | Diagnóstico del mecánico (FR‑011) |
| `diagnosis_draft` | TINYINT(1) | NOT NULL, default 0 | `1` = diagnóstico en borrador |
| `recommendations` | TEXT | NULL | Recomendaciones para la entrega (FR‑013) |
| `delivery_date` | DATETIME | NULL | Fecha de entrega (se llena en `ENTREGADO`, FR‑015) |
| `mileage_correction_note` | VARCHAR(255) | NULL | Motivo de una corrección de kilometraje (solo `ADMIN`, R‑08) |
| `created_by` | INT | NOT NULL, FK → `users` | Quien creó la orden |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Alta |
| `updated_at` | DATETIME | NOT NULL, al actualizar | Última modificación |

- **Índices**: `uq_service_orders_appointment (appointment_id)`,
  `idx_service_orders_status (status)`,
  `idx_service_orders_mechanic_status (mechanic_id, status)` (listado del mecánico,
  FR‑010), `idx_service_orders_vehicle (vehicle_id)` (historial, RN‑10).
- **Reglas de validación**: cliente y vehículo obligatorios y existentes; el vehículo
  debe pertenecer al cliente (RN‑01, RN‑02); motivo de visita y fecha obligatorios;
  kilometraje ≥ 0 y ≥ al de la última orden del vehículo, salvo corrección explícita
  con motivo (FR‑018, R‑08); una orden `TERMINADO`/`ENTREGADO` no admite reasignación
  (FR‑009); `ENTREGADO` no se modifica ni se elimina (RN‑09, FR‑016).
- **Transiciones de estado** (detalle completo en [research.md](research.md) R‑02 y
  R‑03; autorizadas en backend):

  ```text
  RECIBIDO           → DIAGNOSTICO
  DIAGNOSTICO        → EN_REPARACION | ESPERANDO_REFACCION | TERMINADO
  EN_REPARACION      → ESPERANDO_REFACCION | TERMINADO
  ESPERANDO_REFACCION→ DIAGNOSTICO | EN_REPARACION | TERMINADO
  TERMINADO          → ENTREGADO
  ENTREGADO          → (ninguna)
  ```

### `order_status_history` — Historial de cambios de estado (FR‑015)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `service_order_id` | INT | NOT NULL, FK → `service_orders` (`ON DELETE CASCADE`) | Orden |
| `from_status` | ENUM (mismos valores) | NULL | Estado anterior (`NULL` en el alta) |
| `to_status` | ENUM (mismos valores) | NOT NULL | Estado nuevo |
| `changed_by` | INT | NOT NULL, FK → `users` | Autor del cambio |
| `changed_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Fecha y hora del cambio |
| `note` | VARCHAR(255) | NULL | Comentario opcional del cambio |

- **Índice**: `idx_order_status_history_order (service_order_id, changed_at)`.
- Se inserta también al crear la orden (`NULL → RECIBIDO`), de modo que toda orden
  tenga trazabilidad desde el origen.

### `order_services` — Servicios aplicados a la orden (FR‑012)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `service_order_id` | INT | NOT NULL, FK → `service_orders` (`ON DELETE CASCADE`) | Orden |
| `description` | VARCHAR(150) | NOT NULL | Nombre/descripción del servicio |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Registro |

### `order_labor` — Mano de obra de la orden (FR‑012)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `service_order_id` | INT | NOT NULL, FK → `service_orders` (`ON DELETE CASCADE`) | Orden |
| `service_id` | INT | NOT NULL, FK → `order_services` (`ON DELETE CASCADE`) | Servicio al que pertenece la mano de obra |
| `description` | VARCHAR(150) | NOT NULL | Descripción de la mano de obra |
| `duration_minutes` | INT | NOT NULL, > 0 | Duración (HU4, escenario 2) |
| `price` | DECIMAL(10,2) | NULL | Precio de la mano de obra (informativo; la facturación es del Sprint 4) |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Registro |

- **Índice**: `idx_order_labor_service (service_id)` para recuperar la mano de obra de
  cada servicio y borrarla en cascada.

> Al registrar un servicio desde la interfaz, el backend crea **una fila en
> `order_services` y su partida asociada en `order_labor` en la misma transacción**
> (R‑13 en [research.md](research.md)); así se cumplen las cuatro tablas del insumo del
> sprint sin duplicar la información del servicio y sin partidas de mano de obra
> huérfanas.

### `order_parts` — Repuestos utilizados en la orden (FR‑012)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `service_order_id` | INT | NOT NULL, FK → `service_orders` (`ON DELETE CASCADE`) | Orden |
| `description` | VARCHAR(120) | NOT NULL | Repuesto o refacción usada |
| `quantity` | INT | NOT NULL, default 1, ≥ 1 | Cantidad usada |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Registro |

- **Nota de alcance**: este sprint solo **registra** el repuesto junto a la orden
  (RN‑06). El control de stock y la salida de inventario pertenecen al Sprint 3; por
  eso no hay FK a una tabla de inventario ni validación de stock aquí.

## Relaciones

```text
users (RECEPTIONIST/ADMIN) ──crea──> appointments ──(service_orders.appointment_id)──> service_orders
users (MECHANIC)           ──asignado en──> service_orders
clients ──1──N── vehicles
clients ──1──N── appointments / service_orders
vehicles──1──N── appointments / service_orders
service_orders ──1──N── order_status_history
service_orders ──1──N── order_services / order_labor / order_parts
```

- `client_id` y `vehicle_id` de la orden y de la cita se **validan en backend**
  contra `clients`/`vehicles` antes de insertar (no solo por FK): una FK impide el
  huérfano a nivel de base, pero el mensaje en español debe devolverlo el servicio
  (FR‑002, SC‑002).

## Resumen de cambios de esquema

| Archivo | Contenido | Tipo |
|---------|-----------|------|
| `database/migrations/002_citas_ordenes_servicio.sql` | 6 tablas nuevas + índices y FK | Inmutable, nuevo número |
| `database/seeds/002_ejemplos_citas_ordenes.sql` | ≥ 5 citas y ≥ 4 órdenes con estados variados, historial, servicios y repuestos de ejemplo | Idempotente (`INSERT IGNORE`, ids fijos) |

No se edita ningún script ya aplicado (Principio III).
