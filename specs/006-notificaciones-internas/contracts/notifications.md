# Contrato: avisos internos (`/api/notifications`)

Todas las rutas requieren sesión (`authenticate`). Los tres roles pueden llamarlas; el servidor filtra por rol y por asignación (FR-009 a FR-013). Ningún aviso incluye importes (FR-012).

## `GET /api/notifications`

Calcula los avisos del usuario (antes llama a la detección de citas vencidas, R-03).

**200**:

```json
{
  "noLeidos": 4,
  "totalAvisos": 6,
  "grupos": [
    {
      "tipo": "MANT_VENCIDO",
      "titulo": "Mantenimientos vencidos",
      "cantidad": 1,
      "noLeidos": 1,
      "avisos": [
        {
          "clave": "MANT_VENCIDO:60001:2026-11-06|-",
          "tipo": "MANT_VENCIDO",
          "titulo": "Mantenimiento vencido",
          "descripcion": "Cambio de aceite · Nissan Versa 2020 (ABC1234)",
          "fechaReferencia": "2026-11-06",
          "leido": false,
          "destino": { "pantalla": "VEHICULO", "id": 60001 }
        }
      ]
    }
  ]
}
```

- `grupos` en el orden fijo de FR-007a; solo aparecen grupos con avisos. Dentro de cada grupo: no leídos primero, luego `fechaReferencia` ascendente.
- `destino.pantalla`: `ORDEN` (id de la orden), `CITAS` (con `fecha`), `VEHICULO` (id del vehículo), `REFACCION` (id de la refacción).
- Descripción por tipo:
  - `MANT_*`: servicio · vehículo (placas).
  - `STOCK_*`: código · nombre · existencia y mínimo (sin precios).
  - `CITA_HOY`: hora · cliente · vehículo.
  - `ORDEN_DETENIDA`: «Orden #N» · vehículo · estado · «N días sin cambio».
- MECHANIC: solo grupo `ORDEN_DETENIDA` con sus órdenes; nunca otros grupos.
- Sin avisos: `{ "noLeidos": 0, "totalAvisos": 0, "grupos": [] }`.
- Ninguna clave de la respuesta se llama `total`, `subtotal`, `precio*`, `importe*` ni `monto*`: el conteo de avisos se llama `totalAvisos` para no confundirse con un total de dinero (FR-012, regla del mecánico del Sprint 5).

## `GET /api/notifications/count`

**200**: `{ "noLeidos": 4 }` — mismo cálculo que el anterior, sin armar los grupos para la interfaz (FR-017).

## `POST /api/notifications/read`

**Cuerpo**: `{ "clave": "MANT_VENCIDO:60001:2026-11-06|-" }` — cadena de 1 a 120 caracteres.

**204**: siempre que la clave sea válida en formato, exista o no entre los avisos del usuario (FR-030). Solo se guarda si la clave está entre sus avisos actuales; repetirla no duplica.

**400 `VALIDACION`**: falta `clave` o excede 120 caracteres.

## Errores comunes

| Código HTTP | `codigo` | Cuándo |
|---|---|---|
| 401 | `SESION_REQUERIDA` | sin token o sesión expirada (código real del middleware `authenticate`) |
| 400 | `VALIDACION` | cuerpo inválido en `read` |
