# Contrato: Tickets de servicio (`/api/tickets`)

Relacionado: FR‑007, FR‑008, FR‑009, FR‑012, FR‑013; historia 4 (HU4); supuesto
«ticket imprimible, sin PDF almacenado» y «folio del ticket»; RN‑9.

Rutas **protegidas**: generación y consulta para `ADMIN` y `RECEPTIONIST`
(FR‑003 aplica al ciclo de cobro). El ticket nace de una orden con un pago `PAGADO`
(FR‑009) y nunca se duplica: reintentar la generación devuelve el mismo registro y el
mismo folio (HU4‑2).

## Formato del ticket

```json
{
  "id": 3,
  "folio": "T000003-2026",
  "ordenId": 12,
  "pagoId": 5,
  "emitidoPor": "recepcion",
  "emitidoEn": "2026-10-13 11:02:00",
  "taller": {
    "nombre": "Motorix",
    "direccion": "Av. Ejemplo 123, Col. Centro",
    "telefono": "55-0000-0000"
  },
  "cliente": { "id": 4, "nombre": "María López", "telefono": "55-1111-2222" },
  "vehiculo": {
    "id": 7,
    "marca": "Nissan",
    "modelo": "Versa",
    "anio": 2020,
    "placas": "ABC-123-D",
    "kilometraje": 84500
  },
  "servicios": [
    {
      "descripcion": "Cambio de aceite",
      "manoDeObra": 450.00,
      "refacciones": [
        { "codigo": "ACE-5W30", "nombre": "Aceite 5W-30", "cantidad": 4, "precioUnitario": 180.00, "subtotal": 720.00 }
      ]
    }
  ],
  "subtotalManoDeObra": 450.00,
  "subtotalRefacciones": 720.00,
  "total": 1170.00,
  "metodoPago": "EFECTIVO",
  "estadoPago": "PAGADO",
  "fecha": "2026-10-13"
}
```

- `folio`: consecutivo único por año, formato `T000001-2026` (D3, supuesto de folio).
- `subtotalManoDeObra`, `subtotalRefacciones` y `total` provienen del mismo cálculo del
  cobro (FR‑015, módulo `order-total.js`), con `NULL` en precio tratado como 0 (D2).
- El ticket no guarda una copia en frío de los datos: se reconstruye desde la orden y
  su pago al consultarlo (FR‑007, FR‑012); no existen archivos PDF en el servidor
  (supuesto del sprint).
- Nunca incluye datos de tarjeta ni credenciales (RN‑14).

## `POST /api/tickets`

- **Roles**: `ADMIN`, `RECEPTIONIST`.
- **Cuerpo**: `{ "ordenId": 12 }`.
- **Reglas** (FR‑009):
  - la orden debe existir y tener al menos un pago `PAGADO`;
  - si la orden ya tiene ticket, **no se crea otro**: se devuelve el existente con su
    folio original (idempotente, HU4‑2).
- **Respuesta `201`**: el ticket con el formato de arriba (primera generación).
- **Respuesta `200`**: el ticket existente (reintento sobre la misma orden).
- **Errores**: `400 VALIDACION`; `401`; `403 rol`;
  `404 ORDEN_NO_ENCONTRADA`; `409 TICKET_REQUIERE_PAGO` (orden sin pago aprobado).

## `GET /api/tickets/:id`

- **Roles**: `ADMIN`, `RECEPTIONIST`.
- **Respuesta `200`**: el ticket con el formato de arriba.
- **Errores**: `401`; `403 rol`; `404 TICKET_NO_ENCONTRADO`.

## `GET /api/tickets/orden/:ordenId`

- **Roles**: `ADMIN`, `RECEPTIONIST`.
- **Consulta**: existe o no el ticket de la orden (para mostrar u ocultar el botón de
  «Ver ticket» sin intentar generarlo).
- **Respuesta `200`**: `{ "existe": true, "ticket": { … } }` o
  `{ "existe": false, "ticket": null }`.
- **Errores**: `401`; `403 rol`; `404 ORDEN_NO_ENCONTRADA`.

## Impresión (FR‑008, CA‑5)

La visualización e impresión ocurren en el cliente: `ticket_screen.dart` renderiza el
formato de comprobante y delega la impresión al diálogo de impresión del
navegador/sistema. El backend solo entrega el JSON del ticket; no expone endpoints de
PDF.
