# Contrato: Bitácora (`/api/audit-log`)

Solo **ADMIN** (FR-024). No existen `POST`, `PUT`, `PATCH` ni `DELETE`.

## GET /api/audit-log

Query (todo opcional): `desde`, `hasta` (`AAAA-MM-DD`, inclusive), `usuarioId` (entero), `accion` (una de la lista), `pagina`, `porPagina` (máx. 50, por defecto 20).

`200`:

```json
{
  "elementos": [
    { "id": 12, "fecha": "2026-11-26 10:15:03", "usuarioId": 1, "usuario": "admin",
      "accion": "PRECIO_REFACCION_CAMBIADO", "entidad": "part", "entidadId": 9001,
      "detalle": "Precio de venta: 150.00 → 180.00" }
  ],
  "pagina": 1, "paginas": 3, "total": 47,
  "acciones": ["LOGIN_FALLIDO", "CUENTA_BLOQUEADA", "..."]
}
```

Orden: más reciente primero. `400 VALIDACION` si un filtro es inválido.

## Acciones y origen

| Acción | Origen | Usuario |
|--------|--------|---------|
| `LOGIN_FALLIDO` | contraseña incorrecta o usuario inexistente | el usuario si existe; si no, `null` y el identificador recortado a 60 en el detalle |
| `CUENTA_BLOQUEADA` | quinto intento fallido | el usuario bloqueado |
| `USUARIO_CREADO`, `USUARIO_ROL_CAMBIADO`, `USUARIO_ACTIVADO`, `USUARIO_DESACTIVADO` | `/api/users` | el ADMIN que actuó |
| `CONFIG_ACTUALIZADA` | `PUT /api/settings` | ADMIN |
| `TIPO_SERVICIO_*` | `/api/service-types` | ADMIN |
| `PRECIO_REFACCION_CAMBIADO` | `PUT /api/parts/:id` cuando cambia el precio de compra o de venta | ADMIN |
| `PAGO_ANULADO` | `POST /api/payments/:id/anular` | ADMIN |
| `PAGO_CANCELADO` | `POST /api/payments/:id/confirmar` que termina en `CANCELADO` (manual o por importe desfasado) | quien confirmó |
| `TERMINOS_ACEPTADOS` | `POST /api/terms/accept` | el usuario |

El detalle nunca incluye contraseñas, hashes, tokens ni datos de tarjeta (FR-023).
