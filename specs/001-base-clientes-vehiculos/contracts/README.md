# Contratos de Interfaz (Fase 1) — API REST del Sprint 1

**Funcionalidad**: Base del Sistema, Clientes y Vehículos (`001-base-clientes-vehiculos`)
**Fecha**: 2026-10-11 | **Plan**: [plan.md](plan.md) | **Modelo de datos**:
[data-model.md](../data-model.md)

Contrato que expone el backend al frontend (y a cualquier cliente HTTP). Formato
adecuado al tipo de proyecto: servicios web con API REST.

## Convenciones comunes

- **Base URL**: `http://localhost:<PUERTO_API>` (variable de entorno), prefijo `/api`.
- **Autenticación**: encabezado `Authorization: Bearer <token JWT>`. Las rutas marcadas
  como *Protegida* exigen token válido, estado `ACTIVE` y rol permitido; todo lo demás
  se deniega con `401` (sin sesión) o `403` (rol insuficiente).
- **Sesión**: el token expira a las 8 horas como máximo y la sesión cierra a los 30
  minutos de inactividad (FR‑004, R‑02).
- **Cuerpos**: JSON, codificación UTF‑8.
- **Respuesta de éxito**: el recurso o la colección directamente, o un objeto con
  mensaje de confirmación cuando no hay cuerpo que devolver.
- **Respuesta de error** (siempre en español, sin trazas internas):

  ```json
  { "error": { "mensaje": "Mensaje claro y accionable", "codigo": "CODIGO_NEGOCIO" } }
  ```

- **Códigos HTTP**: `200` ok, `201` creado, `400` validación, `401` sin sesión o
  credenciales inválidas, `403` rol no autorizado, `404` no encontrado, `409` conflicto
  (duplicado), `423` cuenta bloqueada, `500` error interno.
- **Validación**: todos los cuerpos se validan con los esquemas de
  `server/validators/`; los mensajes de validación detallan qué dato corregir.

## Endpoints

| Archivo | Recurso | Endpoints |
|---------|---------|-----------|
| [auth.md](auth.md) | Sesión y contraseña | `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`, `POST /api/auth/change-password` |
| [users.md](users.md) | Usuarios (solo ADMIN) | `GET /api/users`, `POST /api/users`, `PATCH /api/users/:id` |
| [clients.md](clients.md) | Clientes | `GET /api/clients`, `POST /api/clients`, `GET /api/clients/:id`, `PUT /api/clients/:id` |
| [vehicles.md](vehicles.md) | Vehículos | `GET /api/vehicles`, `POST /api/vehicles`, `GET /api/vehicles/:id`, `PUT /api/vehicles/:id` |

## Reglas de autorización por rol

| Rol | Auth | Users | Clients | Vehicles |
|-----|------|-------|---------|----------|
| `ADMIN` | sí | CRUD (sin borrado físico) | CRUD | CRUD |
| `RECEPTIONIST` | sí | no | CRUD | CRUD |
| `MECHANIC` | sí | no | no | no |

> El acceso del rol `MECHANIC` está en conflicto abierto con
> `docs/project-context.md` (solo lectura): ver R‑04 en
> [research.md](../research.md). El contrato aplica la decisión de la especificación.
