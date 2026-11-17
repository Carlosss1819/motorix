# Plan de implementación: Notificaciones internas

**Rama**: `006-notificaciones-internas` | **Fecha**: 2026-11-16 | **Spec**: [spec.md](./spec.md)

**Input**: especificación de `specs/006-notificaciones-internas/spec.md`, con las aclaraciones de la sesión 2026-11-16 (7 respuestas de Carlos, su ajuste de «orden detenida» y las decisiones del agente) y las correcciones de la revisión de checklists.

## Resumen

El sprint agrega un **centro de notificaciones** en el encabezado y una lista **«Clientes por avisar»**. Los avisos **no se guardan**: un servicio nuevo (`notification.service.js`) los calcula en cada consulta, reutilizando las reglas que ya existen:

- mantenimientos: `calcMaintenanceState` (`server/utils/maintenance-status.js`) con el kilometraje vigente del vehículo, igual que la lista de Mantenimientos;
- stock: la regla de stock bajo `WHERE_STOCK_BAJO` (`stock_current <= stock_min AND stock_min > 0`, sin filtrar por activa, igual que hoy), la misma del panel y del filtro de Refacciones;
- citas: estados `PROGRAMADA` y `RECIBIDA` de la fecha, igual que el bloque de citas del panel;
- órdenes detenidas: `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` y `ESPERANDO_REFACCION` sin cambio de estado por más de N × 24 horas (N = 3, `NOTIF_ORDEN_DETENIDA_DIAS`).

Solo se guardan dos cosas, en dos tablas nuevas de la migración `007`: la **lectura** de cada aviso por usuario (`notification_reads`) y el **aviso a cliente** por hecho (`client_notices`). El filtro por rol y por asignación lo hace el servidor. En Flutter se agregan la campana en el `AppBar` del `AppShell`, el panel de avisos y la sección «Clientes por avisar» en el menú lateral.

## Contexto técnico

**Lenguaje/Versión**: Node 24 (LTS) con ES Modules; Dart/Flutter (Material 3).

**Dependencias principales**: Express, mysql2, Zod, jsonwebtoken (servidor); Provider y las librerías de `docs/design-system.md` (cliente). **Sin dependencias nuevas.**

**Almacenamiento**: MySQL 8 local, InnoDB y `utf8mb4`: `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas).

**Pruebas**: Jest (unitarias) y Jest + supertest (contrato e integración) contra `motorix_v2_test`; `flutter test`. Línea base: **64 suites y 545 pruebas** del backend y **155** de Flutter.

**Plataforma**: servidor local en Windows; cliente Flutter de escritorio y web.

**Tipo de proyecto**: aplicación web, cliente Flutter más API REST.

**Metas de rendimiento**: la consulta de avisos de un usuario responde en menos de 1 s con 10 veces el volumen de los datos de ejemplo (SC-006). Se logra con consultas acotadas por índices existentes (`idx_service_orders_mechanic_status`, `idx_appointments_date_time`, `idx_order_status_history_order`) y un solo `SELECT` de lecturas por usuario.

**Restricciones**: los avisos no llevan importes (FR-012); sin consultas por intervalo (FR-017); migración aditiva `007`; seed idempotente `006` con ids 60001 a 60099.

**Escala**: taller pequeño; decenas a cientos de avisos como máximo; sin paginación (FR-007a).

## Revisión de la constitución

| Principio | Cómo se cumple | Estado |
|---|---|---|
| I. Alcance | Sprint 6 dentro del alcance oficial (enmienda 1.1.0). Sin funciones fuera del insumo; las aclaraciones de Carlos están en la spec. `docs/project-context.md` §6.12 se actualiza (FR-028). | ✅ |
| II. Arquitectura | Lógica en `services/notification.service.js` y `services/client_notice.service.js`; consultas en `models/`; Flutter solo habla con la API. | ✅ |
| III. Stack y base local | Sin dependencias nuevas; migración `007` aditiva y numerada (dos tablas nuevas, sin tocar tablas existentes); seed `006` idempotente con datos para la demostración; pruebas en `motorix_v2_test`. | ✅ |
| IV. Seguridad | `authenticate` en todas las rutas; `authorize('ADMIN','RECEPTIONIST')` en clientes por avisar; filtro por rol y asignación en el servicio; sin importes en avisos; FR-030 no revela existencia de objetos. | ✅ |
| V. Reglas de negocio | Se reutilizan las reglas existentes (mantenimiento, stock, citas); RN-10: los avisos no se copian. | ✅ |
| VI. API y errores | Formato de respuesta y de error existente (`sendOk`, `HttpError` con `codigo`); códigos nuevos `YA_AVISADO` y `HECHO_NO_VIGENTE`. | ✅ |
| VII. Pruebas | Pruebas primero: unitarias de las claves y criterios, contrato de los endpoints, integración por rol y rendimiento. Línea base intacta. | ✅ |
| VIII. UX/UI | Campana, panel y lista con estados de carga, vacío y error de `docs/design-system.md`; se documenta en el mismo sprint. | ✅ |

**Resultado**: sin violaciones. Se repite la revisión después del diseño (abajo): sin cambios.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/006-notificaciones-internas/
├── spec.md
├── plan.md              # este archivo
├── research.md          # decisiones R-01 a R-10
├── data-model.md        # tablas nuevas, claves y avisos calculados
├── quickstart.md        # validación de punta a punta
├── contracts/
│   ├── README.md
│   ├── notifications.md
│   ├── client-notices.md
│   └── ui-flutter.md
├── checklists/
└── tasks.md             # lo genera /speckit-tasks
```

### Código fuente (archivos que el sprint va a tocar)

```text
database/
├── migrations/007_notificaciones_internas.sql          # nuevo
├── seeds/006_ejemplos_notificaciones.sql               # nuevo
└── README.md                                           # sección Sprint 6

server/
├── config/env.js                                       # NOTIF_ORDEN_DETENIDA_DIAS (3)
├── .env.example                                        # documentar la variable
├── utils/notice-keys.js                                # nuevo: claves de aviso y de hecho (funciones puras)
├── models/notification.js                              # nuevo: consultas de origen y lecturas
├── models/client_notice.js                             # nuevo
├── services/notification.service.js                    # nuevo
├── services/client_notice.service.js                   # nuevo
├── controllers/notifications.controller.js             # nuevo
├── controllers/client_notices.controller.js            # nuevo
├── validators/notification.validator.js                # nuevo (clave)
├── routes/notifications.routes.js                      # nuevo
├── routes/client_notices.routes.js                     # nuevo
├── routes/index.js                                     # montar /notifications y /client-notices
└── tests/
    ├── unit/notice-keys.test.js
    ├── unit/stalled-order.test.js
    ├── contract/notifications.test.js
    ├── contract/client-notices.test.js
    ├── integration/notifications-by-role.test.js
    ├── integration/notifications-consistency.test.js
    ├── integration/notifications-read.test.js
    ├── integration/client-notices.test.js
    ├── integration/notifications-performance.test.js
    └── integration/seed-006.test.js

client/lib/
├── models/notification.dart                            # nuevo
├── models/client_notice.dart                           # nuevo
├── services/notifications_service.dart                 # nuevo
├── services/client_notices_service.dart                # nuevo
├── providers/notifications_provider.dart               # nuevo
├── providers/client_notices_provider.dart              # nuevo
├── widgets/notification_bell.dart                      # nuevo: campana + panel
├── screens/client_notices_screen.dart                  # nuevo
├── widgets/app_shell.dart                              # campana en el AppBar, sección nueva, refresco al navegar
├── utils/app_routes.dart                               # ruta /client-notices
├── screens/appointments_screen.dart                    # aceptar una fecha inicial (destino del aviso de cita)
└── main.dart                                           # registrar providers
client/test/
├── notification_bell_test.dart
├── client_notices_screen_test.dart
└── fake_notifications_service.dart

docs/project-context.md (§6.12), docs/design-system.md (campana, panel, lista)
```

## Decisiones clave del diseño

Detalle y alternativas en [research.md](./research.md).

1. **Cálculo al consultar (R-01)**: cada `GET` calcula los avisos con consultas acotadas; no hay tabla de avisos ni trabajo programado.
2. **Reutilización (R-02)**: `calcMaintenanceState` y la condición SQL de stock bajo se reutilizan tal cual; el criterio de citas del panel se extrae a una constante compartida (`ACTIVE_APPOINTMENT_STATUSES`) para que no diverjan.
3. **Citas vencidas (R-03)**: antes de calcular, el servicio llama a `markExpiredAsNotPresented()`, la misma detección perezosa que usa la agenda; así una cita `PROGRAMADA` cuya hora ya pasó no aparece como «cita de hoy».
4. **Orden detenida (R-04)**: fecha de referencia = `MAX(order_status_history.changed_at)` o `service_orders.created_at`; detenida si `NOW() - referencia > N × 24 h`. N en `config.notifications.stalledOrderDays` (variable `NOTIF_ORDEN_DETENIDA_DIAS`, 3 por defecto, entero > 0).
5. **Claves (R-05)**: funciones puras en `utils/notice-keys.js`: `MANT_PROXIMO:<id>:<objetivo>`, `MANT_VENCIDO:<id>:<objetivo>`, `STOCK_BAJO:<id>`, `STOCK_AGOTADO:<id>`, `CITA_HOY:<id>:<fecha>`, `ORDEN_DETENIDA:<id>:<estado>`. Objetivo = `<fecha objetivo o ->|<km objetivo o ->`. Hechos de clientes: `ORDEN:<id>`, `CITA:<id>`, `MANT:<id>:<objetivo>`.
6. **Lecturas (R-06)**: `POST /notifications/read` solo inserta (`INSERT IGNORE`) si la clave está entre los avisos actuales del usuario; si no, responde 204 sin guardar (FR-030).
7. **Clientes por avisar (R-07)**: `client_notices.fact_key` único; el `INSERT` atrapa `ER_DUP_ENTRY` y responde 409 `YA_AVISADO` (cubre la marcación concurrente sin candados). Una clave que no está en la lista actual responde 404 `HECHO_NO_VIGENTE`.
8. **Contador (R-08)**: `GET /notifications/count` (ligero) se llama al iniciar sesión y en cada cambio de sección del `AppShell`; `GET /notifications` al abrir el panel. Sin `Timer`.
9. **Rendimiento (R-09)**: prueba de integración que inserta 10× el volumen del seed y mide < 1 s.
10. **Seed (R-10)**: `006_ejemplos_notificaciones.sql` con ids 60001 a 60099, fechas relativas a `CURDATE()`/`NOW()` y `INSERT ... ON DUPLICATE KEY UPDATE` para refrescar fechas sin duplicar; la cita de hoy a las 23:30 para que no pase a `NO_PRESENTADA` durante la demostración.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Los números del centro y del panel difieren por una cita `PROGRAMADA` vencida que el panel aún cuenta (el panel no llama a la detección perezosa). | El centro llama a `markExpiredAsNotPresented()` y lo persiste; la prueba de coherencia (SC-003) consulta el panel después del centro. Se documenta como hallazgo menor del panel (no se cambia el panel). |
| El seed con fechas relativas deja de generar avisos si se carga un día y se demuestra otro. | Las fechas se calculan al cargar; el quickstart pide volver a cargar el seed el día de la demostración (es idempotente). |
| Ids 60001+ hacen saltar el AUTO_INCREMENT de las tablas tocadas. | Inofensivo; ya ocurre con el Sprint 5. Las pruebas cuentan por claves propias del seed (`NOT-`, «[Sprint 6]»), no por rangos. |
| Pruebas dependientes de la hora (órdenes detenidas, citas de hoy). | Las pruebas fijan fechas relativas con `NOW()` en SQL y el umbral N, sin depender del reloj del día de la corrida. |
| El volumen de avisos crece sin paginación. | Escala de un taller pequeño; la prueba de rendimiento con 10× protege el umbral. |

## Registro de complejidad

Sin violaciones de la constitución; no aplica.

## Revisión de la constitución después del diseño

Sin cambios: el diseño agrega dos tablas y dos grupos de rutas, sin dependencias nuevas ni cambios a tablas existentes. ✅

## Siguiente paso

`/speckit-tasks`.
