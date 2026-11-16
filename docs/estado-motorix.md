# Estado del proyecto Motorix (implementación)

Estado conocido al 2026-11-13. Todo lo posterior hay que confirmarlo con Carlos.

## Datos base
- Responsable: Carlos Castro Rafael (product builder). Aprobador asignado en el proyecto escolar: Jorge Francisco. Los roles son asignados por el profesor; no hay aprobación formal y no se debe inventar.
- Repositorio: https://github.com/Carlosss1819/motorix (público). Todo está en `main`, commit base `a01b8b1`.
- Herramienta de trabajo: se deja OpenCode y se usa Claude Code. Reglas en `CLAUDE.md` (importa `AGENTS.md`).
- Pruebas: `npm test` en `server/`, `flutter test` en `client/`. Base de pruebas `motorix_v2_test`.

## Objetivo actual
1. Implementar Sprint 5 (precios de refacciones y cobro) con Spec Kit. Nada de Spec Kit se ha ejecutado todavía.
2. Implementar Sprints 6 y 7 (specs enviadas por el líder del equipo).
3. Decidir hosting (no se sabe si los specs del líder lo cubren; el insumo del Sprint 5 ubica la puesta en producción en el Sprint 10).
4. Aviso de privacidad y política de privacidad, con su documentación (el profesor advirtió de multas). No soy abogado; verificar con fuentes oficiales y con el profesor.
5. Revisar si los sprints 6 en adelante encajan con Motorix o necesitan ajustes como el Sprint 5.
Ya no se documenta el Sprint 5 como QA.

## Sprint 5 (insumo corregido, opción A)
Brechas: congelar precio en `order_parts`; tickets emitidos que no cambien; precio de compra solo para ADMIN; validar 2 decimales y topes; revalidar pagos pendientes de Mercado Pago; centavos enteros; aviso «sin precio registrado» en el ticket; migración `005` y seeds. Además H-15: inmovilizar contenido de órdenes `TERMINADO` con pago (decidido el 2026-11-04). Requiere enmienda de la constitución (principio I) antes de implementar; no hay enmienda registrada.

## Línea base (commit a01b8b1)
- Backend: 49 suites / 411 pruebas. Captura B-1 (2026-11-03): 2 fallos de auth (uno con timeout 5000 ms visible). TXT B-2: 49/49, 7.618 s. Ejecución aislada de auth (declarada): 2 suites, 16 pruebas, 3.853 s. Repetición completa del 2026-11-04 (declarada, sin log): 49/49, 24.712 s.
- Frontend: 127 pruebas aprobadas.
- H-B01 abierto: causa de los timeouts y de la advertencia «worker failed to exit» no investigada.

## Hallazgos conocidos del código (útiles como lista de trabajo)
H-06 (precio no congelado, precioCompra expuesto, sin límite de decimales, MP sin revalidar), H-02 (insumo original contradecía el código), H-05 (README desactualizado), H-B01.

## Pendientes inmediatos
- Subir/pegar specs de Sprints 6 y 7 del líder.
- Revisión de solo lectura del insumo de cada sprint contra el código.
- Enmienda de constitución para sprints post-MVP.
- Confirmar versión de Claude Code y que Spec Kit tenga comandos para Claude.

## Reglas de trabajo
Todo dato sale de lo que Carlos pega o de los archivos; si falta, se pide en un solo mensaje. No inventar conteos, líneas, tiempos ni aprobaciones. No pedir commit ni push. Respuestas en español, detalladas, paso a paso.
