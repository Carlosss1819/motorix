# Reporte de implementación: Sprint 6, notificaciones internas

**Rama**: `006-notificaciones-internas` | **Fecha**: 2026-11-16 | **Sin commit ni push** (CLAUDE.md, regla 1).

Se implementó en dos sesiones; la primera se cortó por el límite de uso y la segunda retomó desde los archivos.

## 1. Resumen

| Concepto | Resultado |
|---|---|
| Tareas | 68 de 68 marcadas `[X]` en `tasks.md`. T065 y T066 las hizo Carlos el 2026-11-16 (§7). |
| Backend | 64 suites y 545 pruebas (línea base) → **78 suites y 647 pruebas** al cierre (3 corridas seguidas en verde, sin timeouts y sin aviso de worker) → **79 suites y 649 pruebas** tras la corrección de §9 (1 corrida en verde). |
| Flutter | 155 → **178 pruebas** al cierre → **183** tras la corrección de §9, todas en verde. |
| Lint | `npm run lint`: sin errores. |
| Migraciones | `007_notificaciones_internas.sql` aplicada **solo en `motorix_v2_test`** (la aplica `tests/helpers/db.js`). **No** aplicada en `motorix_v2`. |

## 2. Archivos

### Nuevos

- **Base**: `database/migrations/007_notificaciones_internas.sql`, `database/seeds/006_ejemplos_notificaciones.sql`.
- **Servidor**: `utils/clock.js`, `utils/dates.js`, `utils/notice-keys.js`, `utils/stalled-order.js`, `models/notification.js`, `models/client_notice.js`, `services/notification.service.js`, `services/client_notice.service.js`, `controllers/notifications.controller.js`, `controllers/client_notices.controller.js`, `routes/notifications.routes.js`, `routes/client_notices.routes.js`, `validators/notification.validator.js`.
- **Pruebas del servidor** (14 suites): unitarias `notice-keys`, `stalled-order`, `notification-grouping`; contrato `notifications`, `client-notices`; integración `notifications-maintenance-appointments`, `notifications-consistency`, `notifications-stock`, `notifications-stalled-orders`, `notifications-by-role`, `notifications-read`, `client-notices`, `notifications-performance`, `seed-006`; apoyo `tests/helpers/notifications-fixtures.js`.
- **Cliente**: `models/notification.dart`, `models/client_notice.dart`, `services/notifications_service.dart`, `services/client_notices_service.dart`, `providers/notifications_provider.dart`, `providers/client_notices_provider.dart`, `widgets/notification_bell.dart`, `screens/client_notices_screen.dart`.
- **Pruebas del cliente**: `test/notification_bell_test.dart` (14), `test/client_notices_screen_test.dart` (9), `test/fake_notifications_service.dart`.
- **Evidencias**: `docs/evidencias/sprint 6/` (línea base, H-S6-02, corridas finales, lint, Flutter y recorrido por API).

### Modificados

- **Servidor**: `config/env.js` y `.env.example` (`NOTIF_ORDEN_DETENIDA_DIAS`), `utils/status-constants.js` (`ACTIVE_APPOINTMENT_STATUSES`), `models/dashboard.js` (exporta `WHERE_STOCK_BAJO` y usa la constante; sin cambio de comportamiento), `services/maintenance.service.js` (usa `todayIso` compartido), `routes/index.js` (monta `/notifications` y `/client-notices`), `package.json` (`maxWorkers: "50%"`, H-S6-02), `tests/helpers/env.js` (pasarela simulada forzada, H-S6-01).
- **Cliente**: `main.dart` (providers, rutas `/client-notices` y fecha inicial de Citas, permisos), `utils/app_routes.dart`, `widgets/app_shell.dart` (campana en el encabezado y sección «Clientes por avisar»), `screens/appointments_screen.dart` (`fechaInicial` y `AppointmentsArgs`).
- **Documentación**: `docs/project-context.md` §6.12, `docs/design-system.md` §8.5.1 y §8.5.2, `database/README.md` (Sprint 6), contratos (`SESION_REQUERIDA`), `CLAUDE.md` regla 7 (línea base nueva).
- `server/.env` **no** se tocó ni se agrega.

## 3. Historias y requisitos cubiertos

| Historia | Cobertura |
|---|---|
| US1 Centro con contador | Campana con insignia («99+», sin insignia en 0, sin error si falla), panel con carga, vacío y error, grupos en el orden de FR-007a. |
| US2 Mantenimientos y citas | `MANT_PROXIMO`, `MANT_VENCIDO` (un solo aviso si se cumplen fecha y km), `CITA_HOY` con detección de no presentadas (R-03, solo para roles con avisos de cita: M2). |
| US3 Stock | `STOCK_BAJO`, `STOCK_AGOTADO` solo ADMIN; coinciden con el panel y el filtro (prueba de coherencia, T023/T029). |
| US4 Órdenes detenidas | N × 24 h con N configurable; sin historial usa `created_at`. |
| US5 Mecánico | Solo órdenes detenidas asignadas a él; sin importes en ningún rol (SC-002). |
| US6 Leído | Por usuario, clave tipo + objeto + estado; tocar un aviso lo marca (M1, FR-018); claves ajenas → 204 sin guardar (FR-030). |
| US7 Clientes por avisar | Cuatro motivos, confirmación, 201/409/404, carrera de dos `POST` (SC-005), 403 al mecánico. |
| FR-025 / SC-007 | Seed 006 idempotente con todos los tipos y motivos. |
| SC-006 | Mediana de 3 consultas < 1 s con 10× el volumen del seed (prueba de rendimiento). |
| M3 | Las pruebas que dependen de la hora usan el reloj fijo (`utils/clock.js`, 2035-06-15 12:00) o, en la prueba del seed, las 12:00 del día de MySQL. |
| M5 | Fecha de referencia de FR-007 cubierta en stock (hoy), citas (fecha y hora) y órdenes (último cambio). |

## 4. Pruebas existentes que se cambiaron (antes y después)

Ninguna se borró ni se debilitó. Todas fallaban de forma intermitente por datos de **otras suites** que corren en paralelo.

1. **`tests/contract/parts-by-role.test.js`**, prueba `FR_036_buscar_sigue_siendo_por_nombre_o_codigo_y_no_expone_precios` (H-S6-04).
   - Antes: `expect(JSON.stringify(porPrecio.body)).not.toMatch(/precio/i);` (falla si otra suite creó una refacción llamada «Refacción con precio …» cuyo código contiene «320»).
   - Después: no hay claves de precio en el JSON (`/"precio\w*"\s*:/i`) y ningún elemento tiene una propiedad que contenga «precio». Se sigue verificando que la búsqueda por importe no encuentra la refacción.
2. **`tests/integration/tickets.test.js`**, prueba `los folios siguen el formato T000000-AAAA y son consecutivos (SC-003)` (H-S6-03).
   - Antes: `expect(numero(segundo.body.folio)).toBe(numero(primero.body.folio) + 1);`
   - Después: B > A y **todos** los números entre A y B existen en `tickets` (secuencia sin huecos). Si nadie emitió en medio, sigue siendo B = A + 1.

Pruebas nuevas del sprint corregidas en esta sesión: `notifications-stock` (la regex de precios `/120|80/` encontraba esos dígitos dentro de códigos e ids; ahora se exige número suelto y solo en sus propios avisos) y `notifications-read` (comparaba el contador global; ahora compara sobre los avisos presentes antes y después, más la coherencia `noLeidos` = lista). `client-notices` (contrato) se **reforzó** para exigir la hora local en `avisadoEn` (H-S6-06).

## 5. Hallazgos

| Id | Estado | Descripción |
|---|---|---|
| H-S6-01 | Resuelto (sesión 1) | Las pruebas podían llamar a Mercado Pago real si `server/.env` tenía token. `tests/helpers/env.js` fuerza la pasarela simulada. |
| H-S6-02 | Resuelto con excepción autorizada a la regla 7 | Timeouts de 5 s en login e historial. Con la pasarela simulada hubo 3 corridas verdes de 13 s, pero más tarde volvieron (3 corridas con 4 a 7 suites fallidas, ~70 s: `h-s6-02-sin-maxworkers-*.txt`). Causa probable: contención de CPU con 11 procesos de Jest (bcrypt en cada login; `auth.test.js` sola pasó de ~3 s a 5,7 s). Con `maxWorkers: "50%"`: 5 corridas seguidas en verde, sin timeouts. **No** hizo falta `testTimeout`. Riesgo: la suite tarda ahora de 70 a 85 s. |
| H-S6-03 | Resuelto | Folios consecutivos chocaban con otras suites: la prueba verifica la secuencia sin huecos (§4). El código era correcto. |
| H-S6-04 | Resuelto | `parts-by-role` (§4). |
| H-S6-05 | Resuelto (§9, a pedido de Carlos) | El MECHANIC no podía abrir `Routes.serviceOrderDetail`, aunque «Mis órdenes» y el aviso de orden detenida navegan a esa ruta, y veía «Sección no disponible». Venía de antes del Sprint 6. |
| H-S6-06 | Resuelto | `avisadoEn` mostraba la hora UTC como si fuera local (`toISOString`). Ahora usa la hora local guardada. |
| H-S6-07 | Resuelto (§9, a pedido de Carlos) | Mismo patrón `toISOString()` en `services/client.service.js` (`fechaRegistro`) y `services/service_order.service.js` (`fechaEntrega` y fecha del historial): después de las 18:00 (UTC−6) salía el día siguiente. Venía de antes del Sprint 6. |
| Contratos | Resuelto | Decían 401 `NO_AUTENTICADO`; el middleware real responde `SESION_REQUERIDA`. Se corrigieron los contratos. |

## 6. Desviaciones del plan

- T024: en lugar de un `listAllMaintenance()` nuevo se reutiliza `listMaintenance()` sin paginar (misma consulta que la lista de Mantenimientos).
- T052: el esquema de «Clientes por avisar» vive en `validators/notification.validator.js` (no hay `client_notice.validator.js`).
- T020: la campana va en el encabezado propio del `AppShell` (no hay `AppBar`). Si una prueba arma el `AppShell` sin el provider de avisos, la campana no se muestra en lugar de fallar.
- Pruebas de Flutter: en la segunda sesión se escribieron justo después del código, así que **no se vieron fallar antes** (principio VII). Sí se vieron fallar T056 (seed) y el refuerzo de `avisadoEn`.
- T067: el recorrido por API se hizo contra `motorix_v2_test` porque `motorix_v2` todavía no tiene la 007.

## 7. Pendientes para Carlos (cerrados el 2026-11-16)

1. **Respaldo (T065)**: hecho por Carlos el 2026-11-16. El archivo `respaldo-motorix_v2-antes-007-20261116.sql` quedó en `C:\Users\kastr\Documents\MotorixVer2\respaldos\`, fuera del repositorio.
2. **Migración y seed (T066)**: hecho por Carlos el 2026-11-16. La migración 007 y el seed 006 se aplicaron a `motorix_v2` con `database/scripts/aplicar-migraciones.ps1`. Se comprobó al ver la campana de avisos en la app como administrador. No se guardó `s6-migracion-motorix_v2.txt`.
3. **Recorrido en la app y cronómetro (T067, SC-008)**: no se ejecutó, por decisión de Carlos. Lo cubren el recorrido por API (`s6-quickstart-recorrido-api.txt`) y las pruebas de Flutter: 183 al tomar la decisión, 186 en la línea base final. SC-008 (menos de 10 minutos) queda sin medir.

## 8. Riesgos

- La suite del backend tarda de 70 a 85 s con `maxWorkers: "50%"`.
- El seed usa fechas relativas: recárgalo el día de la demostración.
- La base de pruebas crece en cada corrida (las suites no borran sus datos); hoy el centro responde en ~200 ms con ~2000 órdenes.

## 9. Corrección antes del commit (2026-11-16, a pedido de Carlos)

### 9.1 El mecánico abre el detalle de sus órdenes (H-S6-05)

- `client/lib/main.dart`: la regla de rutas pasa de `_puedeAcceder` (privada) a `canAccessRoute` (pública, para probarla), **sin otro cambio de comportamiento**. `Routes.serviceOrderDetail` ahora permite ADMIN, RECEPTIONIST y **MECHANIC**. El mecánico sigue sin acceso a la lista general de órdenes, al alta, al cobro, al ticket ni a las fichas de cliente y vehículo.
- `client/lib/screens/service_order_detail_screen.dart`: para el mecánico, «Cliente» y «Vehículo» ya no llevan enlace (esas fichas lo mandarían a «Sección no disponible»). Conserva «Ver historial del vehículo».
- Ya existía y no se tocó:
  - La pantalla de detalle ya ocultaba al mecánico los precios, el total, el cobro, el ticket y la asignación (Sprints 2 y 5).
  - El backend ya responde 403 `ORDEN_AJENA` si la orden es de otro mecánico o no está asignada, y nunca le envía precios. Lo cubren las pruebas de contrato existentes `service-orders-mechanic` y `mechanic-price-exposure`.
- Error que atraparon las pruebas: en el primer intento puse el `return` del detalle en medio de un grupo de `case`, y clientes, vehículos y citas también quedaban abiertos al mecánico. `route_permissions_test.dart` lo detectó y se corrigió antes de cerrar.
- Pruebas nuevas:
  - `client/test/route_permissions_test.dart` (2). Se vio fallar antes del cambio.
  - En `service_orders_mechanic_test.dart`, 2 pruebas: el mecánico no tiene enlaces a las fichas y recepción sí los conserva. Se escribieron después del cambio.

### 9.2 Fechas en hora local (H-S6-07)

- **Prueba primero**: `server/tests/integration/local-dates.test.js` (2) usa valores fijos a las 23:30 locales. Antes de la corrección falló así:
  - `fechaRegistro`: esperado `2026-11-16`, recibido `2026-11-17`.
  - `fechaEntrega`: esperado `2026-11-16 23:30:00`, recibido `2026-11-17T05:30:00.000Z`.
- `server/services/client.service.js`: `fechaRegistro` usa `toIsoDate` (día local).
- `server/services/service_order.service.js`: `formatDateTime` devuelve `AAAA-MM-DD HH:MM:SS` local (como `avisadoEn` y los pagos). Afecta `fechaEntrega` y la `fecha` del historial.
- `client/lib/screens/service_order_detail_screen.dart`: la fecha de entrega se muestra con el mismo formateador del historial (`DD/MM/AAAA HH:MM`). Antes `Formatters.date` la deformaba (por ejemplo `17T05:30:00.000Z/11/2026`). El historial ya interpretaba bien los dos formatos.
- Prueba nueva en `service_orders_mechanic_test.dart`: «la fecha de entrega se muestra en hora local con día y hora». Para eso se agregó a la fábrica `_orden` de esa prueba el parámetro opcional `fechaEntrega`; las pruebas existentes no cambian.

### 9.3 Resultado

| Comando | Resultado |
|---|---|
| `npm run lint` | sin errores (`docs/evidencias/sprint 6/s6-correccion-lint.txt`) |
| `npm test` (1 vez) | 79/79 suites, 649/649 pruebas, 16,5 s, sin timeouts ni aviso de worker (`s6-correccion-npm.txt`) |
| `flutter analyze` | sin problemas |
| `flutter test` | 183/183 (`s6-correccion-flutter.txt`) |

Ninguna prueba existente se borró ni se debilitó.

## 10. Campana que no se veía en la web (2026-11-17, a pedido de Carlos)

- **Síntoma**: en `localhost:8080` (abierto con `arrancar.bat`) el administrador no veía la campana, aunque los datos del seed 006 sí estaban en `motorix_v2`.
- **Causa**: `arrancar.bat` → `arrancar.ps1` → `scripts/web-server.cjs` sirve la compilación ya hecha de `client/build/web`, y solo la regenera con `-RebuildWeb`. Esa compilación era del 14 de octubre, anterior al Sprint 6. El código sí tenía la campana en el header, con un solo diseño para cualquier ancho; no había una versión aparte para pantallas angostas.
- **Corrección 1**: se volvió a compilar con `flutter build web` (2026-11-17). El nuevo `main.dart.js` ya contiene la campana. `client/build/` está ignorado por git, así que esto no entra al commit.
- **Corrección 2 (visual)**: la prueba nueva mostró que, en 1920 px, la campana quedaba a la mitad del header (x ≈ 460), porque la fila no tenía espacio flexible. En `client/lib/widgets/app_shell.dart`, el título y el buscador ahora van en un `Expanded`. Así la campana, el usuario y el rol quedan pegados a la derecha. Sigue de acuerdo con `docs/design-system.md` §7 y §8.5.1 (la campana a la izquierda del usuario).
- **Prueba nueva**: en `client/test/notification_bell_test.dart`, «con sesión ADMIN en pantalla ancha … la campana está en el encabezado», para 1920×1080, 1366×768 y 1280×720 (3 casos). Comprueba que la campana aparece con su insignia, que el header no se desborda, que está en la franja superior, en el último cuarto derecho y antes del usuario. Se vio fallar antes del cambio de diseño (x = 460 < 1440).
- **Resultado**: `flutter analyze` sin problemas; `flutter test` 186/186 (`docs/evidencias/sprint 6/s6-campana-flutter.txt`). Ninguna prueba existente se borró ni se debilitó.

### 10.1 Error de conexión al iniciar sesión tras la recompilación (2026-11-17)

- **Síntoma**: después de la recompilación de §10, el inicio de sesión en `localhost:8080` mostraba «No se pudo conectar con el servidor…».
- **Causa (error del agente)**: se compiló con `flutter build web` sin `--dart-define=API_BASE_URL=/api`. Así, la app pedía la API a `http://localhost:3000/api`, otro origen. El backend no tiene CORS, por diseño: `scripts/web-server.cjs` reenvía `/api` desde el mismo origen. Por eso el navegador bloqueaba la petición. El backend estaba sano: `POST /api/auth/login` devolvía 200, tanto en el puerto 3000 como a través de 8080.
- **Corrección**: se volvió a compilar con `flutter build web --dart-define=API_BASE_URL=/api`. Además, `arrancar.ps1 -RebuildWeb` ahora pasa ese mismo parámetro; antes tenía el mismo defecto.
- **Segundo intento fallido (error del agente)**: la compilación se lanzó desde la terminal Git Bash. Bash convierte un argumento que empieza con `/` en una ruta de Windows, así que `/api` se convirtió en `C:/Program Files/Git/api`. En el navegador, la app pedía `file:///C:/Program%20Files/Git/api/auth/login`, que falla con 503. Se volvió a compilar desde PowerShell. Comprobado en Chrome: `POST http://localhost:8080/api/auth/login` responde 200, el panel de recepción carga y la campana aparece arriba a la derecha con su insignia. `arrancar.ps1` corre en PowerShell, así que no tiene este problema.