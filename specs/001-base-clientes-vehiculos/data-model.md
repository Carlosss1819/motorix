# Modelo de Datos (Fase 1)

**Funcionalidad**: Base del Sistema, Clientes y Vehículos (`001-base-clientes-vehiculos`)
**Fecha**: 2026-10-11 | **Plan**: [plan.md](plan.md) | **Investigación**: [research.md](research.md)

Base de datos: MySQL local (InnoDB, `utf8mb4`). Esquema versionado en
`database/migrations/`, datos de ejemplo en `database/seeds/`. Las tablas de este
sprint son `users`, `clients` y `vehicles` (más el control de migraciones
`schema_migrations`).

---

## Entidades

### `users` — Usuarios del sistema

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `username` | VARCHAR(50) | NOT NULL, UNIQUE | Nombre de usuario (login) |
| `email` | VARCHAR(100) | NOT NULL, UNIQUE | Correo electrónico (login) |
| `password_hash` | VARCHAR(255) | NOT NULL | Contraseña con hash (bcryptjs, costo 10); nunca texto plano |
| `role` | ENUM o VARCHAR | NOT NULL, valores `ADMIN` / `RECEPTIONIST` / `MECHANIC` | Rol y permisos |
| `status` | ENUM o TINYINT | NOT NULL, valores `ACTIVE` / `INACTIVE`, default `ACTIVE` | Estado de la cuenta |
| `failed_login_attempts` | INT | NOT NULL, default 0 | Intentos fallidos consecutivos (R‑03) |
| `locked_until` | DATETIME | NULL | Bloqueo temporal tras 5 fallos (15 min, R‑03) |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Fecha de registro |
| `updated_at` | DATETIME | NOT NULL, al actualizar | Última modificación |

- **Índices únicos**: `uq_users_username (username)`, `uq_users_email (email)` (FR‑012).
- **Reglas de validación**: login aceptando `username` o `email` en un mismo campo,
  distinguiendo por presencia de `@` (FR‑002); política de contraseña nueva: mínimo 8
  caracteres con mayúscula, minúscula y número (FR‑008); contraseñas iniciales
  `admin` / `recepcion` / `mecanico` creadas por seeds con hash (FR‑009).
- **Transiciones de estado**:

  ```text
  ACTIVE --(admin desactiva: cierra sesión abierta, efecto inmediato)--> INACTIVE
  INACTIVE --(admin activa)--> ACTIVE
  ```

  `INACTIVE` no puede iniciar sesión; su sesión abierta se cierra de inmediato
  (FR‑011, aclaración Q2). No hay borrado físico en este sprint.

### `clients` — Clientes (propietarios)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `name` | VARCHAR(100) | NOT NULL | Nombre completo (obligatorio, Q3) |
| `phone` | VARCHAR(20) | NOT NULL | Teléfono (obligatorio, Q3) |
| `email` | VARCHAR(100) | NULL | Correo electrónico (opcional, Q3) |
| `status` | ENUM o VARCHAR | NOT NULL, default `ACTIVO` | Estado del cliente (activo/inactivo) |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Fecha de registro (FR‑013) |
| `updated_at` | DATETIME | NOT NULL, al actualizar | Última modificación |

- **Índices**: `idx_clients_name (name)`, `idx_clients_phone (phone)` para búsquedas
  frecuentes de la lista.
- **Reglas de validación**: nombre y teléfono obligatorios (FR‑013); teléfono repetido en
  otro cliente → aviso y confirmación, no bloqueo (R‑05); correo opcional; si existe, se
  valida formato.
- **Relaciones**: un cliente tiene 0..N vehículos (FR‑014, FR‑018).

### `vehicles` — Vehículos

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `client_id` | INT | NOT NULL, FK → `clients.id` | Propietario obligatorio (RN‑1, FR‑017) |
| `brand` | VARCHAR(50) | NOT NULL | Marca |
| `model` | VARCHAR(50) | NOT NULL | Modelo |
| `year` | SMALLINT | NOT NULL | Año |
| `plates` | VARCHAR(20) | NOT NULL, UNIQUE | Placas únicas (FR‑023) |
| `vin` | VARCHAR(20) | NULL, UNIQUE cuando existe | Número de serie, opcional y único (FR‑023) |
| `current_mileage` | INT | NOT NULL, ≥ 0 | Kilometraje actual (FR‑016) |
| `created_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Fecha de registro |
| `updated_at` | DATETIME | NOT NULL, al actualizar | Última modificación |

- **Índices únicos**: `uq_vehicles_plates (plates)`, `uq_vehicles_vin (vin)` (el índice
  permite múltiples `NULL`, cumpliendo "único cuando exista").
- **FK**: `fk_vehicles_client` → `clients.id` con `ON DELETE RESTRICT` (no se borran
  clientes con vehículos en este sprint; no hay borrado físico).
- **Reglas de validación**: sin propietario no se guarda (RN‑1/FR‑017); placas o VIN
  duplicados → rechazo con mensaje (FR‑023); kilometraje no negativo.
- **Relaciones**: N:1 con `clients`; cada vehículo pertenece a un único cliente.

### `schema_migrations` — Control de migraciones

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | INT AUTO_INCREMENT | PK | Identificador |
| `name` | VARCHAR(255) | NOT NULL, UNIQUE | Nombre del script aplicado |
| `applied_at` | DATETIME | NOT NULL, default `CURRENT_TIMESTAMP` | Momento de aplicación |

Los scripts de `database/migrations/` son numerados e inmutables y solo se agregan como
nuevos archivos; los seeds son idempotentes (FR‑020, SC‑005).

---

## Relaciones

```text
users (1) ──── (N) operaciones sobre el sistema (auditoría: fuera de alcance del Sprint 1)

clients (1) ──── (N) vehicles        [FK vehicles.client_id, ON DELETE RESTRICT]
```

## Reglas de validación resumidas (de la especificación)

- **FR‑002 / RN‑16**: login por usuario o correo en un mismo campo (presencia de `@`).
- **FR‑008 / RN‑17**: política de contraseña: ≥ 8 caracteres, mayúscula, minúscula y
  número.
- **FR‑012**: `username` y `email` únicos.
- **FR‑013**: cliente con nombre y teléfono obligatorios; correo opcional.
- **FR‑017 / RN‑1**: vehículo siempre con propietario.
- **FR‑023**: placas únicas; VIN único cuando se captura.
- **FR‑006 / RN‑15**: el rol se verifica en cada operación protegida en el backend.

## Transiciones de estado

- **Usuario**: `ACTIVE ↔ INACTIVE` (solo administrador; desactivar cierra sesiones
  abiertas de inmediato). Bloqueo temporal por intentos fallidos: cuenta operativa →
  bloqueada 15 min tras 5 fallos → operativa (R‑03).
- **Cliente**: `ACTIVO ↔ INACTIVO` (sin borrado físico). No afecta a los vehículos
  asociados (FR‑015).
- **Vehículo**: sin estados en este sprint; es un registro histórico con props
  actualizables.
