# Contrato: Clientes (`/api/clients`)

Relacionado: FR‑013, FR‑014, FR‑015; historias 2 y 4 (US3 y US4); aclaración Q3.

Rutas **protegidas**: roles `ADMIN` y `RECEPTIONIST` (`403` para el resto).

## `GET /api/clients`

- **Consulta**: `?buscar=<texto>` filtra por nombre, teléfono o correo.
- **Respuesta `200`**:

  ```json
  [
    { "id": 1, "nombre": "María López", "telefono": "5512345678", "email": "maria@correo.com", "estado": "ACTIVO", "fechaRegistro": "2026-10-11" }
  ]
  ```

## `POST /api/clients`

- **Cuerpo**:

  ```json
  { "nombre": "María López", "telefono": "5512345678", "email": "maria@correo.com" }
  ```

- **Reglas**: `nombre` y `telefono` obligatorios; `email` opcional (aclaración Q3). Un
  teléfono repetido en otro cliente responde `200` con aviso para confirmar, no bloquea:

  ```json
  { "aviso": "Ya existe un cliente con este teléfono", "confirmarReenvio": true }
  ```

  El cliente confirma reenviando con `confirmar: true`.

- **Respuesta `201`**: el cliente creado.
- **Errores**: `400` datos faltantes o inválidos (indica el dato a corregir).

## `GET /api/clients/:id`

- **Respuesta `200`**: el cliente y sus vehículos asociados (FR‑014, CA‑4):

  ```json
  {
    "id": 1,
    "nombre": "María López",
    "telefono": "5512345678",
    "email": "maria@correo.com",
    "estado": "ACTIVO",
    "fechaRegistro": "2026-10-11",
    "vehiculos": [ { "id": 1, "placas": "ABC1234", "marca": "Nissan", "modelo": "Versa", "anio": 2020 } ]
  }
  ```

- Cliente sin vehículos: `200` con `"vehiculos": []` (sin error).
- **Errores**: `404` cliente inexistente.

## `PUT /api/clients/:id`

Edición completa conservando los vehículos asociados (FR‑015).

- **Cuerpo**: mismo esquema que `POST`.
- **Respuesta `200`**: el cliente actualizado.
- **Errores**: `400` datos inválidos (no se aplica el cambio); `403` rol no autorizado;
  `404` inexistente.
