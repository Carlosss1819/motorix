# Plan de implementación: Precios de refacciones y cobro completo

**Rama**: `005-precios-refacciones-cobro` | **Fecha**: 2026-11-14 | **Spec**: [spec.md](./spec.md)

**Input**: especificación de `specs/005-precios-refacciones-cobro/spec.md`, con las aclaraciones de la sesión 2026-11-14.

## Resumen

El sprint congela el precio de venta de cada refacción en la línea de la orden (`order_parts.unit_price`), calcula el total en centavos enteros y conserva cada ticket como una copia con versión de formato (`tickets.content`, `tickets.format_version`), con un ticket por pago en lugar de uno por orden. Además:

- restringe por rol los precios que devuelve el servidor (el mecánico no recibe ningún precio de refacción);
- cancela, con el motivo «importe desfasado», un pago pendiente de Mercado Pago cuyo importe ya no coincide al confirmarlo;
- bloquea los servicios de una orden `TERMINADO` con pago `PAGADO`;
- corrige con un candado por orden la concurrencia de pagos, que hoy no está garantizada (hallazgo H3 de [research.md](./research.md)).

La migración se divide en `005`, solo esquema, y `006`, solo datos y dentro de una transacción. El `005` es la primera migración que reemplaza una restricción (ver «Registro de complejidad»).

## Contexto técnico

**Lenguaje/Versión**: Node 24 (LTS) con ES Modules (`"type": "module"`); Dart/Flutter (Material 3).

**Dependencias principales**: Express, mysql2, Zod, jsonwebtoken y bcryptjs (servidor); Provider y las librerías de apoyo de `docs/design-system.md` (cliente). **Sin dependencias nuevas.**

**Almacenamiento**: MySQL 8 local, InnoDB y `utf8mb4`: `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas). Importes en `DECIMAL(10,2)`; cálculo en centavos enteros en memoria.

**Pruebas**: Jest (unitarias) y Jest + supertest (integración y contrato) contra `motorix_v2_test`; `flutter test`. Línea base: **49 suites y 411 pruebas** del backend y **127** de Flutter.

**Plataforma**: servidor local en Windows (desarrollo); cliente Flutter de escritorio y web; despliegue en hosting solo para la demostración (excepción del principio III).

**Tipo de proyecto**: aplicación web, cliente Flutter más API REST.

**Metas de desempeño**: las del proyecto. El candado por orden solo serializa operaciones sobre **la misma** orden; no hay metas nuevas.

**Restricciones**: sección 10 del insumo (organización del servidor, base local de pruebas, migraciones numeradas, seeds idempotentes, español y sistema de diseño); `DECIMAL(10,2)`; sin datos de tarjeta; sin trazas en las respuestas.

**Escala**: taller pequeño, 3 roles y decenas de órdenes por día. La base de pruebas acumula cientos de órdenes y tickets entre corridas (H11).

No quedan puntos «NEEDS CLARIFICATION»: todos se resolvieron en [research.md](./research.md). Decisiones del responsable del 2026-11-14:
- **R-09 aprobada**: vencimiento de las preferencias de Mercado Pago (FR-037).
- **R-12 no aprobada**: no se cierran sesiones al cambiar el rol; queda como limitación conocida en la spec. La propuesta R-12 de `research.md` y la sección correspondiente de `contracts/ui-flutter.md` quedan **descartadas** y no generan tareas.
- La verificación manual de Mercado Pago en sandbox la hace el responsable durante la implementación.

## Revisión de la constitución

*Compuerta: debe pasar antes de la Fase 0 y se vuelve a revisar después de la Fase 1.*

| Principio | Revisión | Resultado |
|---|---|---|
| I. Alcance y fuente de verdad | El Sprint 5 está en el alcance oficial (enmienda 1.1.0). Todo FR tiene historia y CA (trazabilidad en la spec). FR-031 actualiza `docs/project-context.md`. El vencimiento de las preferencias de Mercado Pago, aprobado por el responsable, ya está en la spec como FR-037. El cierre de sesiones al cambiar el rol no se aprobó y quedó fuera de alcance. No quedan agregados fuera de la spec. | ✔ |
| II. Arquitectura separada | La lógica va en `services/` (cálculo en `utils/order-total.js`, puro). Mercado Pago sigue aislado en `services/payment_gateway/`. Los controladores no cambian de responsabilidad. | ✔ |
| III. Stack y base local | Sin dependencias nuevas. ES Modules. Migraciones `005` y `006` nuevas y numeradas; ninguna anterior se edita. Seeds idempotentes (seed `005`). Variable nueva `MP_PREFERENCIA_VIGENCIA_HORAS` en `.env.example`, sin secretos. El `005` **reemplaza una restricción**: cumple la letra del principio («scripts nuevos numerados; no se editan los aplicados») y no borra datos. Queda registrado abajo. | ✔ con registro |
| IV. Seguridad | Los precios por rol se filtran en el servidor (R-10), omitiendo campos. Sin datos de tarjeta. Sin trazas en las respuestas. Los mensajes con cifras solo aparecen en rutas de ADMIN y RECEPTIONIST. | ✔ |
| V. Reglas de negocio | Salida de inventario y stock no negativo sin cambios (FR-028). Las órdenes `ENTREGADO` siguen inmutables (FR-023). Todo pago y todo ticket ligado a una orden. | ✔ |
| VI. API y errores | Errores nuevos con el formato de siempre: `REFACCION_SIN_PRECIO`, `TOTAL_EXCEDE_LIMITE`, `ORDEN_PAGADA` e `IMPORTE_DESFASADO` (ver [contracts/](./contracts/README.md)). | ✔ |
| VII. Pruebas | Pruebas primero (CLAUDE.md, regla 6); suite completa antes y después; contra `motorix_v2_test`. Nuevas pruebas de: centavos, instantáneas, topes, permisos y exposición por rol, concurrencia, D-04, tickets por pago, migración (SC-011 y SC-012) e inmovilización. | ✔ |
| VIII. UX y sistema de diseño | Marcas con los tokens `warning` y `danger`; sin colores sueltos; transiciones suaves; aviso D-07 no bloqueante ([contracts/ui-flutter.md](./contracts/ui-flutter.md)). | ✔ |

**Revisión posterior al diseño (Fase 1)**: sin violaciones nuevas. El diseño del candado (R-07) no agrega dependencias; las copias JSON usan funciones nativas de MySQL 8. El cálculo sigue en un módulo puro que se prueba como unidad.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/005-precios-refacciones-cobro/
├── spec.md
├── plan.md              # este archivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
├── contracts/           # Fase 1
│   ├── README.md
│   ├── parts.md
│   ├── service-orders.md
│   ├── payments.md
│   ├── tickets.md
│   └── ui-flutter.md
├── checklists/          # requirements.md + 3 checklists de requisitos
└── tasks.md             # Fase 2 (/speckit-tasks; no lo genera este comando)
```

### Código fuente (archivos que el sprint va a tocar)

```text
database/
├── migrations/
│   ├── 005_precios_congelados_tickets_por_pago.sql     # nuevo: solo DDL (R-01, R-02)
│   └── 006_datos_precio_congelado_copia_tickets.sql    # nuevo: solo datos, en transacción (R-03, R-04)
├── seeds/
│   └── 005_ejemplos_precios_congelados.sql             # nuevo: idempotente (R-05)
└── README.md                                           # tablas del Sprint 5

server/
├── utils/
│   ├── order-total.js            # centavos enteros, unit_price, tope (R-06)
│   └── money.js                  # nuevo: conversión DECIMAL ↔ centavos sin flotantes
├── validators/
│   ├── price.js                  # nuevo: esquema Zod de precio (R-13)
│   ├── part.validator.js
│   └── service-order.validator.js
├── models/
│   ├── order_items.js            # unit_price en insert y listado
│   ├── payment.js                # unit_price en findChargeContent; cancellation_reason
│   ├── ticket.js                 # content, format_version, búsqueda por pago, lista por orden
│   └── service_order.js          # candado FOR UPDATE por orden (R-07)
├── services/
│   ├── part.service.js           # precios por rol (R-10), advertencia D-07
│   ├── service_order.service.js  # precio congelado, ORDEN_PAGADA, TOTAL_EXCEDE_LIMITE, campos por rol, candado
│   ├── payment.service.js        # candado, D-04, motivo de cancelación
│   ├── ticket.service.js         # ticket por pago, copia v2, vigente, pagoAnulado
│   └── payment_gateway/mercadopago.js   # expiración de la preferencia (R-09)
├── config/env.js                 # MP_PREFERENCIA_VIGENCIA_HORAS
├── .env.example
└── tests/
    ├── unit/                     # order-total (centavos), money, price validator
    ├── contract/                 # parts por rol, payments (IMPORTE_DESFASADO), tickets (lista), service-orders
    └── integration/              # concurrencia de pago, carrera confirmar/servicio, migración, tickets por pago, inmovilización

client/lib/
├── models/                       # part, service_order (precioUnitario, importe), ticket (marcas), payment (motivoCancelacion)
├── screens/
│   ├── parts_screen.dart
│   ├── part_detail_screen.dart
│   ├── part_form_screen.dart     # aviso D-07
│   ├── service_order_detail_screen.dart
│   ├── payment_form_screen.dart  # diálogo IMPORTE_DESFASADO
│   └── ticket_screen.dart        # «Formato anterior», «Pago anulado», nota del desglose, tickets anteriores
└── utils/validators.dart         # precio de mano de obra (FR-032)
client/test/                      # pruebas de widgets por rol y marcas del ticket

docs/
├── project-context.md            # FR-031: total, precios, visibilidad por rol, ticket por pago
└── evidencias/sprint 5/          # salidas de npm test y flutter test
CLAUDE.md                         # FR-031: aclarar la regla 4 («aditiva»); requiere aprobación del responsable
```

**Decisión de estructura**: se conserva la estructura existente (`client/`, `server/` sin `src/`, `database/`), sin carpetas nuevas salvo los archivos nuevos señalados.

## Decisiones clave del diseño

Resumen; el detalle está en [research.md](./research.md).

1. **Ticket por pago (R-01)**: una sola sentencia `ALTER TABLE tickets` que agrega `idx_tickets_service_order`, quita `uq_tickets_service_order` y agrega `uq_tickets_payment`. Antes se corre la consulta de duplicados. La sentencia es atómica: si hubiera duplicados, falla sin cambiar nada.
2. **Migración y recuperación (R-02)**:
   - `005` = DDL en tres `ALTER` atómicos;
   - `006` = datos en una transacción, repetible;
   - respaldo previo con `mysqldump`;
   - pasos de recuperación en el [quickstart](./quickstart.md#3-aplicar-migraciones-y-datos-de-ejemplo).
3. **Precio congelado (R-03)**: `unit_price` se llena con el precio vigente al migrar, en todas las líneas con refacción. `NULL` = sin precio.
4. **Copia de tickets (R-04)**: versión 1 «formato anterior», generada en SQL con `total = importe pagado` y nota si no cuadra; versión 2 escrita por la aplicación. «Pago anulado» y «vigente» se calculan al consultar.
5. **Datos de ejemplo (R-05)**: seed `005` que completa `unit_price` y la copia **solo de las filas del seed 004, por id**, y agrega ejemplos del sprint.
   - La orden 5 de `motorix_v2` es de depuración, con ids que chocaron con el seed 004 (H12).
6. **Centavos (R-06)**: conversión de cadena a centavos sin flotantes; tope del total de 99,999,999.99.
7. **Concurrencia (R-07)**: `SELECT … FOR UPDATE` sobre la orden en pagos, servicios, refacciones, estado y tickets; la preferencia de Mercado Pago se crea fuera del candado y se revalida dentro. Resuelve la carrera «confirmar pago contra cambiar servicio» y el hueco de CA-8.
8. **D-04 (R-08)**: cancelación con `cancellation_reason = IMPORTE_DESFASADO` y error 409 con las cifras.
9. **Mercado Pago (R-09, FR-037, aprobada)**: vencimiento de 24 horas, configurable con `MP_PREFERENCIA_VIGENCIA_HORAS`. Los campos están verificados en la documentación oficial de Brasil; la de México dio 404. Por eso el responsable hace una prueba manual en sandbox durante la implementación. Los enlaces creados antes del sprint no vencen.
10. **Precios por rol (R-10, R-11)**: el servidor omite los campos y Flutter aplica la doble condición. Marcas con `warning` y `danger`.
11. **Cambio de rol**: no se cierran sesiones (R-12 no aprobada). Es una limitación conocida: el servidor aplica el rol nuevo en la siguiente petición, y Flutter muestra el anterior hasta volver a iniciar sesión. No hay tareas para esto.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| El `005` falla a la mitad (el DDL no es transaccional). | Respaldo obligatorio, `ALTER` atómicos, consultas de diagnóstico y restauración (quickstart). |
| Generar la copia en SQL no coincide con lo que hoy devuelve `buildTicket` (redondeos, orden de las líneas). | Prueba de integración que compara, para cada ticket de prueba, la copia v1 con la respuesta del Sprint 4 antes de migrar. |
| Seeds con ids fijos que se cuelgan de datos manuales (orden 5 de `motorix_v2`). | Se aprovecha para probar la migración con un caso real y, al cierre, el responsable recrea `motorix_v2` limpia (ver «Orden de aplicación en `motorix_v2`»). |
| La API de Mercado Pago de México no acepta el vencimiento como la de Brasil. | Prueba manual en sandbox que hace el responsable durante la implementación. Si falla, se registra el hallazgo y se decide con él antes de cerrar el sprint. El agente nunca lee ni muestra `server/.env`. |
| Limitación conocida: Flutter muestra el rol anterior tras un cambio de rol con la sesión abierta. | Aceptada por el responsable (fuera de alcance). El servidor decide los campos según el rol actual, así que los precios siguen protegidos. |
| Candados que esperan entre sí en la suite paralela. | Orden fijo (primero la orden, después las refacciones); transacciones cortas, sin llamadas HTTP dentro. |
| Riesgo de D-04: el cliente paga un enlace de un pago ya cancelado. | En los Supuestos de la spec. La expiración (R-09) acota la ventana; el mensaje de `IMPORTE_DESFASADO` recuerda revisar el panel de Mercado Pago. |

## Registro de complejidad

| Desviación | Por qué se necesita | Alternativa más simple descartada porque |
|---|---|---|
| **El `005` reemplaza una restricción** (`uq_tickets_service_order` → `uq_tickets_payment`). Es la primera migración que quita una restricción; las 001 a 004 solo agregaban. | FR-033 exige un ticket por cada pago `PAGADO`. Con la unicidad por orden, una orden con un pago anulado y otro nuevo no puede tener dos tickets (hoy se devuelve el ticket viejo, H2). **No se pierde ningún dato**: no se borra ninguna fila ni columna; solo cambia qué combinación debe ser única. | Una tabla nueva de tickets dejaría dos tablas con el mismo propósito y un folio que hay que coordinar entre ambas. Detener el sprint hasta una enmienda fue descartado por el responsable el 2026-11-14 (opción 1 con condiciones). La regla 4 de CLAUDE.md se aclarará como tarea de FR-031, con su aprobación. |
| **Migración dividida en `005` (DDL) y `006` (datos)**. | MySQL hace un commit implícito en cada DDL, así que una transacción no puede envolver todo. Separar los datos permite revertirlos y volver a correrlos. | Un solo archivo dejaría el esquema aplicado sin registro en `schema_migrations` si fallaran los datos, y no se podría volver a correr. |

## Orden de aplicación en `motorix_v2`

Aprobado por el responsable el 2026-11-14. Las pruebas automatizadas siempre corren contra `motorix_v2_test`; este orden es para la base de desarrollo.

1. **Respaldo** de `motorix_v2` con `mysqldump` ([quickstart, paso 2](./quickstart.md#2-verificación-previa)), junto con la consulta de `payment_id` repetidos.
2. **Aplicar `005` y `006` sobre la base actual**, con la orden 5 de depuración incluida, para probar la migración con datos reales (H12).
3. **Verificar SC-011 y SC-012** con las consultas del [quickstart, paso 4](./quickstart.md#4-verificar-la-migración-sc-011-y-sc-012). Además, comprobar que el ticket de la orden 5 conserva el total de 1390.00 con la nota «El desglose no coincide con lo cobrado».
4. **Al cierre del sprint**, antes de la demostración, **recrear `motorix_v2` limpia con los datos de ejemplo** (migraciones 001 a 006 y seeds 001 a 005). **Esta recreación la ejecuta el responsable**, no el agente; es una acción destructiva.

## Puntos que requieren al responsable

1. **FR-031 / CLAUDE.md**: la aclaración de la regla 4 («aditiva») va como tarea y la aprueba el responsable antes de aplicarla.
2. **Recreación de `motorix_v2`**: la ejecuta el responsable al cierre del sprint (paso 4 del orden de aplicación).
3. **Prueba manual en el sandbox de Mercado Pago** (FR-037, SC-014): la hace el responsable durante la implementación, con sus credenciales de `server/.env`. El agente nunca lee ni muestra ese archivo.

## Siguiente paso

`/speckit-tasks` para generar `tasks.md` a partir de este plan, empezando por las pruebas (CLAUDE.md, regla 6).
