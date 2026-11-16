# Motorix - instrucciones permanentes para Claude Code

@AGENTS.md

Lo de arriba importa las reglas que ya existen en `AGENTS.md` (idioma, formato de commits, nombres de pruebas). Lo de abajo es lo que se agrega para trabajar con Claude Code. Si hay contradicción, gana la constitución (`.specify/memory/constitution.md`) y luego este archivo.

## Qué es el proyecto
Motorix: sistema para un taller mecánico. Flutter (cliente, Material 3) + Node 20 / Express (servidor, ES Modules) + MySQL 8. Roles: ADMIN, RECEPTIONIST, MECHANIC. Proyecto escolar de 6 personas, materia "Gestión de proyectos de software". El MVP fueron los sprints 1 a 4; los sprints 5 en adelante son posteriores al MVP.

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

## Reglas de trabajo
1. No hagas commit ni push salvo que el usuario lo pida expresamente.
2. Nunca trabajes en `main`. La rama `NNN-nombre` la crea `/speckit.specify`.
3. No leas, imprimas ni subas secretos (`.env`, claves, tokens).
4. Migraciones: aditivas y numeradas (`005_...`); nunca edites una migración ya aplicada. Seeds: idempotentes.
5. Backend: ES Modules; la lógica de negocio va en servicios; los permisos se validan en el backend, no solo en la interfaz.
6. Pruebas primero: planea las pruebas antes del código. Corre la suite completa antes de empezar y al terminar. No borres ni debilites pruebas existentes sin registrarlo y avisar.
7. Hay dos pruebas de bloqueo de cuenta (auth) que fallaron de forma intermitente con la suite completa (timeout de 5000 ms) y pasan aisladas. No las "arregles" en silencio: repórtalo (hallazgo H-B01 abierto).
8. Seguridad: nunca guardes datos de tarjeta; no devuelvas trazas de error (stack traces) al cliente.
9. Si un sprint contradice un principio de la constitución (por ejemplo, el principio I: MVP = sprints 1 a 4), NO implementes hasta que exista una enmienda registrada (versión SemVer, fecha, impacto). Avisa al usuario.
10. Para editar archivos usa las herramientas de edición, no cadenas en PowerShell (los acentos y las comillas invertidas fallan).
11. Idioma: responde, documenta y escribe commits en español; identificadores de código en inglés.

## Cómo reportar
Al terminar cada paso informa: archivos cambiados, historias o requisitos cubiertos, pruebas corridas (comando y resultado real, sin inventar conteos), pendientes y riesgos. Antes de una decisión difícil de revertir, detente y propón opciones.

## Usuario
Carlos usa poco la terminal y GitHub: explica los términos técnicos y di qué comando correr y qué esperar ver.
