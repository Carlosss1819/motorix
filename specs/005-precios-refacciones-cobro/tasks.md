---

description: "Lista de tareas del Sprint 5: precios de refacciones y cobro completo"
---

# Tareas: Precios de refacciones y cobro completo

**Input**: documentos de diseño de `specs/005-precios-refacciones-cobro/`

**Prerrequisitos**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/README.md), [quickstart.md](./quickstart.md)

**Pruebas**: obligatorias (FR-030 y CLAUDE.md, regla 6). En cada historia, las pruebas se escriben **antes** del código y deben **fallar** antes de implementar.

**Organización**: por historia de usuario (US1 a US5), con una fase de preparación, una fase base y una fase final.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede hacer en paralelo (otro archivo y sin depender de tareas incompletas).
- **[US1] … [US5]**: historia de la spec a la que pertenece la tarea.
- **[MANUAL - Carlos]**: la hace el responsable, no el agente. El agente se detiene y espera su confirmación.

## Convenciones de rutas

- Servidor: `server/` (sin `src/`): `config/`, `controllers/`, `models/`, `routes/`, `services/`, `validators/`, `utils/`, `tests/{unit,contract,integration}/`.
- Cliente: `client/lib/{models,screens,services,providers,utils}/` y `client/test/`.
- Base de datos: `database/{migrations,seeds,scripts}/`.
- Evidencias: `docs/evidencias/sprint 5/`.

## Reglas para todo el sprint

- **Puntos de control**: en `server/` corre `npm test`; en `client/` corre `flutter test`. Deben pasar las **49 suites y 411 pruebas** del backend y las **127** de Flutter de la línea base, **más** las nuevas. Si falla una de la línea base, se detiene y se reporta; no se debilita ni se borra ninguna prueba.
- El agente **nunca** lee ni muestra `server/.env`.
- Las pruebas corren contra `motorix_v2_test`, nunca contra `motorix_v2`.
- Las migraciones `001` a `004` no se editan.

---

## Fase 1: Preparación

**Propósito**: fijar la línea base antes de tocar nada.

- [X] T001 Correr `npm test` en `server/` y guardar la salida en `docs/evidencias/sprint 5/s5-linea-base-npm.txt` (SC-007). Confirmar 49/49 suites y 411/411 pruebas; si no, detenerse y reportar.
- [X] T002 [P] Correr `flutter test` en `client/` y guardar la salida en `docs/evidencias/sprint 5/s5-linea-base-flutter.txt`. Confirmar 127 pruebas aprobadas; si no, detenerse y reportar.

---

## Fase 2: Base (prerrequisitos que bloquean todas las historias)

**Propósito**: esquema nuevo, migración de datos, cálculo en centavos, validador de precios y candado por orden. Todas las historias dependen de esta fase.

**⚠️ CRÍTICO**: ninguna historia empieza hasta que pase el punto de control T014.

### Pruebas de la fase base (escribir primero; deben fallar)

- [X] T003 [P] Pruebas unitarias de la conversión monetaria en `server/tests/unit/money.test.js`:
  - `'320.00'` → 32000 centavos;
  - `'0.10'` → 10 y `'999999.99'` → 99999999, sin pasar por flotante;
  - `null` → `null`;
  - de centavos a número de dos decimales (`32000` → `320`).
- [X] T004 [P] Pruebas unitarias del validador de precios en `server/tests/unit/price.validator.test.js`. La regla es «numérico, ≥ 0, máximo 2 decimales, ≤ 999,999.99»:
  - se aceptan `0`, `10.5` y `999999.99`;
  - se rechazan `-1`, `'abc'`, `10.005` y `1000000`.
- [X] T005 [P] Extender `server/tests/unit/order-total.test.js` para el cálculo en centavos con precio congelado:
  - el importe de línea usa `precioUnitario` de la línea;
  - una línea sin precio vale 0 con «sin precio registrado»;
  - `3 × 33.33 = 99.99` exacto y una orden de 10 líneas suma igual que a mano (SC-003);
  - `excedeLimite` es verdadero por encima de 9,999,999,999 centavos (99,999,999.99).
- [X] T006 Prueba de integración de la migración en `server/tests/integration/migration-005-006.test.js`:
  - **Esquema**: existen `order_parts.unit_price`, `tickets.content`, `tickets.format_version` y `payments.cancellation_reason`; existe `uq_tickets_payment` y ya no `uq_tickets_service_order`.
  - **Datos**: la prueba inserta por SQL una orden con mano de obra, una línea con refacción con precio, una línea con refacción sin precio y una línea sin `part_id`, más un pago `PAGADO` y un ticket con `content NULL`. Después ejecuta el texto de `database/migrations/006_…sql`.
  - **SC-011**: la línea con refacción toma el precio vigente; las demás quedan en `NULL`.
  - **SC-012**: la copia tiene `format_version = 1` y `total = payments.amount`.
  - **FR-020**: con un pago cuyo importe no coincide con el desglose, la copia lleva `desgloseNoCoincide: true` y la nota «El desglose no coincide con lo cobrado».
  - **Repetible**: volver a ejecutar el `006` no cambia nada.
  - **Aislamiento (evitar timeouts como H-B01)**: la prueba **no** ejecuta el `006` completo sobre toda la base compartida mientras corren otras suites. Ejecuta las mismas sentencias del `006` **acotadas a las filas que crea la propia prueba** (por sus ids). Si eso no es posible, la suite se marca para correr sola (en serie) y se documenta en el archivo por qué.

### Implementación de la fase base

- [X] T007 Crear `database/migrations/005_precios_congelados_tickets_por_pago.sql`: cabecera «Script INMUTABLE», **solo DDL**, en tres sentencias atómicas:
  - (a) `ALTER TABLE order_parts ADD COLUMN unit_price DECIMAL(10,2) NULL AFTER quantity`;
  - (b) **una sola** sentencia `ALTER TABLE tickets ADD COLUMN content JSON NULL, ADD COLUMN format_version SMALLINT NULL, ADD KEY idx_tickets_service_order (service_order_id), DROP INDEX uq_tickets_service_order, ADD UNIQUE KEY uq_tickets_payment (payment_id)`;
  - (c) `ALTER TABLE payments ADD COLUMN cancellation_reason VARCHAR(30) NULL`.

  Incluir un comentario de que es la primera migración que reemplaza una restricción y que no borra ni modifica datos (R-01, plan, «Registro de complejidad»).
- [X] T008 Crear `database/migrations/006_datos_precio_congelado_copia_tickets.sql` (FR-010, D-03; FR-020): **solo datos**, entre `START TRANSACTION;` y `COMMIT;`.
  - (a) `UPDATE order_parts op JOIN parts p ON p.id = op.part_id SET op.unit_price = p.sale_price WHERE op.unit_price IS NULL`.
  - (b) `UPDATE tickets t JOIN payments pa ON pa.id = t.payment_id … SET t.content = JSON_OBJECT(…), t.format_version = 1 WHERE t.content IS NULL`, con la estructura de [data-model.md](./data-model.md#ticket-copia-del-contenido): `total = pa.amount`, y `desgloseNoCoincide` y `nota` cuando la suma del desglose ≠ `pa.amount`.
  - Sin `DELIMITER` ni procedimientos, porque `tests/helpers/db.js` usa mysql2 con `multipleStatements`.
- [X] T009 [P] Crear `server/utils/money.js` (conversión de `DECIMAL` en cadena ↔ centavos enteros, sin flotantes), hasta que pase T003.
- [X] T010 [P] Crear `server/validators/price.js`, un esquema Zod reutilizable: numérico, ≥ 0, máximo 2 decimales con la tolerancia de R-13 y ≤ 999,999.99, con mensajes en español que nombran el campo. Hasta que pase T004.
- [X] T011 Reescribir `server/utils/order-total.js` en centavos con `money.js` (FR-008; FR-009: el total es mano de obra + refacciones, sin un precio de servicio aparte):
  - usa `precioUnitario` congelado de cada línea;
  - una línea sin `partId` o sin precio vale 0 y lleva el aviso;
  - redondeo hacia arriba desde 0.5 solo si la cantidad no es entera;
  - exporta `LIMITE_TOTAL_CENTAVOS = 9999999999` y `excedeLimite()`;
  - conserva la forma de la respuesta del Sprint 4.

  Hasta que pase T005.
- [X] T012 [P] Agregar `lockServiceOrderForUpdate(connection, id)` en `server/models/service_order.js` (`SELECT id, status FROM service_orders WHERE id = ? FOR UPDATE`), con un comentario sobre el orden de candados: primero la orden, después las refacciones (R-07).
- [X] T013 Crear `database/seeds/005_ejemplos_precios_congelados.sql`, **parte A**: idempotente. Completa `unit_price` **solo** de `order_parts.id = 4` y la copia en versión 1 **solo** de `tickets.id IN (1, 2)`, en ambos casos donde la columna siga en `NULL`, con la misma lógica que T008 (R-05).
- [X] T014 **Punto de control** (SC-007):
  1. **Antes** de correr las pruebas, que aplican el `005` en `motorix_v2_test` mediante el `globalSetup`, ejecutar sobre `motorix_v2_test` la consulta de solo lectura `SELECT payment_id, COUNT(*) AS n FROM tickets GROUP BY payment_id HAVING n > 1;`. Debe devolver 0 filas; si no, detenerse y reportar sin correr las pruebas.
  2. Correr `npm test` en `server/`: deben pasar la línea base y T003 a T006.
  3. Guardar la salida en `docs/evidencias/sprint 5/s5-fase2-npm.txt`.

### Aplicación en `motorix_v2` (orden aprobado en el plan)

- [X] T015 [MANUAL - Carlos] Respaldar `motorix_v2` con `mysqldump` según [quickstart.md, paso 2](./quickstart.md#2-verificación-previa) y guardar el archivo **fuera** del repositorio. Avisar al agente cuando esté listo.
- [X] T016 Después de T015, ejecutar en `motorix_v2` la consulta de solo lectura de `payment_id` repetidos en `tickets` (quickstart, paso 2). Debe devolver 0 filas; si no, detenerse y reportar.
- [X] T017 Aplicar `005` y `006` en `motorix_v2` con `database/scripts/aplicar-migraciones.ps1`, sobre la base actual con la orden 5 incluida. Si la ejecución pide la contraseña de `motorix_app`, la escribe Carlos; el agente no lee `server/.env`.
- [X] T018 Verificar en `motorix_v2` SC-011 y SC-012 con las consultas del [quickstart, paso 4](./quickstart.md#4-verificar-la-migración-sc-011-y-sc-012), y que el ticket de la orden 5 conserve `total = 1390.00` con la nota de desglose. Guardar la salida en `docs/evidencias/sprint 5/s5-migracion-motorix_v2.txt`.

**Punto de control**: base lista; las historias pueden empezar.

---

## Fase 3: Historia 1 - Mantener los datos y precios de una refacción (Prioridad: P1) 🎯 MVP

**Objetivo**: el administrador registra y edita refacciones con precios validados (dos decimales y tope), con advertencia si el precio de venta es menor que el de compra. El precio de la mano de obra tiene la misma validación.

**Prueba independiente**: alta y edición de refacciones con precios válidos e inválidos, sin tocar órdenes; alta de servicios con precios de mano de obra válidos e inválidos.

### Pruebas de la historia 1 (escribir primero; deben fallar)

- [X] T019 [P] [US1] Pruebas de contrato en `server/tests/contract/parts-prices.test.js`:
  - 3 decimales, más de 999,999.99, negativo y no numérico → `400 VALIDACION` con el campo; `999999.99` se acepta (FR-003);
  - `precioVenta < precioCompra` → se guarda con `advertencias[0].codigo = "PRECIO_VENTA_MENOR_A_COMPRA"` (FR-004);
  - la categoría (texto libre) es obligatoria y la marca es opcional (FR-001);
  - recepción y mecánico reciben `403` al crear o editar (FR-002).
- [X] T020 [P] [US1] Pruebas de contrato en `server/tests/contract/service-order-labor-price.test.js`: `POST /api/service-orders/:id/servicios` rechaza `precio` negativo, no numérico, con 3 decimales o mayor que 999,999.99 con `400 VALIDACION`; acepta sin precio y con `999999.99` (FR-032).
- [X] T021 [P] [US1] Pruebas de Flutter en `client/test/part_form_prices_test.dart`: validación de dos decimales y del tope en el formulario de refacción, y aviso `warning` «Se guardó. El precio de venta es menor que el precio de compra» cuando la respuesta trae la advertencia (usar `client/test/fake_parts_service.dart`).
- [X] T022 [P] [US1] Pruebas de Flutter en `client/test/labor_price_validation_test.dart`: el campo de precio de la mano de obra del detalle de la orden rechaza 3 decimales, valores negativos y más de 999,999.99.

### Implementación de la historia 1

- [X] T023 [US1] Usar `server/validators/price.js` en `server/validators/part.validator.js` para `precioCompra` y `precioVenta` (alta y edición).
- [X] T024 [US1] Usar `server/validators/price.js` en `server/validators/service-order.validator.js` para `precio` de la mano de obra, que sigue siendo opcional.
- [X] T025 [US1] En `server/services/part.service.js`, agregar `advertencias: [{ codigo: "PRECIO_VENTA_MENOR_A_COMPRA", mensaje: "El precio de venta es menor que el precio de compra" }]` a la respuesta de alta y edición cuando corresponda (contracts/parts.md).
- [X] T026 [P] [US1] Agregar en `client/lib/utils/validators.dart` un validador de precio con la misma regla que el servidor.
- [X] T027 [US1] En `client/lib/screens/part_form_screen.dart`, usar el validador y mostrar el aviso D-07 con el token `warning` (contracts/ui-flutter.md).
- [X] T028 [US1] En `client/lib/screens/service_order_detail_screen.dart`, validar el precio de la mano de obra con el validador nuevo (reemplaza el `double.tryParse` que solo rechaza negativos).
- [X] T029 [US1] **Punto de control**: `npm test` y `flutter test` (línea base + T019 a T022).

---

## Fase 4: Historia 2 - Total de la orden con precio congelado (Prioridad: P2)

**Objetivo**: al agregar una refacción a una orden, la línea guarda el precio de venta vigente. El total (mano de obra + refacciones congeladas) es exacto al centavo y no cambia si cambia el catálogo.

**Prueba independiente**: agregar una refacción, cambiar el precio del catálogo y comprobar que la línea y el total no cambian.

### Pruebas de la historia 2 (escribir primero; deben fallar)

- [X] T030 [P] [US2] Pruebas de integración en `server/tests/integration/order-parts-frozen-price.test.js`:
  - `addPart` guarda `unit_price` = precio vigente (FR-006);
  - un cambio de precio del catálogo o la desactivación de la refacción no cambian la línea ni el total (FR-007, SC-001);
  - quitar y volver a agregar la línea toma el precio nuevo (FR-011);
  - una refacción sin `sale_price` da `409 REFACCION_SIN_PRECIO` (FR-005);
  - agregar una refacción o un servicio que haga pasar el total de 99,999,999.99 da `409 TOTAL_EXCEDE_LIMITE` (FR-008);
  - `3 × 33.33` suma 99.99.
- [X] T031 [P] [US2] Extender `server/tests/contract/order-parts.test.js`:
  - `GET /api/service-orders/:id` trae `repuestos[].precioUnitario`, `importe` y `aviso` para ADMIN y RECEPTIONIST y **no** trae esas claves para MECHANIC;
  - `POST /:id/refacciones` responde sin precios para los tres roles (contracts/service-orders.md).
- [X] T032 [P] [US2] Extender `server/tests/contract/payments.test.js`:
  - `GET /api/payments/orden/:ordenId/total` usa el precio congelado;
  - una orden `TERMINADO` con solo refacciones y total > 0 se cobra, y un total de 0 se rechaza (FR-012, D-02).
- [X] T033 [P] [US2] Extender `client/test/service_order_detail_test.dart`: precio unitario e importe de las refacciones visibles para ADMIN y RECEPTIONIST y ocultos para MECHANIC; «sin precio registrado» en las líneas sin precio.
- [X] T087 [US2] Ajustar las pruebas existentes de los Sprints 3 y 4 que cambian **por diseño** con el precio congelado y el cálculo en centavos. Revisar al menos `server/tests/integration/payments.test.js` (FR-015, «precios vigentes»), `server/tests/contract/payments.test.js` (desglose «con precios vigentes»), `server/tests/unit/order-total.test.js` y `server/tests/contract/order-parts.test.js`. **Regla 6 de CLAUDE.md**:
  1. **antes** de cambiar cada prueba, mostrarle a Carlos el archivo y la línea, por qué cambia (qué FR del Sprint 5 lo exige) y el texto de antes y después;
  2. **esperar su aprobación**;
  3. registrar el cambio en `specs/005-precios-refacciones-cobro/reporte-implementacion.md`.

  Nunca se borra ni se debilita una prueba sin esa aprobación.

### Implementación de la historia 2

- [X] T034 [US2] En `server/models/order_items.js`, guardar `unit_price` en `insertOrderPart` y devolverlo en `listPartsByOrder`.
- [X] T035 [US2] En `server/models/payment.js` (`findChargeContent`), tomar `op.unit_price` como `precioUnitario` en lugar de `pa.sale_price` (R-03).
- [X] T036 [US2] En `server/services/service_order.service.js` (`addPart`):
  - rechazar sin `sale_price` con `REFACCION_SIN_PRECIO`;
  - guardar `unit_price`;
  - tomar `lockServiceOrderForUpdate` **antes** de `lockStockForUpdate`;
  - rechazar con `TOTAL_EXCEDE_LIMITE` si el total se pasaría.

  En `addService`, aplicar la misma verificación del tope. Para MECHANIC, el mensaje de `TOTAL_EXCEDE_LIMITE` va **sin cifras** (FR-036). La salida de inventario y el stock no negativo no cambian (FR-028).
- [X] T037 [US2] En `server/services/service_order.service.js` (`toApiDetail`), recibir el rol y agregar `precioUnitario`, `importe` y `aviso` a `repuestos[]` solo para ADMIN y RECEPTIONIST.
  - **Denegar por defecto: «sin rol = sin precios»**. Si el rol no llega o no es ADMIN ni RECEPTIONIST, no se incluye ninguna de esas claves.
  - **Todas** las llamadas a `toApiDetail` DEBEN pasar el rol: detalle, actualización, diagnóstico, recomendaciones, cambio de estado, asignación de mecánico y cualquier otra que se encuentre buscando `toApiDetail(` en el archivo.
  - Pasar `req.user` desde `server/controllers/service_orders.controller.js` a cada uno de esos servicios (FR-025, FR-034).
- [X] T038 [P] [US2] Agregar en `client/lib/models/service_order.dart` los campos opcionales `precioUnitario`, `importe` y `aviso` de cada repuesto.
- [X] T039 [US2] En `client/lib/screens/service_order_detail_screen.dart`, mostrar el precio unitario y el importe de las refacciones con la doble condición (rol y campo presente) (contracts/ui-flutter.md).
- [X] T040 [US2] **Punto de control**: `npm test` y `flutter test` (línea base + nuevas). Incluye FR-027: las pruebas del panel y de los listados de órdenes y pagos siguen pasando con el total nuevo, y se agrega a `server/tests/integration/order-parts-frozen-price.test.js` (T030) la comprobación de que el importe de la orden en el listado de pagos y en el panel coincide **al centavo** con el total de `GET /api/payments/orden/:ordenId/total` (FR-008).

---

## Fase 5: Historia 3 - Pago y ticket con el total completo (Prioridad: P3)

**Objetivo**: el pago se registra por el total con refacciones congeladas, con un solo pago vigente aun con solicitudes simultáneas. Un pago pendiente de Mercado Pago con importe desfasado se cancela al confirmarlo. Las preferencias nuevas vencen. El ticket desglosa las refacciones.

**Prueba independiente**: cobrar una orden terminada con mano de obra y refacciones, generar el ticket y comprobar el desglose; dos cobros simultáneos dejan uno solo.

### Pruebas de la historia 3 (escribir primero; deben fallar)

- [X] T041 [P] [US3] Prueba de integración de concurrencia en `server/tests/integration/payments-concurrency.test.js`: dos `POST /api/payments` simultáneos (`Promise.all`) para la misma orden dan exactamente un `201` y un `409` (`ORDEN_YA_LIQUIDADA` o `PAGO_PENDIENTE`). Repetir 5 veces con órdenes nuevas (FR-014, SC-005, CA-8).
- [X] T042 [P] [US3] Prueba de integración de D-04 en `server/tests/integration/payments-stale-pending.test.js`:
  - pago de Mercado Pago `PENDIENTE` (pasarela simulada); se quita un servicio; confirmar `PAGADO` da `409 IMPORTE_DESFASADO` con `importePago`, `totalActual` y `diferencia`, y el pago queda `CANCELADO` con `motivoCancelacion = "IMPORTE_DESFASADO"`;
  - después se registra un pago nuevo por el total correcto (FR-016, SC-010);
  - una cancelación manual guarda `"MANUAL"`; `RECHAZADO` no compara el importe.
- [X] T043 [P] [US3] Prueba unitaria del cuerpo de la preferencia en `server/tests/unit/mercadopago-preference.test.js`:
  - `expires: true`;
  - `expiration_date_from` = ahora;
  - `expiration_date_to` = ahora + `MP_PREFERENCIA_VIGENCIA_HORAS` (24 por defecto);
  - las dos fechas en ISO 8601 con zona horaria (FR-037, SC-014);
  - el `unit_price` del ítem enviado a Mercado Pago es igual al total de la orden con precio congelado, aunque el precio del catálogo haya cambiado después de agregar la refacción (FR-015).

  La prueba usa una función pura de armado del cuerpo, sin llamar a la red.
- [X] T044 [P] [US3] Extender `server/tests/contract/tickets.test.js`: el ticket nuevo trae, por refacción, `cantidad`, `precioUnitario` congelado y `subtotal`, y el subtotal y el total las suman. Una línea sin precio trae `aviso: "sin precio registrado"`, y una mano de obra sin precio trae `servicios[].avisoManoDeObra: "sin precio registrado"`, igual que el desglose del pago (FR-017, FR-018, SC-008; data-model.md).
- [X] T045 [P] [US3] Extender `client/test/payment_flow_test.dart`: ante `409 IMPORTE_DESFASADO` al confirmar, se muestra un diálogo con el importe del pago, el total actual, la diferencia y el recordatorio de revisar el panel de Mercado Pago (usar `client/test/fake_payments_service.dart`).

### Implementación de la historia 3

- [X] T046 [US3] Leer `MP_PREFERENCIA_VIGENCIA_HORAS` (entero > 0, 24 por defecto) en `server/config/env.js` y documentarla **sin valor secreto** en `server/.env.example`.
- [X] T047 [US3] En `server/services/payment_gateway/mercadopago.js`, extraer una función pura que arme el cuerpo de la preferencia con `expires`, `expiration_date_from` y `expiration_date_to` (R-09), y usarla en `crearPreferencia`. La pasarela simulada (`simulado.js`) no cambia.
- [X] T048 [US3] En `server/models/payment.js`, mapear `cancellation_reason` como `motivoCancelacion`, aceptarlo en `updatePaymentStatus` y permitir que `createPayment` y `updatePaymentStatus` reciban una conexión de transacción.
- [X] T049 [US3] En `server/services/payment.service.js` (`registerPayment`; FR-013, FR-014, FR-015):
  1. validar sin candado;
  2. crear la preferencia de Mercado Pago **fuera** del candado;
  3. abrir la transacción, tomar `lockServiceOrderForUpdate`, volver a validar (estado `TERMINADO`, sin `PAGADO` ni `PENDIENTE`, total igual en centavos), insertar y hacer commit.

  Si la segunda validación falla, se responde 409 (R-07).
- [X] T050 [US3] En `server/services/payment.service.js` (`confirmPayment`), con el candado de la orden:
  - si `estado = PAGADO` y el importe no coincide con el total, pasar a `CANCELADO` con `cancellation_reason = 'IMPORTE_DESFASADO'`, hacer commit y lanzar `conflict(…, 'IMPORTE_DESFASADO', { importePago, totalActual, diferencia })` con el mensaje de contracts/payments.md;
  - `CANCELADO` manual guarda `'MANUAL'`.
- [X] T051 [US3] En `server/services/payment.service.js` (`annulPayment`), hacer la anulación dentro de una transacción con el candado de la orden (FR-014).
- [X] T052 [P] [US3] Agregar `motivoCancelacion` en `client/lib/models/payment.dart` y exponer los campos de `IMPORTE_DESFASADO` en el error de `client/lib/services/payments_service.dart`.
- [X] T053 [US3] En `client/lib/screens/service_order_detail_screen.dart` (confirmación de Mercado Pago), mostrar el diálogo de `IMPORTE_DESFASADO` (contracts/ui-flutter.md).
- [X] T054 [US3] **Punto de control**: `npm test` y `flutter test` (línea base + nuevas).
- [X] T055 [US3] [MANUAL - Carlos] **Ejecutada por Carlos en sandbox el 2026-11-16: PASÓ** (evidencia en `docs/evidencias/sprint 5/s5-mp-sandbox.md`). Prueba en el sandbox de Mercado Pago (México), con sus credenciales en `server/.env`, que el agente no lee:
  - crear un cobro;
  - comprobar que la preferencia se acepta con `expires: true` y `expiration_date_to` a 24 horas, y que `GET /checkout/preferences/{id}` la devuelve con esos campos;
  - anotar el resultado en `docs/evidencias/sprint 5/s5-mp-sandbox.md`.

  Si falla, avisar antes de cerrar el sprint (plan, «Riesgos»).

---

## Fase 6: Historia 4 - Integridad del historial ante cambios de precio (Prioridad: P4)

**Objetivo**: los tickets se leen de su copia con versión; hay un ticket por cada pago `PAGADO`; el ticket del pago anulado muestra «pago anulado»; una orden `TERMINADO` con pago `PAGADO` no admite cambios de servicios hasta que el pago se anule.

**Prueba independiente**: emitir un ticket, cambiar el catálogo y volver a consultarlo sin cambios; anular, volver a cobrar y obtener un ticket nuevo.

### Pruebas de la historia 4 (escribir primero; deben fallar)

- [X] T056 [P] [US4] Prueba de integración en `server/tests/integration/tickets-per-payment.test.js`:
  - cobrar → ticket con `formatoVersion = 2` y copia guardada (FR-019);
  - cambiar el precio del catálogo → la copia no cambia (SC-002);
  - el administrador anula el pago → se permite agregar un servicio;
  - un pago nuevo y `POST /api/tickets` dan un ticket **nuevo** con otro folio (FR-033);
  - `GET /api/tickets/orden/:ordenId` devuelve `ticket` (el vigente) y `tickets` (2);
  - el ticket viejo trae `pagoAnulado: true` y `vigente: false` y conserva su contenido (FR-022);
  - repetir `POST /api/tickets` es idempotente para el mismo pago (SC-013);
  - **entrega (SC-015)**: con el pago anulado y sin pago nuevo, pasar la orden a `ENTREGADO` da `409 PAGO_PENDIENTE` (regla actual de `hasApprovedPayment` en `server/services/payment.service.js`); después de registrar el pago `PAGADO` nuevo, el paso a `ENTREGADO` se permite;
  - **conjunto de referencia de SC-002**: los tickets `T000001-2026` y `T000002-2026` del seed 004 y los tickets que crea esta prueba conservan su copia (importe y contenido) después de cambiar el precio de sus refacciones en el catálogo. Los del seed 005 se comprueban en T076.
- [X] T057 [P] [US4] Prueba de integración en `server/tests/integration/service-order-paid-lock.test.js`:
  - en `TERMINADO` con `PAGADO`, agregar o quitar un servicio da `409 ORDEN_PAGADA` (FR-021);
  - se permite con un pago `PENDIENTE`, `RECHAZADO` o `CANCELADO`, con el `PAGADO` anulado (`ANULADO`) y sin pago (FR-021, FR-022, SC-009);
  - las refacciones en `TERMINADO` siguen dando `ORDEN_CERRADA` y `ENTREGADO` sigue dando `ORDEN_ENTREGADA` (FR-023, SC-009).
- [X] T058 [P] [US4] Prueba de integración de la carrera en `server/tests/integration/payment-service-race.test.js`. Se lanzan en paralelo «confirmar `PAGADO`» de un pago pendiente y «quitar un servicio» de la misma orden, 10 veces con órdenes nuevas. El resultado siempre es uno de estos dos:
  - confirmación `409 IMPORTE_DESFASADO` y servicio quitado;
  - confirmación `200 PAGADO` y `409 ORDEN_PAGADA`.

  Nunca debe quedar un pago `PAGADO` con importe distinto del total (R-07).
- [X] T059 [P] [US4] Extender `server/tests/contract/tickets.test.js`:
  - los tickets sembrados (`T000001-2026` y `T000002-2026`) traen `formatoAnterior: true`;
  - un ticket con desglose desfasado trae `desgloseNoCoincide` y `nota`;
  - `GET /api/tickets/orden/:ordenId` tiene la forma `{ existe, ticket, tickets }` de contracts/tickets.md.
- [X] T060 [P] [US4] Extender `client/test/ticket_screen_test.dart`:
  - chip «Formato anterior» con `warning`;
  - chip «Pago anulado» con `danger` y su aviso;
  - aviso «El desglose no coincide con lo cobrado»;
  - lista «Tickets anteriores» en el detalle de la orden.

  Usar `client/test/fake_tickets_service.dart`.
- [X] T088 [US4] Ajustar las pruebas existentes del Sprint 4 que cambian **por diseño** con el ticket por pago y la copia con versión. Por ejemplo, `server/tests/contract/tickets.test.js:277`, que espera exactamente `{ existe: false, ticket: null }` cuando el contrato nuevo agrega `tickets: []`. Revisar también `server/tests/integration/tickets.test.js` (consulta por orden e idempotencia) y `client/test/ticket_screen_test.dart`. **Regla 6 de CLAUDE.md**:
  1. **antes** de cambiar cada prueba, mostrarle a Carlos el archivo y la línea, por qué cambia (FR-019, FR-033) y el texto de antes y después;
  2. **esperar su aprobación**;
  3. registrar el cambio en `specs/005-precios-refacciones-cobro/reporte-implementacion.md`.

  Nunca se borra ni se debilita una prueba sin esa aprobación.

### Implementación de la historia 4

- [X] T061 [US4] En `server/models/ticket.js`:
  - `create` guarda `content` y `format_version` y acepta una conexión;
  - agregar `findByPaymentId` y `listByServiceOrder` (del más reciente al más antiguo);
  - `mapTicket` incluye la copia;
  - actualizar el comentario de unicidad (`uq_tickets_payment`).
- [X] T062 [US4] En `server/services/ticket.service.js`:
  - `generateTicket`, con el candado de la orden: busca el pago `PAGADO` no anulado; devuelve su ticket si existe o crea uno con copia versión 2 armada con la lógica actual de `buildTicket`;
  - `getTicket` lee la copia y agrega `estadoPago`, `pagoAnulado`, `vigente` y `formatoAnterior`;
  - `getTicketByOrder` devuelve `{ existe, ticket, tickets }` (R-14).
- [X] T063 [US4] En `server/services/service_order.service.js` (`addService`, `removeService` y el cambio de estado):
  - transacción con `lockServiceOrderForUpdate`;
  - rechazar con `409 ORDEN_PAGADA` y el mensaje «La orden ya está pagada: no admite cambios en sus servicios» si la orden está en `TERMINADO` con un pago `PAGADO`.
- [X] T064 [P] [US4] Agregar en `client/lib/models/ticket.dart` los campos `formatoVersion`, `formatoAnterior`, `desgloseNoCoincide`, `nota`, `pagoAnulado` y `vigente`, y en `client/lib/services/tickets_service.dart` la forma nueva de la consulta por orden.
- [X] T065 [US4] En `client/lib/screens/ticket_screen.dart`, mostrar los chips y avisos con los tokens `warning` y `danger` de `docs/design-system.md` (contracts/ui-flutter.md), también en la versión imprimible.
- [X] T066 [US4] En `client/lib/screens/service_order_detail_screen.dart`, hacer que «Ver ticket» abra el vigente y mostrar la lista «Tickets anteriores» con folio, fecha y chip «Pago anulado».
- [X] T067 [US4] **Punto de control**: `npm test` y `flutter test` (línea base + nuevas).

---

## Fase 7: Historia 5 - Precios de refacciones visibles según el rol (Prioridad: P5)

**Objetivo**: el servidor solo envía a cada rol los precios que le corresponden (compra: ADMIN; venta: ADMIN y RECEPTIONIST; ninguno de refacción al mecánico) y ningún precio restringido sale por otras vías.

**Prueba independiente**: consultar el catálogo, el detalle de una refacción y el detalle de una orden con los tres roles y comparar las claves recibidas.

### Pruebas de la historia 5 (escribir primero; deben fallar)

- [X] T068 [P] [US5] Pruebas de contrato en `server/tests/contract/parts-by-role.test.js`:
  - en `GET /api/parts` y `GET /api/parts/:id`, `precioCompra` solo existe para ADMIN, `precioVenta` para ADMIN y RECEPTIONIST, y ninguna de las dos claves para MECHANIC (FR-024, FR-025, SC-004);
  - el mecánico sí recibe todos los campos que no son importes: `id`, `codigo`, `nombre`, `categoria`, `marca`, `stockActual`, `stockMinimo`, `stockBajo` y `activa` (FR-025, contracts/parts.md);
  - `buscar` sigue siendo por nombre o código y no expone precios (FR-036).
- [X] T069 [P] [US5] Pruebas de contrato en `server/tests/contract/mechanic-price-exposure.test.js`:
  - el mecánico recibe `403` en pagos, tickets y panel (FR-035);
  - el detalle y el listado de órdenes no traen total ni subtotal de refacciones (FR-034);
  - sí trae `servicios[].manoDeObra.precio` (FR-026);
  - el cuerpo de `TOTAL_EXCEDE_LIMITE` y de los demás errores que recibe el mecánico no contiene ninguna cifra de precio (FR-036);
  - **ninguna** respuesta armada con `toApiDetail` le entrega al mecánico `precioUnitario`, `importe` ni `aviso` de las refacciones. Se revisan detalle, diagnóstico, recomendaciones, cambio de estado, alta y baja de servicios y cualquier otra que use `toApiDetail` (FR-025, FR-034; complementa T037).
- [X] T070 [P] [US5] Extender `client/test/parts_screen_test.dart` y `client/test/part_detail_test.dart`: «Compra» solo para ADMIN, «Venta» para ADMIN y RECEPTIONIST, y ningún precio para MECHANIC; el renglón no se dibuja cuando el campo no viene.
- [X] T089 [US5] Ajustar las pruebas existentes del Sprint 3 que cambian **por diseño** con los precios por rol, si alguna espera `precioCompra` o `precioVenta` para RECEPTIONIST o MECHANIC. Revisar `server/tests/contract/parts.test.js`, `server/tests/integration/parts.test.js`, `server/tests/contract/parts-search.test.js`, `client/test/parts_screen_test.dart`, `client/test/part_detail_test.dart`, `client/test/stock_low_test.dart` y `client/test/edit_routes_navigation_test.dart`. **Regla 6 de CLAUDE.md**:
  1. **antes** de cambiar cada prueba, mostrarle a Carlos el archivo y la línea, por qué cambia (FR-024, FR-025) y el texto de antes y después;
  2. **esperar su aprobación**;
  3. registrar el cambio en `specs/005-precios-refacciones-cobro/reporte-implementacion.md`.

  Si ninguna prueba cambia, anotarlo en el reporte.

### Implementación de la historia 5

- [X] T071 [US5] En `server/services/part.service.js`, cambiar `toApi(part)` por `toApi(part, role)`, que **omite** las claves no permitidas (R-10), y pasar `req.user.role` desde `server/controllers/parts.controller.js` en el listado y el detalle.
- [X] T072 [US5] Revisar `server/middlewares/errorHandler.js` y confirmar que no registra cuerpos de petición ni de respuesta con precios (FR-036). Cambiarlo solo si los registra, y anotar el resultado en el reporte del sprint.
- [X] T073 [P] [US5] En `client/lib/screens/parts_screen.dart` y `client/lib/screens/part_detail_screen.dart`, aplicar la doble condición (rol y campo presente) para los precios.
- [X] T074 [US5] En `client/lib/screens/service_order_detail_screen.dart` (selector para agregar refacciones), que el mecánico vea los campos que no son importes (nombre, código, categoría, marca, existencia, stock mínimo, stock bajo y activa) y ningún precio (FR-025).
- [X] T075 [US5] **Punto de control**: `npm test` y `flutter test` (línea base + nuevas).

---

## Fase 8: Final (datos de ejemplo, documentación y cierre)

**Propósito**: datos de ejemplo del sprint, documentación de FR-031, evidencias y cierre.

- [X] T076 Prueba de integración de los datos de ejemplo en `server/tests/integration/seed-005.test.js` (escribir primero; debe fallar):
  - cargar dos veces el seed 005 no duplica registros;
  - existen la refacción con venta menor que compra, la orden `TERMINADO` cobrable con refacciones congeladas y su ticket versión 2, y la orden con un pago anulado, un pago nuevo y 2 tickets (FR-029);
  - los tickets del seed 005 conservan su copia (importe y contenido) después de cambiar el precio de sus refacciones en el catálogo (conjunto de referencia de SC-002).
- [X] T077 Completar `database/seeds/005_ejemplos_precios_congelados.sql`, **parte B**: idempotente con `INSERT IGNORE` e **ids fijos en un rango alto** (por ejemplo, a partir de 9001), para no chocar con datos manuales (riesgo H12). Contiene los ejemplos de T076, con las copias de ticket versión 2 en SQL con la estructura de data-model.md. Hasta que pase T076.
- [X] T078 [P] Actualizar `docs/project-context.md` (FR-031): total en centavos con precio congelado, precios por rol (D-10 y su alcance), ticket por pago con copia y versión, «formato anterior» y «pago anulado», D-04 con motivo, vencimiento de las preferencias de Mercado Pago y la limitación conocida del cambio de rol.
- [X] T079 [P] Actualizar `database/README.md`: tablas y columnas del Sprint 5, la nota de que el `005` es la primera migración que reemplaza una restricción (sin borrar datos) y el respaldo obligatorio antes de aplicarla.
- [X] T080 Redactar la propuesta de texto para la regla 4 de `CLAUDE.md` en `specs/005-precios-refacciones-cobro/reporte-implementacion.md`. El texto: «aditiva» significa no editar migraciones anteriores y no borrar tablas, columnas ni datos; se permite reemplazar una restricción si se conservan los datos y se documenta en el plan. **No** editar `CLAUDE.md` todavía.
- [X] T081 [MANUAL - Carlos] Aprobar o corregir la propuesta de T080 para la regla 4 de `CLAUDE.md`.
- [X] T082 Después de la aprobación de T081, aplicar el texto aprobado en la regla 4 de `CLAUDE.md`, sin cambiar ninguna otra regla.
- [X] T083 **Punto de control final** (FR-030, SC-007): `npm test` en `server/` 3 veces y `flutter test` en `client/` 1 vez. Guardar las salidas en `docs/evidencias/sprint 5/s5-final-npm-1.txt` a `-3.txt` y `s5-final-flutter.txt`. Reportar, por corrida, suites, pruebas, tiempo y si hubo timeouts o el aviso de worker.
- [ ] T084 **No ejecutada por decisión de Carlos (2026-11-16)**: no se hicieron los pasos de interfaz ni el cronometraje de SC-006. El flujo quedó cubierto por el recorrido por API (13/13, `docs/evidencias/sprint 5/s5-quickstart-recorrido-api.txt`) y por las pruebas de Flutter (155/155, `docs/evidencias/sprint 5/s5-final-flutter.txt`). Recorrer las secciones 4 a 6 de [quickstart.md](./quickstart.md) contra `motorix_v2` con la app corriendo y anotar el resultado de cada paso. Los pasos de interfaz que el agente no pueda ejecutar se marcan como pendientes de Carlos. **Medir el tiempo del recorrido completo de la sección 6 (pasos 1 a 9, SC-006: menos de 10 minutos). Lo cronometra Carlos** y el agente anota en el reporte el tiempo que él le indique.
- [X] T085 **Completar** `specs/005-precios-refacciones-cobro/reporte-implementacion.md`, iniciado en T080 y con los cambios de pruebas de T087 a T089: archivos cambiados, historias y requisitos cubiertos, pruebas (comando y resultado real), pendientes y riesgos (CLAUDE.md, «Cómo reportar»). Incluir una **nota** de que la aclaración 2 del Sprint 4 («precios vigentes al cobrar») y el contrato de tickets del Sprint 4 (`specs/004-pagos-tickets-dashboard/contracts/tickets.md`, un ticket por orden reconstruido al consultarlo) **quedan superados por el Sprint 5**. Los artefactos del Sprint 4 **no se editan**.
- [X] T086 [MANUAL - Carlos] Al cierre del sprint y antes de la demostración, recrear `motorix_v2` limpia con migraciones `001` a `006` y seeds `001` a `005` (plan, «Orden de aplicación en `motorix_v2`», paso 4), y comprobar que la app arranca con los datos de ejemplo.

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1 (Preparación)**: no depende de nada.
- **Fase 2 (Base)**: depende de la fase 1 y bloquea todas las historias. T015 (manual) bloquea T016 a T018, pero **no** bloquea las historias: las pruebas corren contra `motorix_v2_test`.
- **Historias (fases 3 a 7)**: dependen de T014.
- **Fase 8**: depende de las historias. T077 depende de las fases 5 y 6 (pagos y tickets por pago). T082 depende de T081. T086 va al final.

### Dependencias entre historias

- **US1 (P1)**: solo de la fase base.
- **US2 (P2)**: de la fase base. Es independiente de US1, pero se recomienda después de ella porque reutiliza el validador.
- **US3 (P3)**: de US2, porque el total con precio congelado es el que se cobra (T035).
- **US4 (P4)**: de US3, porque el candado, la anulación y el registro del pago están en `payment.service.js`.
- **US5 (P5)**: de la fase base. Toca `part.service.js` y pantallas de catálogo, así que puede ir en paralelo con US3 y US4 si las hacen personas distintas; T074 comparte archivo con T039, T053 y T066.

### Dentro de cada historia

- Pruebas primero; deben fallar antes de implementar.
- Las pruebas existentes que cambian por diseño (T087, T088 y T089) se ajustan solo con la aprobación de Carlos y antes del punto de control de su historia.
- Modelos → servicios → controladores → Flutter → punto de control.
- `server/services/service_order.service.js` y `client/lib/screens/service_order_detail_screen.dart` se tocan en varias historias: esas tareas **no** van en paralelo entre sí.

### Oportunidades de paralelismo

- Fase 2: T003, T004 y T005; luego T009, T010 y T012.
- En cada historia, las tareas de prueba marcadas [P] (archivos distintos).
- Fase 8: T078 y T079.

---

## Ejemplo de paralelismo: historia 3

```text
# Pruebas de la historia 3 (archivos distintos, a la vez):
T041 server/tests/integration/payments-concurrency.test.js
T042 server/tests/integration/payments-stale-pending.test.js
T043 server/tests/unit/mercadopago-preference.test.js
T044 server/tests/contract/tickets.test.js
T045 client/test/payment_flow_test.dart

# Después, en paralelo con el servidor:
T052 client/lib/models/payment.dart y client/lib/services/payments_service.dart
```

---

## Estrategia de implementación

### MVP primero (historia 1)

1. Fase 1 y fase 2 (incluida la migración probada en `motorix_v2_test`).
2. Fase 3 (US1): catálogo con precios validados.
3. **Detenerse y validar** con T029.

### Entrega incremental

1. Base → US1 (precios validados) → US2 (precio congelado y total) → US3 (cobro completo y concurrencia) → US4 (historial íntegro y ticket por pago) → US5 (precios por rol).
2. Cada historia cierra con su punto de control.
3. Fase 8: datos de ejemplo, documentación y cierre con las tareas de Carlos.

---

## Notas

- **[P]**: archivos distintos y sin dependencias pendientes.
- **[MANUAL - Carlos]**: T015, T055, T081 y T086. El agente se detiene y espera. Además, en T084 el cronometraje lo hace Carlos, y T087 a T089 requieren su aprobación antes de cambiar cada prueba existente.
- **Números T087 a T089**: se agregaron después del análisis (`/speckit-analyze`, hallazgo I1) con los siguientes números libres, para no cambiar los números de las demás tareas. Están ubicados dentro de su fase (US2, US4 y US5), después de las pruebas nuevas y antes de la implementación, y se ejecutan en ese lugar, no al final.
- Hacer commit solo cuando Carlos lo pida, con Conventional Commits en español.
- Las pruebas de autenticación con bloqueo (antes H-B01) deben seguir pasando; si vuelven a fallar de forma intermitente, se reporta y no se «arreglan» en silencio.
