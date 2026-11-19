# 03. Esquema de la base de datos

**Proyecto:** Motorix, sistema de gestión para un taller mecánico
**Elaboró:** Carlos Castro Rafael
**Fecha de corte de los datos:** 2026-11-19 (rama `006-notificaciones-internas`)

> Este esquema se reconstruyó leyendo las **siete migraciones** de `database/migrations/` (001 a 007) y el script `database/scripts/aplicar-migraciones.ps1`. Motor: MySQL 8. Bases: `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas).

## 1. Diagrama entidad-relación

El diagrama muestra las 16 tablas de negocio con su llave primaria (PK), sus llaves foráneas (FK), las llaves únicas (UK) y las columnas más importantes. Las columnas `created_at` y `updated_at` se omiten para que el diagrama sea legible.

```mermaid
erDiagram
  users {
    int id PK
    varchar username UK
    varchar email UK
    varchar password_hash
    enum role "ADMIN, RECEPTIONIST, MECHANIC"
    enum status "ACTIVE, INACTIVE"
    int failed_login_attempts
    datetime locked_until
  }
  clients {
    int id PK
    varchar name
    varchar phone
    varchar email
    varchar status
  }
  vehicles {
    int id PK
    int client_id FK
    varchar brand
    varchar model
    smallint year
    varchar plates UK
    varchar vin UK
    int current_mileage
  }
  appointments {
    int id PK
    int client_id FK
    int vehicle_id FK
    date appointment_date
    varchar reason
    enum status "PROGRAMADA, RECIBIDA, CANCELADA, NO_PRESENTADA"
    int created_by FK
  }
  service_orders {
    int id PK
    int client_id FK
    int vehicle_id FK
    int appointment_id FK "UK"
    enum status "RECIBIDO ... ENTREGADO"
    date entry_date
    int entry_mileage
    int mechanic_id FK
    text diagnosis
    text recommendations
    datetime delivery_date
    int created_by FK
  }
  order_status_history {
    int id PK
    int service_order_id FK
    enum from_status
    enum to_status
    int changed_by FK
    datetime changed_at
  }
  order_services {
    int id PK
    int service_order_id FK
    varchar description
  }
  order_labor {
    int id PK
    int service_order_id FK
    int service_id FK
    int duration_minutes
    decimal price "10,2"
  }
  order_parts {
    int id PK
    int service_order_id FK
    int part_id FK "003"
    varchar description
    int quantity
    decimal unit_price "10,2 congelado, 005"
  }
  parts {
    int id PK
    varchar code UK
    varchar name
    varchar category
    int stock_current
    int stock_min
    decimal purchase_price "10,2"
    decimal sale_price "10,2"
    tinyint is_active
  }
  inventory_movements {
    int id PK
    int part_id FK
    enum movement_type "ENTRADA, SALIDA, AJUSTE"
    int quantity
    int service_order_id FK
    int stock_after
    int created_by FK
  }
  maintenance {
    int id PK
    int vehicle_id FK
    varchar service_type
    date target_date
    int target_mileage
    int interval_days
    int interval_km
    int created_by FK
  }
  payments {
    int id PK
    int service_order_id FK
    decimal amount "10,2"
    enum method "EFECTIVO, TARJETA, TRANSFERENCIA, MERCADO_PAGO"
    enum status "PENDIENTE, PAGADO, RECHAZADO, CANCELADO, ANULADO"
    varchar external_reference
    varchar gateway_mode
    varchar cancellation_reason "005"
    int annulled_by FK
    int created_by FK
  }
  tickets {
    int id PK
    int service_order_id FK
    int payment_id FK "UK desde 005"
    varchar folio UK
    json content "005"
    smallint format_version "005"
    int issued_by FK
  }
  notification_reads {
    int id PK
    int user_id FK
    varchar notice_key
    datetime read_at
  }
  client_notices {
    int id PK
    int client_id FK
    enum reason "VEHICULO_LISTO, CITA_MANANA, MANT_PROXIMO, MANT_VENCIDO"
    varchar fact_key UK
    int notified_by FK
    datetime notified_at
  }

  clients ||--o{ vehicles : "es propietario de"
  clients ||--o{ appointments : "agenda"
  vehicles ||--o{ appointments : "se agenda en"
  clients ||--o{ service_orders : "solicita"
  vehicles ||--o{ service_orders : "recibe"
  appointments |o--o| service_orders : "se convierte en"
  users |o--o{ service_orders : "mecánico asignado"
  service_orders ||--o{ order_status_history : "registra cambios"
  service_orders ||--o{ order_services : "incluye"
  order_services ||--o{ order_labor : "detalla mano de obra"
  service_orders ||--o{ order_labor : "tiene"
  service_orders ||--o{ order_parts : "usa"
  parts |o--o{ order_parts : "se usa en"
  parts ||--o{ inventory_movements : "se mueve en"
  service_orders |o--o{ inventory_movements : "origina"
  vehicles ||--o{ maintenance : "programa"
  service_orders ||--o{ payments : "se cobra con"
  payments ||--o| tickets : "genera"
  service_orders ||--o{ tickets : "tiene"
  users ||--o{ notification_reads : "marca como leído"
  clients ||--o{ client_notices : "recibe aviso"
  users ||--o{ client_notices : "avisó"
```

**Llaves foráneas hacia `users` omitidas en las líneas del diagrama** (para no saturarlo; todas existen en las migraciones): `appointments.created_by`, `service_orders.created_by`, `order_status_history.changed_by`, `inventory_movements.created_by`, `maintenance.created_by`, `payments.created_by`, `payments.annulled_by` y `tickets.issued_by`. Sirven de **bitácora de quién hizo cada acción**.

## 2. Tablas, migración que las creó y propósito

| Tabla | Migración / sprint que la creó | Propósito |
|---|---|---|
| `users` | `001_esquema_inicial.sql` / Sprint 1 | Cuentas del personal con rol (ADMIN, RECEPTIONIST, MECHANIC), estado y control de intentos fallidos y bloqueo. |
| `clients` | `001_esquema_inicial.sql` / Sprint 1 | Propietarios de los vehículos (nombre, teléfono, correo). |
| `vehicles` | `001_esquema_inicial.sql` / Sprint 1 | Vehículos con su propietario; placa única y número de serie (VIN) opcional pero único. |
| `appointments` | `002_citas_ordenes_servicio.sql` / Sprint 2 | Citas de llegada al taller y su estado (programada, recibida, cancelada, no presentada). |
| `service_orders` | `002_citas_ordenes_servicio.sql` / Sprint 2 | Orden de servicio: cliente, vehículo, cita de origen (una cita genera como máximo una orden), mecánico, diagnóstico, recomendaciones y estado. |
| `order_status_history` | `002_citas_ordenes_servicio.sql` / Sprint 2 | Bitácora de cada cambio de estado de la orden, con quién y cuándo. |
| `order_services` | `002_citas_ordenes_servicio.sql` / Sprint 2 | Servicios realizados en la orden. |
| `order_labor` | `002_citas_ordenes_servicio.sql` / Sprint 2 | Mano de obra de cada servicio: duración y precio. |
| `order_parts` | `002_citas_ordenes_servicio.sql` / Sprint 2 (ampliada en 003 y 005) | Refacciones usadas en la orden. La 003 agrega `part_id` (liga con el catálogo); la 005 agrega `unit_price` (precio congelado). |
| `parts` | `003_historial_mantenimiento_inventario.sql` / Sprint 3 | Catálogo de refacciones: código único, categoría, marca, stock actual y mínimo, precios de compra y venta. |
| `maintenance` | `003_historial_mantenimiento_inventario.sql` / Sprint 3 | Próximo mantenimiento por vehículo y tipo de servicio (por fecha y/o kilometraje, con anticipación). |
| `inventory_movements` | `003_historial_mantenimiento_inventario.sql` / Sprint 3 | Entradas, salidas y ajustes de inventario con el stock resultante; puede ligarse a una orden. |
| `payments` | `004_pagos_tickets_dashboard.sql` / Sprint 4 (ampliada en 005) | Pagos de una orden: importe, método, estado, referencia de Mercado Pago y anulación. La 005 agrega `cancellation_reason`. |
| `tickets` | `004_pagos_tickets_dashboard.sql` / Sprint 4 (ampliada en 005) | Comprobante con folio único. La 005 cambia la regla «un ticket por orden» por «un ticket por pago» y guarda una copia inmutable del contenido (`content` JSON, `format_version`). |
| `notification_reads` | `007_notificaciones_internas.sql` / Sprint 6 | Qué avisos internos marcó como leídos cada usuario (un registro por usuario y aviso). Los avisos se calculan con datos reales; no se guardan. |
| `client_notices` | `007_notificaciones_internas.sql` / Sprint 6 | Registro de clientes ya avisados (vehículo listo, cita de mañana, mantenimiento próximo o vencido) para no repetir el aviso. |
| `schema_migrations` | `database/scripts/aplicar-migraciones.ps1` (no es una migración) | Control técnico: nombre y fecha de cada migración aplicada, para no aplicarla dos veces. |

### Migraciones sin tablas nuevas

| Migración | Sprint | Qué hace |
|---|---|---|
| `003_...` (parte final) | Sprint 3 | `ALTER TABLE order_parts` agrega `part_id` con FK a `parts`; índice `idx_service_orders_vehicle_status` para el historial del vehículo. |
| `005_precios_congelados_tickets_por_pago.sql` | Sprint 5 | **Solo esquema:** agrega `order_parts.unit_price`, `tickets.content`, `tickets.format_version` y `payments.cancellation_reason`; reemplaza el índice único `uq_tickets_service_order` por `uq_tickets_payment` (cambio de restricción permitido y documentado en el plan del Sprint 5). |
| `006_datos_precio_congelado_copia_tickets.sql` | Sprint 5 | **Solo datos**, dentro de una transacción y repetible: congela el precio de las líneas existentes y copia los tickets anteriores en la versión 1 del formato. |
| `007_notificaciones_internas.sql` | Sprint 6 | Crea `notification_reads` y `client_notices`. |

### Datos de ejemplo (seeds)

`database/seeds/` contiene seis scripts (`001_datos_iniciales.sql` a `006_ejemplos_notificaciones.sql`), uno por sprint con cambios de datos. Se aplican con `aplicar-migraciones.ps1 -Seeds`.

## 3. Reglas del diseño de la base

| Regla | Cómo se cumple |
|---|---|
| **Motor InnoDB** | Todas las tablas declaran `ENGINE=InnoDB`: transacciones y llaves foráneas reales. |
| **Juego de caracteres utf8mb4** | Todas usan `DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`: acentos, eñes y cualquier carácter en español. |
| **Importes `DECIMAL(10,2)`** | `order_labor.price`, `order_parts.unit_price`, `parts.purchase_price`, `parts.sale_price` y `payments.amount`. Nunca `FLOAT`, para no perder centavos por redondeo binario. |
| **Migraciones inmutables y numeradas** | Una migración aplicada no se edita; cada cambio va en un script nuevo (`008_...`). «Aditiva» significa no borrar tablas, columnas ni datos. Se permite reemplazar una restricción conservando los datos y documentándolo (caso de la 005). |
| **Seeds idempotentes** | Se pueden correr varias veces sin duplicar datos: usan ids fijos con `INSERT IGNORE`, `ON DUPLICATE KEY` o `WHERE NOT EXISTS`. |
| **Contraseñas** | Solo hash bcrypt en `users.password_hash`; nunca texto plano. |
| **Sin datos de tarjeta** | `payments` guarda solo la referencia externa y el enlace de Mercado Pago; ningún número de tarjeta. |
| **Integridad del historial** | El precio de una refacción se **congela** en `order_parts.unit_price` al agregarla y cada ticket guarda una copia de su contenido; un cambio posterior del catálogo no altera órdenes, pagos ni tickets emitidos. |
| **Base local** | Desarrollo y pruebas en MySQL local; una instancia en la nube solo para la demostración (enmienda 1.1.0). |
