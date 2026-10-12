# Contrato: Órdenes de servicio (`/api/service-orders`)

Relacionado: FR‑001 a FR‑004, FR‑009 a FR‑022; historias 1, 3, 4 y 5 (HU1, HU3, HU4,
HU5); aclaraciones del 2026‑10‑11.

Rutas **protegidas** para todos los roles autenticados, con permisos distintos según el
rol (ver [README.md](README.md)): `ADMIN` y `RECEPTIONIST` gestionan todas las órdenes;
`MECHANIC` solo consulta y opera las suyas (FR‑010, SC‑003).

## `GET /api/service-orders`

- **Consulta**: `?estado=RECIBIDO|DIAGNOSTICO|EN_REPARACION|ESPERANDO_REFACCION|TERMINADO|ENTREGADO`,
  `?estadoAbierta=true` (todo lo que no sea `ENTREGADO`, usado por el panel de
  recepción), `?buscar=<texto>` (placas o nombre/apellido del cliente, FR‑003),
  `?pagina=&porPagina=`.
- **Reglas**: con token de `MECHANIC` el backend devuelve **solo** las órdenes con
  `mechanic_id` igual al usuario, aunque el filtro intente ampliar el alcance
  (FR‑010, RN‑15).
- **Respuesta `200`** (paginada):

  ```json
  {
    "elementos": [
      {
        "id": 4,
        "clienteId": 1,
        "cliente": "Juan Pérez",
        "vehiculoId": 1,
        "vehiculo": "Nissan Versa 2020",
        "placas": "ABC1234",
        "estado": "DIAGNOSTICO",
        "motivoVisita": "Revisión de frenos",
        "fechaIngreso": "2026-10-13",
        "kilometrajeEntrada": 45200,
        "mecanicoId": 3,
        "mecanico": "mecanico",
        "citaId": 1
      }
    ],
    "pagina": 1,
    "paginas": 2,
    "total": 14
  }
  ```

## `POST /api/service-orders`

- **Cuerpo**:

  ```json
  {
    "clienteId": 1,
    "vehiculoId": 1,
    "motivoVisita": "Revisión de frenos",
    "fechaIngreso": "2026-10-13",
    "kilometraje": 45200,
    "mecanicoId": null,
    "citaId": 1
  }
  ```

- **Reglas**:
  - `clienteId`, `vehiculoId`, `motivoVisita`, `fechaIngreso` y `kilometraje`
    obligatorios; el vehículo debe existir y pertenecer al cliente (FR‑001, FR‑002,
    RN‑01, RN‑02). Un cliente sin vehículos no puede generar una orden huérfana.
  - `mecanicoId` opcional; si viene, debe ser un usuario `MECHANIC` activo (FR‑009).
  - `citaId` opcional: la cita debe estar `RECIBIDA` y no usar todavía en otra orden
    (FR‑007). La orden guarda el enlace y la cita conserva su estado.
  - `kilometraje` ≥ 0 y ≥ al de la última orden del vehículo; si es menor se responde
    `400` salvo que venga `correccionKilometraje` (texto obligatorio), que solo `ADMIN`
    puede enviar (FR‑018, R‑08).
  - La orden nace siempre en estado `RECIBIDO` y se registra en el historial de estados
    (FR‑014, FR‑015).
- **Respuesta `201`**: la orden creada (formato del detalle).
- **Errores**: `400` validación (indica el dato a corregir) o kilometraje sin
  corrección; `403` rol; `404` cliente, vehículo, mecánico o cita inexistente;
  `409` cita ya usada o cita que no está `RECIBIDA`.

## `GET /api/service-orders/:id`

- **Respuesta `200`**: orden completa:

  ```json
  {
    "id": 4,
    "clienteId": 1,
    "cliente": "Juan Pérez",
    "telefono": "5551002001",
    "vehiculoId": 1,
    "vehiculo": "Nissan Versa 2020",
    "placas": "ABC1234",
    "estado": "DIAGNOSTICO",
    "motivoVisita": "Revisión de frenos",
    "fechaIngreso": "2026-10-13",
    "kilometrajeEntrada": 45200,
    "notaCorreccionKilometraje": "",
    "mecanicoId": 3,
    "mecanico": "mecanico",
    "citaId": 1,
    "diagnostico": "Pastillas delanteras al límite",
    "diagnosticoBorrador": false,
    "recomendaciones": "Revisar discos en 5,000 km",
    "fechaEntrega": null,
    "servicios": [ { "id": 9, "descripcion": "Cambio de pastillas", "manoDeObra": { "id": 9, "duracionMinutos": 45, "precio": 350 } } ],
    "repuestos": [ { "id": 3, "descripcion": "Juego de pastillas delanteras", "cantidad": 1 } ],
    "historial": [ { "de": null, "a": "RECIBIDO", "usuario": "recepcion", "fecha": "2026-10-13T09:00:00" } ]
  }
  ```

- **Errores**: `403` si un `MECHANIC` pide una orden que no es suya; `404` inexistente.

## `PUT /api/service-orders/:id`

- **Cuerpo**: `{ "motivoVisita": "...", "fechaIngreso": "AAAA-MM-DD", "kilometraje": 45200, "correccionKilometraje": "Corrección autorizada por el cliente" }`.
- **Reglas**: roles `ADMIN` y `RECEPTIONIST`; no aplica a órdenes `TERMINADO` ni
  `ENTREGADO`; la asignación de mecánico no se modifica aquí (ver `/asignar`); la
  validación de kilometraje es la misma que en el alta.
- **Respuesta `200`**: la orden actualizada. **Errores**: `400`, `403`, `404`, `409`.

## `POST /api/service-orders/:id/asignar`

- **Cuerpo**: `{ "mecanicoId": 3 }` o `{ "mecanicoId": null }` para desasignar.
- **Reglas**: roles `ADMIN` y `RECEPTIONIST`; se rechaza en `TERMINADO`/`ENTREGADO`
  (FR‑009, escenario 4 HU3); `mecanicoId` debe ser usuario `MECHANIC` activo.
- **Respuesta `200`**: `{ "id": 4, "mecanicoId": 3, "mecanico": "mecanico" }`.
- **Errores**: `403`, `404`, `409` (orden cerrada).

## `POST /api/service-orders/:id/estado`

- **Cuerpo**: `{ "estado": "EN_REPARACION", "nota": "Se cambiaron bujes" }` (`nota`
  opcional).
- **Reglas** (FR‑014, FR‑022, R‑02 y R‑03): la transición debe estar en el mapa de
  estados y corresponder al rol del usuario:

  | Desde | Hasta permitidos |
  |-------|------------------|
  | `RECIBIDO` | `DIAGNOSTICO` |
  | `DIAGNOSTICO` | `EN_REPARACION`, `ESPERANDO_REFACCION`, `TERMINADO` |
  | `EN_REPARACION` | `ESPERANDO_REFACCION`, `TERMINADO` |
  | `ESPERANDO_REFACCION` | `DIAGNOSTICO`, `EN_REPARACION`, `TERMINADO` |
  | `TERMINADO` | `ENTREGADO` |
  | `ENTREGADO` | — |

  `RECIBIDO → DIAGNOSTICO … → TERMINADO` solo para el mecánico asignado o `ADMIN`;
  `TERMINADO → ENTREGADO` solo para `RECEPTIONIST` o `ADMIN`. Cada cambio se registra
  con usuario y fecha (FR‑015) y `ENTREGADO` llena `fechaEntrega`.
- **Respuesta `200`**: la orden con el estado nuevo y su historial actualizado.
- **Errores**: `403` rol no autorizado para esa transición; `404` inexistente; `409`
  transición inválida, con mensaje que indica los estados permitidos (SC‑004).

## `POST /api/service-orders/:id/diagnostico`

- **Cuerpo**: `{ "texto": "Pastillas delanteras al límite", "borrador": false }`.
- **Reglas**: mientras la orden no esté `ENTREGADO` (escenario 5 HU4);
  `borrador: true` guarda el texto como borrador (FR‑011) y `false` lo marca como
  guardado definitivamente.
- **Respuesta `200`**: `{ "diagnostico": "...", "diagnosticoBorrador": false }`.
- **Errores**: `400` texto vacío; `403` (un `MECHANIC` solo en sus órdenes); `404`;
  `409` orden `ENTREGADO`.

## `POST /api/service-orders/:id/servicios`

- **Cuerpo**: `{ "descripcion": "Cambio de pastillas", "duracionMinutos": 45, "precio": 350 }`
  (`precio` opcional).
- **Reglas**: crea el servicio **y** su partida de mano de obra en la misma transacción
  (FR‑012, R‑13); no aplica en órdenes `ENTREGADO`.
- **Respuesta `201`**: `{ "servicio": { "id": 9, "descripcion": "..." }, "manoDeObra": { "id": 9, "duracionMinutos": 45, "precio": 350 } }`.
- **Errores**: `400`; `403`; `404`; `409` orden `ENTREGADO`.

## `DELETE /api/service-orders/:id/servicios/:servicioId`

- Borra el servicio y su mano de obra asociada (cascada). Solo mientras la orden no
  esté `ENTREGADO`; la interfaz pide confirmación (Principio VIII).
- **Respuesta `200`**: `{ "mensaje": "Servicio eliminado" }`. **Errores**: `403`,
  `404`, `409`.

## `POST /api/service-orders/:id/repuestos`

- **Cuerpo**: `{ "descripcion": "Juego de pastillas delanteras", "cantidad": 1 }`.
- **Reglas**: `cantidad` ≥ 1; registra el repuesto junto a la orden (RN‑06). El stock
  se valida en el Sprint 3, por lo que aquí **no** se consulta inventario.
- **Respuesta `201`**: el repuesto creado. **Errores**: `400`, `403`, `404`, `409`.

## `DELETE /api/service-orders/:id/repuestos/:repuestoId`

- Elimina un repuesto registrado mientras la orden no esté `ENTREGADO` (confirmación en
  la interfaz). **Respuesta `200`** y errores como en el endpoint anterior.

## `POST /api/service-orders/:id/recomendaciones`

- **Cuerpo**: `{ "texto": "Revisar discos en 5,000 km" }`.
- **Reglas**: guarda las recomendaciones para la entrega (FR‑013); no aplica en órdenes
  `ENTREGADO`; un `MECHANIC` solo en sus órdenes.
- **Respuesta `200`**: `{ "recomendaciones": "..." }`. **Errores**: `400`, `403`,
  `404`, `409`.
