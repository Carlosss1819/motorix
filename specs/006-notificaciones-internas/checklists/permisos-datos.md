# Lista de calidad de requisitos: permisos por rol y exposición de datos

**Propósito**: comprobar que los requisitos de permisos y de exposición de datos del Sprint 6 estén completos, claros y sean coherentes (no prueba la implementación).
**Creada**: 2026-11-16
**Funcionalidad**: [spec.md](../spec.md)

> Un `[x]` significa que el revisor dio por buena la calidad del requisito, no que esté implementado. Evaluación hecha por el agente a pedido de Carlos (2026-11-16).

## Completitud

- [x] CHK001 - ¿Están definidos los tipos de aviso que recibe cada uno de los tres roles? [Completitud, Spec §FR-009 a FR-011]
- [x] CHK002 - ¿Está definido el acceso de cada rol a «Clientes por avisar», tanto para consultar como para marcar? [Completitud, Spec §FR-019, FR-022, FR-029]
- [x] CHK003 - ¿Se especifica la respuesta para peticiones sin sesión? [Completitud, Spec §FR-013, FR-030] (corregido: se agregó FR-030 con 401)
- [x] CHK004 - ¿Se define qué pasa si un usuario intenta marcar como leído un aviso que no le corresponde? [Gap → resuelto, Spec §FR-030]

## Claridad

- [x] CHK005 - ¿Está definido sin ambigüedad qué órdenes son «asignadas» al mecánico, incluidas las que no tienen mecánico? [Claridad, Spec §FR-011, Casos límite]
- [x] CHK006 - ¿Está explícito que ningún aviso, para ningún rol, incluye importes? [Claridad, Spec §FR-012, Corrección C-04]
- [x] CHK007 - ¿Está claro que el filtro por rol lo aplica el servidor y no solo la interfaz? [Claridad, Spec §FR-013]

## Coherencia

- [x] CHK008 - ¿Los avisos del mecánico son coherentes con sus permisos actuales (sin acceso a citas, al panel ni a pagos)? [Coherencia, Spec §FR-011, Corrección C-09]
- [x] CHK009 - ¿La exclusión de stock para RECEPTIONIST y MECHANIC es coherente entre la historia 3, FR-010 y FR-011? [Coherencia]
- [x] CHK010 - ¿Los datos personales del cliente (teléfono) solo se exponen a los roles que ya pueden ver clientes? [Coherencia, Spec §FR-019, FR-022]

## Cobertura de escenarios y casos límite

- [x] CHK011 - ¿Se cubren las órdenes detenidas sin mecánico asignado? [Casos límite]
- [x] CHK012 - ¿Se cubre la marcación concurrente del mismo hecho por dos recepcionistas? [Casos límite, Spec §FR-020]
- [x] CHK013 - ¿Se documenta la limitación del cambio de rol con la sesión abierta (heredada del Sprint 5)? [Supuesto] (cubierta por la regla vigente: el servidor aplica el rol actual en cada petición, así que los avisos se filtran por el rol nuevo)

## Medibilidad

- [x] CHK014 - ¿Se puede medir de forma objetiva que cada rol recibe solo sus avisos? [Medibilidad, Spec §SC-002]

## Notas

- Corrección aplicada a la spec durante la revisión: FR-030 (marcar una clave ajena o inexistente responde éxito sin guardar; 401 sin sesión).
