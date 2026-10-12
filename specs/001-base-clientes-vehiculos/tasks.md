---

description: "Lista de tareas para la implementación de la funcionalidad"
---

# Tasks: Base del Sistema, Clientes y Vehículos

**Input**: Documentos de diseño de `/specs/001-base-clientes-vehiculos/`

**Prerequisites**: plan.md (requerido), spec.md (historias de usuario), research.md,
data-model.md, contracts/, quickstart.md

**Tests**: Incluidos porque la constitución (Principio VII) exige pruebas de toda la
lógica de negocio (Jest + supertest contra `motorix_test`; `flutter test`).

**Organization**: Las tareas están agrupadas por historia de usuario para permitir
implementación y prueba independientes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario a la que pertenece (US1, US3, US5…)
- Todas las descripciones incluyen la ruta exacta del archivo

## Convención de rutas

Estructura definida en `plan.md`: frontend en `client/`, backend en `server/` (sin
carpeta `src/` intermedia) y esquema en `database/`.

**Etiquetas de historia** (según `spec.md`): `[US1]` inicio de sesión, `[US3]` registro
y consulta de clientes, `[US5]` registro de vehículos con propietario (cubre el US5 y
US6 del sprint), `[US4]` edición de clientes, `[US2]` gestión de usuarios.

## Phase 1: Setup (Infraestructura Compartida)

**Purpose**: Inicialización del proyecto

- [X] T001 Create base directory structure client/, server/ and database/ per plan.md structure (client/, server/, database/)
- [X] T002 Initialize backend with package.json declaring "type": "module" and dependencies express, mysql2, jsonwebtoken, bcryptjs, zod in server/package.json
- [ ] T003 [P] Initialize Flutter project with flutter create in client/
- [X] T004 [P] Configure .gitignore to exclude .env and database/data/ at .gitignore
- [X] T005 [P] Create .env.example with DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME without secrets in server/.env.example
- [X] T006 [P] Create database/ skeleton with migrations/, seeds/, scripts/ and README.md in database/README.md
- [X] T007 Configure Jest and supertest scripts pointing to motorix_test database in server/package.json
- [ ] T008 [P] Configure ESLint for backend and analysis_options.yaml for Flutter in server/eslint.config.js and client/analysis_options.yaml

---

## Phase 2: Foundational (Prerrequisitos Bloqueantes)

**Purpose**: Infraestructura base que DEBE estar lista antes de cualquier historia

**⚠ CRITICAL**: Ninguna historia puede comenzar hasta completar esta fase

- [X] T009 Create initial migration creating users, clients, vehicles and schema_migrations with the exact constraints of data-model.md (username/email UNIQUE, FK vehicles.client_id NOT NULL ON DELETE RESTRICT, plates UNIQUE, vin UNIQUE nullable, InnoDB, utf8mb4) in database/migrations/001_esquema_inicial.sql
- [X] T010 [P] Create idempotent migration script with schema_migrations registry in database/scripts/aplicar-migraciones.ps1
- [X] T011 [P] Create local environment script creating the motorix_app dedicated MySQL user in database/scripts/crear-entorno.ps1
- [X] T012 Create idempotent seeds with 3 initial users (admin, recepcion, mecanico with bcrypt hashes), at least 3 clients and 3 vehicles in database/seeds/001_datos_iniciales.sql
- [X] T013 [P] Create admin bootstrap script using bcryptjs hash in server/scripts/create-admin.js
- [X] T014 Implement environment configuration loader reading DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME in server/config/env.js and MySQL connection pool in server/config/db.js
- [X] T015 [P] Implement centralized error handler returning Spanish JSON messages without stack traces in server/middlewares/errorHandler.js and response helpers in server/utils/response.js
- [X] T016 [P] Implement zod validation middleware with Spanish messages in server/middlewares/validate.js
- [X] T017 [P] Implement JWT authentication middleware (401) and role authorization middleware (403) validating active status on every protected request in server/middlewares/auth.js and server/middlewares/authorize.js
- [X] T018 Create Express app wiring routes, validation and error middleware with /api prefix in server/app.js and server/routes/index.js
- [ ] T019 Create Flutter theme with color, typography, spacing and radius tokens from docs/design-system.md (Material 3, useMaterial3: true, no default Material theme) in client/lib/utils/app_theme.dart
- [ ] T020 [P] Create HTTP client with base URL from environment configuration in client/lib/services/api_client.dart
- [ ] T021 Create role-based collapsible sidebar shell with sections Inicio, Clientes, Vehículos, Usuarios and Mi cuenta filtered by role in client/lib/widgets/app_shell.dart
- [ ] T022 [P] Create session and sidebar providers skeleton in client/lib/providers/ and wire app entry in client/lib/main.dart

**Checkpoint**: Base lista; las historias pueden comenzar

---

## Phase 3: User Story 1 - Inicio de sesión con usuario o correo (Priority: P1) ⭐ MVP

**Goal**: El usuario inicia sesión con usuario o correo y contraseña, y accede a las
funciones de su rol.

**Independent Test**: Iniciar sesión con `admin` y luego con el correo de `admin`;
verificar acceso y denegación con credenciales inválidas y con sesión expirada (30 min).

### Tests for User Story 1

> **NOTE: Estas pruebas DEBEN fallar antes de implementar**

- [X] T023 [P] [US1] Contract test for POST /api/auth/login covering username, email, invalid credentials (401) and locked account (423) in server/tests/contract/auth.test.js
- [X] T024 [P] [US1] Integration test for login flow, lockout after 5 failed attempts (15 min) and 30-minute inactivity expiry against motorix_test in server/tests/integration/auth.test.js
- [X] T025 [P] [US1] Unit test for password policy (min 8 chars, uppercase, lowercase, number) and identifier detection by "@" in server/tests/unit/auth.validators.test.js

### Implementation for User Story 1

- [X] T026 [P] [US1] Create users model with constraints verbatim: username UNIQUE, email UNIQUE, password_hash, role ADMIN/RECEPTIONIST/MECHANIC, status ACTIVE/INACTIVE, failed_login_attempts, locked_until in server/models/user.js
- [X] T027 [US1] Implement auth service with identifier detection by "@", bcryptjs compare (cost 10), lockout after 5 consecutive failures, JWT with 8h max and 30-minute inactivity validation in server/services/auth.service.js
- [X] T028 [US1] Implement zod schemas for login and change-password enforcing password policy "mínimo 8 caracteres y al menos una mayúscula, una minúscula y un número" in server/validators/auth.validator.js
- [X] T029 [US1] Implement auth controller and routes: POST /api/auth/login, POST /api/auth/logout, GET /api/auth/me, POST /api/auth/change-password per contracts/auth.md in server/controllers/auth.controller.js and server/routes/auth.routes.js
- [ ] T030 [P] [US1] Create auth provider with session state, login and logout actions in client/lib/providers/auth_provider.dart
- [ ] T031 [P] [US1] Create auth service calling the contract endpoints in client/lib/services/auth_service.dart
- [ ] T032 [US1] Create login screen with single identifier field (username or email) and Spanish error messages in client/lib/screens/login_screen.dart
- [ ] T033 [US1] Create Inicio (welcome) screen and Mi cuenta screen with change-password form in client/lib/screens/home_screen.dart and client/lib/screens/account_screen.dart
- [ ] T034 [US1] Wire protected routing and redirect to login on missing or expired session (30-minute inactivity) in client/lib/main.dart

**Checkpoint**: Historia 1 funcional y verificable de forma independiente

---

## Phase 4: User Story 2 - Registro y consulta de clientes (Priority: P2)

**Goal**: El recepcionista registra y consulta clientes con sus vehículos.

**Independent Test**: Registrar un cliente con nombre y teléfono, encontrarlo en la
lista y abrir su ficha con la lista de vehículos (vacía al inicio).

### Tests for User Story 2

> **NOTE: Estas pruebas DEBEN fallar antes de implementar**

- [X] T035 [P] [US3] Contract test for GET and POST /api/clients covering required name/phone, optional email and search parameter in server/tests/contract/clients.test.js
- [X] T036 [P] [US3] Integration test for register then query client against motorix_test in server/tests/integration/clients.test.js
- [X] T037 [P] [US3] Unit test for client validation: "nombre y teléfono obligatorios, correo opcional" and repeated phone warning flow in server/tests/unit/client.validator.test.js

### Implementation for User Story 2

- [X] T038 [P] [US3] Create clients model with constraints: name NOT NULL, phone NOT NULL, email nullable, status default ACTIVO, created_at default CURRENT_TIMESTAMP in server/models/client.js
- [X] T039 [US3] Implement client service with create including repeated-phone warning and confirmation re-send, list with search, getById with associated vehicles in server/services/client.service.js
- [X] T040 [US3] Implement zod schema for client payloads with Spanish messages in server/validators/client.validator.js
- [X] T041 [US3] Implement client controller and routes GET /api/clients, POST /api/clients, GET /api/clients/:id per contracts/clients.md in server/controllers/client.controller.js and server/routes/client.routes.js
- [ ] T042 [P] [US3] Create clients provider with list and detail state in client/lib/providers/clients_provider.dart
- [ ] T043 [P] [US3] Create clients service calling the contract endpoints in client/lib/services/clients_service.dart
- [ ] T044 [US3] Create client list screen with search and empty state in client/lib/screens/clients_screen.dart
- [ ] T045 [US3] Create client form screen for creation validating required name and phone in client/lib/screens/client_form_screen.dart
- [ ] T046 [US3] Create client detail screen showing data and associated vehicles with empty-state message in client/lib/screens/client_detail_screen.dart
- [ ] T047 [US3] Register Clientes section in sidebar for ADMIN and RECEPTIONIST roles in client/lib/widgets/app_shell.dart

**Checkpoint**: Historias 1 y 2 funcionan de forma independiente

---

## Phase 5: User Story 3 - Registro de vehículos con su propietario (US5 y US6) (Priority: P3)

**Goal**: El recepcionista da de alta un vehículo siempre asociado a su propietario.

**Independent Test**: Registrar un vehículo eligiendo un cliente como propietario y
verificar que aparece en la ficha del cliente; intentar guardarlo sin propietario y
verificar el rechazo.

### Tests for User Story 3

> **NOTE: Estas pruebas DEBEN fallar antes de implementar**

- [X] T048 [P] [US5] Contract test for POST /api/vehicles covering missing owner (400 "Seleccione el propietario"), duplicate plates (409) and duplicate VIN (409) in server/tests/contract/vehicles.test.js
- [X] T049 [P] [US5] Integration test for client then vehicle then association query against motorix_test in server/tests/integration/vehicles.test.js
- [X] T050 [P] [US5] Unit test for vehicle validation: mileage >= 0 and VIN unique when provided in server/tests/unit/vehicle.validator.test.js

### Implementation for User Story 3

- [X] T051 [P] [US5] Create vehicles model with constraints: client_id NOT NULL FK to clients, brand/model/year NOT NULL, plates UNIQUE, vin UNIQUE nullable, current_mileage >= 0 in server/models/vehicle.js
- [X] T052 [US5] Implement vehicle service enforcing RN-1 owner required, plates and VIN uniqueness and mileage >= 0 in server/services/vehicle.service.js
- [X] T053 [US5] Implement zod schema for vehicle payloads with Spanish messages in server/validators/vehicle.validator.js
- [X] T054 [US5] Implement vehicle controller and routes GET /api/vehicles (?buscar, ?clienteId), POST, GET :id, PUT :id per contracts/vehicles.md in server/controllers/vehicle.controller.js and server/routes/vehicle.routes.js
- [ ] T055 [P] [US5] Create vehicles provider with list and detail state in client/lib/providers/vehicles_provider.dart
- [ ] T056 [P] [US5] Create vehicles service calling the contract endpoints in client/lib/services/vehicles_service.dart
- [ ] T057 [US5] Create vehicle form screen with required owner selector and mileage >= 0 validation in client/lib/screens/vehicle_form_screen.dart
- [ ] T058 [US5] Create vehicle list screen with search by plates, brand or model in client/lib/screens/vehicles_screen.dart
- [ ] T059 [US5] Create vehicle detail screen showing data and owner in client/lib/screens/vehicle_detail_screen.dart
- [ ] T060 [US5] Show associated vehicles list linking to vehicle detail from client detail in client/lib/screens/client_detail_screen.dart
- [ ] T061 [US5] Register Vehículos section in sidebar for ADMIN and RECEPTIONIST roles in client/lib/widgets/app_shell.dart

**Checkpoint**: Historias 1, 2 y 3 funcionan de forma independiente; flujo demostrable completo

---

## Phase 6: User Story 4 - Edición de la información de clientes (Priority: P4)

**Goal**: El recepcionista corrige datos de un cliente sin perder sus vehículos.

**Independent Test**: Cambiar el teléfono de un cliente con vehículos y verificar que el
dato cambia y los vehículos siguen asociados; cancelar y verificar que nada cambia.

### Tests for User Story 4

> **NOTE: Estas pruebas DEBEN fallar antes de implementar**

- [X] T062 [P] [US4] Contract test for PUT /api/clients/:id covering success (200), invalid data (400) and vehicles preserved in response in server/tests/contract/clients-edit.test.js
- [X] T063 [P] [US4] Integration test for edit client keeping associated vehicles against motorix_test in server/tests/integration/clients-edit.test.js

### Implementation for User Story 4

- [X] T064 [US4] Extend client service with update preserving vehicle associations in server/services/client.service.js
- [X] T065 [US4] Extend client controller and routes with PUT /api/clients/:id per contracts/clients.md in server/controllers/client.controller.js and server/routes/client.routes.js
- [ ] T066 [US4] Add edit mode to client form with cancel and confirmation on exit with unsaved changes in client/lib/screens/client_form_screen.dart
- [ ] T067 [US4] Add edit action from client detail screen showing updated data in client/lib/screens/client_detail_screen.dart

**Checkpoint**: Historias 1 a 4 funcionan de forma independiente

---

## Phase 7: User Story 5 - Gestión de usuarios y roles (Priority: P5)

**Goal**: El administrador crea usuarios, cambia roles y activa/desactiva cuentas con
efecto inmediato.

**Independent Test**: Crear un usuario recepcionista, iniciar sesión con él, desactivarlo
desde `admin` y verificar que su sesión abierta se cierra de inmediato.

### Tests for User Story 5

> **NOTE: Estas pruebas DEBEN fallar antes de implementar**

- [X] T068 [P] [US2] Contract test for /api/users covering 403 for non-admin roles, 409 for duplicate username or email and 201 on create in server/tests/contract/users.test.js
- [X] T069 [P] [US2] Integration test for deactivation closing an open session immediately and role change applying on next request against motorix_test in server/tests/integration/users.test.js
- [X] T070 [P] [US2] Unit test for role and status transitions with immediate effect in server/tests/unit/user.service.test.js

### Implementation for User Story 5

- [X] T071 [P] [US2] Extend users model with unique-username/email create and role/status update methods in server/models/user.js
- [X] T072 [US2] Implement user service with immediate effect: deactivation closes open sessions and new role applies on next request in server/services/user.service.js
- [X] T073 [US2] Implement zod schemas for user creation and updates with Spanish messages in server/validators/user.validator.js
- [X] T074 [US2] Implement user controller and routes GET /api/users, POST /api/users, PATCH /api/users/:id restricted to ADMIN per contracts/users.md in server/controllers/user.controller.js and server/routes/user.routes.js
- [ ] T075 [P] [US2] Create users provider with list and mutations in client/lib/providers/users_provider.dart
- [ ] T076 [P] [US2] Create users service calling the contract endpoints in client/lib/services/users_service.dart
- [ ] T077 [US2] Create users screen with create form, role change and deactivate with confirmation in client/lib/screens/users_screen.dart
- [ ] T078 [US2] Show Usuarios sidebar section only for ADMIN role in client/lib/widgets/app_shell.dart

**Checkpoint**: Las 5 historias funcionan de forma independiente

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Mejoras que afectan a varias historias

- [ ] T079 [P] Review all screens against docs/design-system.md: tokens without hardcoded values, transitions 150/200/250 ms, empty/loading/error/success states in client/lib/screens/
- [ ] T080 [P] Verify mandatory confirmations: logout, leaving forms with unsaved changes, deactivating records in client/lib/widgets/
- [X] T081 [P] Verify no secrets in repository and .env ignored with .env.example containing DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME (SC-006) at .gitignore and server/.env.example
- [ ] T082 Run complete automated suites: npm test in server/ and flutter test in client/ (all green against motorix_test)
- [ ] T083 Run quickstart.md validation scenarios V1 through V9 end-to-end per specs/001-base-clientes-vehiculos/quickstart.md
- [X] T084 [P] Update root README.md and database/README.md with environment setup and execution steps in README.md and database/README.md
- [ ] T085 Confirm MECHANIC access decision (R-04) with the team and update docs/project-context.md accordingly per constitution Principle I in docs/project-context.md
- [ ] T086 Produce final report: modified files, covered stories, tests run, pending items and risks per constitution "Flujo de Desarrollo" in specs/001-base-clientes-vehiculos/tasks.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sin dependencias; puede iniciar de inmediato
- **Foundational (Phase 2)**: Depende de Setup — BLOQUEA todas las historias
- **User Stories (Phase 3+)**: Todas dependen de la fase Foundational
  - Pueden ejecutarse en paralelo si hay capacidad, o en orden de prioridad
    (P1 → P2 → P3 → P4 → P5)
- **Polish (fase final)**: Depende de las historias que se deseen completar

### User Story Dependencies

- **US1 (P1)**: Inicia tras Foundational; sin dependencias de otras historias
- **US3 (P2)**: Inicia tras Foundational; independiente (los vehículos llegan en US5)
- **US5 (P3)**: Inicia tras Foundational; usa clientes de US3 para el selector de
  propietario (integración mínima: pantalla de selección)
- **US4 (P4)**: Inicia tras US3 (amplía el formulario y el detalle de clientes)
- **US2 (P5)**: Inicia tras Foundational; usa el modelo de usuarios de US1

### Within Each User Story

- Pruebas primero (DEBEN fallar antes de implementar)
- Modelos antes que servicios; servicios antes que endpoints/rutas
- Backend antes que la integración de pantalla correspondiente
- Historia completa antes de pasar a la siguiente prioridad

### Parallel Opportunities

- Toda la fase Setup marcada [P] puede ejecutarse en paralelo
- Dentro de Foundational: T010, T011, T013, T015, T016, T017, T020 y T022 en paralelo
- Tras Foundational, historias distintas en paralelo (con capacidades del equipo)
- Dentro de cada historia: pruebas [P] en paralelo; modelos [P] en paralelo;
  provider y servicio de pantalla [P] en paralelo

---

## Parallel Example: User Story 1

```bash
# Lanzar las 3 pruebas de la US1 juntas (archivos distintos):
Task: "Contract test for POST /api/auth/login ... in server/tests/contract/auth.test.js"
Task: "Integration test for login flow ... in server/tests/integration/auth.test.js"
Task: "Unit test for password policy ... in server/tests/unit/auth.validators.test.js"

# Lanzar en paralelo modelo, provider y servicio:
Task: "Create users model ... in server/models/user.js"
Task: "Create auth provider ... in client/lib/providers/auth_provider.dart"
Task: "Create auth service ... in client/lib/services/auth_service.dart"
```

## Parallel Example: User Story 3 (vehículos)

```bash
Task: "Contract test for POST /api/vehicles ... in server/tests/contract/vehicles.test.js"
Task: "Integration test for client then vehicle ... in server/tests/integration/vehicles.test.js"
Task: "Unit test for vehicle validation ... in server/tests/unit/vehicle.validator.test.js"

Task: "Create vehicles model ... in server/models/vehicle.js"
Task: "Create vehicles provider ... in client/lib/providers/vehicles_provider.dart"
Task: "Create vehicles service ... in client/lib/services/vehicles_service.dart"
```

(Los ejemplos de US3-clientes, US4 y US2 siguen el mismo patrón: pruebas en paralelo
luego modelos en paralelo con servicios y pantallas secuenciales.)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRÍTICO — bloquea todas las historias)
3. Completar Phase 3: User Story 1
4. **PARAR Y VALIDAR**: probar la US1 de forma independiente (quickstart V1 login, V3, V4)
5. Demostrar si está listo

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → probar → demostrar (¡MVP de acceso!)
3. US3 → probar → demostrar (registro y consulta de clientes)
4. US5 → probar → demostrar (vehículos con propietario; **flujo completo del sprint**)
5. US4 → probar → demostrar (edición de clientes)
6. US2 → probar → demostrar (gestión de usuarios)
7. Polish → validación completa con quickstart V1–V9

### Parallel Team Strategy

1. El equipo completa Setup + Foundational conjunto
2. Una vez lista la base:
   - Desarrollador A: US1 (login)
   - Desarrollador B: US3 (clientes)
   - Desarrollador C: US5 (vehículos) — requiere el selector de dueño de US3
3. Historias concluidas e integradas de forma independiente

---

## Notes

- [P] = archivos distintos, sin dependencias
- La etiqueta [Story] vincula la tarea a su historia para trazabilidad
- Cada historia es completable y testeable de forma independiente
- Verificar que las pruebas fallan antes de implementar
- Commit después de cada tarea o grupo lógico (Conventional Commits, descripción en español)
- Detenerse en cada checkpoint para validar la historia por separado
- Evitar: tareas vagas, conflictos de archivo y dependencias que rompan la independencia
