# Contrato: Panel de control (`/api/dashboard`)

Relacionado: FR‑010, FR‑011, FR‑012; historias 5 y 6 (HU5, HU6); supuesto «dashboard
al abrir»; RN‑15.

Ruta **protegida**: solo `ADMIN` (FR‑010, RN‑15). Los indicadores se calculan al abrir
el panel con una sola petición; no hay actualización en tiempo real (supuesto del
sprint). El panel solo **resume** datos ya registrados en los sprints 1 a 3: no crea
copias ni tablas derivadas (CA‑6, FR‑012).

## `GET /api/dashboard`

- **Roles**: solo `ADMIN`.
- **Consulta**: `?fecha=AAAA-MM-DD` (día de referencia para citas y mantenimientos;
  por defecto, la fecha actual).
- **Respuesta `200`**:

```json
{
  "fecha": "2026-10-13",
  "ordenes": {
    "total": 12,
    "abiertas": 7,
    "entregadas": 5,
    "porEstado": {
      "RECIBIDO": 2,
      "DIAGNOSTICO": 1,
      "EN_REPARACION": 2,
      "ESPERANDO_REFACCION": 1,
      "TERMINADO": 1,
      "ENTREGADO": 5
    }
  },
  "citas": {
    "hoy": 2,
    "proximas": [
      { "id": 9, "fecha": "2026-10-14", "hora": "10:00", "cliente": "María López", "estado": "PROGRAMADA" }
    ]
  },
  "mantenimientos": {
    "proximos": [
      { "id": 5, "vehiculo": "Nissan Versa ABC-123-D", "tipo": "Cambio de aceite", "estado": "PROXIMO", "objetivo": "2026-10-20" }
    ],
    "vencidos": [
      { "id": 2, "vehiculo": "Chevrolet Aveo XYZ-987-L", "tipo": "Rotación de llantas", "estado": "VENCIDO", "objetivo": "2026-10-01" }
    ]
  },
  "alertasInventario": {
    "stockBajo": 3,
    "refacciones": [
      { "id": 2, "codigo": "PAD-001", "nombre": "Juego de pastillas delanteras", "stockActual": 3, "stockMinimo": 5 }
    ]
  }
}
```

- `ordenes.porEstado` usa los seis estados de `ORDER_STATUSES` (`RECIBIDO`,
  `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`, `TERMINADO`, `ENTREGADO`);
  `abiertas` = todo lo no entregado (`OPEN_ORDER_STATUSES`) y `entregadas` = `ENTREGADO`.
- `citas.hoy` cuenta las citas de la fecha de referencia con estado `PROGRAMADA` o
  `RECIBIDA`; `proximas` lista las siguientes (máximo 5, orden ascendente).
- `mantenimientos.proximos` y `vencidos` reutilizan el cálculo existente
  (`calcMaintenanceState`, estados `PROXIMO` y `VENCIDO`); `objetivo` es la fecha o el
  kilometraje que disparó la alerta.
- `alertasInventario.refacciones` reutiliza la regla `stockBajo` del inventario
  (`stockActual <= stockMinimo && stockMinimo > 0`), máximo 10 filas ordenadas por
  faltante ascendente.
- Cada bloque puede traer su arreglo vacío (`[]`) y contadores en 0 cuando no hay
  datos: el cliente muestra un estado vacío amigable, sin errores (HU6‑4).
- **Sin bloque de ingresos**: no está en el mínimo de FR‑011; agregarlo sería ampliar
  el alcance (Principio I).
- **Errores**: `401`; `403 PANEL_SOLO_ADMIN` (rol distinto de `ADMIN`, HU5‑2,
  SC‑006); `400 VALIDACION` si `fecha` no tiene formato `AAAA-MM-DD`.

## Consumo en el cliente

`dashboard_provider.dart` llama la ruta al abrir la pantalla y con la acción de
«Actualizar»; `dashboard_screen.dart` pinta los cuatro bloques con estados de carga,
vacío y error. La sección «Panel» solo se muestra en la navegación cuando el rol es
`ADMIN` (doble filtro: navegación oculta + `403` en backend).
