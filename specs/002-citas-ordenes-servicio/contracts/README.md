# Contratos de Interfaz (Fase 1) — API REST del Sprint 2

**Funcionalidad**: Gestión de Citas y Órdenes de Servicio (`002-citas-ordenes-servicio`)
**Fecha**: 2026-10-12 | **Plan**: [plan.md](plan.md) | **Modelo de datos**:
[../data-model.md](../data-model.md)

Contrato que expone el backend al frontend (y a cualquier cliente HTTP). Formato
adecuado al tipo de proyecto: servicios web con API REST. Se suman a las rutas del
Sprint 1 documentadas en
`specs/001-base-clientes-vehiculos/contracts/`.

## Convenciones comunes

- **Base URL**: `http://localhost:<PUERTO_API>` (variable de entorno), prefijo `/api`.
- **Autenticación**: encabezado `Authorization: Bearer <token JWT>`; todas las rutas de
  este documento son *Protegidas*: token válido, usuario `ACTIVE` y rol permitido → `401`
  sin sesión o `403` con rol insuficiente.
- **Cuerpos**: JSON, codificación UTF‑8, claves en español (patrón del Sprint 1).
- **Respuesta de éxito**: el recurso o la colección directamente, o un objeto con
  mensaje de confirmación cuando no hay cuerpo que devolver.
- **Respuesta de error** (siempre en español, sin trazas internas):

  ```json
  { "error": { "mensaje": "Mensaje claro y accionable", "codigo": "CODIGO_NEGOCIO" } }
  ```

- **Códigos HTTP**: `200` ok, `201` creado, `400` validación o regla de negocio
  violada, `401` sin sesión, `403` rol no autorizado, `404` no encontrado, `409` conflicto
  (conflicto de cita, transición inválida o acción no permitida en ese estado), `500`
  error interno.
- **Validación**: todos los cuerpos con `zod` en `server/validators/`; los mensajes
  detallan qué dato corregir.
- **Paginación** (solo listados): query `?pagina=` (default 1) y `?porPagina=` (default
  10, máximo 50). Respuesta:

  ```json
  { "elementos": [ ... ], "pagina": 1, "paginas": 3, "total": 27 }
  ```

  Las listas sin paginación explícita devuelven el arreglo directamente.

## Endpoints

| Archivo | Recurso | Endpoints |
|---------|---------|-----------|
| [appointments.md](appointments.md) | Citas de recepción | `GET /api/appointments`, `POST /api/appointments`, `GET /api/appointments/:id`, `PUT /api/appointments/:id`, `POST /api/appointments/:id/cancelar`, `POST /api/appointments/:id/recibir` |
| [service-orders.md](service-orders.md) | Órdenes de servicio | `GET /api/service-orders`, `POST /api/service-orders`, `GET /api/service-orders/:id`, `PUT /api/service-orders/:id`, `POST /api/service-orders/:id/asignar`, `POST /api/service-orders/:id/estado`, `POST /api/service-orders/:id/diagnostico`, `POST /api/service-orders/:id/servicios`, `DELETE /api/service-orders/:id/servicios/:servicioId`, `POST /api/service-orders/:id/repuestos`, `DELETE /api/service-orders/:id/repuestos/:repuestoId`, `POST /api/service-orders/:id/recomendaciones` |

## Reglas de autorización por rol

| Rol | Citas (lectura/alta/edición) | Órdenes (listado) | Órdenes (contenido: diagnóstico, servicios, repuestos, recomendaciones) | Transiciones de estado | Asignación de mecánico |
|-----|------------------------------|-------------------|--------------------------------------------------------------------------|------------------------|------------------------|
| `ADMIN` | sí | todas | cualquier orden | todas las transiciones válidas | sí |
| `RECEPTIONIST` | sí | todas | cualquier orden | ingreso (`RECIBIDO`, alta) y entrega (`ENTREGADO`) | sí |
| `MECHANIC` | no (`403`) | solo las suyas (FR‑010) | solo sus órdenes | `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`, `TERMINADO` solo en sus órdenes | no |

- El filtro del mecánico lo aplica el **backend** (no el frontend): `GET
  /api/service-orders` con token de `MECHANIC` ignora filtros que intenten ver órdenes
  ajenas (SC‑003).
- Toda transición se comprueba en `server/services/service_order.service.js` aunque la
  ruta ya tenga `authorize` (RN‑15, FR‑022).
