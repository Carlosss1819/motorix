# Contrato: Mantenimientos preventivos (`/api/maintenance`)

Relacionado: FR‑008 a FR‑015; historias 3 y 4 (HU3, HU4); clarificaciones 1, 2 y 4
del 2026‑10‑13; RN‑11, RN‑12, RN‑15.

Rutas **protegidas**: lectura para los tres roles (clarificación 4); escritura solo
`ADMIN` y `MECHANIC`. El estado (`normal | proximo | vencido`) **no se recibe ni se
guarda**: lo calcula el backend en cada respuesta (R‑04).

## Formato del mantenimiento

```json
{
  "id": 1,
  "vehiculoId": 1,
  "vehiculo": "Nissan Versa 2020",
  "placas": "ABC1234",
  "cliente": "Juan Pérez",
  "tipoServicio": "Cambio de aceite",
  "fechaUltimoServicio": "2026-07-01",
  "kilometrajeUltimoServicio": 40000,
  "fechaObjetivo": "2026-10-30",
  "kilometrajeObjetivo": 45000,
  "intervaloDias": 90,
  "intervaloKm": 5000,
  "antelacionDias": 30,
  "antelacionKm": 500,
  "notas": "Usar aceite 5W30 sintético.",
  "estado": "PROXIMO"
}
```

- `estado` se deriva de la fecha actual y del kilometraje vigente del vehículo
  (FR‑011, FR‑012): `VENCIDO` si ya se alcanzó el kilometraje objetivo o se cumplió la
  fecha objetivo; `PROXIMO` si falta a lo sumo la antelación propia del registro
  (30 días / 500 km por defecto, clarificación 1); `NORMAL` en otro caso.

## `GET /api/maintenance`

- **Consulta**: `?vehiculoId=`, `?estado=normal|proximo|vencido` (filtrado sobre el
  estado calculado), `?buscar=<texto>` (tipo de servicio o placas), `?pagina=&porPagina=`
  (patrón estándar).
- **Reglas**: aplica los tres roles; cada elemento incluye `vehiculo`, `placas` y
  `cliente` para que recepción pueda avisar sin abrir cada ficha (FR‑013, HU4).
  Mantenimientos sin pendientes → lista vacía con total 0 (HU4, escenario 3).
- **Respuesta `200`**: paginada, con el formato de arriba en `elementos`.
- **Errores**: `401`; `403` rol.

## `GET /api/maintenance/:id`

- **Respuesta `200`**: el mantenimiento con todos sus campos.
- **Errores**: `401`, `403`, `404 MANTENIMIENTO_NO_ENCONTRADO`.

## `POST /api/maintenance`

- **Roles**: `ADMIN`, `MECHANIC` (clarificación 4, FR‑008).
- **Cuerpo**:

  ```json
  {
    "vehiculoId": 1,
    "tipoServicio": "Cambio de aceite",
    "fechaObjetivo": "2026-10-30",
    "kilometrajeObjetivo": 45000,
    "intervaloDias": 90,
    "intervaloKm": 5000,
    "antelacionDias": 30,
    "antelacionKm": 500,
    "notas": "Usar aceite 5W30 sintético."
  }
  ```

- **Reglas**:
  - `vehiculoId` y `tipoServicio` obligatorios; el vehículo debe existir (FR‑008).
  - **Al menos uno** de `fechaObjetivo` / `kilometrajeObjetivo` es obligatorio →
    `400 OBJETIVO_REQUERIDO` (FR‑009, RN‑11).
  - `intervaloDias`, `intervaloKm`, `antelacionDias` y `antelacionKm` opcionales: al
    omitirlos se guardan los defectos 30 días / 500 km de antelación (clarificación 1)
    y sin intervalo hasta que se configure (RN‑12); si vienen, deben ser enteros
    positivos.
  - Un registro ya existe por vehículo y tipo → `409 MANTENIMIENTO_DUPLICADO`
    (clarificación 2).
  - El estado inicial se calcula y se devuelve junto con el registro.
- **Respuesta `201`**: el mantenimiento creado.
- **Errores**: `400` validación u objetivo faltante; `403` rol; `404` vehículo;
  `409` duplicado.

## `PUT /api/maintenance/:id`

- **Roles**: `ADMIN`, `MECHANIC`.
- **Cuerpo**: mismos campos editables de `POST` (excepto `vehiculoId`, que no cambia);
  todos opcionales (actualización parcial de los enviados).
- **Reglas**: conserva la validación de objetivo (no puede quedar sin ninguno) y la
  unicidad por vehículo y tipo.
- **Respuesta `200`**: el mantenimiento actualizado, con su estado recalculado.
- **Errores**: `400`, `403`, `404 MANTENIMIENTO_NO_ENCONTRADO`, `409` duplicado.

## `POST /api/maintenance/:id/realizar`

- **Roles**: `ADMIN`, `MECHANIC` (FR‑015, clarificación 2).
- **Cuerpo** (todo opcional):

  ```json
  { "fechaServicio": "2026-10-13", "kilometrajeServicio": 45300 }
  ```

- **Reglas** (una sola transacción, R‑05):
  1. Por defecto `fechaServicio` = hoy y `kilometrajeServicio` = el kilometraje
     vigente del vehículo; si se envía un kilometraje menor al vigente se rechaza con
     `400 KILOMETRAJE_INVALIDO` (misma regla de no‑regresión del Sprint 2; la
     corrección solo la hace `ADMIN` con `correccionKilometraje` igual que en la
     creación de órdenes).
  2. Se actualizan `fechaUltimoServicio` y `kilometrajeUltimoServicio`.
  3. Se recalcula el objetivo: `fechaObjetivo = fechaServicio + intervaloDias` (si hay
     `intervaloDias`) y `kilometrajeObjetivo = kilometrajeServicio + intervaloKm` (si
     hay `intervaloKm`); si no hay ningún intervalo, se usan los objetivos enviados en
     el cuerpo y, si tampoco vienen, `400 MANTENIMIENTO_SIN_INTERVALO`.
  4. Se actualiza `vehicles.current_mileage` con la regla de valor más alto (FR‑007).
  5. El registro **no se duplica** ni cambia de identidad; su estado vuelve a
     `NORMAL` (salvo que los nuevos objetivos ya estén alcanzados).
- **Respuesta `200`**: el mantenimiento renovado con su estado recalculado.
- **Errores**: `400` kilometraje sin corrección o renovación imposible; `403` rol;
  `404` mantenimiento.

## `DELETE /api/maintenance/:id`

No existe en este sprint: los mantenimientos se renuevan, no se eliminan
(clarificación 2). La baja queda fuera de alcance.
