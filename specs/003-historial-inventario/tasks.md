# Tasks: Historial, mantenimiento e inventario

**Input**: Design documents from `/specs/003-historial-inventario/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Incluidos. La constitución (Principio VII) exige pruebas automáticas para
cada historia: Jest (unitarias, integración, contrato) contra `motorix_v2_test` y
`flutter test` en el frontend. Nombres de pruebas y mensajes de aserción en español.

**Organization**: Las tareas se agrupan por historia de usuario (US1…US8 = HU1…HU8
del spec) para implementarlas y probarlas de forma independiente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Ejecutable en paralelo (archivos distintos, sin dependencias de tareas
  incompletas)
- **[Story]**: Historia a la que pertenece la tarea (US1…US8)
- Toda tarea indica su ruta exacta de archivo.

## Path Conventions

- Backend: `server/` (models, services, controllers, routes, validators, utils, tests)
- Frontend: `client/` (lib/models, lib/services, lib/providers, lib/screens, lib/utils,
  test/)
- Base de datos: `database/migrations/`, `database/seeds/`
- Base de pruebas: `motorix_v2_test` (nunca `motorix` ni `motorix_test`)

---

## Phase 1: Setup (Infraestructura compartida)

**Purpose**: Confirmar la línea base antes de tocar nada

- [X] T001 Ejecutar la suite del backend (`npm test` en `server/`) y la de Flutter
  (`flutter test` en `client/`) para confirmar que la línea base del Sprint 2 (207 y
  57 pruebas) pasa limpia antes de empezar

---

## Phase 2: Foundational (Prerrequisitos bloqueantes)

**Purpose**: Esquema y modelos que TODAS las historias usan

**⚠ CRITICAL**: No puede empezar ninguna historia hasta completar esta fase

- [X] T002 Escribir `database/migrations/003_historial_mantenimiento_inventario.sql`
  (script nuevo e inmutable; no se editan `001` ni `002`) con: tabla `parts`
  (`code` VARCHAR(30) NOT NULL **UNIQUE**, `name` VARCHAR(120) NOT NULL, `category`
  VARCHAR(80) NOT NULL, `brand` VARCHAR(80) NULL, `stock_current` INT NOT NULL DEFAULT
  0 CHECK ≥ 0, `stock_min` INT NOT NULL DEFAULT 0 CHECK ≥ 0, `purchase_price`/
  `sale_price` DECIMAL(10,2) NULL CHECK ≥ 0, `is_active` TINYINT(1) NOT NULL DEFAULT
  1, timestamps, `UNIQUE KEY uq_parts_code (code)`, `KEY idx_parts_name (name)`),
  tabla `maintenance` (`vehicle_id` FK→`vehicles` RESTRICT, `service_type` VARCHAR(120)
  NOT NULL, `last_service_date` DATE NULL, `last_service_mileage` INT NULL CHECK ≥ 0,
  `target_date` DATE NULL, `target_mileage` INT NULL CHECK ≥ 0, `interval_days`/
  `interval_km` INT NULL CHECK > 0, `advance_days` INT NOT NULL DEFAULT 30 CHECK > 0,
  `advance_km` INT NOT NULL DEFAULT 500 CHECK > 0, `notes` VARCHAR(255) NULL,
  `created_by` FK→`users` RESTRICT, timestamps, **UNIQUE
  KEY `uq_maintenance_vehicle_type (vehicle_id, service_type)`**, `KEY
  idx_maintenance_vehicle (vehicle_id)`), tabla `inventory_movements` (`part_id`
  FK→`parts` RESTRICT, `movement_type` ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
  `quantity` INT NOT NULL CHECK > 0, `reason` VARCHAR(255) NOT NULL para `AJUSTE`, `service_order_id`
  FK→`service_orders` RESTRICT NULL, `stock_after` INT NOT NULL CHECK ≥ 0, `created_by`
  FK→`users` RESTRICT, `created_at`, `KEY idx_movements_part (part_id, created_at)`,
  `KEY idx_movements_order (service_order_id)`), el ALTER de `order_parts` (`ADD COLUMN
  part_id INT NULL` + FK→`parts` `ON DELETE RESTRICT` + `KEY idx_order_parts_part`) y el
  índice `KEY idx_service_orders_vehicle_status (service_orders(vehicle_id, status))`
  (R‑02); todo con InnoDB/utf8mb4 y comentarios de cabecera al estilo de las migraciones
  previas
- [X] T003 Escribir `database/seeds/003_ejemplos_historial_inventario.sql` idempotente
  (ids fijos + `INSERT IGNORE`): 6 refacciones variadas (al menos una en stock bajo,
  una con `stock_min = 0`, una desactivada), movimientos `ENTRADA`/`SALIDA`/`AJUSTE`
  iniciales con `stock_after` coherente y mantenimientos en estados normal/próximo/
  vencido ligados a los vehículos seed previos (FR‑031, R‑13)
- [X] T004 Aplicar migración y seed contra `motorix_v2_test` con
  `.specify/scripts/powershell`/`database/scripts/aplicar-migraciones.ps1 -DbName motorix_v2_test`
  **dos veces seguidas** y comprobar idempotencia (segunda corrida: `[omitida] … ya
  aplicada`, conteos idénticos)
- [X] T005 [P] Crear `server/models/parts.js` con el CRUD (crear, buscar por id,
  listar con filtros, editar, desactivar) y el helper de bloqueo de fila
  `SELECT stock_current FROM parts WHERE id = ? FOR UPDATE` para las transacciones de
  stock (R‑08)
- [X] T006 [P] Crear `server/models/maintenance.js` con CRUD, búsqueda por
  vehículo/tipo (unicidad) y listado con joins a `vehicles` y `clients`
- [X] T007 [P] Crear `server/models/inventory_movement.js` con el registro de
  movimientos (tipo, cantidad, motivo, orden asociada, `stock_after`, `created_by`)
- [X] T008 [P] Crear `server/models/vehicle_history.js` con la consulta derivada:
  `service_orders` de un vehículo con `status IN ('TERMINADO','ENTREGADO')` unidas a
  `order_services`, `order_parts` (+ `parts` cuando hay `part_id`), ordenadas por
  `entry_date, id` DESC y paginadas (R‑01, R‑02)

**Checkpoint**: esquema aplicado y modelos listos; las historias pueden avanzar en paralelo

---

## Phase 3: User Story 1 - Consultar el historial de servicios del vehículo (Priority: P1) ★ MVP

**Goal**: El mecánico ve el historial derivado de las órdenes terminadas, con todo el
detalle de cada servicio, paginado y accesible desde sus órdenes

**Independent Test**: con dos órdenes terminadas y una en curso, abrir el historial del
vehículo desde una orden del mecánico: aparecen solo las terminadas, en orden
cronológico inverso, con diagnóstico, servicios, refacciones, observaciones y
recomendaciones; la lista pagina con 10 por defecto; un vehículo sin servicios muestra
el estado vacío (V1 y V2 del quickstart)

### Tests for User Story 1

- [X] T009 [P] [US1] Escribir la prueba de contrato `server/tests/contract/vehicle-history.test.js`
  para `GET /api/vehicles/:id/history`: 200 paginado, 401 sin token, 403 por rol
  inválido, 404 vehículo inexistente
- [X] T010 [P] [US1] Escribir la prueba de integración `server/tests/integration/vehicle-history.test.js`:
  excluye órdenes no terminadas (FR‑003), no duplica (SC‑002), ordena por
  `fechaServicio` DESC, incluye `refacciones[]` con `partId: null` en filas heredadas
  y estado vacío con total 0

### Implementation for User Story 1

- [X] T011 [US1] Implementar `server/services/vehicle_history.service.js`
  (`listByVehicle(vehiculoId, { pagina, porPagina })`) sobre el modelo de T008:
  paginación R‑10 (defecto 10, máximo 50, fuera de rango se corrige sin error) y
  mapeo a `{ordenId, fechaServicio, kilometraje, estadoOrden, observaciones,
  diagnostico, servicios[], refacciones[], recomendaciones}` (contracts/history.md)
- [X] T012 [US1] Implementar `server/controllers/vehicle_history.controller.js` con el
  handler `historyHandler`
- [X] T013 [US1] Agregar `GET /:id/history` en `server/routes/vehicles.routes.js` con
  `authenticate` + `authorize('ADMIN','RECEPTIONIST','MECHANIC')` y `asyncHandler`
- [X] T014 [P] [US1] Crear `client/lib/models/vehicle_history.dart` (entrada del
  historial con todos los campos y `fromJson` tolerante a nulos)
- [X] T015 [US1] Crear `client/lib/services/vehicle_history_service.dart` con
  `fetchHistory(vehiculoId, pagina)` sobre el patrón de `http` ya usado
- [X] T016 [US1] Crear `client/lib/providers/vehicle_history_provider.dart` con
  estados de carga/vacío/error y paginación
- [X] T017 [US1] Crear `client/lib/screens/vehicle_history_screen.dart` con la lista
  paginada, tarjetas por servicio y estado vacío «aún no hay servicios registrados»
- [X] T018 [US1] Registrar la ruta en `client/lib/utils/app_routes.dart` y agregar el
  botón «Ver historial del vehículo» en el detalle del vehículo
  (`client/lib/screens/vehicle_detail_screen.dart` o equivalente) y en el detalle de
  orden del mecánico (`client/lib/screens/mechanic_order_detail_screen.dart`)
- [X] T019 [US1] Escribir `client/test/vehicle_history_screen_test.dart` (widget con
  datos de prueba, estado vacío y error; viewport 1280×3000 y
  `GoogleFonts.config.allowRuntimeFetching = false`)

**Checkpoint**: US1 funcional y verificable por sí sola

---

## Phase 4: User Story 2 - Registrar el kilometraje del servicio (Priority: P2)

**Goal**: El kilometraje del servicio se registra al abrir la orden, alimenta el
historial y nunca regresa sin corrección del administrador

**Independent Test**: crear una orden con kilometraje menor a la anterior → rechazo sin
corrección y acepta con `correccionKilometraje` de `admin`; el historial muestra el
`kilometraje` de cada entrada y `vehicles.current_mileage` nunca baja (V2 del
quickstart)

### Tests for User Story 2

- [X] T020 [P] [US2] Escribir `server/tests/integration/mileage-history.test.js`:
  kilometraje heredado al historial (FR‑005), rechazo de regresión sin corrección y
  aceptación con corrección de `ADMIN` (FR‑006), `current_mileage` con el valor más
  alto (FR‑007)

### Implementation for User Story 2

- [X] T021 [US2] Verificar y, si falta, completar en
  `server/services/service_order.service.js` y `server/models/vehicle.js` la regla
  heredada (helper `UPDATE … WHERE current_mileage < ?`); este sprint NO duplica la
  lógica, solo la comprueba y la reutiliza en la renovación de mantenimientos (R‑03)
- [X] T022 [US2] Escribir `client/test/mileage_history_test.dart`: cada entrada del
  historial muestra su kilometraje y el formulario de corrección de kilometraje
  responde con el mensaje en español

**Checkpoint**: US1 y US2 verificables; el kilometraje es confiable para el preventivo

---

## Phase 5: User Story 3 - Establecer el próximo mantenimiento (Priority: P3)

**Goal**: El mecánico crea y renueva mantenimientos por vehículo y tipo de servicio con
estado calculado (normal/próximo/vencido)

**Independent Test**: registrar un mantenimiento con fecha y km objetivo y verlo en la
lista con su estado; marcar «servicio realizado» y comprobar que el mismo registro se
renueva (último servicio + objetivo desde el intervalo) sin duplicarse; intentar
duplicar → 409 (V3 del quickstart)

### Tests for User Story 3

- [X] T023 [P] [US3] Escribir `server/tests/unit/maintenance-status.test.js` para
  `server/utils/maintenance-status.js`: normal/próximo/vencido por fecha y por km,
  antelación propia (30 días/500 km por defecto), mantenimiento solo-por-km y
  solo-por-fecha, y «vence primero lo que se cumple» (FR‑011, FR‑012)
- [X] T024 [P] [US3] Escribir la prueba de contrato
  `server/tests/contract/maintenance.test.js`: `POST/PUT/GET/realizar` con 200/201,
  `400 OBJETIVO_REQUERIDO`, `409 MANTENIMIENTO_DUPLICADO`, `400
  MANTENIMIENTO_SIN_INTERVALO`, `403` para `recepcion` en escrituras
- [X] T025 [P] [US3] Escribir la prueba de integración
  `server/tests/integration/maintenance.test.js`: ciclo completo alta → estado
  calculado → «servicio realizado» renueva el mismo registro (mismo `id`,
  `last_service_*` y objetivos recalculados, estado vuelve a `NORMAL`) y no crea
  duplicados

### Implementation for User Story 3

- [X] T026 [US3] Crear `server/utils/maintenance-status.js` como módulo puro
  (`calcMaintenanceState(maintenance, hoy, kmActual)` → `NORMAL|PROXIMO|VENCIDO`,
  R‑04) al estilo de `order-transitions.js`
- [X] T027 [US3] Crear `server/validators/maintenance.validator.js` (zod): alta con
  `vehiculoId`/`tipoServicio` obligatorios, al menos uno de `fechaObjetivo`/
  `kilometrajeObjetivo`, intervalos y antelaciones enteros positivos opcionales
  (defectos 30/500)
- [X] T028 [US3] Crear `server/services/maintenance.service.js` con
  `create/update/realizar`: unicidad por vehículo+tipo (409), y `realizar` en
  **transacción** (R‑05): defectos hoy + `current_mileage`, no-regresión de km con
  corrección solo de `ADMIN`, actualización de `last_service_*`, recálculo de
  objetivos desde `interval_days`/`interval_km` o desde el body,
  `MANTENIMIENTO_SIN_INTERVALO` si no hay ninguno, y actualización de
  `vehicles.current_mileage` con el helper de valor más alto
- [X] T029 [US3] Crear `server/controllers/maintenance.controller.js` con los handlers
  de la Fase 5
- [X] T030 [US3] Crear `server/routes/maintenance.routes.js` (lectura
  `authorize('ADMIN','RECEPTIONIST','MECHANIC')`; escritura y `realizar`
  `authorize('ADMIN','MECHANIC')`) y montarla en `server/routes/index.js`
- [X] T031 [P] [US3] Crear `client/lib/models/maintenance.dart` (incluye `estado`
  calculado y campos opcionales)
- [X] T032 [US3] Crear `client/lib/services/maintenance_service.dart`
  (list/get/create/update/realizar)
- [X] T033 [US3] Crear `client/lib/providers/maintenance_provider.dart` con filtros y
  estados de carga/vacío/error
- [X] T034 [US3] Crear `client/lib/screens/maintenance_form_screen.dart`: alta y
  edición de mantenimiento (SC‑004, sin conocimientos técnicos) y botón «Servicio
  realizado» con confirmación obligatoria
- [X] T035 [US3] Escribir `client/test/maintenance_form_test.dart` (alta, validación
  de objetivo faltante y confirmación de «servicio realizado»; snacks encoladas:
  `pump(Duration(seconds: 4))` entre guardados)

**Checkpoint**: el mantenimiento preventivo funciona de punta a punta

---

## Phase 6: User Story 4 - Consultar los mantenimientos próximos (Priority: P4)

**Goal**: Recepción identifica pronto los mantenimientos próximos y vencidos con
vehículo y cliente

**Independent Test**: con mantenimientos en los tres estados, filtrar por estado y ver
vehículo, placas, cliente y objetivo; `recepcion` consulta pero no ve controles de
escritura y sus escrituras devuelven 403 (HU4, V3)

### Tests for User Story 4

- [X] T036 [P] [US4] Escribir `server/tests/contract/maintenance-list.test.js`:
  `GET /api/maintenance` con `?estado=`, `?vehiculoId=`, `?buscar=` y paginación;
  `200` para los tres roles; `403` de `POST` con token de `recepcion`

### Implementation for User Story 4

- [X] T037 [US4] Completar en `server/services/maintenance.service.js` y
  `server/models/maintenance.js` el `list` con filtros (estado calculado, vehículo,
  búsqueda por tipo/placas), joins de `vehiculo`/`placas`/`cliente` y paginación
- [X] T038 [US4] Crear `client/lib/screens/maintenance_screen.dart` con lista,
  chips/filtro de estado, vencidos destacados y estado vacío «no hay pendientes»
  (SC‑003)
- [X] T039 [US4] Ampliar `client/lib/utils/app_shell.dart` con la sección
  **Mantenimientos** visible para `ADMIN`, `RECEPTIONIST` y `MECHANIC` (R‑12, §16)
- [X] T040 [US4] Escribir `client/test/maintenance_list_test.dart` (lista con estados,
  filtro y estado vacío)

**Checkpoint**: recepción puede hacer su llamada de seguimiento en menos de 30 segundos

---

## Phase 7: User Story 5 - Registrar y consultar refacciones (Priority: P5)

**Goal**: El administrador gestiona el catálogo de refacciones con código único y
desactivación sin borrado

**Independent Test**: registrar una refacción y verla de inmediato en el inventario;
registrar otra con el mismo código → 409 con mensaje; desactivarla → no usable en
órdenes pero su historial persiste (V4 del quickstart)

### Tests for User Story 5

- [ ] T041 [P] [US5] Escribir `server/tests/unit/part.validator.test.js` (alta válida,
  código vacío o largo, stock negativo rechazado)
- [ ] T042 [P] [US5] Escribir la prueba de contrato `server/tests/contract/parts.test.js`:
  CRUD con `201/200`, `409 CODIGO_DUPLICADO`, `404 REFACCION_NO_ENCONTRADA`,
  `403` para `recepcion`/`mecanico` en escrituras
- [ ] T043 [P] [US5] Escribir la prueba de integración `server/tests/integration/parts.test.js`:
  código único, `stockInicial > 0` genera `ENTRADA` inicial con motivo "Stock inicial"
  (SC‑007), desactivación idempotente y `REFACCION_INACTIVA` al usarla en una orden

### Implementation for User Story 5

- [ ] T044 [US5] Crear `server/validators/part.validator.js` (zod): `codigo` 1–30
  caracteres, precios ≥ 0, `stockInicial`/`stockMinimo` ≥ 0
- [ ] T045 [US5] Crear `server/services/part.service.js` con `create/update/deactivate`:
  unicidad de código (409), transacción que crea el movimiento `ENTRADA` inicial cuando
  `stockInicial > 0`, edición sin tocar `stock_current` ni `codigo`, desactivar
  idempotente (R‑06, R‑08)
- [ ] T046 [US5] Crear `server/controllers/parts.controller.js`
- [ ] T047 [US5] Crear `server/routes/parts.routes.js` (escritura solo `ADMIN`,
  lectura los tres roles, R‑11) y montarla en `server/routes/index.js`
- [ ] T048 [P] [US5] Crear `client/lib/models/part.dart` (incluye `stockBajo` y
  `activa`)
- [ ] T049 [US5] Crear `client/lib/services/parts_service.dart`
- [ ] T050 [US5] Crear `client/lib/providers/parts_provider.dart` con búsqueda y
  filtros
- [ ] T051 [US5] Crear `client/lib/screens/parts_screen.dart` (listado con código,
  nombre, categoría, marca, stock actual/mínimo y precios; SC‑005)
- [ ] T052 [US5] Crear `client/lib/screens/part_form_screen.dart` (alta y edición sin
  campo de stock actual)
- [ ] T053 [US5] Ampliar `client/lib/utils/app_shell.dart` con la sección
  **Inventario** visible solo para `ADMIN` (R‑12)
- [ ] T054 [US5] Escribir `client/test/parts_screen_test.dart` (alta, duplicado con
  mensaje y desactivación)

**Checkpoint**: el catálogo existe y es gestionable por el administrador

---

## Phase 8: User Story 6 - Consultar el stock disponible (Priority: P6)

**Goal**: El administrador busca y consulta existencias y el detalle de movimientos de
cada refacción

**Independent Test**: buscar por nombre y por código → solo coincidencias; abrir el
detalle de una refacción y ver sus movimientos con tipo, cantidad, motivo y
`stockAfter` (V4 y V6)

### Tests for User Story 6

- [ ] T055 [P] [US6] Escribir `server/tests/contract/parts-search.test.js` +
  `server/tests/integration/parts-search.test.js`: búsqueda por nombre/código,
  `GET /api/parts/:id/movements` con `?tipo=` y paginación, orden descendente

### Implementation for User Story 6

- [ ] T056 [US6] Completar en `server/services/part.service.js` los filtros
  `?buscar=` (nombre o código, FR‑018) y el `GET /api/parts/:id/movements` con paginación
  (FR‑030), más el detalle de refacción
- [ ] T057 [US6] Crear `client/lib/screens/part_detail_screen.dart` con los datos de
  la refacción y su historial de movimientos (tabla con tipo, cantidad, motivo,
  orden, stock resultante y fecha)
- [ ] T058 [US6] Escribir `client/test/part_detail_test.dart` (detalle y lista de
  movimientos)

**Checkpoint**: el inventario es auditable movimiento a movimiento

---

## Phase 9: User Story 7 - Agregar refacciones utilizadas a una orden (Priority: P7)

**Goal**: El uso de refacciones en órdenes sale del catálogo, descuenta stock en
transacción y deja el movimiento de salida; el retiro repone

**Independent Test**: con stock 5, agregar cantidad 2 a una orden abierta → stock 3 y
movimiento `SALIDA` con la orden; intentar cantidad 6 → 409 sin tocar stock; retirar →
stock 5 y movimiento `ENTRADA` de reposición; en orden cerrada → 409 (V5 del
quickstart)

### Tests for User Story 7

- [ ] T059 [P] [US7] Escribir `server/tests/unit/order-parts-stock.test.js` para las
  reglas puras de stock (cálculo de `stock_after`, rechazo de cantidad ≤ 0)
- [ ] T060 [P] [US7] Escribir la prueba de contrato
  `server/tests/contract/order-parts.test.js` para
  `POST/DELETE /api/service-orders/:id/refacciones` **y sus alias heredados**
  `/repuestos` (misma respuesta, R‑07): `201/200`, `409 STOCK_INSUFICIENTE`,
  `409 REFACCION_INACTIVA`, `404 REFACCION_NO_ENCONTRADA`, `403` de `mecanico` en
  orden ajena
- [ ] T061 [P] [US7] Escribir la prueba de integración
  `server/tests/integration/order-parts-stock.test.js`: salida con transacción,
  reposición al retirar con motivo "Reposición por retiro de la orden #<id>",
  fila heredada sin `part_id` (retiro sin movimiento), orden cerrada → 409 y el caso
  límite de stock insuficiente concurrente (dos peticiones, nunca stock negativo,
  RN‑8)

### Implementation for User Story 7

- [ ] T062 [US7] Reescribir `addPart`/`removePart` en
  `server/services/service_order.service.js`: alta exige `partId` de refacción activa
  (FR‑023), `cantidad` ≥ 1, bloqueo `FOR UPDATE` + validación de stock + `ROLLBACK`
  con `STOCK_INSUFICIENTE` (R‑08), inserción de la fila con `description` copiado del
  catálogo y movimiento `SALIDA` con la orden en la misma transacción (FR‑024, RN‑7);
  `removePart` repone stock con `ENTRADA` de reposición (FR‑026, R‑09) o solo elimina
  la fila heredada; ambos con el guard `assertOrderOpenForContent`
- [ ] T063 [US7] Ampliar `server/routes/service_orders.routes.js`: rutas
  `POST/DELETE /:id/refacciones[/:refaccionId]` con
  `authorize('ADMIN','RECEPTIONIST','MECHANIC')` (FR‑027) y sus alias
  `/:id/repuestos[/:repuestoId]` apuntando al mismo handler (R‑07)
- [ ] T064 [US7] Actualizar el detalle de orden en Flutter
  (`client/lib/screens/mechanic_order_detail_screen.dart` y el de recepción si
  aplica): selector de refacción del catálogo con cantidad y stock visible en vez de
  texto libre, y retiro con confirmación obligatoria
- [ ] T065 [US7] Escribir `client/test/order_parts_test.dart` (agregar, error de stock
  y retiro con confirmación)

**Checkpoint**: el inventario y las órdenes quedan conectados (RN‑6, RN‑7)

---

## Phase 10: User Story 8 - Visualizar alertas de stock bajo (Priority: P8)

**Goal**: Las refacciones en stock bajo se marcan de forma inmediata y filtrable

**Independent Test**: dejar una refacción con `stock_actual <= stock_minimo` → aparece
marcada al abrir el inventario; una con `stock_min = 0` nunca se marca (V4)

### Tests for User Story 8

- [ ] T066 [P] [US8] Escribir `server/tests/contract/stock-low.test.js` +
  `server/tests/integration/stock-low.test.js`: campo `stockBajo` calculado
  (`stock_actual <= stock_minimo && stock_minimo > 0`, FR‑020), `?stockBajo=true` y el
  caso `stock_min = 0` sin alerta

### Implementation for User Story 8

- [ ] T067 [US8] Agregar en `server/services/part.service.js` el cálculo de
  `stockBajo` en el listado y el filtro `?stockBajo=true` (R‑10)
- [ ] T068 [US8] Ampliar `client/lib/screens/parts_screen.dart` con el semáforo de
  `docs/design-system.md` (chip/ícono de stock bajo) y el filtro de alertas (SC‑008)
- [ ] T069 [US8] Escribir `client/test/stock_low_test.dart` (marcado, filtro y
  `stock_min = 0` sin alerta)

**Checkpoint**: todas las historias del sprint funcionan de forma independiente

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Mejoras transversales y cierre del sprint

- [ ] T070 [P] Unificar la terminología «repuesto» → «refacción» en la UI heredada del
  Sprint 2 (`client/lib/screens/*order*`, labels y tooltips) y en comentarios de
  `server/routes/service_orders.routes.js`, sin tocar los identificadores ni los alias
  de ruta (clarificación 3)
- [ ] T071 [P] Ejecutar `npx eslint .` en `server/` (0 errores) y `flutter analyze` en
  `client/` (0 problemas) y corregir lo que aparezca
- [ ] T072 [P] Ejecutar las suites completas: `npm test` en `server/` y `flutter test`
  en `client/` (todas en verde; Jest puede requerir `--forceExit` conocido)
- [ ] T073 Aplicar `aplicar-migraciones.ps1 -Seeds` contra `motorix_v2` (base local de
  desarrollo) **solo con la aprobación del usuario**, verificando que las migraciones
  se aplican sin tocar datos existentes
- [ ] T074 Ejecutar los escenarios V1 a V7 del [quickstart.md](quickstart.md) contra el
  backend local (puerto del `.env`, `DB_NAME=motorix_v2_test`) con los tres roles y
  registrar el resultado
- [ ] T075 Revalidar [checklists/requirements.md](checklists/requirements.md) y
  [../guia-spec-kit.md](../../docs/guia-spec-kit.md) (checklist del sprint) y redactar
  `specs/003-historial-inventario/reporte-implementacion.md` con alcance, decisiones,
  métricas y decisiones abiertas

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende del Setup; **bloquea todas las historias**
- **Historias (Phase 3–10)**: todas dependen de la fase Foundational
  - US1 (P1) → US2 (P2) → US3 (P3) → US4 (P4) → US5 (P5) → US6 (P6) → US7 (P7) → US8 (P8)
  - Las historias son independientes entre sí y podrían ejecutarse en paralelo si hay
    capacidad; la dependencia real de datos es: US7/US8 necesitan el catálogo de US5
    (y US6 su detalle), y US4 usa el servicio de US3
- **Polish (Phase 11)**: depende de las historias que se deseen completar (para el
  cierre del sprint, de las ocho)

### User Story Dependencies

- **US1 (P1)**: lista tras Foundational; no depende de otras historias
- **US2 (P2)**: hereda la regla del Sprint 2; se apoya en US1 solo para mostrar el km
  en el historial
- **US3 (P3)**: independiente (usa `maintenance` de Foundational)
- **US4 (P4)**: usa `maintenance.service.js` de US3 (mismo servicio, filtros y
  pantalla)
- **US5 (P5)**: independiente (usa `parts` de Foundational)
- **US6 (P6)**: usa `part.service.js` de US5 (búsqueda, detalle, movimientos)
- **US7 (P7)**: usa `parts` (Foundational/US5) y la orden del Sprint 2 (guard ya
  existente)
- **US8 (P8)**: usa `part.service.js` de US5 y su pantalla

### Within Each User Story

- Pruebas primero (deben fallar antes de implementar)
- Módulos/modelos del backend → servicios → rutas → frontend (modelo → servicio →
  provider → pantalla) → pruebas Flutter

### Parallel Opportunities

- T005–T008 (modelos Foundational) entre sí
- T009 + T010 (pruebas de US1) entre sí
- T014 (modelo Flutter de US1) puede correr con el backend de US1
- T023–T025 (pruebas de US3) entre sí
- T031 (modelo Flutter de US3) con el backend de US3
- T036 / T041–T043 / T055 / T059–T061 / T066 (pruebas por historia) entre sí
- Historias completas en paralelo si hay capacidad (por ejemplo US5 y US3 a la vez,
  tras Foundational)
- T070–T073 (polish) entre sí

---

## Parallel Example: User Story 7

```bash
# Lanzar juntas las pruebas de US7 (archivos distintos):
Task: "server/tests/unit/order-parts-stock.test.js"
Task: "server/tests/contract/order-parts.test.js"
Task: "server/tests/integration/order-parts-stock.test.js"

# Luego la implementación (secuencial en archivos compartidos):
Task: "server/services/service_order.service.js (addPart/removePart v2)"
Task: "server/routes/service_orders.routes.js (rutas y alias)"
Task: "client/lib/screens/*order*.dart (selector de catálogo)"
```

---

## Implementation Strategy

### MVP Primero (solo US1)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational)
2. Completar Phase 3 (US1)
3. **PARAR y VALIDAR**: probar el historial de forma independiente (V1 y V2)
4. Demostrable: el mecánico consulta el historial completo del vehículo

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 → historial (MVP)
3. + US2 → kilometraje confiable
4. + US3 y US4 → mantenimiento preventivo completo
5. + US5 y US6 → catálogo y stock auditables
6. + US7 → inventario ligado a órdenes
7. + US8 → alertas de stock bajo
8. Polish → terminología, calidad y cierre

### Estrategia de equipo

Con una sola persona, seguir el orden por prioridad (P1 → P8). Con dos, se pueden
paralelizar el bloque mantenimiento (US3/US4) y el bloque inventario (US5–US8) tras
Foundational, que debe estar terminado primero.

---

## Notes

- [P] = archivos distintos, sin dependencias de tareas incompletas
- Cada historia es independientemente implementable y testeable (regla del comando)
- Las pruebas deben FALLAR antes de implementar y pasar después
- Commit tras cada tarea o grupo lógico, con Conventional Commits y mensaje en español
  (patrón del proyecto: backend `test(...)` → `feat(...)`; Flutter `feat(...)` →
  `test(...)`; docs al final)
- Cuidado con la base de datos: pruebas solo contra `motorix_v2_test`; `motorix_v2` solo
  se toca en T073 y con aprobación
