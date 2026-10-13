# Contrato: Historial del vehículo (`GET /api/vehicles/:id/history`)

Relacionado: FR‑001 a FR‑007; historias 1 y 2 (HU1, HU2); clarificación 5 del
2026‑10‑13; RN‑10.

Ruta **protegida** para `ADMIN`, `RECEPTIONIST` y `MECHANIC` (FR‑004). Es un
subrecurso de `GET /api/vehicles/:id` (Sprint 1) y no crea tablas: la respuesta se
deriva de las órdenes terminadas o entregadas del vehículo (RN‑10, R‑01).

## `GET /api/vehicles/:id/history`

- **Consulta**: `?pagina=` (por defecto 1), `?porPagina=` (por defecto 10, máximo 50;
  valores fuera de rango se corrigen al límite, sin error).
- **Reglas**:
  - Solo órdenes con estado `TERMINADO` o `ENTREGADO` (FR‑003); una orden en curso
    jamás aparece ni duplica entradas (SC‑002).
  - Orden: `fechaIngreso` descendente (lo más reciente primero); el orden cronológico
    se conserva dentro de cada página (FR‑001).
  - El kilometraje de cada entrada es el `kilometrajeEntrada` registrado al abrir la
    orden (FR‑005); el backend garantiza además que `vehicles.current_mileage` es el
    valor más alto registrado (FR‑007).
  - Vehículo sin órdenes terminadas → lista vacía, no error (caso límite de la spec).
  - El vehículo debe existir → si no, `404`.
- **Respuesta `200`** (paginada):

  ```json
  {
    "elementos": [
      {
        "ordenId": 4,
        "fechaServicio": "2026-10-10",
        "kilometraje": 45200,
        "estadoOrden": "ENTREGADO",
        "observaciones": "Revisión de frenos",
        "diagnostico": "Pastillas desgastadas en el eje delantero.",
        "servicios": ["Cambio de pastillas delanteras", "Rectificado de discos"],
        "refacciones": [
          { "partId": 2, "codigo": "PAD-001", "nombre": "Juego de pastillas delanteras", "cantidad": 1 }
        ],
        "recomendaciones": "Revisar pastillas traseras en la próxima visita."
      }
    ],
    "pagina": 1,
    "paginas": 3,
    "total": 27
  }
  ```

  - `refacciones[]` de las filas heredadas del Sprint 2 (sin `partId`) devuelven
    `"partId": null` y `"codigo": null`, con `nombre` tomado de la descripción
    guardada en su momento.
  - `diagnostico` y `recomendaciones` pueden ser `null` si la orden no los registró;
    `servicios` y `refacciones` pueden ser arreglos vacíos.
- **Errores**: `401` sin token; `404` vehículo inexistente.
