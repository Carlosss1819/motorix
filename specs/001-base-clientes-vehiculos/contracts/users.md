# Contrato: Usuarios (`/api/users`) — solo rol ADMIN

Relacionado: FR‑005, FR‑006, FR‑010, FR‑011, FR‑012; historia 5 (US2); aclaración Q2.

Todas las rutas son **protegidas** y requieren rol `ADMIN`; cualquier otro rol recibe
`403` aunque la pantalla no esté visible (FR‑006, RN‑15).

## `GET /api/users`

- **Respuesta `200`**: lista de usuarios (nunca incluye `password_hash`):

  ```json
  [
    { "id": 1, "username": "admin", "email": "admin@motorix.local", "rol": "ADMIN", "estado": "ACTIVO" }
  ]
  ```

## `POST /api/users`

Crea un usuario con rol asignado (FR‑010).

- **Cuerpo**:

  ```json
  { "username": "recepcion2", "email": "recepcion2@motorix.local", "rol": "RECEPTIONIST", "contrasena": "Clave2026!" }
  ```

- **Respuesta `201`**: el usuario creado (sin contraseña).
- **Errores**:

  | Código | Situación |
  |--------|-----------|
  | `400` | Datos faltantes o contraseña que no cumple la política |
  | `409` | `username` o `email` ya en uso (FR‑012) |
  | `403` | Rol distinto de `ADMIN` |

## `PATCH /api/users/:id`

Cambia rol o estado del usuario con **efecto inmediato** (FR‑011, aclaración Q2): al
poner `estado: "INACTIVO"` la sesión abierta de ese usuario se cierra de inmediato; el
nuevo rol rige en la siguiente operación.

- **Cuerpo** (parcial):

  ```json
  { "rol": "MECHANIC", "estado": "INACTIVO" }
  ```

- **Respuesta `200`**: el usuario actualizado.
- **Errores**: `400` valor de rol o estado inválido; `403` sin rol `ADMIN`;
  `404` usuario inexistente.
- **Nota**: no existe endpoint de borrado en este sprint (sin borrado físico, FR‑011).
