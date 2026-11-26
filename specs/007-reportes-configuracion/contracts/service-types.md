# Contrato: Tipos de servicio (`/api/service-types`)

Objeto:

```json
{ "id": 70001, "nombre": "Cambio de aceite", "intervaloDias": 180, "intervaloKm": 5000, "activo": true }
```

## GET /api/service-types

- Tres roles (FR-009). Devuelve los **activos** ordenados por nombre.
- `?incluirInactivos=true`: solo ADMIN (para otro rol se ignora y devuelve solo activos).
- `200`: `{ "elementos": [ ... ] }`.

## POST /api/service-types (ADMIN)

Cuerpo: `nombre` (1–120, obligatorio), `intervaloDias` (entero 1–3650, opcional), `intervaloKm` (entero 1–500000, opcional).

- `201`: el tipo creado.
- `400 INTERVALO_REQUERIDO`: sin ningún intervalo.
- `409 TIPO_SERVICIO_DUPLICADO`: nombre repetido (sin distinguir mayúsculas).
- Bitácora: `TIPO_SERVICIO_CREADO`.

## PUT /api/service-types/:id (ADMIN)

Cuerpo parcial con los mismos campos (`intervaloDias`/`intervaloKm` aceptan `null` para quitarlo, pero debe quedar al menos uno).

- `200` | `400 INTERVALO_REQUERIDO` | `404 TIPO_SERVICIO_NO_ENCONTRADO` | `409 TIPO_SERVICIO_DUPLICADO`.
- Bitácora: `TIPO_SERVICIO_EDITADO`.

## POST /api/service-types/:id/desactivar y /activar (ADMIN)

- `200`: el tipo con su nuevo estado (idempotente). `404` si no existe.
- Bitácora: `TIPO_SERVICIO_DESACTIVADO` / `TIPO_SERVICIO_ACTIVADO`.
- No existe `DELETE` (FR-008).
