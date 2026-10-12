# Motorix — Sistema de Gestión para Taller Mecánico

Aplicación de escritorio y web para la administración integral de un taller mecánico:
clientes, vehículos, órdenes de servicio, inventario, facturación, monitoreo y más.

> **Estado actual:** Sprint 1 en implementación — base de clientes y vehículos
> (especificación en `specs/001-base-clientes-vehiculos/`).

## Estructura del proyecto

```text
motorix/
├── client/        # Aplicación Flutter (Material 3)
├── server/        # API REST en Node.js (Express + MySQL)
├── database/      # Migraciones, seeds y scripts de automatización
├── docs/          # Reglas, sistema de diseño, decisiones y sprints
├── specs/         # Especificaciones y planes por feature (Spec Kit)
└── .specify/      # Configuración de Spec Kit
```

## Requisitos

- Node.js 20 o superior y npm
- Flutter SDK
- MySQL 8 (local)

## Puesta en marcha

### 1. Base de datos

```powershell
# Crea las bases 'motorix_v2' y 'motorix_v2_test' y el usuario dedicado motorix_app
./database/scripts/crear-entorno.ps1 -AdminPassword '<contraseña de root>'

# Aplica migraciones y datos de ejemplo (idempotente)
./database/scripts/aplicar-migraciones.ps1 -DbPassword '<contraseña de motorix_app>' -Seeds
```

Los datos de ejemplo incluyen las cuentas locales del MVP:

| Usuario    | Contraseña        | Rol         |
|------------|-------------------|-------------|
| `admin`    | `Admin2026!`      | `ADMIN`     |
| `recepcion`| `Recepcion2026!`  | `RECEPTIONIST` |
| `mecanico` | `Mecanico2026!`   | `MECHANIC`  |

> Solo para desarrollo local; nunca usar `root` ni credenciales reales en el repositorio.

### 2. Backend

```powershell
cd server
Copy-Item .env.example .env   # y completa tus valores locales
npm install
npm start                      # API en http://localhost:3000/api
npm test                       # suite completa contra motorix_v2_test
npm run lint                   # ESLint
```

### 3. Frontend

```powershell
cd client
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Convenciones

- **Documentación, commits y mensajes al usuario:** español.
- **Identificadores de código:** inglés.
- Commits con **Conventional Commits** en español (p. ej.
  `feat(clients): agregar validación de teléfono duplicado`).
- Ningún secreto en el repositorio: `.env` está ignorado y `.env.example` no contiene valores reales.
- Pruebas escritas en español, ejecutadas contra `motorix_v2_test` (nunca contra la base principal).

## Documentación útil

- `docs/reglas.md` — reglas del proyecto (base de la constitución).
- `docs/project-context.md` — fuente de verdad del alcance por sprint.
- `docs/design-system.md` — sistema de diseño obligatorio para pantallas.
- `docs/sprints/` — alcance detallado de cada sprint.
- `specs/001-base-clientes-vehiculos/quickstart.md` — validación paso a paso del Sprint 1.
