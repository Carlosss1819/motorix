# Contrato: Inventario de refacciones (`/api/parts` y uso en órdenes)

Relacionado: FR‑016 a FR‑030; historias 5, 6, 7 y 8 (HU5, HU6, HU7, HU8); clarificación 3
y 4 del 2026‑10‑13; RN‑6, RN‑7, RN‑8, RN‑15.

Rutas **protegidas**: lectura (inventario y movimientos) para los tres roles; escritura
del catálogo, entradas y ajustes solo `ADMIN` (clarificación 4, FR‑022, FR‑029); agregar
y retirar refacciones en una orden los tres roles, con `MECHANIC` limitado a sus
órdenes (FR‑027). Término canónico «refacción» (clarificación 3).

## Formato de la refacción

```json
{
  "id": 2,
  "codigo": "PAD-001",
  "nombre": "Juego de pastillas delanteras",
  "categoria": "Frenos",
  "marca": "Brembo",
  "stockActual": 3,
  "stockMinimo": 5,
  "stockBajo": true,
  "precioCompra": 180.00,
  "precioVenta": 320.00,
  "activa": true
}
```

- `stockBajo` se **calcula**: `stockActual <= stockMinimo && stockMinimo > 0`
  (FR‑020, FR‑021, R‑10). Un `stockMinimo` de 0 nunca genera alerta.

## `GET /api/parts`

- **Consulta**: `?buscar=<texto>` (coincide con nombre o código, FR‑018),
  `?stockBajo=true`, `?activa=true|false`, `?pagina=&porPagina=` (patrón estándar).
- **Roles**: los tres (solo consulta, FR‑022).
- **Respuesta `200`**: paginada con el formato de arriba en `elementos`.
- **Errores**: `401`; `403` rol.

## `GET /api/parts/:id`

- **Respuesta `200`**: la refacción con todos sus campos.
- **Errores**: `401`, `404 REFACCION_NO_ENCONTRADA`.

## `POST /api/parts`

- **Roles**: solo `ADMIN` (FR‑022).
- **Cuerpo**:

  ```json
  {
    "codigo": "PAD-001",
    "nombre": "Juego de pastillas delanteras",
    "categoria": "Frenos",
    "marca": "Brembo",
    "stockInicial": 10,
    "stockMinimo": 5,
    "precioCompra": 180.00,
    "precioVenta": 320.00
  }
  ```

- **Reglas**:
  - `codigo`, `nombre` y `categoria` obligatorios; `codigo` con 1 a 30 caracteres,
    único en todo el catálogo → `409 CODIGO_DUPLICADO` (FR‑017).
  - `stockInicial` opcional (defecto 0, ≥ 0); si es > 0 se registra además un
    movimiento `ENTRADA` inicial con motivo "Stock inicial" para que SC‑007 se cumpla
    desde el alta.
  - `stockMinimo` opcional (defecto 0, ≥ 0); `stockActual` **no** se envía: solo
    cambia por movimientos (FR‑022).
- **Respuesta `201`**: la refacción creada.
- **Errores**: `400` validación; `403` rol; `409` código duplicado.

## `PUT /api/parts/:id`

- **Roles**: solo `ADMIN`.
- **Cuerpo**: `nombre`, `categoria`, `marca`, `stockMinimo`, `precioCompra`,
  `precioVenta` (parcial; `codigo` y `stockActual` no se editan aquí: el código es
  identificador y el stock solo vía movimientos, FR‑022).
- **Respuesta `200`**: la refacción actualizada.
- **Errores**: `400`, `403`, `404 REFACCION_NO_ENCONTRADA`.

## `POST /api/parts/:id/desactivar`

- **Roles**: solo `ADMIN` (FR‑019).
- **Reglas**: marca `activa = false`; la refacción deja de poder agregarse a órdenes
  (`409 REFACCION_INACTIVA`) pero su historial de uso y sus movimientos se conservan.
  Desactivar una ya desactivada responde `200` sin cambios (idempotente).
- **Respuesta `200`: `{"message": "Refacción desactivada."}`**.
- **Errores**: `403`, `404`.

## `GET /api/parts/:id/movements`

- **Consulta**: `?tipo=ENTRADA|SALIDA|AJUSTE`, `?pagina=&porPagina=`.
- **Roles**: los tres (consulta de inventario, FR‑022) (FR‑030).
- **Reglas**: orden descendente por fecha; cada movimiento explica un cambio con su
  `stockAfter` (SC‑007).
- **Respuesta `200`**:

  ```json
  {
    "elementos": [
      {
        "id": 9,
        "tipo": "SALIDA",
        "cantidad": 2,
        "motivo": null,
        "ordenId": 4,
        "stockAfter": 3,
        "registradoPor": "admin",
        "fecha": "2026-10-13 09:15:00"
      }
    ],
    "pagina": 1,
    "paginas": 1,
    "total": 1
  }
  ```

- **Errores**: `401`, `404 REFACCION_NO_ENCONTRADA`.

## `POST /api/parts/:id/movements`

- **Roles**: solo `ADMIN` (FR‑029).
- **Cuerpo**:

  ```json
  { "tipo": "ENTRADA", "cantidad": 12, "motivo": "Pedido proveedor 123" }
  ```

- **Reglas**:
  - `tipo` solo `ENTRADA` (reabastecimiento) o `AJUSTE` (corrección manual): las
    salidas las genera el uso en órdenes, nunca una llamada directa.
  - `cantidad` entero > 0.
  - `AJUSTE` exige `motivo` no vacío → `400 AJUSTE_SIN_MOTIVO` (FR‑029); en
    `ENTRADA` el motivo es opcional.
  - Todo en transacción con bloqueo de fila: el `stockAfter` resultante nunca puede
    ser negativo (RN‑8) — una `ENTRADA` o `AJUSTE` siempre aumentan, así que el
    rechazo típico aquí es de validación.
- **Respuesta `201`**: el movimiento registrado con su `stockAfter`.
- **Errores**: `400` validación o ajuste sin motivo; `403` rol; `404`.

## `POST /api/service-orders/:id/refacciones` (alias heredado `/repuestos`)

- **Roles**: `ADMIN`, `RECEPTIONIST` y `MECHANIC` — este último solo si la orden le
  está asignada (FR‑027); la orden debe estar abierta (no `TERMINADO` ni `ENTREGADO`,
  guard heredado `assertOrderOpenForContent`) (FR‑026, RN‑9).
- **Cuerpo** (nuevo contrato, clarificación 3):

  ```json
  { "partId": 2, "cantidad": 2 }
  ```

- **Reglas** (transacción completa, R‑08):
  - `partId` obligatorio: la refacción debe existir y estar **activa** →
    `404 REFACCION_NO_ENCONTRADA` / `409 REFACCION_INACTIVA`; ya no se acepta
    descripción libre (FR‑023, RN‑6).
  - `cantidad` entero ≥ 1; stock insuficiente o 0 → `409 STOCK_INSUFICIENTE` **sin**
    modificar nada (FR‑025, RN‑8, caso límite de dos mecánicos simultáneos: el
    bloqueo de fila decide el ganador y el otro recibe este error).
  - Se inserta la fila en `order_parts` con `part_id` y `description` copiado del
    nombre del catálogo, y en la **misma transacción** un movimiento `SALIDA` con la
    cantidad y `order_id` asociado (FR‑024, RN‑7).
- **Respuesta `201`**: la fila creada:

  ```json
  { "id": 7, "partId": 2, "codigo": "PAD-001", "nombre": "Juego de pastillas delanteras", "cantidad": 2, "stockActual": 3 }
  ```

- **Errores**: `400` validación; `403` rol u orden ajena; `404` orden, refacción;
  `409` orden cerrada, refacción inactiva o stock insuficiente.
- **Alias**: `POST /api/service-orders/:id/repuestos` acepta exactamente lo mismo y
  responde igual (compatibilidad con las pruebas y pantallas del Sprint 2).

## `DELETE /api/service-orders/:id/refacciones/:refaccionId` (alias `/repuestos/:repuestoId`)

- **Roles**: iguales que el alta (FR‑027); orden abierta (FR‑026).
- **Reglas** (transacción):
  - Si la fila tiene `part_id`: se incrementa `stock_current` y se registra un
    movimiento `ENTRADA` con motivo "Reposición por retiro de la orden #<id>" y la
    orden asociada (FR‑026, SC‑007, R‑09).
  - Si la fila es heredada (sin `part_id`): solo se elimina; no había descuento de
    inventario que reponer.
  - La fila se elimina de la orden; el movimiento queda como constancia.
- **Respuesta `200`**: `{"message": "Refacción retirada de la orden.", "stockActual": 5}`.
- **Errores**: `403`, `404` orden o fila inexistente, `409` orden cerrada.
