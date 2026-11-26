# Tareas: Reportes y configuración del taller

**Entrada**: documentos de diseño en `specs/007-reportes-configuracion/`
**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Pruebas**: sí (constitución, principio VII, y regla 6 de `CLAUDE.md`: pruebas primero). En cada historia, las pruebas se escriben antes que el código y deben fallar primero.

**Organización**: primero la **Entrega A** (Fases 1 a 9: fundamentos, US1, US2, US3, US8, US9, US10 y cierre de A) y después la **Entrega B** (Fases 10 a 15: US4 a US7 y cierre de B).

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes).
- **[Historia]**: US1, US2, ... según `spec.md`.

---

# ENTREGA A — Configuración, catálogo, ticket, términos y seguridad

## Fase 1: Preparación

- [X] T001 Correr la línea base: `npm test` en `server/` (esperado 79 suites / 649 pruebas) y `flutter test` en `client/` (186); guardar la salida en `docs/evidencias/sprint 7/s7-inicial-npm-test.txt` y `docs/evidencias/sprint 7/s7-inicial-flutter-test.txt`
- [X] T002 Agregar la dependencia `helmet` en `server/package.json` (`npm install helmet`), con la justificación del plan (Registro de complejidad)

---

## Fase 2: Fundamentos (bloquean todas las historias de la Entrega A)

- [X] T003 Crear `database/migrations/008_configuracion_terminos_bitacora.sql` (solo DDL, aditiva) según `data-model.md`: tablas `settings` (`setting_key VARCHAR(60)` PK, `setting_value VARCHAR(255) NOT NULL`, `updated_by INT NULL` FK users, `updated_at`), `service_types` (`name VARCHAR(120) NOT NULL` UNIQUE, `interval_days INT NULL` 1–3650, `interval_km INT NULL` 1–500000, `CHECK` al menos un intervalo, `is_active`), `terms_versions` (`version VARCHAR(20)` UNIQUE, `published_at`, `terms_text TEXT`, `privacy_text TEXT`, `is_current`), `terms_acceptances` (`UNIQUE (user_id, terms_version_id)`), `audit_log` (`BIGINT` PK, `user_id INT NULL` FK SET NULL, `action VARCHAR(40) NOT NULL`, `entity_type VARCHAR(40) NULL`, `entity_id INT NULL`, `detail VARCHAR(255) NULL`, índices por fecha, usuario y acción) y columna `order_services.service_type_id INT NULL` con FK RESTRICT e índice
- [X] T004 Crear `database/seeds/007_ejemplos_configuracion_terminos.sql` (idempotente, ids 70001–70099): 5 filas de `settings` con los valores de respaldo, 5 `service_types` (70001–70005, `data-model.md`) y `terms_versions` 70001 versión `1.0` vigente con términos y aviso de privacidad en español (elementos mínimos LFPDPPP, responsable ficticio "Taller Motorix", nota visible de "plantilla académica")
- [X] T005 [P] Prueba de integración del esquema y del seed en `server/tests/integration/migration-008-seed-007.test.js`: tablas y columna existen, el seed es idempotente (correrlo dos veces no duplica) y hay exactamente una versión vigente
- [X] T006 [P] Prueba unitaria de la bitácora en `server/tests/unit/audit.test.js`: `sanitizeDetail` recorta a 255 y `record` no lanza si falla la inserción
- [X] T007 Crear `server/models/audit_log.js` (insertar y listar con filtros parametrizados y paginación) y `server/services/audit.service.js` (`AUDIT_ACTIONS`, `record`, `list`) tolerante a fallos (research R-06)
- [X] T008 Actualizar `server/tests/helpers/api.js` (`loginAs` acepta la versión vigente si `terminosPendientes`) y `server/tests/helpers/global-setup.js` (registra en `motorix_v2_test` la aceptación de la versión vigente para todos los usuarios existentes) — Clarifications, FR-020

**Punto de control**: la suite completa sigue en verde con la migración 008 y el seed 007 aplicados a `motorix_v2_test`.

---

## Fase 3: US1 — Datos del taller editables (P1)

**Objetivo**: el administrador edita nombre, dirección y teléfono; los tickets nuevos los usan.
**Prueba independiente**: cambiar el nombre, emitir un ticket nuevo con el nombre nuevo; el ticket anterior conserva el suyo.

### Pruebas de US1

- [X] T009 [P] [US1] Prueba unitaria de `resolveSettings` (respaldo por clave faltante) en `server/tests/unit/settings.test.js`
- [X] T010 [P] [US1] Prueba de contrato en `server/tests/contract/settings.test.js`: `GET`/`PUT /api/settings` (formato, validación 400 con límites "texto 1–120 / 1–200 / 1–30", 403 para RECEPTIONIST y MECHANIC, bitácora `CONFIG_ACTUALIZADA`), restaurando los valores al final
- [X] T011 [P] [US1] Prueba de integración en `server/tests/integration/tickets-shop-settings.test.js`: un ticket emitido después de cambiar el nombre lo muestra y un ticket anterior conserva el suyo

### Implementación de US1

- [X] T012 [US1] Crear `server/utils/settings-defaults.js` (respaldo y `resolveSettings`) y `server/models/settings.js` (leer todas, guardar con `ON DUPLICATE KEY UPDATE`)
- [X] T013 [US1] Crear `server/validators/settings.validator.js`, `server/services/settings.service.js` (obtener y actualizar, con bitácora), `server/controllers/settings.controller.js` y `server/routes/settings.routes.js` (solo ADMIN); montar en `server/routes/index.js`
- [X] T014 [US1] En `server/services/ticket.service.js` tomar `taller` de la configuración al emitir (la constante `TALLER` queda como respaldo en `settings-defaults.js`)
- [X] T015 [P] [US1] Cliente: `client/lib/models/shop_settings.dart` y `client/lib/services/settings_service.dart`
- [X] T016 [US1] Cliente: `client/lib/screens/settings_screen.dart` (datos del taller y márgenes, con validación y mensajes de éxito/error), ruta `Routes.settings` solo ADMIN en `client/lib/utils/app_routes.dart`, `client/lib/main.dart` y la navegación de `client/lib/widgets/app_shell.dart`
- [X] T017 [P] [US1] Prueba de widget en `client/test/settings_screen_test.dart` (carga, validación y guardado con servicio falso)

---

## Fase 4: US2 — Márgenes de "Próximo" (P1)

**Objetivo**: los márgenes guardados son la antelación por defecto de los mantenimientos nuevos.
**Prueba independiente**: margen 15 días → un mantenimiento nuevo sin antelación queda con 15; los existentes no cambian.

- [X] T018 [P] [US2] Prueba de integración en `server/tests/integration/maintenance-default-advance.test.js`: sin antelación en el cuerpo se usa el margen configurado; con antelación se respeta la del cuerpo; límites "entero 1–365" y "entero 1–50000" rechazados con 400
- [X] T019 [US2] En `server/services/maintenance.service.js#create` usar los márgenes de `settings.service` cuando faltan `antelacionDias`/`antelacionKm` (research R-02)

---

## Fase 5: US3 — Catálogo de tipos de servicio (P1)

**Objetivo**: catálogo con intervalos, enlazable a las líneas de la orden y que propone el próximo mantenimiento.
**Prueba independiente**: crear "Cambio de aceite" (180 días, 5,000 km) y verlo propuesto al programar un mantenimiento.

### Pruebas de US3

- [X] T020 [P] [US3] Prueba unitaria de `proposeNextService` en `server/tests/unit/next-service.test.js` (solo días, solo km, ambos)
- [X] T021 [P] [US3] Prueba de contrato en `server/tests/contract/service-types.test.js`: listar activos (tres roles), `incluirInactivos` solo ADMIN, crear/editar/activar/desactivar solo ADMIN, `400 INTERVALO_REQUERIDO`, `409 TIPO_SERVICIO_DUPLICADO` sin distinguir mayúsculas, `404`, sin `DELETE`, bitácora `TIPO_SERVICIO_*`
- [X] T022 [P] [US3] Prueba de contrato en `server/tests/contract/service-order-service-type.test.js`: `tipoServicioId` opcional al agregar servicio, `400 TIPO_SERVICIO_INVALIDO` con tipo inactivo o inexistente, el detalle devuelve `tipoServicioId`/`tipoServicio`, líneas sin tipo siguen funcionando

### Implementación de US3

- [X] T023 [US3] Crear `server/utils/next-service.js` (`proposeNextService(tipo, fechaBase, kmBase)`)
- [X] T024 [US3] Crear `server/models/service_type.js`, `server/validators/service-type.validator.js`, `server/services/service_type.service.js` (con bitácora), `server/controllers/service_types.controller.js` y `server/routes/service_types.routes.js`; montar en `server/routes/index.js`
- [X] T025 [US3] Agregar `tipoServicioId` a `serviceItemSchema` en `server/validators/service-order.validator.js`; validar el tipo activo en `server/services/service_order.service.js#addService`; guardar y leer `service_type_id` en `server/models/order_items.js` (`createServiceWithLabor`, `listServicesByOrder` con el nombre del tipo) y devolverlo en el detalle de la orden
- [X] T026 [P] [US3] Cliente: `client/lib/models/service_type.dart` y `client/lib/services/service_types_service.dart`
- [X] T027 [US3] Cliente: `client/lib/screens/service_types_screen.dart` (lista, alta/edición en diálogo, activar/desactivar con confirmación), ruta `Routes.serviceTypes` solo ADMIN en `app_routes.dart`, `main.dart` y `app_shell.dart`
- [X] T028 [US3] Cliente: en `client/lib/screens/maintenance_form_screen.dart` agregar el selector opcional de tipo del catálogo que propone tipo, intervalos, fecha (hoy + días) y kilometraje (actual + km), editables
- [X] T029 [US3] Cliente: en el alta de servicio de `client/lib/screens/service_order_detail_screen.dart` agregar el selector opcional de tipo (rellena la descripción y envía `tipoServicioId`) y mostrar el tipo en cada línea; actualizar `client/lib/models/service_order.dart` y `client/lib/services/service_orders_service.dart`
- [X] T030 [P] [US3] Pruebas de widget en `client/test/service_types_screen_test.dart` y `client/test/maintenance_form_service_type_test.dart` (propuesta editable)

---

## Fase 6: US8 — Próximo servicio en el ticket (P2)

**Objetivo**: el ticket nuevo muestra el próximo servicio por tipo con intervalo.
**Prueba independiente**: orden con "Cambio de aceite" → ticket con fecha y kilometraje; orden sin tipo → sin sección.

- [X] T031 [P] [US8] Prueba de integración en `server/tests/integration/tickets-next-service.test.js`: un elemento por tipo distinto, fecha = emisión + días, km = entrada + km, lista vacía sin tipos, `formatoVersion` 2
- [X] T032 [US8] En `server/services/ticket.service.js#buildContent` agregar `proximosServicios` usando `proposeNextService` y los tipos de las líneas (nueva consulta en `server/models/ticket.js` o `order_items.js`)
- [X] T033 [US8] Cliente: `proximosServicios` en `client/lib/models/ticket.dart` (ausente = lista vacía) y sección "Próximo servicio" en `client/lib/screens/ticket_screen.dart`
- [X] T034 [P] [US8] Prueba de widget en `client/test/ticket_next_service_test.dart` (con y sin próximos servicios)

---

## Fase 7: US9 — Términos y aviso de privacidad (P1)

**Objetivo**: aceptación obligatoria por versión, validada en backend.
**Prueba independiente**: un usuario nuevo inicia sesión, recibe `terminosPendientes: true`, cualquier operación da `403 TERMINOS_PENDIENTES` hasta aceptar.

### Pruebas de US9

- [X] T035 [P] [US9] Prueba de contrato en `server/tests/contract/terms.test.js`: `GET /api/terms/current`, `POST /api/terms/accept` (idempotente, `409 VERSION_NO_VIGENTE`), `GET /api/terms/acceptances` solo ADMIN, `terminosPendientes` en login y `me`
- [X] T036 [P] [US9] Prueba de integración en `server/tests/integration/terms-enforcement.test.js`: usuario nuevo sin aceptar recibe `403 TERMINOS_PENDIENTES` en rutas protegidas y puede usar `me`, `logout`, `current` y `accept`; tras aceptar entra; una versión nueva vigente vuelve a pedirla (restaurando la vigente al final); bitácora `TERMINOS_ACEPTADOS` una sola vez

### Implementación de US9

- [X] T037 [US9] Crear `server/models/terms.js` (vigente + aceptado en una consulta, aceptar con `INSERT IGNORE`, listar aceptaciones), `server/services/terms.service.js`, `server/validators/terms.validator.js`, `server/controllers/terms.controller.js` y `server/routes/terms.routes.js`; montar en `server/routes/index.js`
- [X] T038 [US9] En `server/middlewares/auth.js` validar la aceptación vigente y responder `403 TERMINOS_PENDIENTES` fuera de la lista blanca (`contracts/terms.md`); en `server/services/auth.service.js` y `server/controllers/auth.controller.js` agregar `terminosPendientes` a login y `me`
- [X] T039 [P] [US9] Cliente: `client/lib/models/terms.dart` y `client/lib/services/terms_service.dart`
- [X] T040 [US9] Cliente: `terminosPendientes` en `client/lib/models/app_user.dart`/`client/lib/services/auth_service.dart` y en `client/lib/providers/auth_provider.dart` (`acceptTerms`, `rejectTerms` = logout)
- [X] T041 [US9] Cliente: `client/lib/screens/terms_acceptance_screen.dart` (texto desplazable, nota "plantilla académica", Aceptar/Rechazar) mostrada por `client/lib/main.dart` en cualquier ruta mientras haya aceptación pendiente
- [X] T042 [US9] Cliente: `client/lib/screens/terms_screen.dart` (todos los roles ven el texto vigente; ADMIN además ve las aceptaciones paginadas), ruta `Routes.terms` y acceso desde `app_shell.dart`
- [X] T043 [P] [US9] Pruebas de Flutter en `client/test/terms_acceptance_test.dart` (pendiente muestra la pantalla; rechazar cierra sesión; aceptar entra) y actualización de `client/test/route_permissions_test.dart` con las rutas nuevas

---

## Fase 8: US10 — Protección de la información (P1)

**Objetivo**: bitácora consultable, política de contraseñas probada, inactividad, no exposición de datos, inyección y cabeceras.
**Prueba independiente**: tras login fallido, cambio de rol, cambio de precio y anulación de pago, la bitácora muestra las cuatro acciones con filtros.

### Pruebas de US10

- [X] T044 [P] [US10] Prueba de contrato en `server/tests/contract/audit-log.test.js`: solo ADMIN, paginación, filtros `desde`/`hasta`/`usuarioId`/`accion`, 400 con filtro inválido, sin rutas de escritura (404 en `POST`/`DELETE`)
- [X] T045 [P] [US10] Prueba de integración en `server/tests/integration/audit-actions.test.js`: se registran `LOGIN_FALLIDO` (usuario existente e inexistente), `CUENTA_BLOQUEADA`, `USUARIO_CREADO`, `USUARIO_ROL_CAMBIADO`, `USUARIO_DESACTIVADO`/`ACTIVADO`, `PRECIO_REFACCION_CAMBIADO`, `PAGO_ANULADO` y `PAGO_CANCELADO`; ninguna entrada contiene la contraseña, `$2` (hash bcrypt) ni el token
- [X] T046 [P] [US10] Prueba de integración en `server/tests/integration/password-policy.test.js` (alta de usuario y cambio de contraseña rechazan cada regla con el mensaje claro; el hash nunca se devuelve)
- [X] T047 [P] [US10] Prueba de integración en `server/tests/integration/session-idle.test.js` (sesión envejecida > 30 min responde `401 SESION_INVALIDA`)
- [X] T048 [P] [US10] Prueba de integración en `server/tests/integration/data-exposure.test.js`: respuestas de usuarios, refacciones, órdenes, pagos y tickets sin `password_hash`/`passwordHash`/token y, para MECHANIC, sin precios
- [X] T049 [P] [US10] Prueba de integración en `server/tests/integration/search-injection.test.js`: cadenas de inyección (`' OR 1=1 --`, `%`, `_`, `\\`, `; DROP TABLE`) en los buscadores de clientes, vehículos, citas, órdenes, mantenimientos y refacciones responden 200 o 400, nunca 500 ni filas ajenas
- [X] T050 [P] [US10] Prueba de contrato en `server/tests/contract/security-headers.test.js` (cabeceras de `helmet` presentes y sin `X-Powered-By`)
- [X] T051 [P] [US10] Prueba de Flutter en `client/test/session_idle_test.dart`: un `401` con sesión abierta cierra la sesión y lleva al inicio de sesión con aviso (CA-23)

### Implementación de US10

- [X] T052 [US10] `app.use(helmet())` en `server/app.js` antes de las rutas
- [X] T053 [US10] Registrar bitácora en `server/services/auth.service.js` (login fallido y bloqueo), `server/services/user.service.js` (alta, rol, activación/desactivación, con el id del ADMIN; ajustar `server/controllers/users.controller.js` para pasar `req.user`), `server/services/part.service.js#update` (cambio de precio de compra o venta, con valores anterior y nuevo) y `server/services/payment.service.js` (`annulPayment` → `PAGO_ANULADO`, `confirmPayment` en `CANCELADO` → `PAGO_CANCELADO`)
- [X] T054 [US10] Crear `server/validators/audit.validator.js`, `server/controllers/audit_log.controller.js` y `server/routes/audit_log.routes.js` (solo ADMIN, solo `GET`); montar en `server/routes/index.js`
- [X] T055 [P] [US10] Cliente: `client/lib/models/audit_entry.dart` y `client/lib/services/audit_service.dart`
- [X] T056 [US10] Cliente: `client/lib/screens/audit_log_screen.dart` (tabla paginada con filtros de fecha, usuario y acción), ruta `Routes.auditLog` solo ADMIN en `app_routes.dart`, `main.dart` y `app_shell.dart`
- [X] T057 [P] [US10] Prueba de widget en `client/test/audit_log_screen_test.dart`

---

## Fase 9: Cierre de la Entrega A

- [X] T058 Actualizar `docs/project-context.md` (configuración, catálogo, términos, bitácora, seguridad; respaldo en código) y `docs/design-system.md` (pantallas nuevas) — FR-041
- [X] T059 Correr `npm test` (maxWorkers "50%"), `npm run lint`, `flutter test` y `flutter analyze`; corregir lo que falle y guardar la salida en `docs/evidencias/sprint 7/s7-entrega-a-*.txt`

---

# ENTREGA B — Reportes y exportación

## Fase 10: Fundamentos de reportes

- [X] T060 Crear `server/utils/report-range.js` (validar `desde`/`hasta`, máximo 366 días) y `server/utils/csv.js` (BOM, coma, comillas dobles duplicadas, CRLF) con pruebas en `server/tests/unit/report-range.test.js` y `server/tests/unit/csv.test.js`
- [X] T061 Agregar al seed `database/seeds/007_ejemplos_configuracion_terminos.sql` (ids 70001–70099) órdenes terminadas con servicios tipificados, refacciones con y sin costo, pagos aprobados y anulados y movimientos de salida en el mes, para que los reportes muestren datos (CA-12)
- [X] T062 Crear `server/models/report.js`, `server/services/report.service.js`, `server/validators/report.validator.js`, `server/controllers/reports.controller.js` y `server/routes/reports.routes.js` (solo ADMIN, `formato=csv`); montar en `server/routes/index.js`
- [X] T063 [P] Cliente: `client/lib/services/reports_service.dart`, `client/lib/screens/reports_screen.dart` (rango libre con atajos hoy/semana/mes en hora de Ciudad de México, pestañas por reporte) y ruta `Routes.reports` solo ADMIN

## Fase 11: US4 — Ingresos por periodo (P2)

- [X] T064 [P] [US4] Prueba de integración en `server/tests/integration/report-income.test.js` (solo `PAGADO`, por método y por día, centavos exactos, `400 RANGO_INVALIDO`, 403 para otros roles)
- [X] T065 [US4] Implementar el reporte de ingresos en `server/models/report.js` y `server/services/report.service.js` y su pestaña en `client/lib/screens/reports_screen.dart`

## Fase 12: US5 — Servicios frecuentes y productividad (P2)

- [X] T066 [P] [US5] Prueba de integración en `server/tests/integration/report-services-productivity.test.js` (agrupación por tipo o descripción, órdenes que pasaron a `TERMINADO` en el rango, mano de obra por mecánico)
- [X] T067 [US5] Implementar ambos reportes en `server/models/report.js`/`server/services/report.service.js` y sus pestañas en `client/lib/screens/reports_screen.dart`

## Fase 13: US6 — Margen y rotación (P2)

- [X] T068 [P] [US6] Prueba de integración en `server/tests/integration/report-parts.test.js` ("sin costo registrado" fuera del margen total; rotación = salidas / existencia; "sin existencia")
- [X] T069 [US6] Implementar margen y rotación en `server/models/report.js`/`server/services/report.service.js` y sus pestañas en `client/lib/screens/reports_screen.dart`

## Fase 14: US7 — Exportación (P3)

- [X] T070 [P] [US7] Prueba de contrato en `server/tests/contract/reports-csv.test.js` (cabeceras, BOM, mismas filas y cifras que el JSON en los 5 reportes)
- [X] T071 [US7] Botón "Exportar CSV" por pestaña en `client/lib/screens/reports_screen.dart` (descarga en web) y prueba de widget en `client/test/reports_screen_test.dart`

## Fase 15: Cierre de la Entrega B

- [X] T072 Medir los reportes con un año de datos de ejemplo (< 3 s, SC-008) en `server/tests/integration/reports-performance.test.js`
- [X] T073 Actualizar `docs/project-context.md` con los reportes y correr la suite completa, lint, `flutter test` y `flutter analyze`

---

## Dependencias y orden de ejecución

- Fase 1 → Fase 2 (bloquea todo) → US1 → US2 (usa `settings.service`) → US3 → US8 (usa `next-service` y los tipos de US3) → US9 → US10 → Fase 9.
- US9 cambia el login de todas las pruebas: T008 (helper) debe estar listo antes de T038.
- La Entrega B (Fases 10 a 15) empieza solo cuando la Fase 9 esté cerrada; dentro de B, Fase 10 bloquea US4–US7, y US7 depende de los cuatro reportes.

## Ejemplos de paralelismo

- Fase 2: T005 y T006 en paralelo.
- US1: T009, T010 y T011 en paralelo; T015 en paralelo con T012–T014.
- US3: T020, T021 y T022 en paralelo; T026 en paralelo con T023–T025.
- US10: T044 a T051 en paralelo (archivos de prueba distintos).

## Estrategia de implementación

1. MVP de este sprint = **Entrega A** completa (Fases 1 a 9), con la suite en verde.
2. La Entrega B se implementa en una corrida posterior, historia por historia (US4 → US7).
3. Cada historia se valida con su prueba independiente antes de pasar a la siguiente.
