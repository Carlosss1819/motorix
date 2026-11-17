# Modelo de datos: Notificaciones internas (Sprint 6)

**Fecha**: 2026-11-16 · **Spec**: [spec.md](./spec.md) · **Investigación**: [research.md](./research.md)

## Tablas nuevas (migración `007_notificaciones_internas.sql`)

Aditiva: solo crea tablas; no toca tablas existentes.

### `notification_reads`

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | |
| `user_id` | INT NOT NULL | FK → `users(id)` ON DELETE CASCADE |
| `notice_key` | VARCHAR(120) NOT NULL | clave del aviso (R-05) |
| `read_at` | DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP | |

Índices: `UNIQUE uq_notification_reads_user_key (user_id, notice_key)`.

### `client_notices`

| Columna | Tipo | Reglas |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | |
| `client_id` | INT NOT NULL | FK → `clients(id)` ON DELETE RESTRICT |
| `reason` | ENUM('VEHICULO_LISTO','CITA_MANANA','MANT_PROXIMO','MANT_VENCIDO') NOT NULL | motivo al momento de avisar |
| `fact_key` | VARCHAR(120) NOT NULL | `ORDEN:<id>`, `CITA:<id>` o `MANT:<id>:<objetivo>` |
| `notified_by` | INT NOT NULL | FK → `users(id)` ON DELETE RESTRICT |
| `notified_at` | DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP | |

Índices: `UNIQUE uq_client_notices_fact (fact_key)`, `KEY idx_client_notices_client (client_id)`.

Sin nota, sin edición y sin borrado desde la app (FR-020, FR-023).

## Entidades calculadas (no se guardan)

### Aviso

| Campo | Origen |
|---|---|
| `clave` | R-05 |
| `tipo` | `MANT_PROXIMO`, `MANT_VENCIDO`, `STOCK_BAJO`, `STOCK_AGOTADO`, `CITA_HOY`, `ORDEN_DETENIDA` |
| `titulo`, `descripcion` | texto armado en el servicio; sin importes (FR-012) |
| `fechaReferencia` | FR-007 |
| `leido` | existe fila en `notification_reads` para el usuario y la clave |
| `destino` | `{ pantalla: 'ORDEN'|'CITAS'|'VEHICULO'|'REFACCION', id, fecha? }` |

Reglas de inclusión por tipo y por rol: spec FR-003 a FR-006 y FR-009 a FR-011.

| Tipo | Fuente | ADMIN | RECEPTIONIST | MECHANIC |
|---|---|---|---|---|
| `MANT_PROXIMO` / `MANT_VENCIDO` | `maintenance` + `vehicles.current_mileage` + `calcMaintenanceState` | ✅ | ✅ | ❌ |
| `STOCK_BAJO` / `STOCK_AGOTADO` | `parts` (regla `WHERE_STOCK_BAJO` existente) | ✅ | ❌ | ❌ |
| `CITA_HOY` | `appointments` de `CURDATE()` en `PROGRAMADA`/`RECIBIDA` | ✅ | ✅ | ❌ |
| `ORDEN_DETENIDA` | `service_orders` + `order_status_history` (R-04) | ✅ | ✅ | solo `mechanic_id = usuario` |

### Cliente por avisar

| Campo | Origen |
|---|---|
| `clave` | clave del hecho (R-05) |
| `motivo` | `VEHICULO_LISTO` (orden `TERMINADO`), `CITA_MANANA` (cita de `CURDATE() + 1` en `PROGRAMADA`/`RECIBIDA`), `MANT_PROXIMO`, `MANT_VENCIDO` |
| `cliente` | `{ id, nombre, telefono }` |
| `vehiculo` | `{ id, descripcion (marca modelo año), placas }` |
| `fecha` | orden: fecha del paso a `TERMINADO`; cita: fecha y hora; mantenimiento: fecha objetivo o fecha del cálculo |

Se excluyen los hechos cuya `fact_key` ya existe en `client_notices`. Orden de la lista: FR-029.

## Transiciones

- Un aviso aparece y desaparece solo según su condición; no tiene estado propio más allá de la lectura.
- Un cambio de estado del objeto cambia la clave → aviso nuevo no leído (FR-015).
- Un hecho de cliente pasa de «por avisar» a «avisado» una sola vez (FR-020); no hay transición de regreso.

## Configuración

| Variable | Valor por defecto | Uso |
|---|---|---|
| `NOTIF_ORDEN_DETENIDA_DIAS` | 3 | N de orden detenida (entero > 0) |
