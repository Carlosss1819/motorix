# Contrato (cambios): Pagos (`/api/payments`)

Relacionado: FR-013 a FR-016; D-04, D-08; riesgo D-04. Rutas para ADMIN y RECEPTIONIST, sin cambios; el mecánico recibe `403` (FR-035).

## Total de la orden (`GET /api/payments/orden/:ordenId/total`)

Misma forma que en el Sprint 4. Cambian el cálculo y un campo:
- Se calcula en centavos enteros con `unit_price` congelado; el resultado se responde con dos decimales (R-06).
- `desglose.refacciones[].precioUnitario` es el precio congelado; `aviso` es «sin precio registrado» cuando la línea no tiene precio.

## Registro (`POST /api/payments`)

- Cuerpo y respuestas iguales al Sprint 4. `MONTO_NO_COINCIDE` compara en centavos (igualdad exacta).
- **Concurrencia (CA-8, R-07)**: la validación final y el `INSERT` ocurren con el candado de la orden. De dos solicitudes simultáneas, exactamente una se registra; la otra recibe `409 ORDEN_YA_LIQUIDADA` o `409 PAGO_PENDIENTE`.
- **Mercado Pago (R-09)**: la preferencia se crea con `expires: true`, `expiration_date_from` = ahora y `expiration_date_to` = ahora + `MP_PREFERENCIA_VIGENCIA_HORAS` (24 por defecto), en ISO 8601 con zona horaria. La pasarela simulada ignora estos campos.

## Confirmación (`POST /api/payments/:id/confirmar`)

Cuerpo sin cambios: `{ "estado": "PAGADO" | "RECHAZADO" | "CANCELADO" }`.

- `estado: PAGADO`: con el candado de la orden, se recalcula el total. Si `importe ≠ total`, el pago pasa a `CANCELADO` con `motivoCancelacion: "IMPORTE_DESFASADO"` y se responde:

```json
{ "error": {
    "codigo": "IMPORTE_DESFASADO",
    "mensaje": "El importe del pago (1390.00) ya no coincide con el total de la orden (1090.00); el pago se canceló. Antes de generar uno nuevo, revisa en el panel de Mercado Pago si el cliente ya pagó.",
    "importePago": 1390.00,
    "totalActual": 1090.00,
    "diferencia": 300.00 } }
```

- `estado: CANCELADO`: guarda `motivoCancelacion: "MANUAL"`. `estado: RECHAZADO`: no compara el importe.
- Confirmar un pago que ya no está `PENDIENTE` (por ejemplo, `CANCELADO`): `409 TRANSICION_INVALIDA`, sin cambios.

## Formato del pago

Se agrega `motivoCancelacion` (`"IMPORTE_DESFASADO"`, `"MANUAL"` o `null`). Los demás campos no cambian.

## Anulación (`POST /api/payments/:id/anular`, solo ADMIN)

Sin cambios de contrato. Ahora toma el candado de la orden. Después de anular, la orden vuelve a admitir cambios en sus servicios (FR-022) y un pago nuevo generará un ticket nuevo (FR-033).
