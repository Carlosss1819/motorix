# Modelo de Datos: Pagos, Tickets y Dashboard

**Funcionalidad**: `004-pagos-tickets-dashboard` | **Fecha**: 2026-10-13
**Relacionado**: [spec.md](spec.md) (entidades clave), [research.md](research.md)
(D2, D3, D6, D7) y migración `database/migrations/004_pagos_tickets_dashboard.sql`.

Los scripts 001 a 003 no se modifican; este sprint solo agrega el script 004 con las
dos tablas nuevas.

## Tablas nuevas

### `payments` — pagos de las órdenes

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT AUTO_INCREMENT` | llave primaria |
| `service_order_id` | `INT NOT NULL` | FK → `service_orders(id)`; un pago siempre pertenece a una orden (RN‑13, FR‑001) |
| `amount` | `DECIMAL(10,2) NOT NULL` | `CHECK (amount > 0)`; debe coincidir con el total calculado de la orden (FR‑015, supuesto «un pago por orden») |
| `method` | `ENUM('EFECTIVO','TARJETA','TRANSFERENCIA','MERCADO_PAGO') NOT NULL` | FR‑002 (CA‑2) |
| `status` | `ENUM('PENDIENTE','PAGADO','RECHAZADO','CANCELADO','ANULADO') NOT NULL` | máquina de estados en D7; los pagos no Mercado Pago nacen `PAGADO` |
| `external_reference` | `VARCHAR(120) NULL` | id del cobro en el proveedor (solo `MERCADO_PAGO`) |
| `payment_link` | `VARCHAR(512) NULL` | enlace del cobro digital para compartir (solo `MERCADO_PAGO`) |
| `gateway_mode` | `VARCHAR(20) NULL` | `sandbox` o `simulado` (D1); indica con qué modo se creó el cobro |
| `annulment_reason` | `VARCHAR(255) NULL` | motivo obligatorio al anular (FR‑016) |
| `annulled_by` | `INT NULL` | FK → `users(id)`; quién anuló (solo `ADMIN`) |
| `created_by` | `INT NOT NULL` | FK → `users(id)`; quién registró el pago |
| `created_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` | fecha de registro |
| `annulled_at` | `DATETIME NULL` | momento de la anulación |

- **Sin datos sensibles** (RN‑14): la tabla no guarda número de tarjeta, titulares ni
  credenciales; solo la referencia externa del cobro.
- La regla «un solo pago `PAGADO` por orden» se valida en el servicio (FR‑004), porque
  MySQL no admite restricciones únicas parciales; la consulta de total pendiente es
  `WHERE service_order_id = ? AND status = 'PAGADO'`.
- La regla «un solo pago `PENDIENTE` por orden» también se valida en el servicio: no se
  inicia un segundo cobro digital mientras exista uno pendiente.

### `tickets` — comprobantes de servicio

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT AUTO_INCREMENT` | llave primaria |
| `service_order_id` | `INT NOT NULL` | FK → `service_orders(id)`; **único**: un ticket por orden (US4‑2) |
| `payment_id` | `INT NOT NULL` | FK → `payments(id)`; el pago que respalda el ticket (FR‑009) |
| `folio` | `VARCHAR(20) NOT NULL UNIQUE` | consecutivo por año, por ejemplo `T000001‑2026` (D3) |
| `issued_by` | `INT NOT NULL` | FK → `users(id)` |
| `issued_at` | `DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` | fecha de emisión |

- El ticket se genera con los datos de la orden **al momento de emitirlo**; la vista
  reconstruye el detalle desde la orden y su pago (FR‑007).
- `UNIQUE KEY uq_tickets_service_order (service_order_id)` impide duplicados
  (escenario US4‑2).

## Cambios en tablas existentes

Ninguno. La validación de la entrega (FR‑014) se aplica en el servicio sobre los datos
existentes (`payments`).

## Relaciones

```text
service_orders 1 ── N payments
service_orders 1 ── 1 tickets
payments 1 ── N tickets (respaldo del comprobante)
users 1 ── N payments (created_by / annulled_by)
users 1 ── N tickets (issued_by)
```

## Máquina de estados del pago (D7)

```text
PENDIENTE ──> PAGADO        (confirmación manual, recepción o ADMIN)
PENDIENTE ──> RECHAZADO     (confirmación manual)
PENDIENTE ──> CANCELADO     (confirmación manual o cancelación del pendiente)
PAGADO    ──> ANULADO       (solo ADMIN, con motivo; FR‑016)
RECHAZADO, CANCELADO, ANULADO  ──> (estados finales)
```

- Los pagos `EFECTIVO`, `TARJETA` y `TRANSFERENCIA` nacen directamente en `PAGADO`
  (el cobro es presencial y verificado).
- Solo los pagos `PAGADO` liquidan la orden (FR‑004, FR‑014); `ANULADO` deja la orden
  libre para un nuevo intento.
- La transición `TERMINADO → ENTREGADO` de la orden exige al menos un pago `PAGADO`
  (FR‑014); si no, `409 PAGO_PENDIENTE`.

## Reglas de negocio asociadas

- **RN‑13 / FR‑001**: todo pago está ligado a una orden existente (FK obligatoria).
- **RN‑9 / FR‑012**: las órdenes entregadas conservan sus pagos y tickets como
  historial; no se borran.
- **RN‑14 / FR‑006**: ningún campo almacena datos de tarjeta ni credenciales.
- **RN‑15**: anulación (FR‑016) y panel (FR‑010) solo `ADMIN`; registro y consulta de
  pagos para recepción y administración (FR‑003).
- **FR‑015 (aclaración 2)**: el total se calcula al cobrar con los precios vigentes
  (`order_labor.price` + `parts.sale_price × order_parts.quantity`), con `NULL` en
  precio tratado como 0 (D2).

## Cálculo del total (entrada del cobro)

```text
total = Σ(order_labor.price | 0)  +  Σ(parts.sale_price × order_parts.quantity)
         mano de obra vigente          refacciones del catálogo vigente
         (filas sin part_id: 0, «sin precio registrado»)
```

El desglose enviado al formulario de pago y reflejado en el ticket proviene del mismo
cálculo (módulo puro `order-total.js`).

## Semillas (D8)

`database/seeds/004_ejemplos_pagos_tickets.sql` (idempotente, ids fijos):

- Pagos de ejemplo: uno `EFECTIVO` `PAGADO`, uno `TARJETA` `PAGADO`, uno
  `MERCADO_PAGO` `PENDIENTE` y uno `MERCADO_PAGO` `ANULADO` con motivo.
- Tickets emitidos para las órdenes de ejemplo ya pagadas, con folios fijos.
- Ningún pago apunta a una orden inexistente (RN‑13).
