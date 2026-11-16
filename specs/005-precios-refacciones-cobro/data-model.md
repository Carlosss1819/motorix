# Modelo de datos (Fase 1): Precios de refacciones y cobro completo

**Funcionalidad**: [spec.md](./spec.md) · **Decisiones**: [research.md](./research.md) · **Fecha**: 2026-11-14

Los cambios de esquema van en scripts nuevos numerados. Ninguna migración anterior se edita y ningún dato existente se borra ni cambia de valor: el `006` solo escribe en columnas nuevas que nacen en `NULL`.

## Resumen de cambios

| Tabla | Cambio | Script | Requisitos |
|---|---|---|---|
| `order_parts` | + `unit_price DECIMAL(10,2) NULL` | 005 (DDL), 006 (datos) | FR-006, FR-007, FR-010, SC-011 |
| `tickets` | + `content JSON NULL`, + `format_version SMALLINT NULL`, + `idx_tickets_service_order`, − `uq_tickets_service_order`, + `uq_tickets_payment` | 005 (DDL), 006 (datos) | FR-019, FR-020, FR-033, SC-012, SC-013 |
| `payments` | + `cancellation_reason VARCHAR(30) NULL` | 005 | FR-016, SC-010 |
| `parts` | sin cambios de esquema; la validación cambia en el servidor | — | FR-001 a FR-005 |
| `order_labor` | sin cambios de esquema; la validación cambia en el servidor y en Flutter | — | FR-032 |

## `order_parts` (línea de refacción de la orden)

| Columna | Tipo | Nueva | Regla |
|---|---|:-:|---|
| `id` | INT PK | | |
| `service_order_id` | INT FK | | |
| `part_id` | INT NULL FK | | `NULL` = línea de texto libre heredada (Sprint 2); hoy ya no se pueden crear (RN-6). |
| `description` | VARCHAR | | Copia histórica del nombre (R-06 del Sprint 3). |
| `quantity` | INT | | ≥ 1. |
| `unit_price` | DECIMAL(10,2) NULL | ✔ | Precio de venta congelado al agregar la línea. `NULL` = «sin precio registrado» (vale 0). |

**Reglas**:
- Al agregar una línea (`addPart`), `unit_price = parts.sale_price` dentro de la misma transacción que descuenta el stock. Si `sale_price` es `NULL`, se rechaza con `409 REFACCION_SIN_PRECIO` (FR-005).
- `unit_price` nunca se actualiza después (FR-007, FR-011). Para corregirlo, se quita la línea y se vuelve a agregar.
- Importe de la línea = `quantity × unit_price`, en centavos enteros (R-06).

**Migración de datos (006)**: `UPDATE order_parts op JOIN parts p ON p.id = op.part_id SET op.unit_price = p.sale_price WHERE op.unit_price IS NULL`. Si `p.sale_price` es `NULL`, la línea queda en `NULL`.

## `tickets` (comprobante de un pago)

| Columna | Tipo | Nueva | Regla |
|---|---|:-:|---|
| `id` | INT PK | | |
| `service_order_id` | INT FK | | Ya no es único: una orden puede tener varios tickets (FR-033). Lo cubre `idx_tickets_service_order`. |
| `payment_id` | INT FK | | **Único** (`uq_tickets_payment`): un ticket por pago `PAGADO`. |
| `folio` | VARCHAR(20) UNIQUE | | Sin cambios: `T000001-2026`, consecutivo por año. |
| `issued_by` | INT FK | | |
| `issued_at` | DATETIME | | |
| `content` | JSON NULL | ✔ | Copia del comprobante (estructura abajo). Solo es `NULL` antes de que corra el `006` o el seed 005. |
| `format_version` | SMALLINT NULL | ✔ | `1` = «formato anterior» (generado al migrar); `2` = formato del Sprint 5. |

**Índices**: en una sola sentencia, `ADD KEY idx_tickets_service_order (service_order_id)`, `DROP INDEX uq_tickets_service_order`, `ADD UNIQUE KEY uq_tickets_payment (payment_id)` (R-01).

**Estados derivados al consultar** (no se guardan):
- `vigente`: el ticket es del pago `PAGADO` no anulado de la orden.
- `pagoAnulado`: `payments.status = 'ANULADO'` para el pago del ticket.
- `formatoAnterior`: `format_version = 1`.

### Ticket: copia del contenido

La misma forma que devuelve hoy `GET /api/tickets/:id` (contrato del Sprint 4), más tres campos nuevos:

```json
{
  "folio": "T000002-2026",
  "ordenId": 5,
  "pagoId": 2,
  "emitidoPor": "recepcion",
  "emitidoEn": "2026-11-13 10:00:00",
  "taller": { "nombre": "Motorix", "direccion": "…", "telefono": "…" },
  "cliente": { "id": 4, "nombre": "…", "telefono": "…" },
  "vehiculo": { "id": 2, "marca": "…", "modelo": "…", "anio": 2019, "placas": "…", "kilometraje": 82650 },
  "servicios": [
    {
      "descripcion": "Cambio de pastillas delanteras",
      "manoDeObra": 750.00,
      "avisoManoDeObra": null,
      "refacciones": [
        { "codigo": "PAS-DEL01", "nombre": "Juego de pastillas delanteras", "cantidad": 2,
          "precioUnitario": 320.00, "subtotal": 640.00, "aviso": null }
      ]
    }
  ],
  "subtotalManoDeObra": 750.00,
  "subtotalRefacciones": 640.00,
  "total": 1390.00,
  "metodoPago": "TARJETA",
  "fecha": "2026-11-13",
  "formatoVersion": 1,
  "desgloseNoCoincide": false,
  "nota": null
}
```

- `refacciones[].aviso`: «sin precio registrado» cuando la línea no tiene precio (FR-018).
- `servicios[].avisoManoDeObra`: «sin precio registrado» cuando la mano de obra no tiene precio (`order_labor.price` en `NULL`; vale 0 en el total), igual que en el desglose del pago (FR-018). Si tiene precio, es `null`. En la versión 1, el `006` lo llena con la misma regla.
- `total`: en la versión 1 siempre es `payments.amount` (FR-020). En la versión 2 es el total calculado, que por FR-013 coincide con el pago.
- `desgloseNoCoincide` / `nota`: solo en la versión 1, cuando `subtotalManoDeObra + subtotalRefacciones ≠ payments.amount`. La nota es «El desglose no coincide con lo cobrado».
- **No** se guardan: `estadoPago`, `pagoAnulado` ni `vigente`. Se calculan al consultar.

**Migración de datos (006)**: un `UPDATE tickets t JOIN payments p … SET t.content = JSON_OBJECT(…), t.format_version = 1 WHERE t.content IS NULL`. Arma el desglose con `JSON_ARRAYAGG` desde `order_labor` y `order_parts`, con los precios congelados que el mismo `006` acaba de escribir, y aplica la regla del importe pagado.

## `payments`

| Columna | Tipo | Nueva | Regla |
|---|---|:-:|---|
| `cancellation_reason` | VARCHAR(30) NULL | ✔ | Solo con `status = 'CANCELADO'`: `IMPORTE_DESFASADO` (FR-016) o `MANUAL`. Los pagos cancelados antes del sprint quedan en `NULL`. |

Máquina de estados sin cambios: `PENDIENTE → PAGADO | RECHAZADO | CANCELADO`, `PAGADO → ANULADO`.

## Entidades sin cambio de esquema

- **`parts`**: `category` (texto libre, obligatoria), `brand` (texto libre, opcional), `purchase_price` y `sale_price` (`DECIMAL(10,2) NULL`). Validación nueva en el servidor: máximo dos decimales y ≤ 999,999.99 (FR-003). Si `sale_price < purchase_price`, la respuesta lleva `advertencias: ["PRECIO_VENTA_MENOR_A_COMPRA"]` (FR-004).
- **`order_labor`**: `price DECIMAL(10,2) NULL`. Las mismas validaciones que los precios de refacciones (FR-032).
- **`service_orders`**: sin columnas nuevas. Su fila se usa como candado (`SELECT … FOR UPDATE`) en las operaciones de cobro y contenido (R-07).

## Reglas de inmovilización (FR-021 a FR-023)

| Estado de la orden | Pago | Servicios (alta/baja) | Refacciones (alta/baja) |
|---|---|---|---|
| `RECIBIDO` … `ESPERANDO_REFACCION` | — | permitido | permitido |
| `TERMINADO` | sin pago, o `PENDIENTE`, `RECHAZADO`, `CANCELADO` | permitido | rechazado (`ORDEN_CERRADA`, como hoy) |
| `TERMINADO` | `PAGADO` no anulado | **rechazado** (`ORDEN_PAGADA`, nuevo) | rechazado |
| `TERMINADO` | el `PAGADO` fue anulado y no hay otro | permitido | rechazado |
| `ENTREGADO` | — | rechazado (`ORDEN_ENTREGADA`) | rechazado |

## Validaciones nuevas

| Campo | Regla | Código de error |
|---|---|---|
| `precioCompra`, `precioVenta`, `manoDeObra.precio` | numérico, ≥ 0, máximo 2 decimales, ≤ 999,999.99 | `400 VALIDACION` |
| Refacción sin `sale_price` al agregarla a una orden | rechazar | `409 REFACCION_SIN_PRECIO` |
| Total que pasaría de 99,999,999.99 | rechazar la operación | `409 TOTAL_EXCEDE_LIMITE` |
| Alta o baja de servicio con `PAGADO` vigente | rechazar | `409 ORDEN_PAGADA` |
| Confirmar como `PAGADO` con importe distinto del total | cancelar el pago y rechazar | `409 IMPORTE_DESFASADO` |
