# Plan de Implementación: Historial, Mantenimiento e Inventario

**Rama**: `003-historial-inventario` | **Fecha**: 2026-10-13 | **Especificación**:
[spec.md](spec.md)

**Entrada**: Especificación de la funcionalidad desde `/specs/003-historial-inventario/spec.md`

## Resumen

Tercer sprint del MVP de Motorix: el historial de servicios por vehículo (derivado de
las órdenes terminadas, sin tablas de duplicado), el mantenimiento preventivo por
vehículo y tipo de servicio (estado calculado «normal / próximo / vencido», renovación
al marcar «servicio realizado») y el inventario de refacciones con catálogo, movimientos
de entrada/salida/ajuste, ligado a las órdenes del Sprint 2 y con alertas de stock bajo.

Enfoque técnico: se conserva el stack validado (Node.js LTS + Express en ES Modules,
capa `services/`, `mysql2` directo, Flutter Material 3 con Provider, `zod`, Jest +
supertest y `flutter test`), sin dependencias nuevas. La lógica del sprint se concentra
en tres servicios (`vehicle_history.service.js`, `maintenance.service.js` y
`part.service.js`), con un módulo puro de cálculo de estados de mantenimiento
(`utils/maintenance-status.js`) y bloqueos de fila (`SELECT … FOR UPDATE`) para que el
stock nunca quede negativo. La migración `003_historial_mantenimiento_inventario.sql`
crea `maintenance`, `parts` e `inventory_movements` y **altera** `order_parts`
(columna `part_id` nullable); los scripts 001 y 002 no se tocan. Detalle de decisiones
en [research.md](research.md).

## Contexto Técnico

**Language/Version**: Dart (Flutter 3.x) en el frontend; JavaScript (Node.js LTS) en el
backend, siempre en ES Modules (`"type": "module"`)

**Primary Dependencies**: Backend: Express, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`
(sin dependencias nuevas). Frontend: Flutter Material Design 3, Provider,
`google_fonts`, `data_table_2`, `lucide_icons_flutter` (las mismas de los sprints 1 y 2)

**Storage**: MySQL local (InnoDB, `utf8mb4`, llaves foráneas); nuevas tablas
`maintenance`, `parts`, `inventory_movements` y alteración de `order_parts` en
`database/migrations/003_historial_mantenimiento_inventario.sql` (script nuevo e
inmutable; la alteración de `order_parts` es una columna agregada, no una edición de la
migración 002); datos de ejemplo en `database/seeds/003_ejemplos_historial_inventario.sql`
(idempotentes, ids fijos); base de pruebas `motorix_v2_test`

**Testing**: Jest (unitarias de `maintenance-status.js`, validadores y reglas de stock) y
Jest + supertest (integración y contrato) contra `motorix_v2_test`; `flutter test` en el
frontend (providers y widgets nuevos)

**Target Platform**: Aplicación Flutter con prioridad en escritorio (Windows/web) y
backend Node.js corriendo en la máquina local de cada integrante

**Project Type**: Aplicación web (frontend + backend + scripts de base de datos)

**Performance Goals**: historial de un vehículo con 10+ servicios en menos de 5 segundos
(SC‑001); recepción identifica los próximos mantenimientos de la semana en menos de 30
segundos (SC‑003); el inventario marca el stock bajo visible en menos de 10 segundos
(SC‑008); transiciones de interfaz de 150/200/250 ms según `docs/design-system.md`

**Constraints**: permisos y reglas de stock validados en backend (RN‑8, RN‑15); sin
secretos en el repositorio; 0 librerías nuevas de UI; solo el backend accede a MySQL;
sin dependencias nuevas sin justificar; scripts de migración inmutables y seeds
idempotentes

**Scale/Scope**: 3 tablas nuevas + 1 alterada, ~6 pantallas nuevas (historial de
vehículo, mantenimientos, formulario de mantenimiento, inventario, detalle de
refacción, formulario de refacción), 3 roles, 8 historias de usuario; equipo local
(sin carga multiusuario concurrente en el MVP, aunque el stock se protege con
bloqueos de fila)

## Verificación de la Constitución

*GATE: Debe pasar antes de la investigación de la Fase 0. Se re-evalúa después del
diseño de la Fase 1.*

| # | Gate (constitución) | Estado | Evidencia |
|---|---------------------|--------|-----------|
| I | Alcance, MVP y fuente de verdad | PASS | Alcance limitado al Sprint 3 (historial, mantenimiento e inventario; pagos, tickets y dashboard quedan fuera); trazabilidad HU1–HU8 → FR‑001…FR‑031 → SC‑001…SC‑009; las referencias RN del `spec.md` (RN‑6, RN‑7, RN‑8, RN‑10, RN‑11, RN‑12, RN‑15) **ya coinciden** con la numeración de `docs/project-context.md` §13 (la corrección del Sprint 2 cerró el conflicto R‑11) |
| II | Arquitectura con responsabilidades separadas | PASS | Se reutilizan `client/`, `server/` y `database/`; nuevos archivos solo en las capas existentes; toda regla de stock, renovación de mantenimiento y cálculo de estado vive en `services/` y en módulos puros de `utils/`, nunca en controladores ni widgets |
| III | Stack tecnológico y base de datos local | PASS | Sin dependencias nuevas; ES Modules; script inmutable `003_…` en `database/migrations/` y seed idempotente `003_…`; la alteración de `order_parts` agrega una columna sin editar la migración 002; InnoDB/`utf8mb4`/FK; solo el backend toca MySQL |
| IV | Seguridad | PASS | Endpoints con `authenticate` + `authorize` (matriz: inventario y ajustes solo `ADMIN`; mantenimientos `ADMIN`/`MECHANIC`; historial los 3 roles); validación con `zod`; sin secretos; mensajes en español |
| V | Integridad de las reglas de negocio | PASS | RN‑6/RN‑7 (refacción ligada a la orden con su salida de inventario), RN‑8 (stock negativo imposible, con bloqueo de fila), RN‑10 (historial derivado, sin tabla de duplicado), RN‑11/RN‑12 (mantenimiento por fecha y/o kilometraje con intervalos configurables), RN‑15 (permisos validados en backend) |
| VI | API consistente y manejo de errores | PASS | Rutas nuevas coherentes con las de los sprints 1 y 2 (`/api/parts`, `/api/maintenance`, `GET /api/vehicles/:id/history`), claves en español, códigos 400/401/403/404/409, errores centralizados (ver [contracts/](contracts/)) |
| VII | Pruebas | PASS | Jest + supertest contra `motorix_v2_test`; unitarias de `maintenance-status.js` y de reglas de stock (CA‑8); `flutter test` para providers y widgets; ninguna historia se da por terminada solo con interfaz |
| VIII | UX/UI profesional y sencilla | PASS | Pantallas nuevas sobre `docs/design-system.md` (Material 3 con tokens, sin valores sueltos); confirmación obligatoria para retirar refacciones y marcar mantenimientos como realizados; estados vacío/cargando/error; 0 librerías extra |

**Resultado del gate inicial**: PASS (sin acciones correctivas; el conflicto R‑11 del
Sprint 2 quedó cerrado con la numeración RN ya alineada).

**Re-evaluación post‑diseño (Fase 1)**: PASS. Los artefactos generados
([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/) y
[quickstart.md](quickstart.md)) mantienen la separación de capas, no introducen
dependencias ni tecnologías nuevas, y ninguna decisión de diseño viola los principios
I–VIII. La alteración de `order_parts` se resuelve como columna nueva en la migración
003 (los scripts aplicados no se editan, Principio III).

## Estructura del Proyecto

### Documentación (esta funcionalidad)

```text
specs/003-historial-inventario/
├── plan.md              # Este archivo (salida de /speckit.plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1 (contrato REST)
│   ├── README.md
│   ├── history.md       # Historial del vehículo
│   ├── maintenance.md   # Mantenimientos preventivos
│   └── parts.md         # Refacciones, movimientos y uso en órdenes
├── checklists/
│   └── requirements.md  # Checklist de calidad de la especificación
└── tasks.md             # Salida de /speckit.tasks (NO la crea /speckit.plan)
```

### Código fuente (raíz del repositorio)

```text
client/                    # Frontend Flutter (se agregan archivos, no se mueven)
├── lib/
│   ├── models/            # + part.dart, maintenance.dart, vehicle_history.dart
│   ├── providers/         # + parts_provider.dart, maintenance_provider.dart,
│   │                      #   vehicle_history_provider.dart
│   ├── services/          # + parts_service.dart, maintenance_service.dart,
│   │                      #   vehicle_history_service.dart
│   ├── screens/           # + vehicle_history, maintenance, maintenance_form,
│   │                      #   parts, part_form, part_detail
│   └── utils/             # app_routes.dart y app_shell.dart ampliados por rol
└── test/                  # flutter test (providers y widgets nuevos)

server/                    # Backend Node.js + Express (ES Modules)
├── models/                # + part.js, inventory_movement.js, maintenance.js
├── services/              # + part.service.js, maintenance.service.js,
│                          #   vehicle_history.service.js (reglas aquí)
├── controllers/           # + parts.controller.js, maintenance.controller.js,
│                          #   vehicle_history.controller.js
├── routes/                # + parts.routes.js, maintenance.routes.js; el historial
│                          #   se agrega a vehicles.routes.js (GET /:id/history)
├── validators/            # + part.validator.js, maintenance.validator.js
├── utils/                 # + maintenance-status.js (módulo puro, estilo
│                          #   order-transitions.js)
└── tests/
    ├── unit/              # + maintenance-status, reglas de stock, validadores
    ├── integration/       # + parts, maintenance, vehicle-history, order-parts
    └── contract/          # + parts, maintenance, vehicle-history

database/                  # Esquema y datos versionados
├── migrations/            # + 003_historial_mantenimiento_inventario.sql
│                          #   (nuevo e inmutable; crea 3 tablas y altera order_parts)
├── seeds/                 # + 003_ejemplos_historial_inventario.sql (idempotente)
└── scripts/               # sin cambios (aplican todo lo nuevo automáticamente)
```

**Decisión de estructura**: se conserva la estructura de aplicación web de los sprints
anteriores. El Sprint 3 solo añade archivos dentro de las capas existentes; la
autorización del contenido de la orden se amplía en el archivo de rutas ya existente
(`service_orders.routes.js`) para incluir `RECEPTIONIST` en refacciones (FR‑026), y el
historial se publica como subrecurso de vehículos (`GET /api/vehicles/:id/history`).

## Registro de Complejidad

> Completo ÚNICAMENTO si la Verificación de la Constitución tiene violaciones que
> deben justificarse.

| Violación | Por qué se necesita | Alternativa más simple rechazada porque |
|-----------|---------------------|------------------------------------------|
| — | Sin violaciones de arquitectura ni de alcance; los gates I–VIII pasan sin acciones correctivas | — |
