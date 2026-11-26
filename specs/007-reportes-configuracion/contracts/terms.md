# Contrato: Términos y aviso de privacidad (`/api/terms`) y cambios en `/api/auth`

## Regla general (FR-020)

Con sesión válida pero sin aceptar la versión vigente, toda ruta protegida responde:

```json
{ "error": { "mensaje": "Debe aceptar los términos y condiciones y el aviso de privacidad para continuar", "codigo": "TERMINOS_PENDIENTES" } }
```

con `403`, excepto: `GET /api/auth/me`, `POST /api/auth/logout`, `GET /api/terms/current`, `POST /api/terms/accept`. Si no hay versión vigente publicada, nada queda pendiente.

## POST /api/auth/login (cambio)

La respuesta `200` agrega `terminosPendientes: boolean`. `GET /api/auth/me` también lo agrega.

## GET /api/terms/current (cualquier usuario autenticado)

`200`:

```json
{ "id": 70001, "version": "1.0", "publicadoEn": "2026-11-26 00:00:00",
  "terminos": "...", "avisoPrivacidad": "...", "aceptado": false, "aceptadoEn": null }
```

`404 TERMINOS_NO_PUBLICADOS` si no hay versión vigente.

## POST /api/terms/accept (cualquier usuario autenticado)

Cuerpo: `{ "version": "1.0" }`.

- `200`: `{ "version": "1.0", "aceptadoEn": "..." }` (idempotente: repetir devuelve la misma fecha).
- `409 VERSION_NO_VIGENTE`: la versión enviada no es la vigente (la pantalla quedó vieja).
- Bitácora: `TERMINOS_ACEPTADOS` (solo la primera vez).

## GET /api/terms/acceptances (ADMIN)

Query: `pagina`, `porPagina` (máx. 50), `version` (opcional).
`200`: `{ "elementos": [{ "usuarioId", "username", "version", "aceptadoEn" }], "pagina", "paginas", "total" }`.

Rechazar en la app = `POST /api/auth/logout` (FR-019).
