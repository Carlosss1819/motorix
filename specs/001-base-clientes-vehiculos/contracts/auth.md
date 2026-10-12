# Contrato: Sesión y contraseña (`/api/auth`)

Relacionado: FR‑001 a FR‑004, FR‑008, FR‑009; aclaraciones Q1 y Q2; R‑02 y R‑03.

## `POST /api/auth/login`

Inicia sesión con usuario o correo en un mismo campo (FR‑001, FR‑002, RN‑16).

- **Protegida**: no.
- **Cuerpo**:

  ```json
  { "identificador": "admin", "contrasena": "Admin2026!" }
  ```

  `identificador` acepta nombre de usuario o correo (el backend decide por la presencia
  de `@`). `contrasena` nunca se almacena ni se devuelve en texto plano.

- **Respuesta `200`**:

  ```json
  {
    "token": "<jwt>",
    "usuario": { "id": 1, "username": "admin", "email": "...", "rol": "ADMIN" }
  }
  ```

- **Errores**:

  | Código | Situación |
  |--------|-----------|
  | `400` | Faltan campos o alguno está vacío |
  | `401` | Credenciales inválidas (mensaje genérico: no revela si falló el usuario o la contraseña, FR‑003) |
  | `403` | Cuenta existente pero desactivada (`CUENTA_INACTIVA`, aclaración Q2: la desactivación surte efecto de inmediato) |
  | `423` | Cuenta bloqueada 15 minutos tras 5 intentos fallidos (R‑03) |

## `POST /api/auth/logout`

- **Protegida**: sí.
- **Cuerpo**: ninguno.
- **Respuesta `200`**: `{ "mensaje": "Sesión cerrada" }`.
- El cliente descarta el token; el acceso a pantallas protegidas queda bloqueado
  (FR‑004).

## `GET /api/auth/me`

Devuelve la sesión actual (rol y estado), útil al reanudar la aplicación.

- **Protegida**: sí.
- **Respuesta `200`**:

  ```json
  { "id": 1, "username": "admin", "email": "...", "rol": "ADMIN" }
  ```

- **Errores**: `401` sin sesión o token expirado; `403` usuario inactivo.

## `POST /api/auth/change-password`

Cambio de la contraseña de la cuenta propia (FR‑008, RN‑17).

- **Protegida**: sí.
- **Cuerpo**:

  ```json
  { "actual": "...", "nueva": "NuevaClave2026" }
  ```

- **Regla de `nueva`**: mínimo 8 caracteres y al menos una mayúscula, una minúscula y
  un número.
- **Respuesta `200`**: `{ "mensaje": "Contraseña actualizada" }`.
- **Errores**: `400` política no cumplida (indica qué requisito falta) o contraseña
  actual incorrecta; `401` sin sesión.
