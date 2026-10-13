# Reporte final de implementación — Sprint 2 (citas y órdenes de servicio)

**Feature**: `002-citas-ordenes-servicio` · **Fecha**: 2026-10-12 · **Estado**: completado
(US1–US6 + Polish, tareas T001–T079).

## 1. Historias cubiertas

| Historia | Alcance entregado | Tareas |
|----------|-------------------|--------|
| US1 — Crear y consultar órdenes de servicio con cliente y vehículo | Migración y seeds del sprint, alta/consulta/edición de órdenes, validación de kilometraje de entrada (R‑04), validación de la cita de origen | T001–T024 |
| US2 — Gestionar citas de recepción | API de citas (alta, listado con filtros, edición, cancelación, recibir), conflicto de horario con reenvío confirmado, pantallas y provider en Flutter | T025–T040 |
| US3 — Consultar las órdenes asignadas | Alcance «Mis órdenes» del mecánico (FR‑010), asignación de mecánico, endpoint de mecánicos activos, pantallas y permisos | T041–T049 |
| US4 — Registrar diagnóstico y servicios realizados | Diagnóstico borrador/definitivo (FR‑011/FR‑019), servicios con mano de obra transaccional (R‑13), repuestos (RN‑06), recomendaciones, guardia `assertOrderOpenForContent` (404/403/409) | T050–T060 |
| US5 — Cambiar el estado de la orden a lo largo del flujo | Máquina de estados como módulo puro (`server/utils/order-transitions.js`, mapa R‑02), `POST /:id/estado` con nota, historial y `fechaEntrega`, matriz de permisos R‑03, acciones e historial en la ficha | T061–T068 |
| US6 — Agendar citas desde el panel de recepción | `ReceptionScreen` con «Citas de hoy» y «Órdenes abiertas», rutas `Routes.reception` e Inicio por rol, sin mutar filtros de los providers | T069–T071 |
| Polish | Verificación transversal, validación de escenarios, idempotencia, seguridad, documentación y cierre | T072–T079 |

## 2. Archivos modificados

### Base de datos
- `database/migrations/002_citas_ordenes_servicio.sql` — 6 tablas nuevas (`appointments`, `service_orders`, `order_status_history`, `order_services`, `order_labor`, `order_parts`).
- `database/seeds/002_ejemplos_citas_ordenes.sql` — datos de ejemplo con `INSERT IGNORE` (R‑12).
- `chore` de aislamiento: bases `motorix_v2` (producción local) y `motorix_v2_test` (pruebas).

### Backend (`server/`)
- **Controladores**: `controllers/appointments.controller.js`, `controllers/service_orders.controller.js`, `controllers/users.controller.js`.
- **Modelos**: `models/appointment.js`, `models/service_order.js`, `models/order_items.js`, `models/user.js`, `models/vehicle.js`.
- **Rutas**: `routes/appointments.routes.js`, `routes/service_orders.routes.js`, `routes/users.routes.js`, `routes/index.js`.
- **Servicios**: `services/appointment.service.js`, `services/service_order.service.js`, `services/user.service.js`.
- **Validadores**: `validators/appointment.validator.js`, `validators/service-order.validator.js`.
- **Utilidades y medios**: `utils/order-transitions.js`, `utils/errors.js`, `utils/response.js`, `utils/status-constants.js`, `middlewares/errorHandler.js`.
- **Pruebas**: `tests/contract/appointments.test.js`, `tests/contract/service-orders*.test.js`, `tests/contract/service-order-content.test.js`, `tests/contract/service-order-status.test.js`, `tests/integration/appointments.test.js`, `tests/integration/service-orders-assignment.test.js`, `tests/integration/service-order-content.test.js`, `tests/unit/order-transitions.test.js`.

### Flutter (`client/`)
- **Modelos**: `models/appointment.dart`, `models/service_order.dart`.
- **Servicios**: `services/appointments_service.dart`, `services/service_orders_service.dart`, `services/api_client.dart` (método `delete`).
- **Providers**: `providers/appointments_provider.dart`, `providers/service_orders_provider.dart`, `providers/shell_provider.dart`.
- **Pantallas**: `screens/appointments_screen.dart`, `screens/appointment_form_screen.dart`, `screens/service_orders_screen.dart`, `screens/service_order_form_screen.dart`, `screens/service_order_detail_screen.dart`, `screens/reception_screen.dart`.
- **Widgets y utilidades**: `widgets/app_shell.dart`, `widgets/status_chip.dart`, `utils/app_routes.dart`, `utils/app_theme.dart`, `utils/formatters.dart`, `utils/parsing.dart`, `main.dart`.
- **Pruebas**: `test/service_orders_provider_test.dart`, `test/appointments_provider_test.dart`, `test/service_orders_mechanic_test.dart`, `test/order_status_actions_test.dart`, `test/service_order_detail_test.dart`, `test/reception_panel_test.dart`.

### Especificación y documentación
- `specs/002-citas-ordenes-servicio/`: `spec.md`, `plan.md`, `tasks.md`, `research.md`, `quickstart.md`, `data-model.md`, `contracts/` (appointments, service-orders, mechanics, README), `checklists/requirements.md`.
- `docs/guia-spec-kit.md` — checklist del Sprint 2 marcado (T077).
- `docs/project-context.md` — revisado bajo Principio I: ninguna regla del §13 cambió durante el sprint; sin cambios.

## 3. Pruebas y validaciones realizadas

### Automatizadas
| Verificación | Resultado |
|--------------|-----------|
| `server`: `npm run lint` (ESLint) | 0 problemas |
| `server`: `npm test` (Jest) | 24 suites, **207 pruebas PASS** |
| `client`: `flutter analyze` | 0 incidencias |
| `client`: `flutter test` | **57 pruebas PASS** |

> Nota: Jest termina con el aviso conocido «A worker process has failed to exit
> gracefully» / `--forceExit` (exit 1 intermitente **sin fallos reales**: el
> resumen reporta 207/207).

### Escenarios V1–V8 del quickstart (T074)
Ejecutados con el backend local apuntando a `motorix_v2_test` (puerto 3999), 40
verificaciones HTTP con códigos reales:

| Escenario | Verificaciones | Resultado |
|-----------|----------------|-----------|
| V1 — flujo demostrable completo (cliente → vehículo → cita recibida → orden → asignación → diagnóstico/servicios/repuestos → estados → entrega con `fechaEntrega` e historial) | 17/17 | PASS |
| V2 — sin órdenes huérfanas (vehículo de otro cliente → 400) | 1/1 | PASS |
| V3 — aislamiento del mecánico (lista propia; orden ajena → 403) | 2/2 | PASS |
| V4 — transiciones válidas e inválidas (409, 403, recorrido completo 200) | 4/4 | PASS |
| V5 — kilometraje de entrada (60000 → 201; regresivo → 400; ADMIN con corrección → 201) | 3/3 | PASS |
| V6 — citas: conflicto 409 → reenvío `confirmar: true` 201; cancelación `CANCELADA`; vencida `NO_PRESENTADA` | 6/6 | PASS |
| V7 — panel de recepción (ruta de datos: citas del día, `estadoAbierta=true`, día vacío sin error) | 3/3 | PASS |
| V8 — orden `ENTREGADA` inmutable (PUT/servicios/repuestos/diagnóstico → 409) | 4/4 | PASS |
| **Total** | **40/40** | **PASS** |

### Idempotencia de migraciones y seeds (T075, SC‑006)
Reaplicación doble de `002_citas_ordenes_servicio.sql` + `002_ejemplos_citas_ordenes.sql`
con `aplicar-migraciones.ps1 -DbName motorix_v2_test -Seeds`:
- Corrida 1: migra y registra; corrida 2: `[omitida] … ya aplicada` para ambas.
- Conteos idénticos antes y después de las dos corridas (sin duplicados):
  `clients=295 vehicles=183 appointments=165 orders=294 history=357 services=26 labor=26 parts=12`.
- `schema_migrations`: 2 registros, 2 nombres únicos.

### Seguridad (T076, RN‑15)
- Sin secretos reales en el código: la contraseña de MySQL no aparece en archivos versionados; solo están las cuentas de semilla local documentadas (`README`, seeds, docs de desarrollo).
- `server/.env` ignorado por git y no rastreado; `server/.env.example` completo (10/10 claves usadas por `config/env.js`).
- Permisos de endpoints nuevos verificados en `routes/`:
  - Citas: `authenticate + authorize('ADMIN', 'RECEPTIONIST')` (MECHANIC → 403, FR‑020).
  - Órdenes: lectura ADMIN/RECEPTIONIST/MECHANIC con alcance acotado en el servicio; alta/edición/asignación ADMIN/RECEPTIONIST; contenido US4 ADMIN/MECHANIC con ownership (403 ajena); estados los 3 roles con matriz R‑03 en la capa de servicio.

## 4. Decisiones de implementación relevantes
- **US4**: los 6 endpoints de contenido exigen `ADMIN`+`MECHANIC`; guard común `assertOrderOpenForContent` (404 `ORDEN_NO_ENCONTRADA` → 403 `ORDEN_AJENA` → 409 `ORDEN_ENTREGADA`); `order_labor.description` se rellena con la descripción del servicio; listas de ítems movidas a `models/order_items.js`.
- **US5**: máquina de estados en módulo puro (testeable sin BD); orden de validación 404 → 409 (`TRANSICION_INVALIDA`) → 403 (`ROL_NO_AUTORIZADO`/`ORDEN_AJENA`); bloque medio = mecánico asignado o ADMIN; entrega = RECEPTIONIST/ADMIN; `deliveryDate` con `toDbDateTime()`.
- **US6**: el panel no muta filtros de providers compartidos — métodos delegados `AppointmentsProvider.listDay(fecha)` y `ServiceOrdersProvider.listOpen()` (servicio `listOpen` con `estadoAbierta=true`, sin cambiar la firma de `list`); `Routes.home` resuelve `ReceptionScreen` para ADMIN/RECEPTIONIST y `HomeScreen` para mecánico.
- **Contrato**: `GET /service-orders?estadoAbierta=true` (R‑09) solo acepta `true`/`false`.

## 5. Pendientes
- **Sprint 3** (`specs/003-historial-inventario`): falta ejecutar `/speckit.clarify` (acordado al cerrar este sprint; spec y checklist ya creados).
- El guion auxiliar que ejecutó V1–V8 vivió fuera del repositorio (temporal); opcional incorporarlo a `database/scripts/` o al quickstart para repetir la validación.
- `docs/project-context.md`: revisado (Principio I); sin cambios porque ninguna regla del §13 se modificó.

## 6. Decisiones abiertas
1. **R‑11 — trazabilidad de referencias RN** (`research.md`, «⚠ conflicto abierto»): el mapeo se aplicó al texto de `spec.md` en T002; **no** se renumeró `docs/project-context.md` §13 (rompería la trazabilidad de los sprints entregados). `research.md` conserva la marca ⚠ como registro. Pendiente de revisión: retirar la advertencia cuando se dé por cerrado el conflicto.
2. **Zona horaria**: el servidor MySQL devolvió `fechaRegistro = 2026-10-13` mientras la fecha local era 2026-10-12; el panel calcula «hoy» en el cliente (`hoyIso()`) y las fechas de la BD usan la zona del servidor. Conviene fijar una zona horaria única antes de un despliegue real.
3. **Salida de Jest**: `--forceExit` termina con código 1 intermitente por el aviso de «worker process»; no hay fallos de pruebas, pero convendría revisar los timers abiertos en `sessionStore`/middlewares.
