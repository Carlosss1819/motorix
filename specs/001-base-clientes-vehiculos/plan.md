# Plan de Implementación: Base del Sistema, Clientes y Vehículos

**Rama**: `001-base-clientes-vehiculos` | **Fecha**: 2026-10-11 | **Especificación**:
[spec.md](spec.md)

**Entrada**: Especificación de la funcionalidad desde `/specs/001-base-clientes-vehiculos/spec.md`

## Resumen

Primer sprint del MVP de Motorix: crear desde cero la estructura del repositorio
(`client/`, `server/`, `database/`), la conexión a MySQL local, la autenticación con
inicio de sesión por usuario o correo, la autorización por roles (ADMIN, RECEPTIONIST,
MECHANIC) y los módulos de clientes y vehículos con su relación 1‑N, todo persistido
localmente y demostrable de extremo a extremo.

Enfoque técnico: backend Node.js LTS + Express en ES Modules con capa `services/` para
la lógica de negocio, driver `mysql2` directo y migraciones SQL inmutables; frontend
Flutter + Material Design 3 con tema propio y Provider, siguiendo `docs/design-system.md`;
validación de entradas con `zod` y pruebas con Jest + supertest (contra `motorix_test`) y
`flutter test`. Detalle de decisiones en [research.md](research.md).

## Contexto Técnico

**Language/Version**: Dart (Flutter 3.x) en el frontend; JavaScript (Node.js LTS) en el
backend, siempre en ES Modules (`"type": "module"`)

**Primary Dependencies**: Backend: Express, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`.
Frontend: Flutter Material Design 3, Provider, `google_fonts`, `data_table_2` (2.6.0),
`lucide_icons_flutter` (set de íconos, pendiente de confirmación del equipo)

**Storage**: MySQL local (InnoDB, `utf8mb4`, llaves foráneas), esquema en
`database/migrations/` y `database/seeds/` con registro en `schema_migrations`; usuario
dedicado `motorix_app`; base de pruebas `motorix_test`

**Testing**: Jest (unitarias) y Jest + supertest (integración y contrato) en el backend
contra `motorix_test`; `flutter test` (providers y widgets) en el frontend

**Target Platform**: Aplicación Flutter con prioridad en escritorio (Windows/web) y
backend Node.js corriendo en la máquina local de cada integrante

**Project Type**: Aplicación web (frontend + backend + scripts de base de datos)

**Performance Goals**: Flujo completo del sprint en menos de 3 minutos (SC‑001);
transiciones de interfaz de 150/200/250 ms según `docs/design-system.md`

**Constraints**: Sesión que expira a los 30 minutos de inactividad (token máximo de
8 horas); bloqueo de cuenta de 15 minutos tras 5 inicios fallidos; sin secretos en el
repositorio; sin más de una librería de componentes de UI (decisión: ninguna); solo el
backend accede a MySQL

**Scale/Scope**: 3 tablas (`users`, `clients`, `vehicles`), ~6 pantallas, 3 roles,
5 historias de usuario; equipo local (sin carga multiusuario concurrente en el MVP)

## Verificación de la Constitución

*GATE: Debe pasar antes de la investigación de la Fase 0. Se re-evalúa después del
diseño de la Fase 1.*

| # | Gate (constitución) | Estado | Evidencia |
|---|---------------------|--------|-----------|
| I | Alcance, MVP y fuente de verdad | ⚠ PASS con acción correctiva | Alcance limitado al Sprint 1; trazabilidad US1–US6 → FR‑001…FR‑023 → SC‑001…SC‑008. **Acción**: la decisión de clarificación sobre el rol MECHANIC contradice a `docs/project-context.md`, que DEBE actualizarse (Principio I) |
| II | Arquitectura con responsabilidades separadas | PASS | `client/`, `server/`, `database/`; backend en `config/`, `models/`, `services/`, `controllers/`, `routes/`, `middlewares/`, `validators/`, `utils/`; lógica de negocio en `services/` |
| III | Stack tecnológico y base de datos local | PASS | Flutter/Dart, Node LTS + Express, MySQL local, JWT + bcrypt (`bcryptjs`), ES Modules con `"type": "module"`, scripts SQL en `database/`, `.env` ignorado y `.env.example` sin secretos, InnoDB/`utf8mb4`/FK, login usuario o correo |
| IV | Seguridad | PASS | Contraseñas con hash (costo 10), secretos solo por variables de entorno, permisos validados en backend, entradas con `zod`, sin trazas internas al usuario |
| V | Integridad de las reglas de negocio | PASS | RN‑1 (sin vehículo sin propietario), RN‑5/RN‑15 (permisos en backend), RN‑16 (login usuario o correo), RN‑17 (política de contraseña). Las RN de inventario/pagos no aplican en este sprint |
| VI | API consistente y manejo de errores | PASS | Rutas REST coherentes, respuestas JSON consistentes, códigos HTTP apropiados, middlewares de autenticación/autorización/validación, errores centralizados en español (ver [contracts/](contracts/)) |
| VII | Pruebas | PASS | Jest + supertest contra `motorix_test` (nunca la base principal), `flutter test`; pruebas de lógica de negocio (roles, duplicados, política de contraseña) |
| VIII | UX/UI profesional y sencilla | PASS | Todas las pantallas siguen `docs/design-system.md`: Material 3 con `ThemeData` propio, tokens (sin valores sueltos), confirmaciones obligatorias, estados vacío/cargando/error/éxito, 0 librerías extra de componentes |

**Resultado del gate inicial**: PASS con 1 acción correctiva documentada (gate I).

**Re-evaluación post‑diseño (Fase 1)**: PASS. Los artefactos generados
([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/) y
[quickstart.md](quickstart.md)) mantienen la separación de capas, no introducen
tecnologías nuevas ni dependencias grandes, y ninguna decisión de diseño viola los
principios I–VIII. La acción correctiva del gate I sigue pendiente: actualizar la regla
del rol MECHANIC en `docs/project-context.md` (ver R‑04 en [research.md](research.md)).

## Estructura del Proyecto

### Documentación (esta funcionalidad)

```text
specs/001-base-clientes-vehiculos/
├── plan.md              # Este archivo (salida de /speckit.plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1 (contrato REST)
│   ├── README.md
│   ├── auth.md
│   ├── users.md
│   ├── clients.md
│   └── vehicles.md
├── checklists/
│   └── requirements.md  # Checklist de calidad de la especificación
└── tasks.md             # Salida de /speckit.tasks (NO la crea /speckit.plan)
```

### Código fuente (raíz del repositorio)

```text
client/                    # Frontend Flutter
├── lib/
│   ├── main.dart
│   ├── utils/app_theme.dart        # ThemeData con tokens (docs/design-system.md)
│   ├── providers/                  # Estado (sesión, sidebar, datos)
│   ├── services/                   # Cliente HTTP hacia el backend
│   ├── screens/                    # login, home, clients, vehicles, users, account
│   └── widgets/                    # Componentes reutilizables
└── test/                            # flutter test (providers y widgets)

server/                    # Backend Node.js + Express (ES Modules)
├── config/                # db.js, variables de entorno
├── models/                # Acceso a datos (mysql2)
├── services/              # Lógica de negocio
├── controllers/           # Adaptadores HTTP
├── routes/                 # Rutas REST
├── middlewares/            # Autenticación, autorización, errores
├── validators/             # Esquemas zod, mensajes en español
├── utils/
├── scripts/                # create-admin.js
├── tests/unit|integration|contract/   # Jest + supertest (motorix_test)
├── package.json            # "type": "module"
└── .env.example             # DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME

database/                  # Esquema y datos versionados
├── migrations/             # Scripts SQL numerados e inmutables
├── seeds/                  # Datos de ejemplo idempotentes
├── scripts/                # crear-entorno.ps1, aplicar-migraciones.ps1
├── data/                   # Datos físicos de MySQL (en .gitignore)
└── README.md
```

**Decisión de estructura**: estructura de aplicación web con frontend y backend
separados, más la carpeta `database/`, exigida por los Principios I y II de la
constitución. El backend no lleva carpeta `src/` intermedia (decisión resuelta en el
Sprint 1, `docs/project-context.md`).

## Registro de Complejidad

> Completo ÚNICAMENTE si la Verificación de la Constitución tiene violaciones que
> deben justificarse.

| Violación | Por qué se necesita | Alternativa más simple rechazada porque |
|-----------|---------------------|------------------------------------------|
| — | Sin violaciones de arquitectura; la acción correctiva del gate I es documental (actualizar `docs/project-context.md`) | — |
