# 01. Concepción arquitectónica inicial: stack tecnológico y uso de IA generativa

**Proyecto:** Motorix, sistema de gestión para un taller mecánico
**Materia:** Gestión de Proyectos de Software
**Elaboró:** Carlos Castro Rafael
**Fecha de corte de los datos:** 2026-11-19 (rama `006-notificaciones-internas`)

> Todos los datos de este documento salen del repositorio: `server/package.json`, `server/package-lock.json`, `client/pubspec.yaml`, `client/pubspec.lock`, `.specify/init-options.json`, `docs/project-context.md` y `.specify/memory/constitution.md`. Lo que no está en el repositorio aparece como `[COMPLETAR: ...]`.

## 1. Visión general

Motorix es una aplicación cliente-servidor de tres capas:

- **Cliente:** aplicación Flutter (Material 3) compilada para web y para escritorio Windows (carpetas `client/web/` y `client/windows/`).
- **Servidor:** API REST en Node.js con Express, escrita con ES Modules (`"type": "module"` en `server/package.json`).
- **Datos:** MySQL 8 local, con dos bases: `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas automatizadas).
- **Servicio externo:** Mercado Pago Checkout Pro en modo de prueba (sandbox), solo para cobros digitales.

La constitución del proyecto (`.specify/memory/constitution.md`, versión 1.1.0) llama a este stack **MENF** (MySQL, Express, Node y Flutter) y lo declara no negociable para el alcance oficial.

## 2. Stack con versiones reales

La columna «Declarada» es el rango que pide el archivo de configuración; la columna «Instalada» es la versión exacta que resolvió el archivo de bloqueo (`package-lock.json` o `pubspec.lock`).

### 2.1 Cliente (Flutter)

| Tecnología | Declarada | Instalada | Por qué se eligió |
|---|---|---|---|
| Flutter SDK | `>=3.47.0` (exigido por las dependencias) | canal `stable`, revisión `d3b14c87` (`client/.metadata`) | Un solo código para la versión web y la de escritorio, con Material 3 integrado. |
| Dart | `^3.13.2` | `>=3.13.2 <4.0.0` | Lenguaje de Flutter; tipado fuerte y null safety. |
| `provider` | `^6.1.5+1` | 6.1.5+1 | Manejo de estado simple (`ChangeNotifier`), suficiente para el tamaño del proyecto; decisión registrada en `docs/project-context.md` §27. |
| `http` | `^1.6.0` | 1.6.0 | Cliente HTTP oficial de Dart para consumir la API REST. |
| `google_fonts` | `^9.0.0` | 9.0.0 | Tipografía del sistema de diseño (`docs/design-system.md`). |
| `data_table_2` | `^2.6.0` | 2.6.0 | Tablas con encabezado fijo y paginación; se fijó la 2.6.0 porque la 3.x no es compatible con Flutter 3.47. |
| `lucide_icons_flutter` | `^3.1.25` | 3.1.25 | Conjunto de íconos lineales coherente con el sistema de diseño. |
| `cupertino_icons` | `^1.0.8` | 1.0.9 | Íconos base que incluye la plantilla de Flutter. |
| `flutter_test` | SDK | SDK | Pruebas de providers y widgets con `flutter test`. |
| `flutter_lints` | `^6.0.0` | 6.0.0 | Reglas de estilo y análisis estático recomendadas por Flutter. |

### 2.2 Servidor (Node.js / Express)

| Tecnología | Declarada | Instalada | Por qué se eligió |
|---|---|---|---|
| Node.js | 24 LTS (según `CLAUDE.md`; `package.json` no fija `engines`) | v24.19.0 en el equipo de desarrollo | Versión LTS con `fetch` nativo, lo que evitó agregar el SDK de Mercado Pago. |
| Express (ES Modules) | `^4.21.2` | 4.22.3 | Framework HTTP mínimo y muy documentado; ES Modules por regla de la constitución. |
| `mysql2` | `^3.11.5` | 3.24.5 | Driver directo con promesas y consultas parametrizadas, sin ORM (decisión del Sprint 1). |
| `jsonwebtoken` (JWT) | `^9.0.2` | 9.0.3 | Sesión sin estado en el servidor: token firmado con duración de 8 horas. |
| `bcryptjs` | `^3.0.2` | 3.0.3 | Hash de contraseñas (costo 10) en JavaScript puro, sin compilar módulos nativos en Windows. |
| `zod` | `^3.24.1` | 3.25.76 | Validación de entradas en `server/validators/` con mensajes en español. |
| Jest | `^30.0.0` | 30.5.2 | Pruebas unitarias, de integración y de contrato; corre con `maxWorkers: "50%"`. |
| `supertest` | `^7.0.0` | 7.3.1 | Pruebas de los endpoints HTTP sin levantar el servidor real. |
| ESLint | `^9.17.0` | 9.39.5 | Análisis estático (`npm run lint`). |

### 2.3 Datos e integraciones

| Tecnología | Versión | Por qué se eligió |
|---|---|---|
| MySQL | 8 (instalación nativa en Windows, no Docker) `[COMPLETAR: versión exacta de MySQL 8 instalada, p. ej. 8.0.x o 8.4.x]` | Base relacional con llaves foráneas y transacciones (InnoDB); requisito del stack MENF. |
| Mercado Pago Checkout Pro (sandbox) | API REST `https://api.mercadopago.com`, sin SDK | Cobro digital sin que Motorix toque datos de tarjeta; el cliente paga en la página de Mercado Pago. Si no hay `MP_ACCESS_TOKEN`, el servidor usa una pasarela simulada (`server/services/payment_gateway/simulado.js`) para la demostración y las pruebas. |
| Migraciones SQL numeradas | 001 a 007 en `database/migrations/` | Historial reproducible del esquema; se aplican con `database/scripts/aplicar-migraciones.ps1` y se registran en la tabla `schema_migrations`. |

## 3. Uso de IA generativa para estructurar el proyecto

### 3.1 Enfoque: desarrollo guiado por especificaciones (SDD)

El equipo usó **Spec Kit** (GitHub) para trabajar con un flujo de *Spec-Driven Development*: primero se escribe qué se va a construir (especificación), después cómo (plan), luego las tareas, y solo al final el código. La IA genera los borradores de cada artefacto y el humano los revisa antes de avanzar a la siguiente etapa.

| Periodo | Sprints | Herramientas |
|---|---|---|
| MVP | 1 a 4 | Spec Kit + **OpenCode** (versión gratuita) dentro de **VS Code**. La guía de ese periodo está en `docs/guia-spec-kit.md`. |
| Alcance posterior al MVP | 5 a 7 | **Claude Code** con Spec Kit (CLI `specify` **1.1.3**, según `.specify/init-options.json`). Los comandos se invocan con guion: `/speckit-specify`, `/speckit-clarify`, `/speckit-checklist`, `/speckit-plan`, `/speckit-tasks`, `/speckit-analyze` y `/speckit-implement` (carpeta `.claude/skills/`). |

### 3.2 Contexto permanente que recibe la IA

Para que la IA no «invente» el proyecto en cada conversación, el repositorio guarda el contexto en archivos que se cargan siempre:

| Archivo | Función |
|---|---|
| `CLAUDE.md` | Reglas permanentes para Claude Code: comandos, línea base de pruebas, reglas de migraciones, seguridad y forma de reportar. Importa `AGENTS.md`. |
| `AGENTS.md` | Reglas compartidas con OpenCode: idioma español, formato de commits (Conventional Commits), nombres de pruebas en español. |
| `.specify/memory/constitution.md` | Constitución del proyecto (versión 1.1.0, última enmienda 2026-11-13): principios no negociables, alcance oficial, stack y seguridad. Si un sprint la contradice, no se implementa sin una enmienda registrada. |
| `docs/project-context.md` | Contexto maestro: requisitos de alto nivel, módulos, entidades, reglas de negocio, plan de sprints y decisiones resueltas. Es la fuente de verdad del alcance. |
| `docs/sprints/sprint-N-*.md` | Un **insumo** por sprint (plantilla en `docs/sprints/_plantilla.md`): objetivo, historias de usuario, flujo demostrable, tablas, reglas, criterios de aceptación, fuera de alcance y decisiones pendientes. Es la entrada de `/speckit-specify`. |
| `docs/design-system.md` | Reglas visuales del cliente (colores, tipografía, estados de pantalla). |

### 3.3 Etapas del SDD: qué genera la IA y qué revisa el humano

| Etapa del SDD (comando) | Artefacto que genera la IA | Qué revisa el humano |
|---|---|---|
| Constitución (`/speckit-constitution`) | `.specify/memory/constitution.md` con principios, versión SemVer y reporte de impacto | Que los principios reflejen los acuerdos del equipo; cada enmienda lleva fecha, origen y responsable (p. ej. la 1.1.0, acordada por el equipo el 2026-11-11). |
| Insumo del sprint (lo redacta el humano con apoyo de IA) | `docs/sprints/sprint-N-*.md` | Que las historias, criterios y «fuera de alcance» coincidan con lo acordado; si el insumo contradice el código, se reporta antes de implementar. |
| Especificación (`/speckit-specify`) | Rama `NNN-nombre` y `specs/NNN-nombre/spec.md` con historias priorizadas (P1, P2...), escenarios «Dado / Cuando / Entonces», requisitos `FR-###` y criterios de éxito `SC-###` | Que no haya funciones fuera del alcance y que cada historia del insumo esté cubierta. |
| Aclaración (`/speckit-clarify`) | Hasta 5 preguntas con opciones y recomendación; las respuestas se integran en `spec.md` | El humano **decide** cada respuesta (p. ej. «Estado: Borrador (aclarado el 2026-11-16)» en el Sprint 6). |
| Lista de verificación (`/speckit-checklist`) | `specs/NNN/checklists/*.md` («pruebas unitarias» de la redacción de los requisitos) | Que los requisitos sean completos, claros y medibles antes de planear. |
| Plan (`/speckit-plan`) | `plan.md`, `research.md` (decisiones R-##), `data-model.md`, `contracts/` (endpoints) y `quickstart.md` | Que el diseño respete la constitución: migraciones aditivas, lógica en servicios, permisos en el backend, sin dependencias nuevas sin justificar. |
| Tareas (`/speckit-tasks`) | `tasks.md` con tareas `T###`, marcas `[P]` (paralelizables) y `[US#]` (historia), ordenadas por dependencia y con pruebas primero | Que el orden sea ejecutable y que cada historia tenga sus pruebas. |
| Análisis (`/speckit-analyze`) | Reporte de consistencia entre `spec.md`, `plan.md` y `tasks.md` (sin modificar archivos) | Qué hallazgos se corrigen antes de implementar. |
| Implementación (`/speckit-implement`) | Código, pruebas, migraciones y `reporte-implementacion.md`; marca las tareas como `[x]` | Corre o revisa las suites (`npm test`, `flutter test`), prueba la app en el navegador, aprueba o rechaza excepciones y decide el commit. |

### 3.4 Evidencia de supervisión humana en el repositorio

- **Tareas no ejecutadas por decisión humana:** en `specs/005-precios-refacciones-cobro/tasks.md`, la tarea T084 quedó sin marcar con la nota «No ejecutada por decisión de Carlos (2026-11-16)».
- **Excepciones autorizadas:** el hallazgo H-S6-02 (timeouts de pruebas por contención de CPU) se resolvió con `maxWorkers: "50%"` como «excepción autorizada por Carlos»; la evidencia está en `docs/evidencias/sprint 6/`.
- **Regla de no commit automático:** `CLAUDE.md` prohíbe a la IA hacer commit o push salvo petición expresa; los commits los decide el humano.
- **Línea base de pruebas registrada:** desde el Sprint 6 (2026-11-16) la línea base es de 79 suites y 649 pruebas en el backend y 186 pruebas en `flutter test`, según `CLAUDE.md`.

### 3.5 Limitaciones y riesgos del uso de IA

- La IA puede proponer funciones fuera del alcance; por eso la constitución exige trazabilidad requisito → historia → sprint → implementación.
- La IA puede «arreglar» pruebas debilitándolas; `CLAUDE.md` prohíbe borrar o debilitar pruebas sin registrarlo y avisar.
- Los secretos (`server/.env`, tokens de Mercado Pago) quedan fuera del alcance de la IA por regla explícita.
- `[COMPLETAR: horas estimadas ahorradas o costo del uso de IA, si el profesor lo solicita]`
