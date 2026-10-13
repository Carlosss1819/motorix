# Contrato: Mecánicos activos (`GET /api/users/mechanics`)

Endpoint ligero agregado en la US3 del Sprint 2 para que recepción pueda
asignar mecánicos a una orden (FR‑009) sin acceder al listado completo de
usuarios, que sigue siendo exclusivo del `ADMIN` (contrato `users.md` del
Sprint 1).

## `GET /api/users/mechanics`

- **Roles**: `ADMIN` y `RECEPTIONIST`.
- **Reglas**: devuelve solo los usuarios con rol `MECHANIC` en estado `ACTIVE`,
  ordenados por nombre de usuario; incluye únicamente `id` y `username`.
- **Respuesta `200`**:

  ```json
  [
    { "id": 3, "username": "mecanico" }
  ]
  ```

- **Errores**: `401` sin token; `403` rol no autorizado (`ROL_NO_AUTORIZADO`).
