# T055: prueba de vencimiento de preferencias en el sandbox de Mercado Pago

- **Fecha**: 2026-11-16
- **Responsable**: Carlos
- **Requisitos**: FR-037, SC-014, R-09 (`research.md`), quickstart sección 6 («Expiración de Mercado Pago»)
- **Entorno**: Mercado Pago México, credenciales de prueba de una aplicación de Checkout Pro, configuradas en `server/.env` (el token no se incluye en esta evidencia).

## Pasos

1. Con `MP_ACCESS_TOKEN` configurado y `MP_PREFERENCIA_VIGENCIA_HORAS` en su valor por defecto (24), se reinició el servidor.
2. Se registró un cobro con método Mercado Pago para la orden 9003 (seed 005) por 599.50. La app mostró «Pasarela: sandbox (credenciales configuradas)», es decir, se usó la pasarela real y no la simulada.
3. Se consultó la preferencia en PowerShell con `GET https://api.mercadopago.com/checkout/preferences/{id}`.

## Resultado de la consulta

| Campo | Valor |
|---|---|
| `id` | `3848673735-018d0bca-04d4-4ca6-b317-e80696822056` |
| `expires` | `True` |
| `expiration_date_from` | `2026-11-16T15:35:16.687-06:00` |
| `expiration_date_to` | `2026-11-17T15:35:16.687-06:00` |
| `external_reference` | `MOT-9003-1794864916687` |

## Verificación

| Criterio | Esperado | Obtenido | ¿Cumple? |
|---|---|---|---|
| Mercado Pago acepta la preferencia con vencimiento | Se crea el cobro sin `GATEWAY_ERROR` | Cobro creado en modo sandbox | Sí |
| `expires` | `true` | `True` | Sí |
| Vigencia | 24 horas entre `from` y `to` | Exactamente 24 h 00 min 00.000 s | Sí |
| `external_reference` | `MOT-9003-…` | `MOT-9003-1794864916687` | Sí |
| `GET /checkout/preferences/{id}` devuelve los campos | Los campos aparecen en la consulta | Aparecen | Sí |

Comprobación adicional: la marca de tiempo de la referencia (`1794864916687` ms) corresponde a 2026-11-16 21:35:16.687 UTC, es decir, 15:35:16.687 en la zona -06:00, el mismo instante de `expiration_date_from`. La preferencia se creó con el reloj del servidor y Mercado Pago conservó la zona horaria enviada.

## Conclusión

**PASÓ.** La API de Mercado Pago de México acepta `expires`, `expiration_date_from` y `expiration_date_to` igual que la de Brasil. El riesgo del plan («La API de Mercado Pago de México no acepta el vencimiento como la de Brasil») queda descartado.
