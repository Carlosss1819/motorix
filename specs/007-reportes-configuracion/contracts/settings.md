# Contrato: Configuración del taller (`/api/settings`)

Solo **ADMIN** (FR-006). Otros roles: `403 ROL_NO_AUTORIZADO`. Sin sesión: `401`.

## GET /api/settings

`200`:

```json
{
  "taller": { "nombre": "Motorix", "direccion": "Av. Ejemplo 123, Col. Centro", "telefono": "55-0000-0000" },
  "mantenimiento": { "antelacionDias": 30, "antelacionKm": 500 }
}
```

Las claves sin fila guardada devuelven el valor de respaldo (FR-003).

## PUT /api/settings

Cuerpo parcial (al menos un campo):

| Campo | Regla |
|-------|-------|
| `nombreTaller` | texto 1–120 |
| `direccionTaller` | texto 1–200 |
| `telefonoTaller` | texto 1–30 |
| `antelacionDias` | entero 1–365 |
| `antelacionKm` | entero 1–50000 |

- `200`: la configuración completa (mismo formato que `GET`).
- `400 VALIDACION`: campo fuera de límites o cuerpo vacío, con mensaje en español.
- Bitácora: `CONFIG_ACTUALIZADA`, `entity_type = settings`, detalle con las claves cambiadas (sin valores largos).
