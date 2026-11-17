# Tareas: Notificaciones internas (Sprint 6)

**Entrada**: documentos de diseño en `specs/006-notificaciones-internas/` ([spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)).

**Pruebas**: obligatorias y primero (constitución, principio VII; FR-026). Cada prueba nueva se escribe y se ve fallar antes de implementar.

**Formato**: `- [ ] T### [P] [US#] Descripción con ruta`. `[P]` = archivos distintos y sin dependencias pendientes.

**Rutas**: servidor en `server/`, cliente en `client/`, base en `database/`. Los comandos se corren en Windows (PowerShell).

---

## Fase 1: Preparación

- [X] T001 Correr `npm test` en `server/` y guardar la salida en `docs/evidencias/sprint 6/s6-linea-base-npm.txt`. Esperado: 64/64 suites y 545/545 pruebas, sin timeouts.
- [X] T002 [P] Correr `flutter test` en `client/` y guardar la salida en `docs/evidencias/sprint 6/s6-linea-base-flutter.txt`. Esperado: 155/155.

---

## Fase 2: Base (bloquea todas las historias)

- [X] T003 [P] Prueba unitaria `server/tests/unit/notice-keys.test.js` (debe fallar): formatos de R-05 — `MANT_PROXIMO:<id>:<objetivo>`, `MANT_VENCIDO:<id>:<objetivo>`, `STOCK_BAJO:<id>`, `STOCK_AGOTADO:<id>`, `CITA_HOY:<id>:<YYYY-MM-DD>`, `ORDEN_DETENIDA:<id>:<estado>`, hechos `ORDEN:<id>`, `CITA:<id>`, `MANT:<id>:<objetivo>`; objetivo `<target_date o ->|<target_mileage o ->` (`2026-12-01|45000`, `-|45000`, `2026-12-01|-`); toda clave ≤ 120 caracteres; `parsearClave` reconoce el tipo y rechaza formatos inválidos.
- [X] T004 [P] Prueba unitaria `server/tests/unit/stalled-order.test.js` (debe fallar): `estaDetenida({ estado, referencia, ahora, dias })` es verdadera solo para `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` y `ESPERANDO_REFACCION` cuando `ahora - referencia > dias × 24 h`; falsa justo en el límite (= N × 24 h), para `TERMINADO` y para `ENTREGADO`.
- [X] T005 Crear `database/migrations/007_notificaciones_internas.sql` (solo `CREATE TABLE IF NOT EXISTS`, InnoDB, `utf8mb4`), exactamente como [data-model.md](./data-model.md):
  - `notification_reads`: `id INT AUTO_INCREMENT PK`, `user_id INT NOT NULL` FK → `users(id)` ON DELETE CASCADE, `notice_key VARCHAR(120) NOT NULL`, `read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`, `UNIQUE uq_notification_reads_user_key (user_id, notice_key)`.
  - `client_notices`: `id INT AUTO_INCREMENT PK`, `client_id INT NOT NULL` FK → `clients(id)` ON DELETE RESTRICT, `reason ENUM('VEHICULO_LISTO','CITA_MANANA','MANT_PROXIMO','MANT_VENCIDO') NOT NULL`, `fact_key VARCHAR(120) NOT NULL`, `notified_by INT NOT NULL` FK → `users(id)` ON DELETE RESTRICT, `notified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`, `UNIQUE uq_client_notices_fact (fact_key)`, `KEY idx_client_notices_client (client_id)`.
- [X] T006 [P] Crear `server/utils/notice-keys.js` (funciones puras: claves de aviso y de hecho, `objetivoMantenimiento`, `parsearClave`) hasta que pase T003.
- [X] T007 [P] Crear `server/utils/stalled-order.js` con `STALLED_ORDER_STATUSES` (`RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`) y `estaDetenida` hasta que pase T004.
- [X] T008 [P] En `server/config/env.js` agregar `notifications.stalledOrderDays` desde `NOTIF_ORDEN_DETENIDA_DIAS` (entero > 0; 3 por defecto, mismo patrón que `MP_PREFERENCIA_VIGENCIA_HORAS`) y documentarla en `server/.env.example`.
- [X] T009 Reutilización sin copiar (R-02): exportar `ACTIVE_APPOINTMENT_STATUSES` (`PROGRAMADA`, `RECIBIDA`) en `server/utils/status-constants.js` y usarla en `server/models/dashboard.js` en lugar de los dos estados sueltos; exportar `WHERE_STOCK_BAJO` desde `server/models/dashboard.js`; exportar `todayIso` (fecha local `YYYY-MM-DD`) desde un util compartido `server/utils/dates.js` y usarlo en `server/services/maintenance.service.js`. Sin cambio de comportamiento.
- [X] T010 **Punto de control**: `npm test` (línea base + T003 y T004 en verde). La migración `007` se aplica sola en `motorix_v2_test` por `tests/helpers/db.js`.

---

## Fase 3: US1 – Centro de notificaciones con contador (P1) 🎯 MVP

**Objetivo**: campana con contador y panel agrupado, con el endpoint y la agrupación listos; los tipos se agregan en US2 a US4.
**Prueba independiente**: la campana muestra el número, «99+», sin insignia en 0; el panel maneja carga, vacío y error; la respuesta tiene la forma del contrato.

- [X] T011 [P] [US1] Prueba unitaria `server/tests/unit/notification-grouping.test.js` (debe fallar): `agruparAvisos(avisos)` devuelve grupos en el orden de FR-007a (`MANT_VENCIDO`, `ORDEN_DETENIDA`, `STOCK_AGOTADO`, `STOCK_BAJO`, `CITA_HOY`, `MANT_PROXIMO`), omite grupos vacíos, ordena dentro del grupo no leídos primero y luego `fechaReferencia` ascendente, y calcula `cantidad`, `noLeidos` y `totalAvisos`.
- [X] T012 [P] [US1] Prueba de contrato `server/tests/contract/notifications.test.js` (debe fallar): 401 `SESION_REQUERIDA` (el contrato decía `NO_AUTENTICADO`; se corrigió al código real) sin sesión en `GET /api/notifications` y `GET /api/notifications/count`; 200 con `{ noLeidos, totalAvisos, grupos }` y `{ noLeidos }`; cada aviso con `clave`, `tipo`, `titulo`, `descripcion`, `fechaReferencia`, `leido`, `destino`; en toda la respuesta (incluido el nivel superior) no hay claves `total`, `subtotal*`, `precio*`, `importe*` ni `monto*` (FR-012).
- [X] T013 [P] [US1] Prueba Flutter `client/test/notification_bell_test.dart` (debe fallar) con `client/test/fake_notifications_service.dart`: insignia `Key('notification-badge')` con el número, «99+» con 120, sin insignia en 0; al tocar `Key('notification-bell')` el panel muestra carga, vacío («No tienes avisos pendientes»), error con «Reintentar», y los grupos con su cantidad.
- [X] T014 [US1] Crear `server/models/notification.js` con `listReadKeys(userId)` (un solo `SELECT notice_key FROM notification_reads WHERE user_id = ?`).
- [X] T015 [US1] Crear `server/services/notification.service.js` con `agruparAvisos` (pasa T011), `getNotifications(user)` y `countUnread(user)`: reúne avisos de un registro de fuentes por rol (vacío por ahora), marca `leido` con `listReadKeys` y agrupa.
- [X] T016 [US1] Crear `server/controllers/notifications.controller.js` y `server/routes/notifications.routes.js` (`authenticate`; `GET /` y `GET /count`) y montarlas en `server/routes/index.js` como `/notifications` (pasa T012).
- [X] T017 [P] [US1] Crear `client/lib/models/notification.dart` (`NotificationItem`, `NotificationGroup`, `NotificationsSummary.fromJson`, destino con `pantalla`, `id`, `fecha`).
- [X] T018 [P] [US1] Crear `client/lib/services/notifications_service.dart` (`fetchAll`, `fetchCount`, `markRead`) con el `ApiClient` existente.
- [X] T019 [US1] Crear `client/lib/providers/notifications_provider.dart` (`LoadStatus`, `noLeidos`, `refreshCount()`, `load()`); si `refreshCount` falla, conserva 0 sin error visible (contrato UI).
- [X] T020 [US1] Crear `client/lib/widgets/notification_bell.dart` (campana, insignia y panel con estados de `common_views.dart`, colores `danger`/`warning`/`info`), agregarla al `AppBar` de `client/lib/widgets/app_shell.dart`, llamar `refreshCount()` al iniciar sesión y en cada cambio de sección, y registrar el provider en `client/lib/main.dart` (pasa T013). Sin `Timer`.
- [X] T021 [US1] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 4: US2 – Mantenimientos y citas para recepción (P2)

**Objetivo**: avisos `MANT_PROXIMO`, `MANT_VENCIDO` y `CITA_HOY` para ADMIN y RECEPTIONIST, con los mismos números que la lista de Mantenimientos y el panel.
**Prueba independiente**: con un mantenimiento próximo, uno vencido y una cita de hoy, recepción ve tres avisos y los números coinciden.

- [X] T022 [P] [US2] Prueba de integración `server/tests/integration/notifications-maintenance-appointments.test.js` (debe fallar): Próximo y Vencido generan aviso; Normal y sin objetivos no; doble cumplimiento (fecha y km) da un solo aviso `MANT_VENCIDO`; cita de hoy `PROGRAMADA` (hora futura) y `RECIBIDA` sí; `CANCELADA`, `NO_PRESENTADA` y de otro día no; una `PROGRAMADA` de hoy con hora pasada no aparece y queda `NO_PRESENTADA` (R-03); claves con el formato de R-05; destinos `VEHICULO` y `CITAS` con `fecha`; RECEPTIONIST los recibe.
- [X] T023 [P] [US2] Prueba de integración `server/tests/integration/notifications-consistency.test.js` (debe fallar; se completa en US3): mantenimientos Próximo y Vencido del centro (ADMIN) = conteo de la lista `GET /api/maintenance` por indicador; citas de hoy = `citas.hoy` de `GET /api/dashboard` consultado después del centro (SC-003).
- [X] T024 [US2] En `server/models/maintenance.js` exportar `listAllMaintenance()` (la misma `BASE_SELECT`, sin paginar, con `vehicle_current_mileage`, placas y cliente) y en `server/models/notification.js` agregar `listAppointmentsOn(fecha)` con `ACTIVE_APPOINTMENT_STATUSES` (cliente, vehículo, hora).
- [X] T025 [US2] En `server/services/notification.service.js` agregar las fuentes de mantenimiento (`calcMaintenanceState(row, todayIso(), row.vehicleCurrentMileage)`; fecha de referencia = fecha objetivo o hoy) y de cita de hoy (llamar antes `markExpiredAsNotPresented()`), registradas para ADMIN y RECEPTIONIST (pasan T022 y la parte de T023).
- [X] T026 [US2] En `client/lib/screens/appointments_screen.dart` aceptar un argumento opcional de fecha inicial; en `notification_bell.dart` navegar a `Routes.vehicleDetail` (`VEHICULO`) y a `Routes.appointments` con la fecha (`CITAS`).
- [X] T027 [P] [US2] Ampliar `client/test/notification_bell_test.dart`: tocar un aviso `VEHICULO` abre el detalle del vehículo y uno `CITAS` abre Citas con la fecha.
- [X] T028 [US2] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 5: US3 – Stock para el administrador (P3)

**Objetivo**: avisos `STOCK_BAJO` y `STOCK_AGOTADO` solo para ADMIN.
**Prueba independiente**: el número coincide con el panel y con el filtro «solo stock bajo».

- [X] T029 [P] [US3] Prueba de integración `server/tests/integration/notifications-stock.test.js` (debe fallar): existencia ≤ mínimo con mínimo > 0 da `STOCK_BAJO`; existencia 0 da `STOCK_AGOTADO`; mínimo 0 no genera aviso; una refacción inactiva en stock bajo sí genera aviso (regla existente); RECEPTIONIST y MECHANIC no reciben avisos de stock; los avisos no traen precios; destino `REFACCION`. Completar en `notifications-consistency.test.js`: cantidad de avisos de stock = `alertasInventario.stockBajo` del panel = `total` de `GET /api/parts?stockBajo=true`.
- [X] T030 [US3] En `server/models/notification.js` agregar `listLowStockParts()` con `WHERE_STOCK_BAJO` (sin límite), seleccionando solo `id`, `code`, `name`, `stock_current`, `stock_min` (sin precios).
- [X] T031 [US3] En `server/services/notification.service.js` agregar la fuente de stock, registrada solo para ADMIN (pasa T029).
- [X] T032 [US3] En `notification_bell.dart` navegar a `Routes.partDetail` (`REFACCION`) y ampliar `notification_bell_test.dart` con ese caso.
- [X] T033 [US3] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 6: US4 – Órdenes detenidas (P4)

**Objetivo**: aviso `ORDEN_DETENIDA` para ADMIN y RECEPTIONIST (y para el mecánico asignado, en US5).
**Prueba independiente**: una orden sin cambio por más de N días aparece; al cambiar de estado desaparece.

- [X] T034 [P] [US4] Prueba de integración `server/tests/integration/notifications-stalled-orders.test.js` (debe fallar): los cuatro estados no finales con último cambio hace más de N × 24 h sí; `TERMINADO` y `ENTREGADO` nunca; sin historial se usa `created_at`; cambiar el estado la quita y la clave nueva incluye el estado nuevo; con `config.notifications.stalledOrderDays` en otro valor se respeta; órdenes sin mecánico aparecen para ADMIN y RECEPTIONIST; descripción con «N días sin cambio»; destino `ORDEN`.
- [X] T035 [US4] En `server/models/notification.js` agregar `listStalledOrders({ days, mechanicId })` según R-04: `COALESCE(MAX(h.changed_at), o.created_at)` como referencia, `o.status IN (STALLED_ORDER_STATUSES)`, `TIMESTAMPDIFF(SECOND, referencia, NOW()) > days * 86400`, filtro opcional `o.mechanic_id = ?`.
- [X] T036 [US4] En `server/services/notification.service.js` agregar la fuente de órdenes detenidas para ADMIN y RECEPTIONIST (pasa T034).
- [X] T037 [US4] En `notification_bell.dart` navegar a `Routes.serviceOrderDetail` (`ORDEN`) y ampliar `notification_bell_test.dart`.
- [X] T038 [US4] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 7: US5 – Avisos del mecánico (P5)

**Objetivo**: el mecánico solo recibe órdenes detenidas asignadas a él, sin importes.
**Prueba independiente**: mecánicos A y B ven cada uno solo la suya.

- [X] T039 [P] [US5] Prueba de integración `server/tests/integration/notifications-by-role.test.js` (debe fallar): mecánico A ve solo su orden detenida; no ve la del mecánico B ni las sin asignar; MECHANIC no recibe grupos de mantenimiento, cita ni stock aunque existan; RECEPTIONIST no recibe stock; ADMIN recibe los seis tipos; para los tres roles ningún aviso contiene `precio`, `subtotal`, `importe`, `monto` ni un total de dinero (SC-002); `count` = `noLeidos` del listado por rol.
- [X] T040 [US5] En `server/services/notification.service.js` centralizar la matriz `FUENTES_POR_ROL` (ADMIN: todas; RECEPTIONIST: mantenimiento, cita, orden detenida; MECHANIC: orden detenida con `mechanicId = user.id`) (pasa T039).
- [X] T041 [P] [US5] Ampliar `client/test/notification_bell_test.dart`: con sesión MECHANIC la campana aparece y el panel muestra solo el grupo de órdenes detenidas que da el servicio falso.
- [X] T042 [US5] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 8: US6 – Marcar como leído y abrir el módulo (P6)

**Objetivo**: lectura por usuario con la clave tipo + objeto + estado.
**Prueba independiente**: marcar baja el contador en 1 solo para ese usuario.

- [X] T043 [P] [US6] Prueba de integración `server/tests/integration/notifications-read.test.js` (debe fallar): `POST /api/notifications/read` responde 204 y el aviso queda `leido: true` solo para ese usuario (SC-004); repetir no duplica filas; una clave inexistente o de otro rol responde 204 y no guarda fila (FR-030); cuerpo sin `clave` o de más de 120 caracteres → 400 `VALIDACION`; sin sesión → 401; un mantenimiento leído como Próximo que pasa a Vencido aparece no leído; al renovar el mantenimiento (objetivo nuevo) el aviso es nuevo; una cita reprogramada a hoy es un aviso nuevo.
- [X] T044 [US6] Crear `server/validators/notification.validator.js` (Zod: `clave` cadena de 1 a 120); en `server/models/notification.js` agregar `insertRead(userId, key)` con `INSERT IGNORE`; en el servicio `markRead(user, clave)` que solo guarda si la clave está entre los avisos actuales del usuario; ruta `POST /read` en `server/routes/notifications.routes.js` (pasa T043).
- [X] T045 [US6] En `notification_bell.dart`: botón `Key('marcar-leido-<clave>')` en los no leídos y, al tocar un aviso, marcarlo como leído antes de navegar; el contador baja en 1; los leídos se ven atenuados. Ampliar `notification_bell_test.dart`.
- [X] T046 [US6] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 9: US7 – Clientes por avisar (P7)

**Objetivo**: lista con teléfono y registro de «avisado» una vez por hecho.
**Prueba independiente**: marcar al cliente de una orden terminada lo saca de la lista con quién y cuándo.

- [X] T047 [P] [US7] Prueba de contrato `server/tests/contract/client-notices.test.js` (debe fallar): forma de `GET /api/client-notices` (`elementos`, `total`; cada elemento con `clave`, `motivo`, `motivoTexto`, `cliente{id,nombre,telefono}`, `vehiculo{id,descripcion,placas}`, `fecha`, `destino`); `POST` → 201 con `avisadoPor` y `avisadoEn`; 400 `VALIDACION`; 404 `HECHO_NO_VIGENTE`; 409 `YA_AVISADO`; MECHANIC → 403 `ROL_NO_AUTORIZADO` en GET y POST; sin sesión → 401.
- [X] T048 [P] [US7] Prueba de integración `server/tests/integration/client-notices.test.js` (debe fallar): aparecen los cuatro motivos (orden `TERMINADO`, cita de mañana `PROGRAMADA`/`RECIBIDA`, mantenimiento próximo y vencido); marcar guarda `notified_by` y `notified_at` y saca el renglón; otra orden del mismo cliente sí aparece; un mantenimiento avisado como Próximo no reaparece al vencer; al renovarlo (objetivo nuevo) reaparece; dos `POST` simultáneos del mismo hecho dan un 201 y un 409 y una sola fila (SC-005); orden de FR-029; ningún elemento trae importes.
- [X] T049 [P] [US7] Prueba Flutter `client/test/client_notices_screen_test.dart` (debe fallar): carga, vacío («No hay clientes por avisar»), error con «Reintentar»; la sección aparece en el menú para ADMIN y RECEPTIONIST y no para MECHANIC; «Marcar como avisado» abre la confirmación; al confirmar el renglón desaparece y sale «Aviso registrado»; con 409 sale el mensaje del servidor y se recarga.
- [X] T050 [US7] Crear `server/models/client_notice.js`: candidatos (órdenes `TERMINADO` con cliente, vehículo y fecha del paso a `TERMINADO`; citas de `CURDATE() + INTERVAL 1 DAY` en `ACTIVE_APPOINTMENT_STATUSES`; mantenimientos vía `listAllMaintenance`), `listNoticedFactKeys()` e `insertNotice({ clientId, reason, factKey, notifiedBy })` que convierte `ER_DUP_ENTRY` en 409 `YA_AVISADO`.
- [X] T051 [US7] Crear `server/services/client_notice.service.js`: arma la lista con claves de hecho (`notice-keys.js`), motivo y `motivoTexto`, excluye hechos ya avisados, ordena según FR-029; `markNotified(user, clave)` con 404 `HECHO_NO_VIGENTE` si la clave no está en la lista actual (pasa T048).
- [X] T052 [US7] Crear `server/controllers/client_notices.controller.js`, `server/validators/client_notice.validator.js` y `server/routes/client_notices.routes.js` (`authenticate`, `authorize('ADMIN', 'RECEPTIONIST')`) y montar `/client-notices` en `server/routes/index.js` (pasa T047).
- [X] T053 [P] [US7] Crear `client/lib/models/client_notice.dart` y `client/lib/services/client_notices_service.dart`.
- [X] T054 [US7] Crear `client/lib/providers/client_notices_provider.dart` y `client/lib/screens/client_notices_screen.dart` (tabla o lista según el ancho, chip de motivo, confirmación); agregar `Routes.clientNotices = '/client-notices'` en `client/lib/utils/app_routes.dart`, la sección en `ShellSections` de `client/lib/widgets/app_shell.dart` (solo ADMIN y RECEPTIONIST) y el provider en `client/lib/main.dart` (pasa T049).
- [X] T055 [US7] **Punto de control**: `npm test` y `flutter test`.

---

## Fase 10: Datos de ejemplo, rendimiento, documentación y cierre

- [X] T056 [P] Prueba de integración `server/tests/integration/seed-006.test.js` (debe fallar): cargar `database/seeds/006_ejemplos_notificaciones.sql` dos veces deja los mismos conteos, contados por claves propias (ids 60001 a 60099, códigos `NOT-`, motivos «[Sprint 6]»), no por rangos que compartan otras suites; después de cargarlo, ADMIN recibe al menos un aviso de cada tipo y «Clientes por avisar» tiene los cuatro motivos.
- [X] T057 Crear `database/seeds/006_ejemplos_notificaciones.sql` según R-10: ids 60001 a 60099 en todas sus tablas; fechas relativas con `CURDATE()`/`NOW()`; `INSERT ... ON DUPLICATE KEY UPDATE` que refresca fechas sin duplicar; usuarios por `username` (`admin`, `recepcion`, `mecanico`); cita de hoy a las 23:30 (pasa T056).
- [X] T058 Revisar que el seed `006` cargado en `motorix_v2_test` no rompa pruebas existentes (panel, citas, refacciones). Si alguna cambia por diseño, ajustarla y registrar antes/después en `reporte-implementacion.md`.
- [X] T059 [P] Prueba de rendimiento `server/tests/integration/notifications-performance.test.js`: insertar 10× el volumen del seed (100 mantenimientos, 50 refacciones en stock bajo, 50 órdenes detenidas, 30 citas de hoy) con claves propias y limpiarlas al final; hacer 1 consulta de calentamiento y luego 3 consultas de `GET /api/notifications` como ADMIN; la **mediana** de las 3 debe ser menor que 1000 ms (SC-006). Medir con `performance.now()` alrededor de la petición, y dar a la prueba un timeout propio de 30 s para que la carga de datos no cuente.
- [X] T060 [P] Actualizar `docs/project-context.md` §6.12: tipos de aviso, criterios, permisos por rol, lectura por clave tipo + objeto + estado, N configurable y «Clientes por avisar».
- [X] T061 [P] Actualizar `docs/design-system.md`: campana con insignia («99+»), panel de avisos (colores por tipo, leídos atenuados) y lista «Clientes por avisar» con confirmación.
- [X] T062 [P] Actualizar `database/README.md`: fila del Sprint 6 en «Tablas por sprint» y sección de la migración `007` y el seed `006` (rango 60001 a 60099, fechas relativas, recargar el día de la demostración).
- [X] T063 `npm run lint` en `server/` sin errores.
- [X] T064 **Punto de control final**: `npm test` 3 veces y `flutter test` 1 vez; guardar en `docs/evidencias/sprint 6/s6-final-npm-1.txt` a `-3.txt` y `s6-final-flutter.txt`; reportar suites, pruebas, tiempo, timeouts y el aviso de worker.
- [X] T065 Respaldo de `motorix_v2` antes de migrar, fuera del repositorio: `mysqldump -u motorix_app -p --single-transaction --routines --no-tablespaces motorix_v2 > C:\Users\kastr\Documents\MotorixVer2\respaldos\respaldo-motorix_v2-antes-007-<fecha>.sql`. **Hecha por Carlos el 2026-11-16**: `respaldo-motorix_v2-antes-007-20261116.sql` en `C:\Users\kastr\Documents\MotorixVer2\respaldos\` (fuera del repositorio).
- [X] T066 Aplicar la migración `007` y el seed `006` en `motorix_v2` con `database/scripts/aplicar-migraciones.ps1` (con y sin `-Seeds`); verificar las dos tablas nuevas y los conteos del seed; guardar en `docs/evidencias/sprint 6/s6-migracion-motorix_v2.txt`. **Hecha por Carlos el 2026-11-16**: migración 007 y seed 006 aplicados a `motorix_v2` con `aplicar-migraciones.ps1`; comprobado al ver la campana de avisos en la app como administrador (no se guardó el archivo de evidencia).
- [X] T067 Recorrer el [quickstart](./quickstart.md) §3 por API contra `motorix_v2` y guardar el resultado de cada paso en `docs/evidencias/sprint 6/s6-quickstart-recorrido-api.txt`. Los pasos de interfaz y el cronometraje (SC-008) **no se ejecutaron por decisión de Carlos**; quedan cubiertos por el recorrido por API y las pruebas de Flutter (183 al decidirlo; 186 en la línea base final).
- [X] T068 Crear `specs/006-notificaciones-internas/reporte-implementacion.md`: archivos cambiados, historias y requisitos cubiertos, pruebas (comando y resultado real), pruebas existentes ajustadas (T058), pendientes y riesgos.

---

## Dependencias

- Fase 1 → Fase 2 → US1 → (US2, US3, US4 en cualquier orden) → US5 → US6 → US7 → Fase 10.
- US5 depende de US4 (fuente de órdenes detenidas). US6 depende de que exista al menos un tipo (US2). US7 solo depende de la Fase 2 y de `listAllMaintenance` (T024).
- T023 se completa entre US2 y US3. T056 antes de T057 (TDD). T065 antes de T066.

## Ejecución en paralelo (ejemplos)

- Fase 2: T003, T004 y T008 juntos; luego T006 y T007.
- US1: T011, T012 y T013 juntos; T017 y T018 juntos.
- US7: T047, T048 y T049 juntos; T053 en paralelo con T050 a T052.
- Fase 10: T060, T061 y T062 juntos.

## Estrategia

- **MVP**: Fases 1 a 4 (centro con contador y avisos de mantenimientos y citas).
- Incremental: cada historia termina con su punto de control en verde antes de la siguiente.
- No hacer commit salvo que Carlos lo pida (CLAUDE.md, regla 1).
