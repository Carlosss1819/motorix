# Contratos del Sprint 5

Estos documentos describen **solo los cambios** respecto de los contratos del Sprint 4 (`specs/004-pagos-tickets-dashboard/contracts/`) y del Sprint 3 (catálogo de refacciones). Lo que no se menciona queda igual.

| Archivo | Alcance | Requisitos |
|---|---|---|
| [parts.md](./parts.md) | `/api/parts`: validación de precios, advertencia D-07 y campos de precio por rol | FR-001 a FR-005, FR-024 a FR-026, FR-036 |
| [service-orders.md](./service-orders.md) | `/api/service-orders`: precio congelado, mano de obra, inmovilización y campos por rol | FR-005 a FR-012, FR-021 a FR-023, FR-032, FR-034 |
| [payments.md](./payments.md) | `/api/payments`: total en centavos, candado por orden, pago pendiente desfasado y expiración de Mercado Pago | FR-013 a FR-016, FR-014 |
| [tickets.md](./tickets.md) | `/api/tickets`: ticket por pago, copia con versión, «formato anterior» y «pago anulado» | FR-017 a FR-020, FR-022, FR-033 |
| [ui-flutter.md](./ui-flutter.md) | Pantallas de Flutter: precios por rol y marcas del ticket | FR-004, FR-024 a FR-026, FR-034, US5 |

Convenciones que se conservan: respuestas JSON con claves en español, errores con `{ "error": { "codigo", "mensaje" } }`, sin trazas internas (principio IV) y permisos validados en el servidor (RN-15).
