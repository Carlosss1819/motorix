# Plan de Implementación: Gestión de Citas y Órdenes de Servicio

**Rama**: `002-citas-ordenes-servicio` | **Fecha**: 2026-10-12 | **Especificación**:
[spec.md](spec.md)

**Entrada**: Especificación de la funcionalidad desde `/specs/002-citas-ordenes-servicio/spec.md`

## Resumen

Segundo sprint del MVP de Motorix: agregar el módulo de citas de recepción y el de
órdenes de servicio, apoyándose en los clientes, vehículos y usuarios ya existentes del
Sprint 1. Recepción registra, consulta, modifica y cancela citas, las marca como
recibidas y deriva de ellas una orden de servicio; la orden nace siempre en `RECIBIDO`,
se asocia a cliente y vehículo (obligatorios), admite asignación de mecánico opcional y
avanza por su secuencia de estados hasta `ENTREGADO`. El mecánico ve solo sus órdenes y
registra diagnóstico, servicios con su mano de obra, repuestos y recomendaciones.

Enfoque técnico: se conserva el stack ya validado del Sprint 1 (Node.js LTS + Express
en ES Modules con capa `services/`, `mysql2` directo, migraciones SQL inmutables,
Flutter + Material Design 3 con Provider, `zod`, Jest + supertest y `flutter test`), sin
dependencias nuevas. La lógica de este sprint se concentra en dos servicios
(`appointment.service.js` y `serviceOrder.service.js`), con una máquina de transiciones
de estado y autorización por transición en el backend. Detalle de decisiones en
[research.md](research.md).

## Contexto Técnico

**Language/Version**: Dart (Flutter 3.x) en el frontend; JavaScript (Node.js LTS) en el
backend, siempre en ES Modules (`"type": "module"`)

**Primary Dependencies**: Backend: Express, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`
(sin dependencias nuevas). Frontend: Flutter Material Design 3, Provider,
`google_fonts`, `data_table_2`, `lucide_icons_flutter` (las mismas del Sprint 1)

**Storage**: MySQL local (InnoDB, `utf8mb4`, llaves foráneas); nuevas tablas
`appointments`, `service_orders`, `order_status_history`, `order_services`,
`order_labor`, `order_parts` en `database/migrations/002_citas_ordenes_servicio.sql`
(script nuevo e inmutable, la migración 001 no se toca); datos de ejemplo en
`database/seeds/002_ejemplos_citas_ordenes.sql` (idempotentes, ids fijos); base de
pruebas `motorix_v2_test`

**Testing**: Jest (unitarias de la máquina de estados y validadores) y Jest + supertest
(integración y contrato) en el backend contra `motorix_v2_test`; `flutter test` en el
frontend (providers y widgets nuevos)

**Target Platform**: Aplicación Flutter con prioridad en escritorio (Windows/web) y
backend Node.js corriendo en la máquina local de cada integrante

**Project Type**: Aplicación web (frontend + backend + scripts de base de datos)

**Performance Goals**: Flujo completo del sprint (cita → orden → diagnóstico → servicios
→ terminado → entregado) en una sola pasada y sin errores (SC‑005); creación de una
orden en menos de 3 minutos (SC‑001); transiciones de interfaz de 150/200/250 ms según
`docs/design-system.md`

**Constraints**: Permisos y transiciones validados en backend (RN‑05, RN‑15); sin
secretos en el repositorio; sin más de una librería de componentes de UI (0 nuevas);
solo el backend accede a MySQL; sin dependencias nuevas sin justificar

**Scale/Scope**: 6 tablas nuevas, ~7 pantallas nuevas (citas, detalle de cita, órdenes,
detalle de orden, formulario de orden, panel de recepción), 3 roles, 6 historias de
usuario; equipo local (sin carga multiusuario concurrente en el MVP)

## Verificación de la Constitución

*GATE: Debe pasar antes de la investigación de la Fase 0. Se re-evalúa después del
diseño de la Fase 1.*

| # | Gate (constitución) | Estado | Evidencia |
|---|---------------------|--------|-----------|
| I | Alcance, MVP y fuente de verdad | ⚠ PASS con acción correctiva | Alcance limitado al Sprint 2 (citas y órdenes; historial de pagos/inventario/tickets/dashboard quedan fuera); trazabilidad HU1–HU6 → FR‑001…FR‑022 → SC‑001…SC‑008. **Acción**: las referencias RN de `spec.md` no coinciden con la numeración de `docs/project-context.md` §13 y apuntan a `docs/reglas.md`, que no numera las reglas; deben corregirse (tabla de mapeo en R‑11 de [research.md](research.md)) |
| II | Arquitectura con responsabilidades separadas | PASS | Se reutilizan `client/`, `server/` y `database/`; nuevos archivos en las capas ya existentes (`models/`, `services/`, `controllers/`, `routes/`, `validators/`); toda regla de transición, asignación y permisos vive en `services/`, nunca en controladores ni widgets |
| III | Stack tecnológico y base de datos local | PASS | Sin dependencias nuevas; ES Modules; scripts SQL numerados e inmutables en `database/migrations/` (002) e idempotentes en `database/seeds/`; conexión solo por variables de entorno; InnoDB/`utf8mb4`/FK; solo el backend toca MySQL |
| IV | Seguridad | PASS | Endpoints protegidos con `authenticate` + `authorize`; validación de payloads con `zod`; permisos por transición comprobados en backend (RN‑15); mensajes de error en español sin trazas; sin secretos |
| V | Integridad de las reglas de negocio | PASS | RN‑01/RN‑02 (orden exige cliente y vehículo existentes), RN‑03/RN‑04 (kilometraje de entrada validado contra la última orden, con corrección explícita), RN‑05 (solo usuarios autorizados modifican órdenes), RN‑06 (repuestos ligados a la orden; salida de inventario queda para el Sprint 3), RN‑09 (orden `ENTREGADO` no se modifica ni elimina) |
| VI | API consistente y manejo de errores | PASS | Rutas nuevas coherentes con las del Sprint 1 (`/api/appointments`, `/api/service-orders`), respuestas JSON en español con claves en español, códigos HTTP apropiados (`409` para conflictos de cita), errores centralizados (ver [contracts/](contracts/)) |
| VII | Pruebas | PASS | Jest + supertest contra `motorix_v2_test`; pruebas unitarias de la máquina de estados (CA‑8) y de validadores; `flutter test` para providers y widgets nuevos; ninguna historia se da por terminada solo con interfaz |
| VIII | UX/UI profesional y sencilla | PASS | Pantallas nuevas sobre `docs/design-system.md` (Material 3 con `ThemeData` propio y tokens, sin valores sueltos); confirmaciones obligatorias para cancelar citas y para entregar/cambiar estado de órdenes; estados vacío/cargando/error/éxito; 0 librerías extra de componentes |

**Resultado del gate inicial**: PASS con 1 acción correctiva documentada (gate I).

**Re-evaluación post‑diseño (Fase 1)**: PASS. Los artefactos generados
([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/) y
[quickstart.md](quickstart.md)) mantienen la separación de capas, no introducen
dependencias nuevas ni tecnología fuera del stack permitido, y ninguna decisión de
diseño viola los principios I–VIII. La acción correctiva del gate I sigue pendiente:
corregir las referencias RN de `spec.md` (ver R‑11 en [research.md](research.md)).

## Estructura del Proyecto

### Documentación (esta funcionalidad)

```text
specs/002-citas-ordenes-servicio/
├── plan.md              # Este archivo (salida de /speckit.plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1 (contrato REST)
│   ├── README.md
│   ├── appointments.md
│   └── service-orders.md
├── checklists/
│   └── requirements.md  # Checklist de calidad de la especificación
└── tasks.md             # Salida de /speckit.tasks (NO la crea /speckit.plan)
```

### Código fuente (raíz del repositorio)

```text
client/                    # Frontend Flutter (se agregan archivos, no se mueven)
├── lib/
│   ├── models/            # + appointment.dart, service_order.dart
│   ├── providers/         # + appointments_provider.dart, service_orders_provider.dart
│   ├── services/          # + appointments_service.dart, service_orders_service.dart
│   ├── screens/           # + appointments, appointment_form, service_orders,
│   │                      #   service_order_form, service_order_detail, reception_panel
│   ├── widgets/           # + chips de estado de orden y de cita (reutilizables)
│   └── utils/             # app_routes.dart y app_shell.dart ampliados por rol
└── test/                  # flutter test (providers y widgets nuevos)

server/                    # Backend Node.js + Express (ES Modules)
├── models/                # + appointment.js, service_order.js, order_items.js
├── services/              # + appointment.service.js, service_order.service.js
│                          #   (transiciones, asignación y permisos aquí)
├── controllers/           # + appointments.controller.js, service_orders.controller.js
├── routes/                # + appointments.routes.js, service_orders.routes.js (index.js ampliado)
├── validators/            # + appointment.validator.js, service_order.validator.js
└── tests/
    ├── unit/              # + transiciones de estado, validadores
    ├── integration/       # + appointments, service-orders
    └── contract/          # + appointments, service-orders

database/                  # Esquema y datos versionados
├── migrations/            # + 002_citas_ordenes_servicio.sql (nuevo, inmutable)
├── seeds/                 # + 002_ejemplos_citas_ordenes.sql (idempotente)
└── scripts/               # sin cambios (aplican todo lo nuevo automáticamente)
```

**Decisión de estructura**: se conserva la estructura de aplicación web del Sprint 1
(frontend, backend y `database/` separados, sin carpeta `src/` intermedia). El Sprint 2
solo añade archivos dentro de las capas ya existentes: no se crean proyectos ni capas
nuevas, y la lógica de negocio exclusiva de este sprint vive en
`server/services/appointment.service.js` y `server/services/service_order.service.js`.

## Registro de Complejidad

> Completo ÚNICAMENTO si la Verificación de la Constitución tiene violaciones que
> deben justificarse.

| Violación | Por qué se necesita | Alternativa más simple rechazada porque |
|-----------|---------------------|------------------------------------------|
| — | Sin violaciones de arquitectura; la acción correctiva del gate I es documental (corregir las referencias RN de `spec.md`) | — |
