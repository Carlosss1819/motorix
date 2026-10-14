# Contratos REST: Pagos, Tickets y Dashboard

Contratos de la funcionalidad `004-pagos-tickets-dashboard` (Sprint 4).

| Archivo | Rutas | Historias |
|---------|-------|-----------|
| [payments.md](payments.md) | `/api/payments` | HU1, HU2, HU3 |
| [tickets.md](tickets.md) | `/api/tickets` | HU4 |
| [dashboard.md](dashboard.md) | `/api/dashboard` | HU5, HU6 |

Convenciones comunes (heredadas de los sprints 1 a 3):

- Autenticación por `Authorization: Bearer <jwt>`; sin token → `401`.
- Autorización por rol validada en backend (`ADMIN`, `RECEPTIONIST`, `MECHANIC`).
- Errores con el formato `{ "error": { "mensaje": "...", "codigo": "..." } }`.
- Claves de payload y respuesta en español; validación con `zod` (`400 VALIDACION`).
- Fechas `AAAA-MM-DD`; montos con dos decimales (pesos mexicanos).
- Paginación estándar: `?pagina=&porPagina=` (máximo 50), respuesta con `elementos`,
  `pagina`, `paginas` y `total`.
