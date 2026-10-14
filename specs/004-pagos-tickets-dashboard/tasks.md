# Tasks: Pagos, Tickets y Dashboard

**Input**: Design documents from `/specs/004-pagos-tickets-dashboard/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Incluidos. La constitución (Principio VII) exige pruebas automáticas para
cada historia: Jest (unitarias, integración, contrato) contra `motorix_v2_test` y
`flutter test` en el frontend. Nombres de pruebas y mensajes de aserción en español.

**Organization**: Las tareas se agrupan por historia de usuario (US1…US6 = HU1…HU6
del spec) para implementarlas y probarlas de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Ejecutable en paralelo (archivos distintos, sin dependencias de tareas
  incompletas)
- **[Story]**: Historia a la que pertenece la tarea (US1…US6)
- Toda tarea indica su ruta exacta de archivo.

## Path Conventions

- Backend: `server/` (models, services, controllers, routes, validators, utils, tests)
- Frontend: `client/` (lib/models, lib/services, lib/providers, lib/screens,
  lib/widgets, lib/utils, test/)
- Base de datos: `database/migrations/`, `database/seeds/`
- Base de pruebas: `motorix_v2_test` (nunca `motorix` ni `motorix_test`)
- Sin dependencias nuevas (plan.md, Contexto Técnico): la llamada a Mercado Pago usa
  `fetch` nativo de Node LTS

---

## Phase 1: Setup (Infraestructura compartida)

**Purpose**: Confirmar la línea base antes de tocar nada

- [x] T001 Ejecutar la suite del backend (`npm test` en `server/`) y la de Flutter
  (`flutter test` en `client/`) para confirmar que la línea base del Sprint 3 pasa
  limpia antes de empezar

---

## Phase 2: Foundational (Prerrequisitos bloqueantes)

**Purpose**: Esquema, módulos puros y modelos que TODAS las historias usan

**⚠ CRITICAL**: No puede empezar ninguna historia hasta completar esta fase

- [x] T002 Escribir `database/migrations/004_pagos_tickets_dashboard.sql` (script nuevo
  e inmutable; no se editan `001`, `002` ni `003`) con: tabla `payments` (`id` INT
  AUTO_INCREMENT PK, `service_order_id` INT NOT NULL FK→`service_orders(id)` RESTRICT,
  `amount` DECIMAL(10,2) NOT NULL **CHECK (amount > 0)**, `method` ENUM('EFECTIVO',
  'TARJETA','TRANSFERENCIA','MERCADO_PAGO') NOT NULL, `status` ENUM('PENDIENTE',
  'PAGADO','RECHAZADO','CANCELADO','ANULADO') NOT NULL, `external_reference`
  VARCHAR(120) NULL, `payment_link` VARCHAR(512) NULL, `gateway_mode` VARCHAR(20) NULL,
  `annulment_reason` VARCHAR(255) NULL, `annulled_by` INT NULL FK→`users(id)` RESTRICT,
  `created_by` INT NOT NULL FK→`users(id)` RESTRICT, `created_at` DATETIME NOT NULL
  DEFAULT CURRENT_TIMESTAMP, `annulled_at` DATETIME NULL, `KEY
  idx_payments_order (service_order_id)`) y tabla `tickets` (`id` INT AUTO_INCREMENT
  PK, `service_order_id` INT NOT NULL FK→`service_orders(id)` RESTRICT, `payment_id`
  INT NOT NULL FK→`payments(id)` RESTRICT, `folio` VARCHAR(20) NOT NULL UNIQUE,
  `issued_by` INT NOT NULL FK→`users(id)` RESTRICT, `issued_at` DATETIME NOT NULL
  DEFAULT CURRENT_TIMESTAMP, **UNIQUE KEY uq_tickets_service_order (service_order_id)**);
  sin columnas de datos de tarjeta ni credenciales (RN‑14); InnoDB/utf8mb4 y comentarios
  de cabecera al estilo de las migraciones previas (data-model.md)
- [x] T003 Escribir `database/seeds/004_ejemplos_pagos_tickets.sql` idempotente (ids
  fijos + `INSERT IGNORE`): un pago `EFECTIVO` `PAGADO`, uno `TARJETA` `PAGADO`, uno
  `MERCADO_PAGO` `PENDIENTE` (con `external_reference`, `payment_link` y
  `gateway_mode='simulado'`) y uno `MERCADO_PAGO` `ANULADO` con motivo, todos ligados a
  órdenes `TERMINADO`/`ENTREGADO` de los seeds previos (RN‑13), más tickets emitidos
  para las órdenes de ejemplo ya pagadas con folios fijos `T000001‑2026`, `T000002‑2026`
  (FR‑013, D8)
- [x] T004 Aplicar migración y seed contra `motorix_v2_test` con
  `database/scripts/aplicar-migraciones.ps1 -DbName motorix_v2_test` **dos veces
  seguidas** y comprobar idempotencia (segunda corrida: `[omitida] … ya aplicada`,
  conteos idénticos)
- [x] T005 [P] Crear `server/utils/order-total.js` como módulo puro
  `calcularTotal({ manoDeObra, refacciones })`: suma `price` de cada partida de mano
  de obra tratando `NULL` como 0; suma `sale_price × quantity` de cada fila de
  `order_parts` con `part_id` (precio vigente del catálogo); las filas sin `part_id`
  se valoran como 0 con el aviso «sin precio registrado» en el desglose; devuelve
  `{ subtotalManoDeObra, subtotalRefacciones, total, desglose }` (FR‑015, D2 y D2.1)
- [x] T006 [P] Crear `server/utils/payment-transitions.js` como módulo puro (estilo
  `order-transitions.js`): máquina de estados `PENDIENTE → PAGADO | RECHAZADO |
  CANCELADO`, `PAGADO → ANULADO` y `RECHAZADO`, `CANCELADO`, `ANULADO` como estados
  finales, con `evaluatePaymentTransition(actual, destino)` que rechaza cualquier otra
  transición (D7)
- [x] T007 [P] Crear `server/models/payment.js` con el CRUD (crear, buscar por id,
  listar por orden con paginación incluyendo anulados, contar pagos `PAGADO` y
  `PENDIENTE` de una orden, actualizar estado/motivo/anulador) y la consulta de la
  orden con su pago para el guard de entrega (FR‑014)

**Checkpoint**: esquema aplicado y módulos puros + modelo de pago listos; las
historias pueden avanzar en paralelo

---

## Phase 3: User Story 1 - Registrar el pago de una orden (Priority: P1) ★ MVP

**Goal**: El recepcionista cobra una orden terminada: el pago queda guardado, ligado a
la orden y visible en su detalle; la entrega exige pago previo y la anulación (solo
administración) deja la orden libre

**Independent Test**: con una orden `TERMINADO` con su total calculado, registrar un
pago en efectivo → el pago queda `PAGADO`, ligado y visible junto al total en el
detalle; un segundo pago rechaza con «orden ya liquidada»; intentar entregar la orden
sin pago rechaza; un pago por error se anula con motivo como `admin` y la orden admite
un nuevo cobro (E1, E2 y E3 del quickstart)

### Tests for User Story 1

- [x] T008 [P] [US1] Escribir la prueba unitaria `server/tests/unit/order-total.test.js`
  para `calcularTotal`: suma de mano de obra con `NULL` tratado como 0, refacciones con
  `part_id` a precio vigente × cantidad, filas sin `part_id` valoradas en 0 con aviso
  «sin precio registrado», desglose y totales exactos con dos decimales (FR‑015, D2)
- [x] T009 [P] [US1] Escribir la prueba unitaria
  `server/tests/unit/payment-transitions.test.js` para la máquina de estados (D7):
  las tres salidas de `PENDIENTE`, `PAGADO → ANULADO`, estados finales sin salida y
  transiciones inválidas rechazadas, con mensajes de aserción en español
- [x] T010 [P] [US1] Escribir la prueba de contrato
  `server/tests/contract/payments.test.js` para `GET /api/payments/orden/:ordenId` y
  `POST /api/payments`: `200` paginado y `201`, `401` sin token, `403` rol inválido
  (`mecanico`), `404 ORDEN_NO_ENCONTRADA`, `400 VALIDACION`,
  `409 ORDEN_NO_COBRABLE`, `409 ORDEN_YA_LIQUIDADA` y `409 MONTO_NO_COINCIDE`
  (contracts/payments.md)
- [x] T011 [P] [US1] Escribir la prueba de integración
  `server/tests/integration/payments.test.js`: pago `EFECTIVO` nace `PAGADO` y ligado
  a la orden (SC‑002, pagos huérfanos = 0), segundo pago rechazado, orden no cobrable
  rechazada, el total coincide con el calculado por `order-total.js`, anulación con
  motivo solo `ADMIN` deja la orden libre y el pago anulado conservado como historial
  (FR‑016, RN‑9), anulación de pago de orden `ENTREGADO` → `409 ORDEN_ENTREGADA`, y la
  transición a `ENTREGADO` sin pago responde `409 PAGO_PENDIENTE` y con pago procede
  (FR‑014, escenarios 5 y 6)

### Implementation for User Story 1

- [x] T012 [US1] Implementar `server/services/payment.service.js` con
  `registerPayment` (valida orden `TERMINADO` → `409 ORDEN_NO_COBRABLE`; sin pago
  `PAGADO` → `409 ORDEN_YA_LIQUIDADA`; `monto` debe coincidir con
  `calcularTotal(...).total` → `409 MONTO_NO_COINCIDE`; los métodos no Mercado Pago
  nacen `PAGADO`), `listPaymentsByOrder` (paginación R‑10, incluye anulados) y
  `annulPayment` (solo `ADMIN` motivo 1–255, pago `PAGADO` y orden no `ENTREGADO`,
  guarda `annulment_reason`, `annulled_by`, `annulled_at`; FR‑001, FR‑004, FR‑015,
  FR‑016, contracts/payments.md)
- [x] T013 [US1] Crear `server/validators/payment.validator.js` con `zod`: esquema de
  registro (`ordenId` entero > 0, `monto` decimal > 0 con dos decimales, `metodo` enum
  de los cuatro valores FR‑002, `fecha` opcional `AAAA-MM-DD`) y esquema de anulación
  (`motivo` string 1–255 obligatorio), mensajes de error en español
- [x] T014 [US1] Crear `server/controllers/payments.controller.js` con
  `registerPaymentHandler`, `listByOrderHandler` y `annulPaymentHandler` sobre el
  servicio, usando `asyncHandler` y las respuestas de `utils/response.js`
- [x] T015 [US1] Crear `server/routes/payments.routes.js` con
  `GET /orden/:ordenId`, `POST /` y `POST /:id/anular` bajo `authenticate` +
  `authorize('ADMIN','RECEPTIONIST')` (la anulación se restringe además a `ADMIN` en el
  servicio, FR‑003, RN‑15) y montarla como `/api/payments` en `server/routes/index.js`
- [x] T016 [US1] Ampliar `server/services/service_order.service.js` en `changeStatus`:
  justo antes de aplicar la transición a `ENTREGADO`, si la orden no tiene un pago
  `PAGADO` responder `409 PAGO_PENDIENTE` con mensaje claro «primero debe registrarse
  el pago»; no se toca `server/utils/order-transitions.js` (FR‑014, D5)
- [x] T062 [US1] *(agregado al implementar, 2026‑10‑14)* Documentar en
  `contracts/payments.md` y crear `GET /api/payments/orden/:ordenId/total` (handler en
  `server/controllers/payments.controller.js`, método `getOrderCharge` en
  `server/services/payment.service.js`, ruta en `server/routes/payments.routes.js`):
  devuelve `{ordenId, subtotalManoDeObra, subtotalRefacciones, total, desglose}` del
  módulo `order-total.js` para que el formulario de pago muestre el desglose
  (cierra el hueco entre `data-model.md`, que dice que el desglose «se envía al
  formulario», y `contracts/payments.md`, que no definía la ruta; aprobado por el
  usuario el 2026‑10‑14)
- [x] T063 [US1] *(agregado al implementar, 2026‑10‑14)* Crear
  `client/lib/models/order_total.dart` con el formato de la nueva ruta y agregar
  `fetchOrderTotal(ordenId)` a `client/lib/services/payments_service.dart`, para que
  `payment_form_screen.dart` (T020) precargue el monto y muestre el desglose
- [x] T017 [P] [US1] Crear `client/lib/models/payment.dart` con todos los campos del
  contrato (`id`, `ordenId`, `monto`, `metodo`, `estado`, `referenciaExterna`,
  `enlacePago`, `modoPasarela`, `motivoAnulacion`, `registradoPor`, `fecha`) y
  `fromJson` tolerante a nulos
- [x] T018 [US1] Crear `client/lib/services/payments_service.dart` con
  `fetchPaymentsByOrder(ordenId, pagina)`, `registerPayment(payload)` y
  `annulPayment(id, motivo)` sobre el patrón de `http` ya usado
- [x] T019 [US1] Crear `client/lib/providers/payment_provider.dart` con estados de
  carga/vacío/error, paginación y refresco tras registrar o anular
- [x] T020 [US1] Crear `client/lib/screens/payment_form_screen.dart` con el desglose
  del total calculado (mano de obra + refacciones × cantidad), campos monto (con el
  total precargado), método y fecha, validación de «método requerido» y errores
  legibles, sobre `docs/design-system.md` (SC‑001)
- [x] T021 [US1] Crear `client/lib/widgets/payment_status_chip.dart` y ampliar
  `client/lib/screens/service_order_detail_screen.dart` con el bloque de cobro: botón
  «Registrar pago» (solo en `TERMINADO`), historial de pagos de la orden con monto,
  método, fecha y estado junto al total (escenario 3), y el botón «Anular pago»
  visible solo para `ADMIN` con confirmación obligatoria y motivo
- [x] T022 [US1] Registrar la ruta del formulario de pago en
  `client/lib/utils/app_routes.dart`
- [x] T023 [US1] Escribir `client/test/payment_flow_test.dart` (formulario con
  desglose y total, registro exitoso, error de backend «orden ya liquidada», estado
  vacío de pagos; viewport 1280×3000 y
  `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: US1 funcional y verificable por sí sola (MVP del sprint: se cobra)

---

## Phase 4: User Story 2 - Seleccionar el método de pago (Priority: P2)

**Goal**: El recepcionista elige la forma de cobro (efectivo, tarjeta, transferencia)
y cada uno queda guardado con su etiqueta legible

**Independent Test**: registrar pagos con cada método permitido → cada uno se guarda
con su etiqueta correcta; sin método → mensaje de validación y no guarda (E1 del
quickstart, pasos 5)

### Tests for User Story 2

- [ ] T024 [P] [US2] Ampliar `server/tests/contract/payments.test.js` y
  `server/tests/integration/payments.test.js` con los métodos `EFECTIVO`, `TARJETA` y
  `TRANSFERENCIA`: cada registro responde `201` con `estado: "PAGADO"` y su `metodo`
  correcto; un `metodo` fuera del enum responde `400 VALIDACION` (FR‑002, HU2‑3)

### Implementation for User Story 2

- [ ] T025 [US2] Asegurar en `server/validators/payment.validator.js` el enum
  `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`, `MERCADO_PAGO` con mensaje «método de pago
  requerido» cuando falta (HU2‑3), y en
  `client/lib/screens/payment_form_screen.dart` un selector de los cuatro métodos con
  etiqueta legible (Efectivo, Tarjeta, Transferencia, Mercado Pago) y validación de
  requerido antes de enviar (FR‑002)
- [ ] T026 [US2] Escribir `client/test/payment_methods_test.dart` (cada método se
  muestra con su etiqueta, sin método no envía y muestra el mensaje de validación)

**Checkpoint**: la forma de cobro queda registrada de forma fiel

---

## Phase 5: User Story 3 - Gestionar pagos con Mercado Pago (Priority: P3)

**Goal**: El recepcionista ofrece el cobro digital en modo sandbox: el pago nace
`PENDIENTE` con su referencia y enlace, y se confirma manualmente sin guardar ningún
dato sensible

**Independent Test**: iniciar un pago Mercado Pago en una orden `TERMINADO` → nace
`PENDIENTE` con referencia externa, enlace y modo (`sandbox` con credenciales,
`simulado` sin ellas); marcarlo aprobado → `PAGADO` y orden liquidada; rechazado o
cancelado → la orden admite otro intento; nunca hay datos de tarjeta en el sistema (E4
del quickstart)

### Tests for User Story 3

- [ ] T027 [P] [US3] Ampliar `server/tests/contract/payments.test.js` con
  `POST /api/payments/:id/confirmar`: `200` con el pago actualizado, `400 VALIDACION`
  con estado fuera del permitido, `404 PAGO_NO_ENCONTRADO`,
  `409 TRANSICION_INVALIDA` sobre pago no `PENDIENTE`, y `403` para `mecanico`
  (contracts/payments.md)
- [ ] T028 [P] [US3] Ampliar `server/tests/integration/payments.test.js` con el flujo
  Mercado Pago usando el gateway simulado: registro `MERCADO_PAGO` nace `PENDIENTE`
  con `referenciaExterna`, `enlacePago` y `modoPasarela` (SC‑004); segundo cobro
  pendiente sobre la misma orden → `409 PAGO_PENDIENTE`; confirmar a `PAGADO` liquida
  la orden; confirmar a `RECHAZADO` o `CANCELADO` libera la orden para nuevo intento;
  cancelación manual del pendiente deja el pago `CANCELADO`; ninguna respuesta ni fila
  contiene datos de tarjeta ni credenciales (RN‑14, FR‑006)

### Implementation for User Story 3

- [ ] T029 [US3] Crear `server/services/payment_gateway/index.js` (selección al
  arrancar: con `MP_ACCESS_TOKEN` usa `mercadopago.js`, sin él usa `simulado.js`), `server/services/payment_gateway/mercadopago.js`
  (`crearPreferencia(orden, monto, referencia)` vía `fetch` nativo a la API REST de
  Mercado Pago en sandbox, credenciales solo por variables de entorno, CA‑7) y
  `server/services/payment_gateway/simulado.js` (enlace de prueba e id externo
  ficticio) tras la interfaz única `{ idExterno, enlace }` (D1)
- [ ] T030 [US3] Ampliar `server/services/payment.service.js`: cuando `metodo` es
  `MERCADO_PAGO`, el pago nace `PENDIENTE` llamando `crearPreferencia`, guarda
  `external_reference`, `payment_link` y `gateway_mode`, y responde con esos campos;
  rechaza un segundo cobro pendiente (`409 PAGO_PENDIENTE`) (FR‑005, D1)
- [ ] T031 [US3] Completar `POST /api/payments/:id/confirmar`: esquema `estado` enum
  `PAGADO|RECHAZADO|CANCELADO` en `server/validators/payment.validator.js`, handler
  `confirmPaymentHandler` en `server/controllers/payments.controller.js`, método
  `confirmPayment` en `server/services/payment.service.js` que aplica
  `evaluatePaymentTransition` (solo `PENDIENTE` y `MERCADO_PAGO`,
  `409 TRANSICION_INVALIDA`) y la ruta en `server/routes/payments.routes.js` con
  `authorize('ADMIN','RECEPTIONIST')` (aclaración 3, D7)
- [ ] T032 [US3] Ampliar `client/lib/screens/payment_form_screen.dart` con la opción
  Mercado Pago y, tras registrar, mostrar el estado `PENDIENTE` con referencia externa,
  enlace de pago y modo usado (`sandbox`/`simulado`); ampliar el bloque de cobro de
  `client/lib/screens/service_order_detail_screen.dart` con las acciones «Marcar como
  aprobado», «Marcar como rechazado» y «Cancelar cobro» para pagos pendientes
- [ ] T033 [US3] Escribir `client/test/payment_gateway_test.dart` (opción Mercado
  Pago, estado pendiente con enlace y modo, acciones de confirmación; viewport
  1280×3000 y `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: el canal digital funciona en sandbox sin exponer datos sensibles

---

## Phase 6: User Story 4 - Generar el ticket de servicio (Priority: P4)

**Goal**: La orden pagada produce un ticket imprimible con folio único y todo el
detalle del comprobante, sin duplicarse

**Independent Test**: generar el ticket de una orden pagada → folio único
`T000001-2026` con todos los campos del contrato; regenerar devuelve el mismo folio;
imprimir muestra el comprobante completo; orden sin pago → «primero debe registrarse
el pago» (E5 del quickstart)

### Tests for User Story 4

- [ ] T034 [P] [US4] Escribir la prueba de contrato
  `server/tests/contract/tickets.test.js` para `POST /api/tickets`,
  `GET /api/tickets/:id` y `GET /api/tickets/orden/:ordenId`: `201` primera
  generación, `200` en reintento y en la consulta por orden (`existe`/`ticket`),
  `400 VALIDACION`, `401`, `403`, `404 ORDEN_NO_ENCONTRADA`, `404 TICKET_NO_ENCONTRADO`
  y `409 TICKET_REQUIERE_PAGO` (contracts/tickets.md)
- [ ] T035 [P] [US4] Escribir la prueba de integración
  `server/tests/integration/tickets.test.js`: folio consecutivo por año con formato
  `T000001‑2026` (SC‑003), idempotencia al regenerar (mismo folio y mismo id, HU4‑2),
  el ticket reconstruye el detalle desde la orden y su pago con los subtotales de
  `order-total.js` (NULL como 0), orden sin pago aprobado → `409 TICKET_REQUIERE_PAGO`
  (FR‑009), y ningún campo del ticket contiene datos de tarjeta (RN‑14)

### Implementation for User Story 4

- [ ] T036 [US4] Crear `server/models/ticket.js` con `findByServiceOrder`,
  `findById`, `findByFolio`, `nextFolio` (consecutivo por año sobre el máximo
  existente, formato `T000001‑2026`) y `create` (D3)
- [ ] T037 [US4] Implementar `server/services/ticket.service.js` con
  `generateTicket(ordenId, usuario)`: exige orden existente con al menos un pago
  `PAGADO` (`409 TICKET_REQUIERE_PAGO`); si ya existe ticket devuelve el existente
  (idempotente, HU4‑2); `getTicket(id)` y `getTicketByOrder(ordenId)` reconstruyen el
  comprobante (taller, cliente, vehículo con placas y kilometraje, servicios con mano
  de obra y refacciones, subtotales, total, método y estado del pago, fecha) desde la
  orden y su pago con `calcularTotal` (FR‑007, FR‑012)
- [ ] T038 [US4] Crear `server/validators/ticket.validator.js` (`ordenId` entero > 0),
  `server/controllers/tickets.controller.js` (`generateTicketHandler`,
  `getTicketHandler`, `getTicketByOrderHandler`) y `server/routes/tickets.routes.js`
  con `authenticate` + `authorize('ADMIN','RECEPTIONIST')`, montada como
  `/api/tickets` en `server/routes/index.js`
- [ ] T039 [P] [US4] Crear `client/lib/models/ticket.dart` con el formato completo del
  contrato (incluye `taller`, `cliente`, `vehiculo`, `servicios[]` con
  `refacciones[]`, subtotales, total, método y estado del pago) y `fromJson` tolerante
  a nulos
- [ ] T040 [US4] Crear `client/lib/services/tickets_service.dart` (`generateTicket`,
  `fetchTicket`, `fetchTicketByOrder`) y `client/lib/providers/ticket_provider.dart`
  con estados de carga/vacío/error
- [ ] T041 [US4] Crear `client/lib/screens/ticket_screen.dart` con formato de
  comprobante (folio, datos del taller, cliente, vehículo, placas, kilometraje,
  servicios, refacciones, mano de obra, subtotales, total, método y estado del pago,
  fecha) y botón de imprimir que delega al diálogo de impresión del navegador/sistema
  (FR‑008, CA‑5, sin PDF almacenado)
- [ ] T042 [US4] Ampliar `client/lib/screens/service_order_detail_screen.dart` con
  «Generar ticket» en órdenes pagadas y «Ver ticket» cuando ya existe (consulta
  `GET /api/tickets/orden/:ordenId`), y registrar `Routes.ticket` en
  `client/lib/utils/app_routes.dart`
- [ ] T043 [US4] Escribir `client/test/ticket_screen_test.dart` (comprobante con todos
  los campos, folio visible, estado sin pago con el mensaje «primero debe registrarse
  el pago»; viewport 1280×3000 y
  `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: el cliente recibe su comprobante imprimible

---

## Phase 7: User Story 5 - Panel de control con información general (Priority: P5)

**Goal**: El administrador abre un panel con los indicadores reales del taller en una
sola petición, visible solo para él

**Independent Test**: entrar como `admin` → el panel carga con el resumen de órdenes
por estado calculado con datos reales; forzar `GET /api/dashboard` como `recepcion` o
`mecanico` → `403 PANEL_SOLO_ADMIN` (E6 pasos 1 a 4 del quickstart)

### Tests for User Story 5

- [ ] T044 [P] [US5] Escribir la prueba de contrato
  `server/tests/contract/dashboard.test.js` + la prueba de integración
  `server/tests/integration/dashboard.test.js`: `200` para `admin` con `fecha`,
  `ordenes.total`, `ordenes.abiertas`, `ordenes.entregadas` y `ordenes.porEstado` con
  los seis estados; `401` sin token; `403 PANEL_SOLO_ADMIN` para `recepcion` y
  `mecanico` (SC‑006); `400 VALIDACION` con `?fecha=` fuera de `AAAA-MM-DD`; los
  conteos coinciden con los registros individuales sin duplicados (SC‑005, CA‑6)

### Implementation for User Story 5

- [ ] T045 [US5] Crear `server/models/dashboard.js` con la consulta de órdenes por
  estado (contadores sobre `service_orders`, sin tablas derivadas)
- [ ] T046 [US5] Implementar `server/services/dashboard.service.js` con
  `getSummary(fecha)`: bloque `ordenes` (`total`, `abiertas` = todo lo no entregado
  según `OPEN_ORDER_STATUSES`, `entregadas`, `porEstado` con los seis valores de
  `ORDER_STATUSES`) calculado con datos reales (FR‑010, D4)
- [ ] T047 [US5] Crear `server/controllers/dashboard.controller.js`
  (`getDashboardHandler`) y `server/routes/dashboard.routes.js` con
  `GET /` bajo `authenticate` + `authorize('ADMIN')` que responde
  `403 PANEL_SOLO_ADMIN` a otros roles, montada como `/api/dashboard` en
  `server/routes/index.js` (RN‑15)
- [ ] T048 [P] [US5] Crear `client/lib/models/dashboard_summary.dart` con todos los
  bloques de la respuesta (`fecha`, `ordenes`, `citas`, `mantenimientos`,
  `alertasInventario`) y `fromJson` tolerante a nulos y arreglos vacíos
- [ ] T049 [US5] Crear `client/lib/services/dashboard_service.dart` y
  `client/lib/providers/dashboard_provider.dart` con carga al abrir, acción
  «Actualizar», estados de carga/vacío/error (D4)
- [ ] T050 [US5] Crear `client/lib/screens/dashboard_screen.dart` con el bloque de
  resumen de órdenes (totales y por estado) y ampliar
  `client/lib/utils/app_shell.dart` con la sección **Panel** visible únicamente para
  `ADMIN` (doble filtro con el 403 del backend, HU5‑2)
- [ ] T051 [US5] Escribir `client/test/dashboard_screen_test.dart` (panel con datos de
  prueba, bloque vacío amigable y error de carga; viewport 1280×3000 y
  `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: el administrador supervisa el taller en un solo lugar

---

## Phase 8: User Story 6 - Órdenes, citas, mantenimientos y alertas en el dashboard (Priority: P6)

**Goal**: El panel completa el detalle operativo: citas, mantenimientos próximos y
vencidos, y alertas de stock bajo, todo con datos reales

**Independent Test**: con una orden, una cita, un mantenimiento vencido y una
refacción en stock bajo registrados, actualizar el panel → cada uno aparece en su
bloque; sin datos en un bloque → estado vacío amigable sin errores (E6 pasos 5 y 6
del quickstart)

### Tests for User Story 6

- [ ] T052 [P] [US6] Ampliar `server/tests/integration/dashboard.test.js` con los
  bloques operativos: `citas.hoy` cuenta las de la fecha de referencia con estado
  `PROGRAMADA` o `RECIBIDA` y `citas.proximas` lista máximo 5 en orden ascendente;
  `mantenimientos.proximos` y `vencidos` reutilizan `calcMaintenanceState` con su
  `objetivo`; `alertasInventario.stockBajo` y su lista (máximo 10, ordenado por
  faltante ascendente, regla `stockActual <= stockMinimo && stockMinimo > 0`); bloques
  vacíos devuelven arreglos `[]` y contadores en 0 sin errores (HU6‑4)

### Implementation for User Story 6

- [ ] T053 [US6] Ampliar `server/services/dashboard.service.js` (y
  `server/models/dashboard.js` si hace falta) con los bloques `citas` (hoy y próximas,
  máximo 5), `mantenimientos` (próximos y vencidos reutilizando el cálculo existente
  `calcMaintenanceState` y su servicio, con `objetivo` = fecha o kilometraje que
  disparó la alerta) y `alertasInventario` (regla de stock bajo del inventario, sin
  duplicar datos) (FR‑011, D4)
- [ ] T054 [US6] Ampliar `client/lib/screens/dashboard_screen.dart` con los bloques de
  citas, mantenimientos y alertas de inventario, cada uno con estados de carga, vacío
  amigable y error, sobre los tokens de `docs/design-system.md`
- [ ] T055 [US6] Ampliar `client/test/dashboard_blocks_test.dart` (bloques de citas,
  mantenimientos y alertas con datos, bloques vacíos y «Actualizar»; viewport
  1280×3000 y `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: todas las historias del sprint funcionan de forma independiente

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Mejoras transversales y cierre del sprint

- [ ] T056 [P] Verificar que `server/.env.example` documenta las variables opcionales
  de Mercado Pago (`MP_ACCESS_TOKEN`, `MP_PUBLIC_URL`) sin valores reales y que no hay
  secretos ni datos de tarjeta en el código ni en la base (CA‑7, RN‑14, FR‑006)
- [ ] T057 [P] Ejecutar `npx eslint .` en `server/` (0 errores) y `flutter analyze` en
  `client/` (0 problemas) y corregir lo que aparezca
- [ ] T058 [P] Ejecutar las suites completas: `npm test` en `server/` y `flutter test`
  en `client/` (todas en verde; Jest puede requerir `--forceExit` conocido)
- [ ] T059 Aplicar `aplicar-migraciones.ps1 -Seeds` contra `motorix_v2` (base local de
  desarrollo) **solo con la aprobación del usuario**, verificando que las migraciones
  se aplican sin tocar datos existentes
- [ ] T060 Ejecutar los escenarios E1 a E7 del [quickstart.md](quickstart.md) contra el
  backend local (puerto del `.env`, `DB_NAME=motorix_v2_test`) con los tres roles y
  registrar el resultado
- [ ] T061 Revalidar [checklists/requirements.md](checklists/requirements.md) y
  [../guia-spec-kit.md](../../docs/guia-spec-kit.md) (checklist del sprint) y redactar
  `specs/004-pagos-tickets-dashboard/reporte-implementacion.md` con alcance, decisiones,
  métricas y decisiones abiertas

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende del Setup; **bloquea todas las historias**
- **Historias (Phase 3–8)**: todas dependen de la fase Foundational
  - US1 (P1) → US2 (P2) → US3 (P3) → US4 (P4) → US5 (P5) → US6 (P6)
  - Las historias son independientes entre sí y podrían ejecutarse en paralelo si hay
    capacidad; la dependencia real de datos es: US2 y US3 extienden el formulario y el
    servicio de US1, y US4 necesita un pago `PAGADO` de US1
- **Polish (Phase 9)**: depende de las historias que se deseen completar (para el
  cierre del sprint, de las seis)

### User Story Dependencies

- **US1 (P1)**: lista tras Foundational; usa `order-total.js`, `payment-transitions.js`
  y `models/payment.js` de la fase Foundational; no depende de otras historias
- **US2 (P2)**: extiende el validador y el formulario de US1 (mismo archivo
  `payment_form_screen.dart`); se prueba por sí sola registrando cada método
- **US3 (P3)**: extiende `payment.service.js` de US1 y agrega
  `services/payment_gateway/` (nuevo, sin conflicto); usa `payment-transitions.js` de
  Foundational
- **US4 (P4)**: necesita el pago `PAGADO` de US1 y `order-total.js` de Foundational
- **US5 (P5)**: independiente de las historias de cobro (lee `service_orders` de los
  sprints anteriores); no depende de US1–US4
- **US6 (P6)**: amplía `dashboard.service.js` y la pantalla de US5

### Within Each User Story

- Pruebas primero (deben fallar antes de implementar)
- Módulos/puros y modelos del backend → servicios → validadores → rutas → frontend
  (modelo → servicio → provider → pantalla/widget) → pruebas Flutter

### Parallel Opportunities

- T005–T007 (Foundational: módulos puros y modelo de pago) entre sí
- T008–T011 (pruebas de US1) entre sí
- T017 (modelo Flutter de US1) puede correr con el backend de US1
- T027 + T028 (pruebas de US3) entre sí
- T034 + T035 (pruebas de US4) entre sí
- T039 (modelo Flutter de US4) con el backend de US4
- T044 (pruebas de US5) puede correr con el backend de US5
- T048 (modelo Flutter de US5) con el backend de US5
- T052 (pruebas de US6) con la implementación de US6 (es su prueba previa)
- Historias completas en paralelo si hay capacidad (por ejemplo US5 y US1 a la vez,
  tras Foundational, por no compartir archivos)
- T056–T058 (polish) entre sí

---

## Parallel Example: User Story 1

```bash
# Lanzar juntas las pruebas de US1 (archivos distintos):
Task: "server/tests/unit/order-total.test.js"
Task: "server/tests/unit/payment-transitions.test.js"
Task: "server/tests/contract/payments.test.js"
Task: "server/tests/integration/payments.test.js"

# Luego la implementación (secuencial en archivos compartidos):
Task: "server/services/payment.service.js"
Task: "server/validators/payment.validator.js"
Task: "server/controllers/payments.controller.js + server/routes/payments.routes.js"
Task: "server/services/service_order.service.js (guard de entrega FR-014)"

# Frontend (el modelo puede ir en paralelo con el backend):
Task: "client/lib/models/payment.dart"
Task: "client/lib/services/payments_service.dart + providers/payment_provider.dart"
Task: "client/lib/screens/payment_form_screen.dart + widgets/payment_status_chip.dart"
Task: "client/lib/screens/service_order_detail_screen.dart (bloque de cobro)"
```

---

## Implementation Strategy

### MVP Primero (solo US1)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational)
2. Completar Phase 3 (US1)
3. **PARAR y VALIDAR**: probar el cobro de forma independiente (E1, E2 y E3)
4. Demostrable: el taller cobra sus órdenes y la entrega exige el pago previo

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 → registro de pagos (MVP)
3. + US2 → métodos de cobro completos
4. + US3 → canal Mercado Pago en sandbox
5. + US4 → ticket imprimible
6. + US5 → panel de control general
7. + US6 → detalle operativo del dashboard
8. Polish → calidad, seeds locales y cierre

### Estrategia de equipo

Con una sola persona, seguir el orden por prioridad (P1 → P6). Con dos, se pueden
paralelizar el bloque de cobro (US1–US4) y el bloque del panel (US5 y US6) tras
Foundational, que debe estar terminado primero; US1 y US5 no comparten archivos.

---

## Notes

- [P] = archivos distintos, sin dependencias de tareas incompletas
- Cada historia es independientemente implementable y testeable (regla del comando)
- Las pruebas deben FALLAR antes de implementar y pasar después
- Commit tras cada tarea o grupo lógico, con Conventional Commits y mensaje en español
  (patrón del proyecto: backend `test(...)` → `feat(...)`; Flutter `feat(...)` →
  `test(...)`; docs al final)
- Cuidado con la base de datos: pruebas solo contra `motorix_v2_test`; `motorix_v2` solo
  se toca en T059 y con aprobación
- Sin datos de tarjeta ni credenciales en ningún archivo, tabla o respuesta (RN‑14,
  FR‑006); las credenciales de Mercado Pago viven solo en variables de entorno (CA‑7)
- Sin dependencias nuevas: la llamada a Mercado Pago usa `fetch` nativo (D1) y la
  impresión usa el diálogo del navegador (D3)
