# Contrato: Pagos de órdenes (`/api/payments`)

Relacionado: FR‑001 a FR‑006, FR‑014 a FR‑016; historias 1, 2 y 3 (HU1, HU2, HU3);
aclaraciones 1, 2, 3, 4 y 5 del 2026‑10‑13; RN‑13, RN‑14, RN‑15.

Rutas **protegidas**: registro y consulta para `ADMIN` y `RECEPTIONIST`; confirmación
del pago Mercado Pago (`PENDIENTE → PAGADO | RECHAZADO | CANCELADO`) para los mismos
roles; anulación (`PAGADO → ANULADO`) solo `ADMIN` (FR‑016, RN‑15). El total de la
orden se calcula en backend con los precios vigentes (FR‑015); el monto enviado debe
coincidir con él.

## Formato del pago

```json
{
  "id": 1,
  "ordenId": 12,
  "monto": 3250.00,
  "metodo": "EFECTIVO",
  "estado": "PAGADO",
  "referenciaExterna": null,
  "enlacePago": null,
  "modoPasarela": null,
  "motivoAnulacion": null,
  "registradoPor": "recepcion",
  "fecha": "2026-10-13 10:15:00"
}
```

- `metodo`: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA` o `MERCADO_PAGO` (FR‑002).
- `estado`: `PENDIENTE`, `PAGADO`, `RECHAZADO`, `CANCELADO` o `ANULADO` (D7).
- `referenciaExterna`, `enlacePago` y `modoPasarela` (`sandbox` | `simulado`) solo se
  llenan para `MERCADO_PAGO` (D1).
- La tabla nunca guarda datos de tarjeta ni credenciales (RN‑14, FR‑006).

## `GET /api/payments/orden/:ordenId`

- **Roles**: `ADMIN`, `RECEPTIONIST`.
- **Consulta**: `?pagina=&porPagina=` (patrón estándar); lista los pagos de una orden
  (incluye anulados, como historial).
- **Respuesta `200`**: paginada con el formato de arriba en `elementos`.
- **Errores**: `401`; `403 rol`; `404 ORDEN_NO_ENCONTRADA`.

## `GET /api/payments/orden/:ordenId/total`

- **Roles**: `ADMIN`, `RECEPTIONIST`.
- **Proporciona**: el total y su desglose calculados en backend con los precios
  vigentes (FR‑015, `order-total.js`), para que el formulario de pago muestre el
  desglose y precargue el monto (data-model.md, sección «Cálculo del total»).
- **Respuesta `200`**:

  ```json
  {
    "ordenId": 12,
    "subtotalManoDeObra": 450.00,
    "subtotalRefacciones": 640.00,
    "total": 1090.00,
    "desglose": {
      "manoDeObra": [
        { "id": 9, "descripcion": "Cambio de pastillas", "precio": 450.00, "aviso": null }
      ],
      "refacciones": [
        {
          "id": 3,
          "descripcion": "Juego de pastillas delanteras",
          "cantidad": 2,
          "precioUnitario": 320.00,
          "subtotal": 640.00,
          "aviso": null
        }
      ]
    }
  }
  ```

- `aviso` (`"sin precio registrado"`) marca partidas con precio `NULL` o filas
  heredadas sin catálogo, valoradas en 0 (D2.1).
- **Errores**: `401`; `403 rol`; `404 ORDEN_NO_ENCONTRADA`.

## `POST /api/payments`

- **Roles**: `ADMIN`, `RECEPTIONIST` (FR‑003).
- **Cuerpo**:

  ```json
  {
    "ordenId": 12,
    "monto": 3250.00,
    "metodo": "EFECTIVO",
    "fecha": "2026-10-13"
  }
  ```

- **Reglas** (FR‑004, FR‑015, aclaración 1):
  - la orden debe estar en estado `TERMINADO` (único estado cobrable);
  - no debe tener un pago `PAGADO`;
  - `monto` debe coincidir con el total calculado de la orden (un pago por orden, por
    su total);
  - si `metodo` es `MERCADO_PAGO`, el pago nace `PENDIENTE` y la respuesta incluye
    `referenciaExterna`, `enlacePago` y `modoPasarela`; los demás métodos nacen
    `PAGADO`.
- **Respuesta `201`**: el pago con el formato de arriba.
- **Errores**: `400 VALIDACION`; `401`; `403 rol`; `404 ORDEN_NO_ENCONTRADA`;
  `409 ORDEN_NO_COBRABLE` (estado distinto de `TERMINADO`);
  `409 ORDEN_YA_LIQUIDADA` (ya tiene pago `PAGADO`);
  `409 PAGO_PENDIENTE` (ya hay un cobro Mercado Pago sin confirmar);
  `409 MONTO_NO_COINCIDE` (distinto al total calculado).

## `POST /api/payments/:id/confirmar`

- **Roles**: `ADMIN`, `RECEPTIONIST` (confirmación manual, aclaración 3).
- **Cuerpo**: `{ "estado": "PAGADO" | "RECHAZADO" | "CANCELADO" }`.
- **Reglas**: el pago debe estar `PENDIENTE` y ser `MERCADO_PAGO`; la transición sigue
  la máquina de estados (D7).
- **Respuesta `200`**: el pago actualizado.
- **Errores**: `400 VALIDACION`; `401`; `403 rol`; `404 PAGO_NO_ENCONTRADO`;
  `409 TRANSICION_INVALIDA`.

## `POST /api/payments/:id/anular`

- **Roles**: solo `ADMIN` (FR‑016).
- **Cuerpo**: `{ "motivo": "Cobro capturado por error" }` (obligatorio, 1–255).
- **Reglas**: el pago debe estar `PAGADO` y su orden no debe estar `ENTREGADO` (una
  orden entregada es historial inmutable, RN‑9); la anulación no devuelve dinero.
- **Respuesta `200`**: el pago con `estado: "ANULADO"` y `motivoAnulacion`.
- **Errores**: `400 VALIDACION`; `401`; `403 rol`; `404 PAGO_NO_ENCONTRADO`;
  `409 TRANSICION_INVALIDA`; `409 ORDEN_ENTREGADA`.

## Efecto en la orden (FR‑014, aclaración 1)

- La transición `TERMINADO → ENTREGADO` (`POST /api/service-orders/:id/estado`)
  responde `409 PAGO_PENDIENTE` cuando la orden no tiene un pago `PAGADO`.
- Un pago `ANULADO`, `RECHAZADO` o `CANCELADO` no cuenta como liquidación; la orden
  vuelve a admitir un nuevo cobro.
