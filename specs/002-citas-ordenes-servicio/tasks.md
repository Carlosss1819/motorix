---

description: "Lista de tareas de la funcionalidad: Gestión de citas y órdenes de servicio"
---

# Tasks: Gestión de Citas y Órdenes de Servicio

**Input**: Documentos de diseño de `/specs/002-citas-ordenes-servicio/`

**Prerequisites**: [plan.md](plan.md) (requerido), [spec.md](spec.md) (historias de
usuario), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Se incluyen tareas de prueba porque la constitución (Principio VII) exige
pruebas para toda lógica de negocio y el criterio CA‑8 del Sprint 2 pide explícitamente
pruebas de la máquina de transiciones. Se ejecutan contra `motorix_v2_test`, nunca contra
la base principal.

**Organization**: Las tareas están agrupadas por historia de usuario para permitir
implementación y pruebas independientes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias de tareas incompletas)
- **[Story]**: Historia de usuario a la que pertenece (US1…US6)
- Rutas exactas en cada descripción (convención del proyecto: `server/`, `client/`, `database/`)

## Path Conventions

- **Backend**: `server/{models,services,controllers,routes,validators}/` (ES Modules)
- **Frontend**: `client/lib/{models,services,providers,screens,widgets,utils}/` (Flutter)
- **Base de datos**: `database/{migrations,seeds,scripts}/`
- **Pruebas**: `server/tests/{unit,integration,contract}/` y `client/test/`

---

## Phase 1: Setup (Preparación compartida)

**Purpose**: dejar el terreno verificado y la trazabilidad corregida antes de escribir código

- [X] T001 Verificar que la base del Sprint 1 opera: aplicar migraciones y seeds, arrancar `cd server && npm test` y `cd client && flutter test`, siguiendo specs/002-citas-ordenes-servicio/quickstart.md
- [X] T002 [P] Corregir las referencias RN de specs/002-citas-ordenes-servicio/spec.md según el mapeo R-11 de specs/002-citas-ordenes-servicio/research.md (acción correctiva del gate I del plan)

---

## Phase 2: Foundational (Requisitos previos bloqueantes)

**Purpose**: esquema de datos y utilidades compartidas que TODAS las historias necesitan

**⚠ CRITICAL**: ninguna historia de usuario puede comenzar hasta completar esta fase

- [X] T003 Crear database/migrations/002_citas_ordenes_servicio.sql con las 6 tablas de specs/002-citas-ordenes-servicio/data-model.md: `appointments`, `service_orders`, `order_status_history`, `order_services`, `order_labor` (con `service_id` NOT NULL FK a `order_services` `ON DELETE CASCADE`), `order_parts`, más FK, índices y `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4` (no editar 001_esquema_inicial.sql)
- [X] T004 Ejecutar database/scripts/aplicar-migraciones.ps1 y comprobar que las 6 tablas quedan registradas en `schema_migrations` y que una segunda ejecución no falla (idempotencia)
- [X] T005 Crear database/seeds/002_ejemplos_citas_ordenes.sql idempotente (`INSERT IGNORE`, ids fijos) con ≥ 5 citas y ≥ 4 órdenes en estados variados, su historial de estados, servicios, mano de obra y repuestos de ejemplo, usando clientes/vehículos/usuarios ya sembrados en el Sprint 1 (FR-021, SC-006, R-12)
- [X] T006 Ejecutar database/scripts/aplicar-migraciones.ps1 -Seeds y comprobar que una segunda ejecución no duplica registros (SC-006)
- [X] T007 [P] Crear server/utils/status-constants.js con los enums de `service_orders` (`RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`, `TERMINADO`, `ENTREGADO`) y de `appointments` (`PROGRAMADA`, `RECIBIDA`, `CANCELADA`, `NO_PRESENTADA`) de data-model.md, para reutilizarlos en los validadores
- [X] T008 [P] Crear client/lib/widgets/status_chip.dart con chips de estado de cita y de orden usando los tokens de docs/design-system.md (verde completado, ámbar advertencia, rojo error/cancelada; sin valores sueltos)

**Checkpoint**: fondación lista; las historias pueden empezar en paralelo

---

## Phase 3: User Story 1 - Crear y consultar órdenes de servicio con cliente y vehículo (Priority: P1) 🎯 MVP

**Goal**: recepción registra una orden que asocia cliente + vehículo + motivo, la consulta en listado y detalle (HU1, FR‑001…FR‑004).

**Independent Test**: crear una orden con cliente y vehículo existentes → estado `RECIBIDO` y visible en listado/detalle; sin motivo → `400` y no se crea; cliente sin vehículos → sin orden huérfana.

### Tests for User Story 1

- [X] T009 [P] [US1] Prueba de contrato de `POST`/`GET /api/service-orders` en server/tests/contract/service-orders.test.js (201, listado paginado, 400 sin motivo, 404 vehículo inexistente)
- [X] T010 [P] [US1] Prueba de integración de creación y detalle contra `motorix_v2_test` en server/tests/integration/service-orders.test.js (incluye vehículo que no pertenece al cliente y kilometraje sin corrección → `400`)

### Implementation for User Story 1

- [X] T011 [P] [US1] Crear server/models/service_order.js con `createServiceOrder`, `findServiceOrderById`, `listServiceOrders` (filtros `estado`, `buscar` por placas o nombre del cliente, paginación) y `getLastMileageByVehicle` según data-model.md
- [X] T012 [P] [US1] Crear server/validators/service-order.validator.js con `zod`: `clienteId`, `vehiculoId`, `motivoVisita` (obligatorio, no vacío), `fechaIngreso` (fecha), `kilometraje` (entero ≥ 0), `mecanicoId` y `citaId` opcionales, `correccionKilometraje` opcional; mensajes en español que indiquen el dato a corregir
- [X] T013 [US1] Crear server/services/service_order.service.js con la creación de la orden: cliente y vehículo existentes y **el vehículo debe pertenecer al cliente** (RN‑01, RN‑02), motivo obligatorio, kilometraje ≥ 0 y ≥ al de la última orden del vehículo salvo `correccionKilometraje` enviado solo por `ADMIN` con motivo guardado en `mileage_correction_note` (FR‑018, R‑08), alta siempre en `RECIBIDO`, fila inicial en `order_status_history` (FR‑014, FR‑015) y actualización de `vehicles.current_mileage` si el nuevo valor es mayor
- [X] T014 [P] [US1] Crear server/controllers/service_orders.controller.js con los handlers de listado (con `elementos`/`pagina`/`paginas`/`total`), detalle y creación, devolviendo errores con `{ error: { mensaje, codigo } }` en español
- [X] T015 [US1] Crear server/routes/service_orders.routes.js: `authenticate` en todas las rutas; creación y edición con `authorize('ADMIN','RECEPTIONIST')`; `GET /` y `GET /:id` con `validate` de los esquemas del validador y `asyncHandler`
- [X] T016 [US1] Registrar `serviceOrdersRoutes` bajo `/api/service-orders` en server/routes/index.js
- [X] T017 [P] [US1] Crear client/lib/models/service_order.dart con los campos en español del contrato (incluye `servicios`, `repuestos` e `historial` vacíos por defecto)
- [X] T018 [P] [US1] Crear client/lib/services/service_orders_service.dart sobre client/lib/services/api_client.dart con `listar`, `obtener` y `crear` (query `estado`, `buscar`, `pagina`, `porPagina`)
- [X] T019 [US1] Crear client/lib/providers/service_orders_provider.dart con estados vacío/cargando/error/éxito, filtros y paginación (patrón de client/lib/providers/clients_provider.dart)
- [X] T020 [US1] Crear client/lib/screens/service_orders_screen.dart con tabla densa, filtro por estado, búsqueda por placas o nombre del cliente y paginación (FR‑003, design system)
- [X] T021 [US1] Crear client/lib/screens/service_order_form_screen.dart con selección cliente → vehículos de ese cliente, motivo de visita obligatorio, fecha de ingreso y kilometraje; si el cliente no tiene vehículos, mostrar aviso para registrar primero uno y no enviar (escenario 5 HU1)
- [X] T022 [US1] Crear client/lib/screens/service_order_detail_screen.dart mostrando cliente, teléfono, vehículo, placas, motivo, estado (chip), fecha de ingreso, kilometraje y mecánico con estados vacío/cargando/error
- [X] T023 [US1] Registrar las rutas de órdenes en client/lib/utils/app_routes.dart y las entradas **Órdenes** en client/lib/widgets/app_shell.dart solo para `ADMIN` y `RECEPTIONIST`
- [X] T024 [P] [US1] Prueba flutter test del provider y del listado de órdenes en client/test/service_orders_provider_test.dart

**Checkpoint**: US1 funcional y verificable de forma independiente

---

## Phase 4: User Story 2 - Gestionar citas de recepción (Priority: P2)

**Goal**: recepción registra, consulta, modifica, cancela y recibe citas, con aviso de conflicto de horario y detección de no presentadas (HU2, FR‑005…FR‑008).

**Independent Test**: crear una cita → `PROGRAMADA` y visible en el listado del día; duplicarla en la misma fecha/hora/vehículo → `409` con aviso y se guarda al confirmar; cancelar → `CANCELADA` y fuera del día activo; una cita vencida aparece como `NO_PRESENTADA`.

### Tests for User Story 2

- [X] T025 [P] [US2] Prueba de contrato de `/api/appointments` en server/tests/contract/appointments.test.js (201, `409` de conflicto, `200` con `confirmar: true`, `403` para `MECHANIC`)
- [X] T026 [P] [US2] Prueba de integración de citas contra `motorix_v2_test` en server/tests/integration/appointments.test.js (cancelación con motivo opcional, recepción con precarga y detección de `NO_PRESENTADA`)

### Implementation for User Story 2

- [X] T027 [P] [US2] Crear server/models/appointment.js con `createAppointment`, `findAppointmentById`, `listAppointments` (filtros `fecha`, `desde`/`hasta`, `estado`, `buscar`, paginación), `findScheduleConflict` (misma fecha, hora y vehículo en `PROGRAMADA`/`RECIBIDA`) y `markExpiredAsNotPresented` según data-model.md
- [X] T028 [P] [US2] Crear server/validators/appointment.validator.js con `zod`: `clienteId`, `vehiculoId`, `fecha`, `hora`, `motivo` obligatorios; `confirmar` booleano opcional; `motivoCancelacion` opcional de hasta 255 caracteres; mensajes en español
- [X] T029 [US2] Crear server/services/appointment.service.js: alta con validación de pertenencia vehículo‑cliente (RN‑01, RN‑02); conflicto de horario → `409` con `pendienteConfirmacion`/`confirmarReenvio` salvo `confirmar: true` (FR‑008, R‑05); `cancelar` solo desde `PROGRAMADA` con motivo opcional guardado (FR‑006); `recibir` solo desde `PROGRAMADA` devolviendo `precargaOrden` sin crear órdenes (FR‑007); marcado perezoso a `NO_PRESENTADA` al listar (R‑06)
- [X] T030 [P] [US2] Crear server/controllers/appointments.controller.js con los handlers de listado, detalle (incluye `orden` derivada o `null`), creación, edición, cancelación y recepción
- [X] T031 [US2] Crear server/routes/appointments.routes.js con `authenticate` + `authorize('ADMIN','RECEPTIONIST')` (MECHANIC → `403`), `validate` por ruta y `asyncHandler`; registrarlo bajo `/api/appointments` en server/routes/index.js
- [X] T032 [US2] Ampliar server/services/service_order.service.js para validar `citaId` al crear la orden: la cita debe existir, estar `RECIBIDA` y no usarse en otra orden (responde `409`), guardando `service_orders.appointment_id` (FR‑007)
- [X] T033 [P] [US2] Crear client/lib/models/appointment.dart con los campos del contrato
- [X] T034 [P] [US2] Crear client/lib/services/appointments_service.dart con `listar`, `obtener`, `crear`, `editar`, `cancelar` y `recibir`
- [X] T035 [US2] Crear client/lib/providers/appointments_provider.dart con filtros por fecha y estado, estados de interfaz y manejo del `409` de conflicto
- [X] T036 [US2] Crear client/lib/screens/appointments_screen.dart con listado del día, filtros, y acciones **Cancelar** y **Recibir** con confirmación (Principio VIII) y mensajes de éxito/error
- [X] T037 [US2] Crear client/lib/screens/appointment_form_screen.dart con alta y edición, y aviso de conflicto de horario que permite reenviar con confirmación
- [X] T038 [US2] Ampliar client/lib/screens/service_order_form_screen.dart para precargar cliente, vehículo y motivo desde una cita `RECIBIDA` y enviar `citaId` (FR‑007)
- [X] T039 [US2] Registrar la ruta de citas en client/lib/utils/app_routes.dart y la entrada **Citas** en client/lib/widgets/app_shell.dart solo para `ADMIN` y `RECEPTIONIST`
- [X] T040 [P] [US2] Prueba flutter test del provider de citas en client/test/appointments_provider_test.dart

**Checkpoint**: US1 y US2 funcionan de forma independiente; una cita recibida puede derivar en orden

---

## Phase 5: User Story 3 - Consultar las órdenes asignadas (Priority: P3)

**Goal**: cada mecánico ve y opera solo sus órdenes; recepción asigna o reasigna mecánicos (HU3, FR‑009, FR‑010).

**Independent Test**: con dos mecánicos y órdenes asignadas a cada uno, cada uno solo ve las suyas (también vía `curl`); asignar a una orden `TERMINADO`/`ENTREGADO` → `409`; desasignar → la orden desaparece del listado del mecánico.

### Tests for User Story 3

- [ ] T041 [P] [US3] Prueba de contrato de aislamiento del mecánico en server/tests/contract/service-orders-mechanic.test.js (`GET /api/service-orders` con token de `MECHANIC` devuelve solo las suyas; `403` al abrir una ajena)
- [ ] T042 [P] [US3] Prueba de integración de asignación en server/tests/integration/service-orders-assignment.test.js (asignar, reasignar, desasignar con `mecanicoId: null` y `409` en `TERMINADO`/`ENTREGADO`)

### Implementation for User Story 3

- [ ] T043 [US3] Ampliar server/services/service_order.service.js para que el listado con token de `MECHANIC` filtre por `mechanic_id = usuario` e excluya las órdenes sin asignar, ignorando filtros que intenten ampliar el alcance (FR‑010, RN‑15, SC‑003)
- [ ] T044 [US3] Implementar `POST /api/service-orders/:id/asignar`: validar que `mecanicoId` sea usuario `MECHANIC` activo o `null`, rechazar con `409` si la orden está `TERMINADO` o `ENTREGADO` (FR‑009), limitar a `ADMIN`/`RECEPTIONIST` y registrar el cambio, en server/services/service_order.service.js, server/controllers/service_orders.controller.js y server/validators/service-order.validator.js
- [ ] T045 [US3] Habilitar `GET /` y `GET /:id` al rol `MECHANIC` y registrar la ruta `/asignar` en server/routes/service_orders.routes.js
- [ ] T046 [P] [US3] Adaptar client/lib/screens/service_orders_screen.dart para que con rol `MECHANIC` muestre **Mis órdenes** (solo las propias, sin filtro de estado global)
- [ ] T047 [US3] Agregar el selector de mecánico (y opción para desasignar) en client/lib/screens/service_order_detail_screen.dart con confirmación y manejo de `409` mostrando el mensaje del backend
- [ ] T048 [US3] Registrar la entrada **Mis órdenes** en client/lib/widgets/app_shell.dart para `MECHANIC` y reflejar el alcance en client/lib/providers/service_orders_provider.dart
- [ ] T049 [P] [US3] Prueba flutter test del filtrado por rol en client/test/service_orders_mechanic_test.dart

**Checkpoint**: el rol mecánico queda aislado y la asignación opera sin romper US1

---

## Phase 6: User Story 4 - Registrar diagnóstico y servicios realizados (Priority: P4)

**Goal**: el mecánico registra diagnóstico (con borrador), servicios con su mano de obra, repuestos y recomendaciones en su orden (HU4, FR‑011…FR‑013, FR‑019).

**Independent Test**: sobre una orden asignada en `DIAGNOSTICO`, guardar diagnóstico, agregar un servicio con duración, un repuesto con cantidad y una recomendación → todo persiste al reabrir; en `ENTREGADO` todos los intentos de alta/baja → `409`.

### Tests for User Story 4

- [ ] T050 [P] [US4] Prueba de contrato de diagnóstico/servicios/repuestos/recomendaciones en server/tests/contract/service-order-content.test.js (201/200, `400` con datos inválidos, `409` en orden `ENTREGADO`)
- [ ] T051 [P] [US4] Prueba de integración de contenido de la orden en server/tests/integration/service-order-content.test.js (servicio y mano de obra atómicos, `403` de mecánico en orden ajena, borrador de diagnóstico)

### Implementation for User Story 4

- [ ] T052 [P] [US4] Crear server/models/order_items.js con `createServiceWithLabor` (transacción: fila en `order_services` y en `order_labor` con `service_id`), `deleteServiceById` (cascada de mano de obra), `createPart`, `deletePartById`, `listServicesByOrder` y `listPartsByOrder` según data-model.md
- [ ] T053 [US4] Ampliar server/validators/service-order.validator.js: `texto` no vacío para diagnóstico y recomendaciones, `borrador` booleano, `descripcion` no vacía, `duracionMinutos` entero > 0, `precio` decimal ≥ 0 opcional, `cantidad` entero ≥ 1 (mensajes en español)
- [ ] T054 [US4] Ampliar server/services/service_order.service.js: guardar diagnóstico con `diagnosis_draft` (FR‑011) y descarte en cliente al no guardar (FR‑019); crear servicio con su mano de obra en la misma transacción (R‑13); registrar repuestos con cantidad ≥ 1 sin consultar inventario (RN‑06, Sprint 3 fuera de alcance); guardar recomendaciones; rechazar con `409` toda alta o baja cuando el estado sea `ENTREGADO` (FR‑016); exigir a `MECHANIC` que la orden sea suya
- [ ] T055 [P] [US4] Agregar los handlers de diagnóstico, servicios (alta y `DELETE`), repuestos (alta y `DELETE`) y recomendaciones en server/controllers/service_orders.controller.js
- [ ] T056 [US4] Registrar las rutas `POST /:id/diagnostico`, `POST /:id/servicios`, `DELETE /:id/servicios/:servicioId`, `POST /:id/repuestos`, `DELETE /:id/repuestos/:repuestoId` y `POST /:id/recomendaciones` en server/routes/service_orders.routes.js con `validate` y permisos por rol
- [ ] T057 [US4] Agregar la sección de diagnóstico en client/lib/screens/service_order_detail_screen.dart con **Guardar borrador** y **Guardar y continuar**, descartando lo no guardado al salir y marcando visualmente el borrador
- [ ] T058 [US4] Agregar en client/lib/screens/service_order_detail_screen.dart el alta y la baja (con confirmación) de servicios con duración/precio y de repuestos con cantidad, ocultando las acciones en `ENTREGADO`
- [ ] T059 [US4] Agregar el bloque de recomendaciones en client/lib/screens/service_order_detail_screen.dart y su persistencia en client/lib/services/service_orders_service.dart
- [ ] T060 [P] [US4] Prueba flutter test del detalle con contenido y borrador en client/test/service_order_detail_test.dart

**Checkpoint**: la constancia técnica de la orden queda completa y probada

---

## Phase 7: User Story 5 - Cambiar el estado de la orden a lo largo del flujo (Priority: P5)

**Goal**: transiciones válidas según el mapa y el rol, con historial, fecha de entrega e inmutabilidad de `ENTREGADO` (HU5, FR‑014…FR‑016, FR‑022).

**Independent Test**: recorrer toda la secuencia `RECIBIDO → … → ENTREGADO` y comprobar historial con usuario y fecha; `RECIBIDO → ENTREGADO` → `409`; transición fuera de rol → `403`; en `ENTREGADO` no se puede cambiar ni eliminar.

### Tests for User Story 5

- [ ] T061 [P] [US5] Prueba unitaria de la máquina de estados en server/tests/unit/order-transitions.test.js: todas las transiciones válidas del mapa R‑02, varias inválidas (p. ej. `RECIBIDO → ENTREGADO`, retroceso desde `TERMINADO`) y la matriz de permisos por rol R‑03 (CA‑8)
- [ ] T062 [P] [US5] Prueba de contrato de `POST /api/service-orders/:id/estado` en server/tests/contract/service-order-status.test.js (`200`, `403` fuera de rol, `409` transición inválida con mensaje claro)

### Implementation for User Story 5

- [ ] T063 [US5] Implementar en server/services/service_order.service.js el mapa de transiciones (`RECIBIDO → DIAGNOSTICO`; `DIAGNOSTICO → EN_REPARACION|ESPERANDO_REFACCION|TERMINADO`; `EN_REPARACION → ESPERANDO_REFACCION|TERMINADO`; `ESPERANDO_REFACCION → DIAGNOSTICO|EN_REPARACION|TERMINADO`; `TERMINADO → ENTREGADO`; `ENTREGADO → ninguna`) y la matriz de permisos FR‑022: mecánico asignado o `ADMIN` en el bloque medio, `RECEPTIONIST`/`ADMIN` en ingreso y entrega, `409` con los estados permitidos cuando la transición es inválida
- [ ] T064 [US5] Registrar cada transición en `order_status_history` con `from_status`, `to_status`, `changed_by` y `changed_at` (FR‑015) y llenar `delivery_date` al pasar a `ENTREGADO`, en server/services/service_order.service.js y server/models/service_order.js
- [ ] T065 [US5] Implementar `POST /api/service-orders/:id/estado` con body `{ estado, nota }` en server/controllers/service_orders.controller.js y server/routes/service_orders.routes.js (authenticate + authorize + validate)
- [ ] T066 [US5] Agregar las acciones de estado en client/lib/screens/service_order_detail_screen.dart según rol y estado actual, con confirmación obligatoria para entregar/cerrar y mensajes de éxito/error (Principio VIII)
- [ ] T067 [US5] Mostrar el historial de cambios (estado, usuario, fecha) en client/lib/screens/service_order_detail_screen.dart y exponerlo en client/lib/services/service_orders_service.dart
- [ ] T068 [P] [US5] Prueba flutter test de las acciones de estado por rol en client/test/order_status_actions_test.dart

**Checkpoint**: el flujo completo del sprint es demostrable de extremo a extremo

---

## Phase 8: User Story 6 - Agendar citas desde el panel de recepción (Priority: P6)

**Goal**: recepción ve citas del día y órdenes abiertas en una sola vista, con estado vacío amigable (HU6).

**Independent Test**: con citas de hoy y órdenes abiertas, el panel muestra ambas listas con sus estados; sin actividades, muestra "sin actividades" y no un error.

### Tests for User Story 6

- [ ] T069 [P] [US6] Prueba flutter test del panel en client/test/reception_panel_test.dart (citas del día, órdenes abiertas y estado vacío)

### Implementation for User Story 6

- [ ] T070 [US6] Crear client/lib/screens/reception_screen.dart que compone `GET /api/appointments?fecha=<hoy>` y `GET /api/service-orders?estadoAbierta=true` (R‑09), con estados vacío ("sin actividades"), cargando y error
- [ ] T071 [US6] Registrar la ruta del panel y hacerlo Inicio por defecto de `ADMIN` y `RECEPTIONIST` en client/lib/utils/app_routes.dart y client/lib/widgets/app_shell.dart

**Checkpoint**: todas las historias del sprint funcionan de forma independiente

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: verificación transversal, documentación y cierre del sprint

- [ ] T072 [P] Ejecutar `cd server && npm run lint` y `cd server && npm test` completo, corrigiendo cualquier regresión del Sprint 1
- [ ] T073 [P] Ejecutar `cd client && flutter analyze` y `cd client && flutter test` completo
- [ ] T074 Ejecutar los escenarios V1 a V8 de specs/002-citas-ordenes-servicio/quickstart.md y registrar el resultado
- [ ] T075 [P] Verificar la idempotencia final: reaplicar database/migrations/002_citas_ordenes_servicio.sql y database/seeds/002_ejemplos_citas_ordenes.sql sin duplicados (SC‑006)
- [ ] T076 [P] Revisar seguridad: sin secretos en el código, `.env` ignorado, `.env.example` completo, permisos de todos los endpoints nuevos comprobados en backend (RN‑15)
- [ ] T077 Actualizar docs/guia-spec-kit.md con el checklist del Sprint 2 marcado y, si alguna regla cambió durante la implementación, docs/project-context.md (Principio I de la constitución)
- [ ] T078 Documentar en el reporte final de implementación los archivos modificados, historias cubiertas, pruebas realizadas, pendientes y decisiones abiertas (R‑11 de research.md incluida)
- [ ] T079 Crear commits incrementales con Conventional Commits y descripción en español, un commit por tarea o grupo lógico relacionado

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias; puede empezar de inmediato
- **Foundational (Fase 2)**: depende del Setup; **bloquea TODAS las historias** (esquema de las 6 tablas)
- **User Stories (Fase 3+)**: dependen de la Fase 2
  - Orden recomendado por prioridad: US1 → US2 → US3 → US4 → US5 → US6
  - US2 es independiente de US1 salvo la precarga de orden (T038, que amplía un archivo de US1)
  - US3, US4 y US5 extienden la orden creada en US1 (mismo archivo `service_order.service.js`: coordinar para evitar conflictos)
  - US6 depende de US2 (citas) y de US1 (órdenes abiertas)
- **Polish (Fase final)**: depende de las historias que se decidan entregar

### User Story Dependencies

- **US1 (P1)**: arranca tras la Fase 2; sin dependencias de otras historias → **MVP**
- **US2 (P2)**: arranca tras la Fase 2; T038 requiere T021 (US1)
- **US3 (P3)**: requiere US1 (órdenes existentes y detalle)
- **US4 (P4)**: requiere US1 y, idealmente, US3 (orden asignada al mecánico)
- **US5 (P5)**: requiere US1; conviene después de US4 para probar el flujo completo
- **US6 (P6)**: requiere US1 y US2

### Within Each Story

1. Pruebas primero (deben fallar antes de la implementación)
2. Models → validators → services → controllers → routes
3. Modelos Flutter → servicios → providers → pantallas → pruebas flutter
4. Historia completa antes de pasar a la siguiente prioridad

### Parallel Opportunities

- T009 + T010 (pruebas de US1) en paralelo; después T011 + T012 + T014 en paralelo
- T025 + T026 y T027 + T028 + T030 en paralelo dentro de US2
- T041 + T042, T050 + T051, T061 + T062 en paralelo (pruebas de cada historia)
- T017 + T018 (Flutter) en paralelo; T033 + T034 en paralelo
- T072 y T073 (lint/pruebas backend y frontend) en paralelo al final
- Distintas personas pueden trabajar US1 y US2 en paralelo tras la Fase 2

---

## Parallel Example: User Story 1

```text
# Lanzar juntas las pruebas de US1:
Task: "Prueba de contrato de POST/GET /api/service-orders en server/tests/contract/service-orders.test.js"
Task: "Prueba de integración de creación y detalle contra motorix_v2_test en server/tests/integration/service-orders.test.js"

# Lanzar juntas las piezas independientes de US1:
Task: "Crear server/models/service_order.js"
Task: "Crear server/validators/service-order.validator.js"
Task: "Crear client/lib/models/service_order.dart"
Task: "Crear client/lib/services/service_orders_service.dart"
```

---

## Implementation Strategy

### MVP Primero (solo User Story 1)

1. Completar Fase 1: Setup
2. Completar Fase 2: Foundational (**CRÍTICO** — bloquea todas las historias)
3. Completar Fase 3: User Story 1
4. **PARAR y VALIDAR**: probar US1 de forma independiente (escenarios V2 y V5 de quickstart.md)
5. Demostrar el alta y consulta de órdenes

### Entrega incremental

1. Setup + Foundational → foundation lista
2. US1 → probar → demo (MVP de órdenes)
3. US2 → probar → demo (citas con aviso de conflicto y derivación)
4. US3 → probar → demo (aislamiento del mecánico)
5. US4 → probar → demo (diagnóstico y servicios)
6. US5 → probar → demo (flujo completo de estados, SC‑005)
7. US6 → probar → demo (panel de recepción)
8. Polish → checklist de cierre del Sprint 2

### Estrategia de equipo paralelo

1. El equipo completa Setup + Foundational juntos
2. Cuando la fundación esté lista:
   - Desarrollador A: US1
   - Desarrollador B: US2 (evitar pisar `service_order.service.js` y `app_shell.dart` a la vez)
   - Desarrollador C: prepara las pruebas de US5 (`order-transitions.test.js`)
3. Las historias se integran y prueban de forma independiente

---

## Notes

- [P] = archivos distintos, sin dependencias de tareas incompletas
- La etiqueta [Story] vincula la tarea con su historia para trazabilidad (HU1…HU6 → FR‑001…FR‑022)
- Cada historia debe poder completarse y probarse por separado
- Verificar que las pruebas fallan antes de implementar
- Commit después de cada tarea o grupo lógico (Conventional Commits, descripción en español)
- Detenerse en cada checkpoint para validar la historia de forma independiente
- Evitar tareas vagas, conflictos en el mismo archivo y dependencias que rompan la independencia de las historias
