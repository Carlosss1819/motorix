# Reporte de implementación: Sprint 5 (precios de refacciones y cobro completo)

**Rama**: `005-precios-refacciones-cobro` · **Fecha**: 2026-11-16 · **Spec**: [spec.md](./spec.md) · **Tareas**: [tasks.md](./tasks.md)

## Resumen

Se implementaron las historias US1 a US5 del Sprint 5: precios validados en el catálogo y la mano de obra, precio congelado por línea con cálculo en centavos y tope, cobro con candado por orden y cancelación por importe desfasado (D-04), vencimiento de las preferencias de Mercado Pago, ticket por pago con copia versionada, inmovilización de servicios con pago vigente y precios por rol. Quedaron 88 de 89 tareas completas. Carlos ejecutó T055 en el sandbox de Mercado Pago y pasó. T084 no se ejecutó por decisión de Carlos; su flujo quedó cubierto por el recorrido por API (13/13) y las pruebas de Flutter (155).

## Pruebas (comando y resultado real)

| Momento | Comando | Resultado |
|---|---|---|
| Línea base (T001, T002) | `npm test` / `flutter test` | 49/49 suites, 411/411 pruebas · 127 pruebas Flutter |
| Fase base (T014) | `npm test` | 52/52 suites, 443/443 |
| US1 (T029) | ambos | 54/54 suites, 461/461 · 136 Flutter |
| US2 (T040) | ambos | 477 aprobadas del backend (además de 9 pruebas de US3 recién escritas que fallaban a propósito, TDD) · 140 Flutter |
| US3 (T054) | ambos | 492 aprobadas; fallaban 4 pruebas de US4 escritas antes de tiempo y 1 prueba del Sprint 4 que cambiaba por diseño (ajustada en T088) · 141 Flutter |
| US4 (T067) | ambos | 61/61 suites, 518/518 · 148 Flutter |
| US5 (T075) | ambos | 63/63 suites, 539/539 · 155 Flutter |
| Final (T083), 3 corridas | `npm test` | 64/64 suites y 545/545 pruebas en las tres (≈9.2 s, 8.8 s y 9.0 s); sin timeouts ni el aviso «A worker process has failed to exit gracefully» |
| Final (T083) | `flutter test` | 155/155 |
| Lint | `npm run lint` | sin errores |

Evidencias: `docs/evidencias/sprint 5/` (`s5-linea-base-*.txt`, `s5-fase2-npm.txt`, `s5-migracion-motorix_v2.txt`, `s5-final-npm-1..3.txt`, `s5-final-flutter.txt`, `s5-quickstart-recorrido-api.txt`).

**Hallazgo durante T083**: la primera tanda de las 3 corridas falló en 1 prueba **nueva** (`seed-005.test.js`). Contaba filas por el rango de ids 9001–9099, pero después de sembrar el id 9001 el AUTO_INCREMENT de MySQL salta y las filas de otras suites también caen en ese rango. Era un error de la prueba, no del seed ni de la línea base. Se corrigió para contar por las claves propias del seed (órdenes 9001–9003, códigos `DEM-`, folios `D00900_-2026`) y se repitieron las 3 corridas (resultados de la tabla). Las pruebas de autenticación con bloqueo (H-B01) pasaron en todas las corridas.

**Nota sobre TDD**: en el servidor todas las pruebas nuevas se escribieron y se vieron fallar antes de implementar. En Flutter de US1 (T021, T022) el validador y la pantalla se escribieron un poco antes que sus pruebas; las pruebas se agregaron enseguida y pasan.

## Archivos cambiados

**Base de datos**: `database/migrations/005_precios_congelados_tickets_por_pago.sql` y `006_datos_precio_congelado_copia_tickets.sql` (nuevos), `database/seeds/005_ejemplos_precios_congelados.sql` (nuevo; parte A por id y parte B con ids desde 9001 y folios `D009001-2026` a `D009003-2026`), `database/README.md`.

**Servidor**: `utils/money.js` y `validators/price.js` (nuevos), `services/order-lock.js` (nuevo, candado por orden compartido), `utils/order-total.js`, `validators/part.validator.js`, `validators/service-order.validator.js`, `models/order_items.js`, `models/parts.js`, `models/payment.js`, `models/service_order.js`, `models/ticket.js`, `services/part.service.js`, `services/payment.service.js`, `services/service_order.service.js`, `services/ticket.service.js`, `services/payment_gateway/mercadopago.js`, `controllers/parts.controller.js`, `config/env.js`, `.env.example`.

**Pruebas nuevas del servidor**: `tests/unit/{money,price.validator,mercadopago-preference}.test.js`; `tests/contract/{parts-prices,service-order-labor-price,parts-by-role,mechanic-price-exposure}.test.js`; `tests/integration/{migration-005-006,order-parts-frozen-price,payments-concurrency,payments-stale-pending,tickets-per-payment,service-order-paid-lock,payment-service-race,seed-005}.test.js`; `tests/helpers/fixtures.js` (helper compartido). Extendidas: `unit/order-total`, `contract/order-parts`, `contract/payments`, `contract/tickets`.

**Cliente**: `models/{part,payment,service_order,ticket}.dart`, `providers/ticket_provider.dart`, `services/{api_client,payments_service,tickets_service}.dart`, `utils/validators.dart`, `screens/{part_form,part_detail,parts,service_order_detail,ticket}_screen.dart`. Pruebas nuevas: `test/part_form_prices_test.dart`, `test/labor_price_validation_test.dart`; extendidas: `service_order_detail_test`, `payment_flow_test`, `ticket_screen_test`, `parts_screen_test`, `part_detail_test`, `fake_parts_service`, `fake_tickets_service`.

**Documentación**: `docs/project-context.md` (sección 6.10.1), `CLAUDE.md` (solo la regla 4), este reporte y `tasks.md`.

## Historias y requisitos cubiertos

- **US1** (FR-001 a FR-005, FR-032): validación común de precios, advertencia `PRECIO_VENTA_MENOR_A_COMPRA`, aviso `warning` en Flutter, validación del precio de la mano de obra en cliente y servidor.
- **US2** (FR-006 a FR-012, FR-027, FR-028, SC-001, SC-003): `unit_price` congelado, `REFACCION_SIN_PRECIO`, `TOTAL_EXCEDE_LIMITE`, total en centavos, precios por rol en el detalle de la orden.
- **US3** (FR-013 a FR-018, FR-037, SC-005, SC-008, SC-010, SC-014): candado por orden (cobro, confirmación, anulación, servicios, refacciones, estado y tickets), D-04 con `IMPORTE_DESFASADO` y motivo `MANUAL`, vencimiento de 24 h configurable, diálogo en Flutter.
- **US4** (FR-019 a FR-023, FR-033, SC-002, SC-009, SC-011 a SC-013, SC-015): ticket por pago con copia v2, v1 al migrar, `ORDEN_PAGADA`, marcas «Formato anterior» y «Pago anulado», «Tickets anteriores».
- **US5** (FR-024 a FR-026, FR-034 a FR-036, SC-004): el servidor omite las claves por rol; Flutter aplica la doble condición; el mecánico ve los datos que no son importes en el selector de refacciones.
- **FR-029** (seed 005), **FR-030** (pruebas), **FR-031** (documentación y regla 4).

## Datos y bases

- `motorix_v2_test`: antes de aplicar el 005, la consulta de `payment_id` repetidos dio 0 filas (T014). Por precaución, el 005 y el 006 se aplicaron a mano y paso a paso, registrándolos en `schema_migrations`, con un respaldo previo en el scratchpad de la sesión.
- `motorix_v2` (T015 a T018): respaldo en `C:\Users\kastr\Documents\MotorixVer2\respaldos\respaldo-motorix_v2-antes-005-20261116.sql` (fuera del repositorio); 0 duplicados; 005 y 006 aplicados con `aplicar-migraciones.ps1`; SC-011 = 0 y 0; SC-012 = 0; el ticket de la orden 5 conserva el total de 1390.00 con la nota del desglose (mano de obra 450 + refacciones 640).
- **T086**: antes de recrear se hizo otro respaldo (`respaldo-motorix_v2-antes-de-recrear-20261116.sql`, misma carpeta). Después se recreó `motorix_v2` con `DROP/CREATE DATABASE` y se aplicaron las migraciones 001 a 006 y los seeds 001 a 005. Comprobado: 5 tickets con copia (2 v1 y 3 v2), líneas con precio congelado, la API arranca y responde con los datos de ejemplo (orden 9002 con 2 tickets, orden 9003 cobrable por 599.50).

## T072 (registro de errores)

`server/middlewares/errorHandler.js` solo registra el objeto de error en los errores 500 inesperados (`console.error('[error]', fecha, error)`). No registra cuerpos de petición ni de respuesta, así que no expone precios. **Sin cambios.**

## Notas de diseño que no estaban explícitas en las tareas

- El panel (dashboard) solo muestra conteos, no importes; para FR-008 se comparó el total contra el listado de pagos y el importe guardado.
- `ORDEN_PAGADA` (T063) se implementó junto con el candado de servicios en US2, para no tocar dos veces el mismo código.
- En el seed 005, los folios de ejemplo usan el prefijo `D` para no chocar con la numeración `T000000-AAAA` de la aplicación en bases con datos.
- La consulta de duplicados de MySQL y el folio se leen con el pool (lo último confirmado), para que un reintento por folio repetido vea el folio que otra transacción acaba de confirmar.

## Superado por el Sprint 5 (no se editan los artefactos del Sprint 4)

- La **aclaración 2 del Sprint 4** («precios vigentes al cobrar») queda superada: el total usa el precio congelado de cada línea.
- El **contrato de tickets del Sprint 4** (`specs/004-pagos-tickets-dashboard/contracts/tickets.md`: un ticket por orden reconstruido al consultarlo) queda superado: un ticket por pago, leído de su copia.

## Pendientes

- **T084: no ejecutada por decisión de Carlos (2026-11-16).** No se hicieron los pasos de interfaz del quickstart en Flutter ni el cronometraje de la sección 6 (SC-006, menos de 10 minutos). El flujo quedó cubierto por el recorrido por API (13/13, `s5-quickstart-recorrido-api.txt`) y las pruebas de Flutter (155/155). SC-006 queda sin medir.
- La línea base de la regla 7 de `CLAUDE.md` se actualizó a 64 suites y 545 pruebas (backend) y 155 (Flutter), con autorización de Carlos (2026-11-16).

## T055: sandbox de Mercado Pago (ejecutada por Carlos en sandbox, 2026-11-16)

Durante la implementación `server/.env` no tenía `MP_ACCESS_TOKEN` (se comprobó sin mostrar el valor), así que las pruebas automatizadas y el recorrido por API usaron la pasarela simulada. Carlos hizo después la prueba manual con las credenciales de prueba de una aplicación de Checkout Pro. Creó un cobro de Mercado Pago para la orden 9003 por 599.50, que salió en modo sandbox, y consultó la preferencia con `GET /checkout/preferences/{id}`:

- `id`: `3848673735-018d0bca-04d4-4ca6-b317-e80696822056`
- `expires`: `True`
- `expiration_date_from`: `2026-11-16T15:35:16.687-06:00`
- `expiration_date_to`: `2026-11-17T15:35:16.687-06:00`, exactamente 24 h después
- `external_reference`: `MOT-9003-1794864916687`

**Resultado: PASÓ.** Se cumplen FR-037 y SC-014. Evidencia: `docs/evidencias/sprint 5/s5-mp-sandbox.md`.

## Riesgos

- ~~La API de Mercado Pago de México podría no aceptar `expires`/`expiration_date_*` como la de Brasil.~~ **Descartado**: T055 pasó el 2026-11-16.
- Las semillas con ids fijos desde 9001 hacen saltar el AUTO_INCREMENT en bases existentes (inofensivo, pero los ids nuevos quedan por encima de 9003).
- El `006` arma la copia v1 con `JSON_ARRAYAGG`, que no garantiza el orden de las líneas dentro del ticket.


## Cambios en pruebas existentes (T087 a T089)

Carlos autorizó por adelantado (2026-11-16) ajustar sin esperar aprobación las pruebas que cambian **por diseño** del sprint, con la condición de registrarlas aquí. Ninguna prueba se borró y ninguna aserción se debilitó: los cambios agregan un dato que la regla nueva exige o actualizan el texto o la forma de la respuesta del contrato nuevo.

### T087 (US2: precio congelado y cálculo en centavos)

| Archivo y línea | Por qué cambia | Antes | Después |
|---|---|---|---|
| `server/tests/contract/order-parts.test.js:30` (helper `crearRefaccion`) | FR-005: una refacción sin precio de venta ya no se puede agregar a una orden (`409 REFACCION_SIN_PRECIO`). El helper creaba refacciones sin precio. | `categoria: 'Frenos', stockInicial: stock, stockMinimo: 1` | Igual, más `precioVenta: 100` |
| `server/tests/contract/service-order-content.test.js:59` (helper `crearRefaccion`) | FR-005 (igual que arriba). | sin `precioVenta` | `precioVenta: 100` |
| `server/tests/integration/service-order-content.test.js:47` (helper `crearRefaccion`) | FR-005. | sin `precioVenta` | `precioVenta: 100` |
| `server/tests/integration/order-parts-stock.test.js:27` (helper `crearRefaccion`) | FR-005. | sin `precioVenta` | `precioVenta: 100` |
| `server/tests/integration/stock-low.test.js:24` (helper de alta) | FR-005. | sin `precioVenta` | `precioVenta: 100` |
| `server/tests/unit/order-total.test.js:38-39` (títulos) | FR-006, FR-007: el cálculo usa el precio congelado de la línea, no el «vigente del catálogo». Solo cambia el texto; las aserciones son las mismas. | `'calcularTotal — refacciones (FR-015, precios vigentes)'` y `'multiplica el precio de venta vigente del catálogo por la cantidad usada'` | `'calcularTotal — refacciones (FR-015; Sprint 5: precio congelado de la línea)'` y `'multiplica el precio unitario congelado de la línea por la cantidad usada'` |
| `server/tests/contract/payments.test.js:141` (título) | FR-006, FR-015: el desglose usa el precio congelado. Solo el texto. | `'… calculados con precios vigentes'` | `'… calculados con el precio congelado (Sprint 5)'` |
| `server/tests/integration/payments.test.js:148` y `:173` (título y comentario) | FR-006, FR-015. Solo el texto. | `'… con precios vigentes (FR-015)'` | `'… con el precio congelado (FR-015; Sprint 5)'` |

### T088 (US3 y US4: desglose del ticket, ticket por pago y copia con versión)

| Archivo y línea | Por qué cambia | Antes | Después |
|---|---|---|---|
| `server/tests/integration/tickets.test.js:275-283` | FR-018: cada refacción del ticket trae `aviso` («sin precio registrado» o `null`), igual que el desglose del pago. La aserción usaba `toEqual` exacto. | `{ codigo, nombre, cantidad: 2, precioUnitario: 320, subtotal: 640 }` | Lo mismo, más `aviso: null` |
| `server/tests/contract/tickets.test.js:277` | FR-033 y R-14: `GET /api/tickets/orden/:ordenId` agrega la lista `tickets` (todos los tickets de la orden). | `toEqual({ existe: false, ticket: null })` | `toEqual({ existe: false, ticket: null, tickets: [] })` |
| `client/test/fake_tickets_service.dart` (`ticketDePrueba`) | FR-019, FR-020, FR-022: el modelo `Ticket` tiene marcas nuevas. Se agregaron parámetros **opcionales** con valores por defecto (ticket vigente, formato 2, sin marcas); las pruebas existentes no cambian. | sin `formatoAnterior`, `desgloseNoCoincide`, `nota`, `pagoAnulado`, `vigente` | con esos parámetros opcionales |

Revisados sin cambios: `server/tests/integration/tickets.test.js` (consulta por orden e idempotencia siguen pasando igual) y `client/test/ticket_screen_test.dart` (solo se le **agregaron** pruebas nuevas al final).


### T089 (US5: precios del catálogo por rol)

**Servidor**: ninguna prueba cambió. Se revisaron `server/tests/contract/parts.test.js`, `server/tests/integration/parts.test.js` y `server/tests/contract/parts-search.test.js`: ninguna espera `precioCompra` o `precioVenta` para RECEPTIONIST o MECHANIC, y siguen pasando sin cambios.

**Flutter**:

| Archivo y línea | Por qué cambia | Antes | Después |
|---|---|---|---|
| `client/test/part_detail_test.dart` (helper `pumpScreen`, ~línea 100) | FR-024, FR-025: `PartDetailScreen` ahora decide los precios con la doble condición (rol de la sesión y campo presente), así que necesita el `AuthProvider` arriba. Sin él, las 5 pruebas existentes fallaban con `ProviderNotFoundException`. Se agregó la sesión con rol **ADMIN por defecto**, que es el rol que ve los dos precios: las aserciones existentes (`$180.00` y `$320.00`) no cambian. | `ChangeNotifierProvider<PartDetailProvider>(…)` | `MultiProvider` con `AuthProvider` (rol ADMIN por defecto) y `PartDetailProvider`; parámetro opcional `rol` |
| `client/test/part_detail_test.dart` (`_PartsServiceFake`) | Para probar la respuesta sin la clave `precioCompra` (servidor que omite el campo). Parámetro **opcional**; sin él devuelve la misma refacción de antes. | `_PartsServiceFake({this.page, this.failure})` | `_PartsServiceFake({this.page, this.failure, this.refaccion})` |

Revisados sin cambios: `client/test/parts_screen_test.dart` (ya usaba ADMIN por defecto; solo se le agregaron pruebas), `client/test/stock_low_test.dart` y `client/test/edit_routes_navigation_test.dart`.


## Aclaración de la regla 4 de `CLAUDE.md` (T080 a T082, FR-031)

**Texto anterior**:

> 4. Migraciones: aditivas y numeradas (`005_...`); nunca edites una migración ya aplicada. Seeds: idempotentes.

**Propuesta (T080)**:

> 4. Migraciones: aditivas y numeradas (`005_...`). «Aditiva» significa no editar migraciones ya aplicadas y no borrar tablas, columnas ni datos. Se permite reemplazar una restricción (por ejemplo, un índice único) si se conservan los datos y se documenta en el plan del sprint. Seeds: idempotentes.

**Aprobación (T081)**: Carlos la aprobó por adelantado el 2026-11-16, en la instrucción de implementación del sprint («redactar y aplicar la aclaración de la regla 4 de CLAUDE.md (T080 a T082, la apruebo de antemano)»).

**Aplicación (T082)**: se reemplazó solo la regla 4 de `CLAUDE.md`; ninguna otra regla cambió.
