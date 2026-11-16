# Contrato (cambios): Tickets (`/api/tickets`)

Relacionado: FR-017 a FR-020, FR-022, FR-033; D-09; aclaraciones de CHK003, CHK004 y CHK021. Rutas para ADMIN y RECEPTIONIST, sin cambios; el mecánico recibe `403` (FR-035).

## Formato del ticket

Es el mismo del Sprint 4, pero **se lee de la copia guardada** (`tickets.content`), no se reconstruye. Se agregan estos campos:

| Campo | Origen | Descripción |
|---|---|---|
| `formatoVersion` | copia | `1` = formato anterior; `2` = Sprint 5. |
| `formatoAnterior` | calculado | `true` si `formatoVersion = 1`. |
| `desgloseNoCoincide` | copia | Solo en la versión 1: el desglose no suma lo cobrado. |
| `nota` | copia | «El desglose no coincide con lo cobrado» o `null`. |
| `estadoPago` | calculado | Estado actual del pago (antes se reconstruía igual). |
| `pagoAnulado` | calculado | `true` si `estadoPago = "ANULADO"`. No se guarda en la copia. |
| `vigente` | calculado | `true` si el ticket es del pago `PAGADO` no anulado de la orden. |

`refacciones[].aviso`: «sin precio registrado» en las líneas sin precio (FR-018).

## `POST /api/tickets` (generar)

Cuerpo sin cambios: `{ "ordenId": 12 }`.

- Busca el pago `PAGADO` no anulado de la orden. Si no hay: `409 TICKET_REQUIERE_PAGO` (sin cambios).
- Si **ese pago** ya tiene ticket: `200` con el existente (idempotente, HU4-2).
- Si no: `201` con un ticket nuevo, folio consecutivo y copia en versión 2.
- Ya no devuelve el ticket de un pago anulado (corrige H2).

## `GET /api/tickets/orden/:ordenId`

Cambia la respuesta para reflejar varios tickets por orden:

```json
{
  "existe": true,
  "ticket": { "id": 160, "folio": "T000160-2026", "vigente": true, "pagoAnulado": false, "…": "…" },
  "tickets": [
    { "id": 160, "folio": "T000160-2026", "pagoId": 702, "emitidoEn": "2026-11-20 12:00:00", "vigente": true, "pagoAnulado": false, "formatoAnterior": false },
    { "id": 151, "folio": "T000151-2026", "pagoId": 690, "emitidoEn": "2026-11-18 09:30:00", "vigente": false, "pagoAnulado": true, "formatoAnterior": false }
  ]
}
```

- `ticket`: el vigente, o `null` si no hay pago `PAGADO` no anulado. `existe` se conserva por compatibilidad con el cliente actual.
- `tickets`: todos los de la orden, del más reciente al más antiguo.

## `GET /api/tickets/:id`

Devuelve la copia más los campos calculados. La búsqueda por folio sigue siendo una función interna del servicio (`getTicketByFolio`), sin ruta pública. Un ticket de un pago anulado se sigue consultando, con `pagoAnulado: true` y `vigente: false`.
