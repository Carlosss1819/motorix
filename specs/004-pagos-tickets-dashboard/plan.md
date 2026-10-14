# Plan de Implementación: Pagos, Tickets y Dashboard

**Rama**: `004-pagos-tickets-dashboard` | **Fecha**: 2026-10-13 | **Especificación**:
[spec.md](spec.md)

**Entrada**: Especificación de la funcionalidad desde `/specs/004-pagos-tickets-dashboard/spec.md`

## Resumen

Cuarto y último sprint del MVP de Motorix: el cobro de las órdenes de servicio (un pago
por orden, previo a la entrega), los pagos por Mercado Pago en sandbox con confirmación
manual, el ticket de servicio imprimible y el panel de control del administrador con los
indicadores reales del taller.

Enfoque técnico: se conserva el stack validado (Node.js LTS + Express en ES Modules,
capa `services/`, `mysql2` directo, Flutter Material 3 con Provider, `zod`, Jest +
supertest y `flutter test`), sin dependencias nuevas. La lógica del sprint se concentra
en dos servicios (`payment.service.js` y `dashboard.service.js`), con el cálculo del
total de la orden como módulo puro (`utils/order-total.js`) y la integración de
Mercado Pago aislada tras una interfaz propia (`services/payment_gateway/`) con modo
sandbox y respaldo simulado. La migración `004_pagos_tickets_dashboard.sql` crea las
tablas `payments` y `tickets`; los scripts 001 a 003 no se tocan. La transición
`TERMINADO → ENTREGADO` pasa a exigir un pago aprobado (FR‑014). Detalle de decisiones
en [research.md](research.md).

## Contexto Técnico

**Language/Version**: Dart (Flutter 3.x) en el frontend; JavaScript (Node.js LTS) en el
backend, siempre en ES Modules (`"type": "module"`)

**Primary Dependencies**: Backend: Express, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`
(sin dependencias nuevas; la llamada a Mercado Pago usa `fetch` nativo de Node LTS).
Frontend: Flutter Material Design 3, Provider, `google_fonts`, `data_table_2`,
`lucide_icons_flutter` (las mismas de los sprints 1 a 3)

**Storage**: MySQL local (InnoDB, `utf8mb4`, llaves foráneas); nuevas tablas `payments`
y `tickets` en `database/migrations/004_pagos_tickets_dashboard.sql` (script nuevo e
inmutable); datos de ejemplo en `database/seeds/004_ejemplos_pagos_tickets.sql`
(idempotentes, ids fijos); base de pruebas `motorix_v2_test`

**Testing**: Jest (unitarias de `order-total.js`, validadores y regla de entrega
condicionada al pago) y Jest + supertest (integración y contrato) contra
`motorix_v2_test`; `flutter test` en el frontend (providers y widgets nuevos)

**Target Platform**: Aplicación Flutter con prioridad en escritorio (Windows/web) y
backend Node.js corriendo en la máquina local de cada integrante

**Project Type**: Aplicación web (frontend + backend + scripts de base de datos)

**Performance Goals**: registro de pago visible en menos de 1 minuto (SC‑001); flujo de
Mercado Pago sandbox completo en menos de 5 minutos (SC‑004); panel de control cargado
en menos de 5 segundos (SC‑005); transiciones de interfaz de 150/200/250 ms según
`docs/design-system.md`

**Constraints**: permisos validados en backend (RN‑15); sin datos de tarjeta ni
credenciales en el código o la base (RN‑14); sin secretos en el repositorio; 0 librerías
nuevas de UI; solo el backend accede a MySQL; scripts de migración inmutables y seeds
idempotentes

**Scale/Scope**: 2 tablas nuevas, ~4 pantallas nuevas (formulario de pago, visor de
ticket, panel de control y detalle de orden ampliado), 3 roles, 6 historias de usuario;
equipo local (sin carga multiusuario concurrente en el MVP)

## Verificación de la Constitución

*GATE: Debe pasar antes de la investigación de la Fase 0. Se re-evalúa después del
diseño de la Fase 1.*

| # | Gate (constitución) | Estado | Evidencia |
|---|---------------------|--------|-----------|
| I | Alcance, MVP y fuente de verdad | PASS | Alcance limitado al Sprint 4 (pagos, tickets y panel); fuera de alcance chatbot, facturación electrónica, notificaciones automáticas, reportes avanzados y app móvil; trazabilidad HU1–HU6 → FR‑001…FR‑016 → SC‑001…SC‑007; las reglas RN‑9, RN‑13, RN‑14 y RN‑15 del insumo coinciden con `docs/project-context.md` §13 |
| II | Arquitectura con responsabilidades separadas | PASS | Se reutilizan `client/`, `server/` y `database/`; la lógica de cobro, ticket y dashboard vive en `services/`; la integración de Mercado Pago queda aislada en `services/payment_gateway/` tras una interfaz propia, separada del dominio |
| III | Stack tecnológico y base de datos local | PASS | Sin dependencias nuevas; ES Modules; script inmutable `004_…` en `database/migrations/` y seed idempotente `004_…`; InnoDB/`utf8mb4`/FK; solo el backend toca MySQL; credenciales de Mercado Pago por variables de entorno (CA‑7) |
| IV | Seguridad | PASS | Endpoints con `authenticate` + `authorize` (pagos recepción/administración; anulación y panel solo administración); validación con `zod`; no se almacena ningún dato de tarjeta ni credencial (RN‑14); sin secretos; mensajes en español |
| V | Integridad de las reglas de negocio | PASS | RN‑13 (todo pago ligado a una orden), RN‑9 (órdenes entregadas conservadas como historial), entrega condicionada a pago aprobado (FR‑014), total calculado con precios vigentes (FR‑015), anulación registrada sin borrados (FR‑016) |
| VI | API consistente y manejo de errores | PASS | Rutas nuevas coherentes con las de los sprints 1 a 3 (`/api/payments`, `/api/tickets`, `/api/dashboard`), claves en español, códigos 400/401/403/404/409, errores centralizados (ver [contracts/](contracts/)) |
| VII | Pruebas | PASS | Jest + supertest contra `motorix_v2_test`; unitarias de `order-total.js` y de la regla de entrega; `flutter test` para providers y widgets; ninguna historia se da por terminada solo con interfaz |
| VIII | UX/UI profesional y sencilla | PASS | Pantallas nuevas sobre `docs/design-system.md` (Material 3 con tokens, sin valores sueltos); confirmación obligatoria para anular pagos; estados vacío/cargando/error; 0 librerías extra; el ticket se imprime con la impresora del navegador |

**Resultado del gate inicial**: PASS (sin acciones correctivas).

**Re-evaluación post‑diseño (Fase 1)**: PASS. Los artefactos generados
([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)
y [quickstart.md](quickstart.md)) mantienen la separación de capas, no introducen
dependencias nuevas y ninguna decisión de diseño viola los principios I–VIII. El
respaldo simulado de Mercado Pago (cuando no hay credenciales) se mantiene dentro del
adaptador, sin mezclarse con el dominio (Principio II).

## Estructura del Proyecto

### Documentación (esta funcionalidad)

```text
specs/004-pagos-tickets-dashboard/
├── plan.md              # Este archivo (salida de /speckit.plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1 (contrato REST)
│   ├── README.md
│   ├── payments.md      # Pagos de órdenes
│   ├── tickets.md       # Tickets de servicio
│   └── dashboard.md     # Panel de control
├── checklists/
│   └── requirements.md  # Checklist de calidad de la especificación
└── tasks.md             # Salida de /speckit.tasks (NO la crea /speckit.plan)
```

### Código fuente (raíz del repositorio)

```text
client/                    # Frontend Flutter (se agregan archivos, no se mueven)
├── lib/
│   ├── models/            # + payment.dart, ticket.dart, dashboard_summary.dart
│   ├── providers/         # + payment_provider.dart, ticket_provider.dart,
│   │                      #   dashboard_provider.dart
│   ├── services/          # + payments_service.dart, tickets_service.dart,
│   │                      #   dashboard_service.dart
│   ├── screens/           # + payment_form_screen, ticket_screen,
│   │                      #   dashboard_screen (service_order_detail se amplía
│   │                      #   con el bloque de cobro)
│   ├── widgets/           # + payment_status_chip.dart (app_shell ampliado con
│   │                      #   la sección Panel para ADMIN)
│   └── utils/             # app_routes.dart ampliado
└── test/                  # flutter test (providers y widgets nuevos)

server/                    # Backend Node.js + Express (ES Modules)
├── models/                # + payment.js, ticket.js, dashboard.js
├── services/              # + payment.service.js, dashboard.service.js;
│   │                      #   service_order.service.js ampliado (entrega exige pago)
│   ├── payment_gateway/   # + index.js (interfaz), mercadopago.js (sandbox),
│   │                      #   simulado.js (respaldo local)
├── controllers/           # + payments.controller.js, tickets.controller.js,
│   │                      #   dashboard.controller.js
├── routes/                # + payments.routes.js, tickets.routes.js,
│   │                      #   dashboard.routes.js
├── validators/            # + payment.validator.js, ticket.validator.js
├── utils/                 # + order-total.js (módulo puro del cálculo del total)
└── tests/
    ├── unit/              # + order-total, payment.validator, regla de entrega
    ├── integration/       # + payments, tickets, dashboard
    └── contract/          # + payments, tickets, dashboard

database/                  # Esquema y datos versionados
├── migrations/            # + 004_pagos_tickets_dashboard.sql (nuevo e inmutable;
│                          #   crea payments y tickets)
├── seeds/                 # + 004_ejemplos_pagos_tickets.sql (idempotente)
└── scripts/               # sin cambios (aplican todo lo nuevo automáticamente)
```

**Decisión de estructura**: se conserva la estructura de aplicación web de los sprints
anteriores. El Sprint 4 solo añade archivos dentro de las capas existentes, con una
carpeta nueva `services/payment_gateway/` para aislar la integración de Mercado Pago
(Principio II). La validación de la entrega (pago previo) se agrega en
`service_order.service.js` (servicio existente), y el panel se publica como
`GET /api/dashboard` de solo administración.

## Registro de Complejidad

> Completo ÚNICAMENTE si la Verificación de la Constitución tiene violaciones que
> deben justificarse.

| Violación | Por qué se necesita | Alternativa más simple rechazada porque |
|-----------|---------------------|------------------------------------------|
| — | Sin violaciones de arquitectura ni de alcance; los gates I–VIII pasan sin acciones correctivas | — |
