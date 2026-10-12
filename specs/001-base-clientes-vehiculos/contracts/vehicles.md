# Contrato: Vehículos (`/api/vehicles`)

Relacionado: FR‑016, FR‑017, FR‑018, FR‑023; historia 3 (US5 y US6); RN‑1; aclaración Q4.

Rutas **protegidas**: roles `ADMIN` y `RECEPTIONIST` (`403` para el resto).

## `GET /api/vehicles`

- **Consulta**: `?buscar=<texto>` filtra por placas, marca, modelo o propietario;
  `?clienteId=<id>` filtra por propietario.
- **Respuesta `200`**:

  ```json
  [
    {
      "id": 1, "clienteId": 1, "dueno": "María López",
      "marca": "Nissan", "modelo": "Versa", "anio": 2020,
      "placas": "ABC1234", "vin": "3N1AB7AP1KY123456", "kilometrajeActual": 45000
    }
  ]
  ```

## `POST /api/vehicles`

- **Cuerpo**:

  ```json
  {
    "clienteId": 1, "marca": "Nissan", "modelo": "Versa", "anio": 2020,
    "placas": "ABC1234", "vin": "3N1AB7AP1KY123456", "kilometrajeActual": 45000
  }
  ```

- **Reglas**: `clienteId` obligatorio (RN‑1/FR‑017); `vin` opcional pero único cuando
  existe; `kilometrajeActual` ≥ 0 (FR‑016).
- **Respuesta `201`**: el vehículo creado, incluyendo `dueno`.
- **Errores**:

  | Código | Situación |
  |--------|-----------|
  | `400` | Sin propietario, datos faltantes o kilometraje negativo (mensaje: "Seleccione el propietario") |
  | `404` | `clienteId` de un cliente inexistente |
  | `409` | Placas ya en uso, o VIN ya en uso (FR‑023) |

## `GET /api/vehicles/:id`

- **Respuesta `200`**: la ficha del vehículo con su propietario (FR‑018).
- **Errores**: `404` vehículo inexistente.

## `PUT /api/vehicles/:id`

Actualización de datos (por ejemplo, kilometraje).

- **Cuerpo**: mismo esquema que `POST` (el propietario no se cambia en este sprint).
- **Respuesta `200`**: el vehículo actualizado.
- **Errores**: `400` datos inválidos; `409` placas o VIN duplicados; `404` inexistente.
