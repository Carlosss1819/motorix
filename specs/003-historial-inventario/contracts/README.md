# Contratos de Interfaz (Fase 1) — API REST del Sprint 3

**Funcionalidad**: Historial, mantenimiento e inventario (`003-historial-inventario`)
**Fecha**: 2026-10-13 | **Plan**: [plan.md](plan.md) | **Modelo de datos**:
[../data-model.md](../data-model.md)

Contrato que expone el backend al frontend (y a cualquier cliente HTTP). Formato
adecuado al tipo de proyecto: servicios web con API REST. Se suman a las rutas de los
sprints 1 y 2 documentadas en `specs/001-base-clientes-vehiculos/contracts/` y
`specs/002-citas-ordenes-servicio/contracts/`.

## Convenciones comunes

- **Base URL**: `http://localhost:<PUERTO_API>` (variable de entorno), prefijo `/api`.
- **Autenticación**: encabezado `Authorization: Bearer <token JWT>`; todas las rutas de
  este documento son *Protegidas*: token válido, usuario `ACTIVE` y rol permitido → `401`
  sin sesión o `403` con rol insuficiente.
- **Cuerpos**: JSON, codificación UTF‑8, claves en español (patrón de los sprints 1 y 2).
- **Respuesta de éxito**: el recurso o la colección directamente, o un objeto con
  mensaje de confirmación cuando no hay cuerpo que devolver.
- **Paginación**: parámetros `?pagina=` (por defecto 1) y `?porPagina=` (por defecto 10,
  máximo 50); respuesta `{ "elementos": [...], "pagina": n, "paginas": n, "total": n }`
  (patrón R‑10 del Sprint 2, aplicado al historial por la clarificación 5).
- **Errores**: `400` validación, `401` sin sesión, `403` rol, `404` recurso, `409`
  conflicto; cuerpo `{"error": "<CÓDIGO>", "message": "<texto en español>"}`.
- **Término canónico**: «refacción» (clarificación 3). Las rutas `/repuestos` heredadas
  del Sprint 2 se conservan como alias compatibles de `/refacciones`.

## Rutas de este sprint

| Método y ruta | Descripción | Roles | Detalle |
|---------------|-------------|-------|---------|
| `GET /api/vehicles/:id/history` | Historial del vehículo | ADMIN, RECEPTIONIST, MECHANIC | [history.md](history.md) |
| `GET /api/maintenance` | Listado de mantenimientos | ADMIN, RECEPTIONIST, MECHANIC | [maintenance.md](maintenance.md) |
| `GET /api/maintenance/:id` | Detalle de un mantenimiento | ADMIN, RECEPTIONIST, MECHANIC | [maintenance.md](maintenance.md) |
| `POST /api/maintenance` | Registrar próximo mantenimiento | ADMIN, MECHANIC | [maintenance.md](maintenance.md) |
| `PUT /api/maintenance/:id` | Editar mantenimiento | ADMIN, MECHANIC | [maintenance.md](maintenance.md) |
| `POST /api/maintenance/:id/realizar` | Marcar «servicio realizado» | ADMIN, MECHANIC | [maintenance.md](maintenance.md) |
| `GET /api/parts` | Inventario (búsqueda y filtros) | ADMIN, RECEPTIONIST, MECHANIC | [parts.md](parts.md) |
| `GET /api/parts/:id` | Detalle de refacción | ADMIN, RECEPTIONIST, MECHANIC | [parts.md](parts.md) |
| `GET /api/parts/:id/movements` | Movimientos de una refacción | ADMIN, RECEPTIONIST, MECHANIC | [parts.md](parts.md) |
| `POST /api/parts` | Registrar refacción | ADMIN | [parts.md](parts.md) |
| `PUT /api/parts/:id` | Editar refacción (sin stock) | ADMIN | [parts.md](parts.md) |
| `POST /api/parts/:id/desactivar` | Desactivar refacción | ADMIN | [parts.md](parts.md) |
| `POST /api/parts/:id/movements` | Entrada o ajuste de stock | ADMIN | [parts.md](parts.md) |
| `POST /api/service-orders/:id/refacciones` | Agregar refacción a la orden | ADMIN, RECEPTIONIST, MECHANIC (solo las suyas) | [parts.md](parts.md) |
| `DELETE /api/service-orders/:id/refacciones/:refaccionId` | Retirar refacción de la orden | ADMIN, RECEPTIONIST, MECHANIC (solo las suyas) | [parts.md](parts.md) |
| `POST /api/service-orders/:id/repuestos` | *Heredada*: alias de `/refacciones` | igual que `/refacciones` | [parts.md](parts.md) |
| `DELETE /api/service-orders/:id/repuestos/:repuestoId` | *Heredada*: alias de `/refacciones` | igual que `/refacciones` | [parts.md](parts.md) |

## Matriz de permisos (RN‑15, SC‑009)

| Operación | ADMIN | RECEPTIONIST | MECHANIC |
|-----------|:-----:|:------------:|:--------:|
| Consultar historial, inventario, movimientos y mantenimientos | ✓ | ✓ | ✓ |
| Crear, editar y realizar mantenimientos | ✓ | — | ✓ |
| Registrar, editar y desactivar refacciones; entradas y ajustes | ✓ | — | — |
| Agregar o retirar refacciones en una orden | ✓ | ✓ | ✓ (solo órdenes asignadas) |

La autorización se comprueba en la ruta (`authorize`) **y** en `service` donde hay
reglas de propiedad; la interfaz no es la fuente de permisos (SC‑009).

## Códigos de error nuevos

| Código | HTTP | Cuándo |
|--------|------|--------|
| `CODIGO_DUPLICADO` | 409 | Ya existe una refacción con ese código (FR‑017) |
| `REFACCION_NO_ENCONTRADA` | 404 | `partId` inexistente |
| `REFACCION_INACTIVA` | 409 | Refacción desactivada usada en una orden (FR‑019, FR‑023) |
| `STOCK_INSUFICIENTE` | 409 | Cantidad mayor que el stock disponible (FR‑025, RN‑8) |
| `MANTENIMIENTO_NO_ENCONTRADO` | 404 | Mantenimiento inexistente |
| `MANTENIMIENTO_DUPLICADO` | 409 | Ya hay un registro para ese vehículo y tipo |
| `MANTENIMIENTO_SIN_INTERVALO` | 400 | «Servicio realizado» sin intervalo ni nuevos objetivos (R‑05) |
| `OBJETIVO_REQUERIDO` | 400 | Mantenimiento sin fecha ni kilometraje objetivo (FR‑009) |
| `AJUSTE_SIN_MOTIVO` | 400 | Ajuste de stock sin motivo (FR‑029) |
| `KILOMETRAJE_INVALIDO` | 400 | Kilometraje menor al vigente sin corrección del administrador (FR‑006, heredado) |
