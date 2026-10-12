# Contrato: Citas de recepción (`/api/appointments`)

Relacionado: FR‑005, FR‑006, FR‑007, FR‑008, FR‑020; historias 2 y 6 (HU2, HU6);
aclaraciones del 2026‑10‑11.

Rutas **protegidas**: roles `ADMIN` y `RECEPTIONIST`; `MECHANIC` recibe `403`
(FR‑020).

## `GET /api/appointments`

- **Consulta**: `?fecha=AAAA-MM-DD` (día exacto), `?desde=` y `?hasta=` (rango),
  `?estado=PROGRAMADA|RECIBIDA|CANCELADA|NO_PRESENTADA`, `?buscar=<texto>` (nombre del
  cliente o placas), `?pagina=&porPagina=`.
- Al ejecutarse, las citas `PROGRAMADA` cuya fecha y hora ya pasaron pasan a
  `NO_PRESENTADA` (detección perezosa, FR‑006, R‑06).
- **Respuesta `200`** (paginada):

  ```json
  {
    "elementos": [
      {
        "id": 1,
        "clienteId": 1,
        "cliente": "Juan Pérez",
        "vehiculoId": 1,
        "vehiculo": "Nissan Versa 2020",
        "placas": "ABC1234",
        "fecha": "2026-10-13",
        "hora": "10:30",
        "motivo": "Revisión de frenos",
        "estado": "PROGRAMADA",
        "motivoCancelacion": "",
        "ordenId": null
      }
    ],
    "pagina": 1,
    "paginas": 1,
    "total": 1
  }
  ```

## `POST /api/appointments`

- **Cuerpo**:

  ```json
  { "clienteId": 1, "vehiculoId": 1, "fecha": "2026-10-13", "hora": "10:30", "motivo": "Revisión de frenos" }
  ```

- **Reglas**: todos los campos obligatorios (FR‑005); el vehículo debe existir y
  pertenecer al cliente (RN‑01, RN‑02).
- **Conflicto de horario** (misma fecha, hora y vehículo con cita `PROGRAMADA` o
  `RECIBIDA`, FR‑008): **`409`**

  ```json
  { "error": { "mensaje": "Ya existe una cita para este vehículo el 2026-10-13 a las 10:30", "codigo": "CITA_CONFLICTO_HORARIO", "pendienteConfirmacion": true, "confirmarReenvio": true } }
  ```

  El cliente reenvía la misma petición con `"confirmar": true` para guardarla.
- **Respuesta `201`**: la cita creada (mismo formato del listado).
- **Errores**: `400` datos faltantes o vehículo que no pertenece al cliente;
  `403` rol no autorizado.

## `GET /api/appointments/:id`

- **Respuesta `200`**: la cita y, si ya se derivó, la orden asociada:

  ```json
  {
    "id": 1,
    "clienteId": 1,
    "cliente": "Juan Pérez",
    "vehiculoId": 1,
    "vehiculo": "Nissan Versa 2020",
    "placas": "ABC1234",
    "fecha": "2026-10-13",
    "hora": "10:30",
    "motivo": "Revisión de frenos",
    "estado": "RECIBIDA",
    "motivoCancelacion": "",
    "orden": { "id": 4, "estado": "RECIBIDO", "fechaIngreso": "2026-10-13" }
  }
  ```

- `orden` es `null` cuando la cita todavía no derivó en ninguna (FR‑007).
- **Errores**: `404` cita inexistente.

## `PUT /api/appointments/:id`

- **Cuerpo**: mismo esquema que `POST` (sin `confirmar`).
- **Reglas**: solo citas en estado `PROGRAMADA`; conserva el estado y el motivo de
  cancelación. Vuelve a aplicar la validación de conflicto de horario.
- **Respuesta `200`**: la cita actualizada.
- **Errores**: `400` inválido; `403` rol; `404` inexistente; `409` conflicto de horario
  o cita que ya no es `PROGRAMADA`.

## `POST /api/appointments/:id/cancelar`

- **Cuerpo**: `{ "motivo": "El cliente no pudo asistir" }` — `motivo` **opcional** y se
  guarda si se envía (aclaración del 2026‑10‑11).
- **Reglas**: solo `PROGRAMADA`; la cancelación no afecta órdenes ya existentes. La
  interfaz pide confirmación antes de llamar.
- **Respuesta `200`**: la cita con `estado: "CANCELADA"`.
- **Errores**: `404` inexistente; `409` si la cita no está `PROGRAMADA`.

## `POST /api/appointments/:id/recibir`

- **Cuerpo**: `{}` (sin campos).
- **Reglas**: solo `PROGRAMADA`; la cita pasa a `RECIBIDA` y **no crea ninguna orden**
  (FR‑007): la respuesta incluye la precarga para el formulario de orden.
- **Respuesta `200`**:

  ```json
  {
    "cita": { "id": 1, "estado": "RECIBIDA" },
    "precargaOrden": { "clienteId": 1, "vehiculoId": 1, "motivo": "Revisión de frenos", "citaId": 1 }
  }
  ```

- **Errores**: `404` inexistente; `409` si la cita no está `PROGRAMADA` (cancelada,
  ya recibida o no presentada).
