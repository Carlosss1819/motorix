# Motorix - instrucciones permanentes para Claude Code

@AGENTS.md

Lo de arriba importa las reglas que ya existen en `AGENTS.md` (idioma, formato de commits, nombres de pruebas). Lo de abajo es lo que se agrega para trabajar con Claude Code. Si hay contradicción, gana la constitución (`.specify/memory/constitution.md`) y luego este archivo.

## Qué es el proyecto
Motorix: sistema para un taller mecánico. Flutter (cliente, Material 3) + Node 24 (LTS) / Express (servidor, ES Modules) + MySQL 8. Roles: ADMIN, RECEPTIONIST, MECHANIC. Proyecto escolar de 6 personas, materia "Gestión de proyectos de software". El MVP fueron los sprints 1 a 4. El alcance oficial posterior al MVP son los sprints 5 a 7 (enmienda 1.1.0); los sprints 8 a 10 son opcionales.

## Fuentes de verdad (léelas antes de decidir, no supongas)
- `docs/project-context.md`: contexto técnico y funcional.
- `docs/reglas.md` y `.specify/memory/constitution.md`: constitución del proyecto.
- `docs/design-system.md`: reglas visuales del cliente.
- `docs/sprints/`: el insumo de cada sprint. Si el insumo contradice el código, el código manda: repórtalo antes de implementar.
- `specs/NNN-nombre/`: lo que genera Spec Kit por sprint.

## Comandos
- Backend (en `server/`): `npm test` (Jest + supertest), `npm run lint`.
- Frontend (en `client/`): `flutter test`.
- Bases de datos: `motorix_v2` (desarrollo) y `motorix_v2_test` (pruebas). Scripts en `database/scripts/*.ps1`.
- Entorno de desarrollo: Windows (cmd/PowerShell).
- Spec Kit: en Claude Code los comandos se escriben con guion (`/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, etc.); en OpenCode, con punto (`/speckit.specify`, `/speckit.plan`, etc.).

## Reglas de trabajo
1. No hagas commit ni push salvo que el usuario lo pida expresamente.
2. Nunca trabajes en `main`. La rama `NNN-nombre` la crea `/speckit-specify` (Claude Code) o `/speckit.specify` (OpenCode).
3. No leas, imprimas ni subas secretos (`.env`, claves, tokens).
4. Migraciones: aditivas y numeradas (`005_...`). «Aditiva» significa no editar migraciones ya aplicadas y no borrar tablas, columnas ni datos. Se permite reemplazar una restricción (por ejemplo, un índice único) si se conservan los datos y se documenta en el plan del sprint. Seeds: idempotentes.
5. Backend: ES Modules; la lógica de negocio va en servicios; los permisos se validan en el backend, no solo en la interfaz.
6. Pruebas primero: planea las pruebas antes del código. Corre la suite completa antes de empezar y al terminar. No borres ni debilites pruebas existentes sin registrarlo y avisar.
7. Línea base (desde el Sprint 6, 2026-11-16): backend 79 suites y 649 pruebas, sin timeouts, con Jest en `maxWorkers: "50%"` (corridas de 16 a 85 s según la carga del equipo); `flutter test` 186 pruebas. Si una prueba vuelve a fallar de forma intermitente, no la "arregles" en silencio: repórtalo como hallazgo.
   - H-S6-02, resuelto el 2026-11-16 (excepción autorizada por Carlos): timeouts de 5 s en login e historial con 11 procesos de Jest en paralelo (contención de CPU). Corrección: `maxWorkers: "50%"` en `server/package.json`; no se cambió `testTimeout`. Evidencia: `docs/evidencias/sprint 6/h-s6-02-*.txt` y `s6-final-npm-*.txt`.
   - H-B01, resuelto el 2026-11-14: las dos pruebas de bloqueo de cuenta (auth) fallaban por timeout de 5000 ms con la suite completa. Causa: cada suite repetía `prepareTestDatabase` y hacía fila en el lock de MySQL, y el pool de MySQL quedaba sin cerrar. Corrección: `globalSetup` (`server/tests/helpers/global-setup.js`) que prepara la base una sola vez y `teardown.js` que cierra el pool. Evidencia: `docs/evidencias/sprint 5/h-b01-*.txt`.
   - H-B02, resuelto el 2026-11-14: `server/tests/integration/dashboard.test.js` dependía de citas de corridas anteriores. Corrección: fecha de referencia única por corrida (el día siguiente a la última cita registrada). Evidencia: `docs/evidencias/sprint 5/h-b02-*.txt` (3 corridas, 49/49 suites y 411/411 pruebas).
8. Seguridad: nunca guardes datos de tarjeta; no devuelvas trazas de error (stack traces) al cliente.
9. Si un sprint contradice un principio de la constitución (por ejemplo, el principio I: alcance oficial = sprints 1 a 7, así que un sprint 8 a 10 requiere enmienda propia), NO implementes hasta que exista una enmienda registrada (versión SemVer, fecha, impacto). Avisa al usuario.
10. Para editar archivos usa las herramientas de edición, no cadenas en PowerShell (los acentos y las comillas invertidas fallan).
11. Idioma: responde, documenta y escribe commits en español; identificadores de código en inglés.

## Cómo reportar
Al terminar cada paso informa: archivos cambiados, historias o requisitos cubiertos, pruebas corridas (comando y resultado real, sin inventar conteos), pendientes y riesgos. Antes de una decisión difícil de revertir, detente y propón opciones.

## Usuario
Carlos usa poco la terminal y GitHub: explica los términos técnicos y di qué comando correr y qué esperar ver.
