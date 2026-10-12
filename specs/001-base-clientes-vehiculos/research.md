# Investigación (Fase 0)

**Funcionalidad**: Base del Sistema, Clientes y Vehículos (`001-base-clientes-vehiculos`)
**Fecha**: 2026-10-11 | **Plan**: [plan.md](plan.md)

No quedan incógnitas marcadas como NEEDS CLARIFICATION en el Contexto Técnico: todas se
resolvieron con la constitución, `docs/project-context.md` y las aclaraciones de
`spec.md` (sesión 2026‑10‑11).

---

## R‑01: Stack y estructura del repositorio

- **Decisión**: Frontend Flutter + Dart (Material Design 3, Provider); backend Node.js
  LTS + Express en ES Modules con capas `config/`, `models/`, `services/`,
  `controllers/`, `routes/`, `middlewares/`, `validators/`, `utils/` directamente en
  `server/`; persistencia MySQL local con scripts SQL en `database/`.
- **Rationale**: Es el stack fijado por la constitución (Principios II y III) y ya
  validado como decisión del Sprint 1; separa las responsabilidades y permite probar
  cada capa por separado.
- **Alternativas consideradas**: React (descartado: el stack ya fijaba Flutter); ORM o
  query builder (descartado: se usa `mysql2` directo); Docker para MySQL (descartado:
  instalación nativa local, decisión R‑04 del proyecto); carpeta `src/` en el backend
  (descartado: decisión explícita del equipo).

## R‑02: Sesión de usuario: duración e inactividad

- **Decisión**: Token JWT con vida máxima de 8 horas y cierre automático de la sesión
  tras 30 minutos de inactividad (escenario US1.6 y FR‑004). El rol y el estado activo
  del usuario se consultan en cada petición.
- **Rationale**: La especificación resolvió 30 minutos de inactividad en `/speckit.clarify`;
  `docs/project-context.md` fija 8 horas de duración del JWT. Ambas se cumplen si el
  token expira a las 8 horas como máximo absoluto y la inactividad de 30 minutos se
  controla en el servidor (o en cliente con verificación en cada petición).
- **Alternativas consideradas**: Solo JWT de 8 h (viola US1.6); solo sesión de 30 min
  sin tope absoluto (deja tokens váliles demasiado tiempo); control de inactividad solo
  en el frontend (no seguro: RN‑15 exige validación en backend).

## R‑03: Bloqueo de cuenta por intentos fallidos

- **Decisión**: Tras 5 inicios de sesión fallidos consecutivos, la cuenta se bloquea 15
  minutos. Cada intento fallido se responde con el mismo mensaje genérico (FR‑003).
- **Rationale**: Decisión ya resuelta en `docs/project-context.md` (Sesión y bloqueo);
  cierra el ítem que la especificación dejó diferido y reduce el riesgo de fuerza bruta
  sin añadir dependencias.
- **Alternativas consideradas**: Sin límite de intentos (riesgo de fuerza bruta);
  captcha o servicio externo (dependencia innecesaria en un MVP local).

## R‑04: Acceso del rol MECHANIC en el Sprint 1 ⚠ conflicto abierto

- **Decisión (para implementar)**: El rol MECHANIC solo usa inicio de sesión, Inicio y
  Mi cuenta; no accede a clientes ni vehículos (FR‑021, FR‑022 y aclaración Q5 del
  2026‑10‑11 en `spec.md`).
- **Rationale**: Es la respuesta explícita del equipo en `/speckit.clarify` y es la
  decisión más reciente.
- **Conflicto**: `docs/project-context.md` (Decisiones resueltas durante el Sprint 1)
  dice "MECHANIC solo consulta clientes y vehículos", es decir, acceso de solo lectura.
- **Acción requerida**: confirmar con el equipo cuál prevalece y, si manda la
  especificación, actualizar `docs/project-context.md` (constitución, Principio I: si
  cambia una regla de rol, la fuente de verdad DEBE actualizarse). El cambio de
  implementación en caso de volverse a la lectura es pequeño (sidebar + vistas de solo
  lectura).
- **Alternativas consideradas**: acceso de solo lectura (opción B de la clarificación,
  descartada por el equipo en esta sesión).

## R‑05: Reglas de unicidad y duplicados

- **Decisión**: `username` y `email` únicos en `users`; `placas` única y `vin` único
  cuando se captura en `vehicles` (FR‑012, FR‑023); un teléfono de cliente repetido
  avisa y pide confirmación, pero no bloquea el registro (regla resuelta en
  `docs/project-context.md`).
- **Rationale**: Evita fichas ambiguas en vehículos sin impedir el registro de familia
  con el mismo teléfono (caso real de talleres).
- **Alternativas consideradas**: teléfono único (se descartó: impide registrar familiares
  con el mismo contacto); sin restricción de placas (se descartó en la clarificación Q4).

## R‑06: Migraciones y seeds

- **Decisión**: Migraciones SQL numeradas e inmutables en `database/migrations/`
  ejecutadas por `database/scripts/aplicar-migraciones.ps1` (idempotentes, con registro
  en `schema_migrations`); seeds idempotentes en `database/seeds/` con al menos 3
  clientes, 3 vehículos y 3 usuarios de ejemplo (SC‑004, SC‑005, FR‑020); entorno local
  con `database/scripts/crear-entorno.ps1` y usuario dedicado `motorix_app`.
- **Rationale**: Exigido por el Principio III y por las decisiones ya resueltas del
  proyecto; permite recrear la base desde cero.
- **Alternativas consideradas**: ORM con migraciones automáticas (descartado: sin ORM);
  seeds en JavaScript del backend (descartado: los seeds viven en `database/`; el
  administrador puede regenerarse con `server/scripts/create-admin.js`).

## R‑07: Validación, errores y autorización

- **Decisión**: Esquemas `zod` en `server/validators/` con mensajes en español;
  middleware de autenticación (JWT) y de autorización (rol) en cada ruta protegida;
  manejo de errores centralizado que devuelve JSON con código HTTP apropiado y nunca
  trazas internas.
- **Rationale**: Principios IV y VI; RN‑15 exige que la autorización viva en el backend.
- **Alternativas consideradas**: validación solo en el formulario (descartado por
  RN‑15); librerías de error personalizado con dependencias externas (innecesarias).

## R‑08: Estrategia de pruebas

- **Decisión**: Jest (unitarias) + Jest + supertest (integración y contrato) contra la
  base `motorix_v2_test`; `flutter test` para providers y widgets; cobertura mínima de
  lógica de negocio: roles/permisos, login usuario o correo, duplicados, política de
  contraseña, RN‑1 (vehículo sin propietario).
- **Rationale**: Principio VII y decisiones resueltas; `motorix_v2_test` protege la base
  principal.
- **Alternativas consideradas**: pruebas solo manuales (descartado: el DoD exige pruebas);
  Cypress/E2E (fuera del alcance definido).

## R‑09: Interfaz y sistema de diseño

- **Decisión**: Pantallas según el sidebar de la aclaración (Inicio, Clientes,
  Vehículos, Usuarios, Mi cuenta) con `NavigationRail` colapsable (~260/~72 px) y estado
  en un Provider; tokens de color/tipografía/espaciado/radio desde `ThemeData`
  (`client/lib/utils/app_theme.dart`); confirmación obligatoria al cerrar sesión, salir
  de formularios con cambios sin guardar y desactivar registros; estados vacío, cargando,
  error y éxito en toda pantalla; sin librería extra de componentes (solo `google_fonts`,
  `data_table_2` 2.6.0 y `lucide_icons_flutter`).
- **Rationale**: `docs/design-system.md` es de cumplimiento obligatorio (Principio VIII).
- **Alternativas consideradas**: set de íconos de Material (posible, pero la librería
  `lucide_icons_flutter` está propuesta; **pendiente de confirmación del equipo**);
  librería de componentes `shadcn_ui` u otra (decisión resuelta: ninguna).

## R‑10: Formularios de clientes y vehículos

- **Decisión**: Cliente: nombre y teléfono obligatorios, correo opcional (aclaración Q3);
  vehículo: propietario obligatorio (RN‑1), placas únicas, VIN opcional pero único,
  kilometraje actual ≥ 0.
- **Rationale**: Respuestas de `/speckit.clarify` más reglas ya resueltas del proyecto.
- **Alternativas consideradas**: correo obligatorio (descartado en Q3: no todos los
  propietarios lo tienen).

---

## Ítems abiertos para el equipo

1. **R‑04 (alto)**: acceso del rol MECHANIC — especificación (sin acceso) vs
   `docs/project-context.md` (solo lectura). Confirmar y actualizar el documento que
   corresponda.
2. **R‑09 (bajo)**: confirmar el set de íconos `lucide_icons_flutter`.

## Resultado

**Todos los NEEDS CLARIFICATION del Contexto Técnico están resueltos** (0 pendientes).
Se puede avanzar a la Fase 1.
