# Contrato (cambios): Catálogo de refacciones (`/api/parts`)

Relacionado: FR-001 a FR-005, FR-024 a FR-026, FR-036; D-06, D-07, D-10.

## Campos de precio por rol (lectura: `GET /api/parts`, `GET /api/parts/:id`)

| Campo | ADMIN | RECEPTIONIST | MECHANIC |
|---|:-:|:-:|:-:|
| `id`, `codigo`, `nombre`, `categoria`, `marca`, `stockActual`, `stockMinimo`, `stockBajo`, `activa` | ✔ | ✔ | ✔ |
| `precioCompra` | ✔ | — | — |
| `precioVenta` | ✔ | ✔ | — |

«—» significa que **la clave se omite** de la respuesta; no se manda `null` (R-10). El mecánico recibe **todos los campos que no son importes** (primera fila) y ningún precio (FR-025, aclaración «D-10 (campos del mecánico)»). El catálogo no tiene un campo «unidad». La búsqueda (`buscar`) sigue siendo por nombre o código y el orden por nombre; no hay filtros ni ordenamientos por precio (FR-036).

Ejemplo para MECHANIC:

```json
{ "id": 3, "codigo": "PAS-DEL01", "nombre": "Juego de pastillas delanteras",
  "categoria": "Frenos", "marca": "Brembo", "stockActual": 12, "stockMinimo": 4,
  "stockBajo": false, "activa": true }
```

## Alta y edición (`POST /api/parts`, `PUT /api/parts/:id`, solo ADMIN)

- `categoria`: texto libre, obligatoria (hasta 80 caracteres). `marca`: texto libre, opcional (hasta 80).
- `precioCompra` y `precioVenta`: opcionales; si vienen, deben ser numéricos, ≥ 0, con máximo dos decimales y ≤ 999,999.99. Si no, `400 VALIDACION` con el campo y el motivo (FR-003).
- Si `precioVenta < precioCompra`, la operación **se guarda** y la respuesta agrega (FR-004):

```json
{ "id": 9, "…": "…",
  "advertencias": [
    { "codigo": "PRECIO_VENTA_MENOR_A_COMPRA",
      "mensaje": "El precio de venta es menor que el precio de compra" }
  ] }
```

- RECEPTIONIST o MECHANIC: `403` (sin cambios).
