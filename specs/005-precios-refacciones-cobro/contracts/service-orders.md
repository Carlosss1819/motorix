# Contrato (cambios): Órdenes de servicio (`/api/service-orders`)

Relacionado: FR-005 a FR-012, FR-021 a FR-023, FR-026, FR-032, FR-034; D-01, D-05, D-08, D-10, H15-a y H15-b.

## `GET /api/service-orders/:id`: refacciones con precio por rol

`repuestos[]` agrega dos campos **solo para ADMIN y RECEPTIONIST**:

| Campo | ADMIN | RECEPTIONIST | MECHANIC |
|---|:-:|:-:|:-:|
| `id`, `descripcion`, `cantidad` | ✔ | ✔ | ✔ |
| `precioUnitario` (congelado; `null` = sin precio) | ✔ | ✔ | — (se omite) |
| `importe` (cantidad × precio, en dos decimales) | ✔ | ✔ | — (se omite) |
| `aviso` («sin precio registrado») | ✔ | ✔ | — (se omite) |

`servicios[].manoDeObra.precio` se sigue enviando a los tres roles (alcance de D-10). Ni el detalle ni el listado incluyen el total ni el subtotal de refacciones (FR-034); el total para cobrar sigue en `GET /api/payments/orden/:ordenId/total` (solo ADMIN y RECEPTIONIST).

## `POST /api/service-orders/:id/refacciones` (y el alias `/repuestos`)

- Guarda `unit_price` = precio de venta vigente, dentro de la transacción del stock.
- `409 REFACCION_SIN_PRECIO`: «La refacción no tiene precio de venta registrado: regístralo en el catálogo antes de usarla» (FR-005).
- `409 TOTAL_EXCEDE_LIMITE`: el total de la orden pasaría de 99,999,999.99. Para el mecánico, el mensaje no incluye cifras (FR-036).
- Respuesta: igual que hoy (`id`, `partId`, `codigo`, `nombre`, `cantidad`, `stockActual`), sin precios para ningún rol.
- `409 ORDEN_CERRADA` en `TERMINADO` y `409 ORDEN_ENTREGADA` en `ENTREGADO`: sin cambios.

## `DELETE /api/service-orders/:id/refacciones/:refaccionId`

Sin cambios de contrato. Es la única forma de corregir un precio congelado (quitar y volver a agregar), mientras la orden no esté en `TERMINADO` ni en `ENTREGADO` (FR-011).

## `POST /api/service-orders/:id/servicios` y `DELETE …/servicios/:servicioId`

- `precio` de la mano de obra: opcional; si viene, numérico, ≥ 0, máximo dos decimales y ≤ 999,999.99. Si no, `400 VALIDACION` (FR-032).
- `409 ORDEN_PAGADA`: «La orden ya está pagada: no admite cambios en sus servicios» cuando la orden está en `TERMINADO` y tiene un pago `PAGADO` no anulado (FR-021). Con un pago `PENDIENTE`, o con el `PAGADO` anulado, se permite (FR-021, FR-022).
- `409 TOTAL_EXCEDE_LIMITE`: igual que en refacciones.
- Las dos operaciones toman el candado de la orden (R-07).
