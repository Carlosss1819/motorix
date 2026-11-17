# Lista de calidad de requisitos: cálculo de avisos y coherencia con las pantallas existentes

**Propósito**: comprobar que los criterios de cálculo de cada aviso estén definidos sin ambigüedad y sean coherentes con el panel, la lista de Mantenimientos y Refacciones (no prueba la implementación).
**Creada**: 2026-11-16
**Funcionalidad**: [spec.md](../spec.md)

> Un `[x]` significa que el revisor dio por buena la calidad del requisito, no que esté implementado. Evaluación hecha por el agente a pedido de Carlos (2026-11-16).

## Completitud

- [x] CHK001 - ¿Cada tipo de aviso tiene un criterio de inclusión explícito? [Completitud, Spec §FR-003 a FR-006]
- [x] CHK002 - ¿Está definida la fecha de referencia de cada tipo de aviso? [Gap → resuelto, Spec §FR-007] (corregido)
- [x] CHK003 - ¿Está definido el orden de los grupos y de los avisos dentro de cada grupo? [Gap → resuelto, Spec §FR-007a] (corregido)
- [x] CHK004 - ¿Se define qué población de mantenimientos se considera (la misma que la lista de Mantenimientos)? [Completitud, Spec §FR-003] (corregido)

## Claridad

- [x] CHK005 - ¿Está cuantificado «más de N días» (N × 24 horas, N = 3, configurable)? [Claridad, Spec §FR-006]
- [x] CHK006 - ¿Están listados de forma explícita los estados de orden que pueden estar detenidos (sin `TERMINADO` ni `ENTREGADO`)? [Claridad, Spec §FR-006, ajuste de Carlos]
- [x] CHK007 - ¿Los estados de cita se nombran con los valores reales del sistema? [Claridad, Spec §FR-005, Corrección C-08]
- [x] CHK008 - ¿Está definido «agotado» respecto de la regla existente de stock bajo? [Claridad, Spec §FR-004, Corrección C-12]
- [x] CHK009 - ¿Está definido qué es «hoy» y «mañana» (fecha local del servidor, como el panel)? [Claridad, Supuestos]

## Coherencia

- [x] CHK010 - ¿El criterio de citas de hoy coincide con el del bloque de citas del panel? [Coherencia, Spec §FR-005, FR-008]
- [x] CHK011 - ¿El criterio de stock coincide con el filtro «solo stock bajo» y el bloque del panel? [Coherencia, Spec §FR-004, FR-016]
- [x] CHK012 - ¿No se duplica una orden `TERMINADO` entre «Orden detenida» y «Clientes por avisar»? [Coherencia, Spec §FR-006, Casos límite] (resuelto con el ajuste de Carlos)
- [x] CHK013 - ¿Las referencias a pantallas existentes coinciden con las que hay en el cliente (sin la insignia de Inventario que no existe)? [Coherencia, Corrección C-06]

## Casos límite

- [x] CHK014 - ¿Se cubren los mantenimientos sin objetivo, con doble cumplimiento (fecha y km) y con kilometraje actualizado en otra orden? [Casos límite]
- [x] CHK015 - ¿Se cubren las refacciones inactivas y las de stock mínimo 0? [Casos límite] (corregido durante el plan: la regla existente no excluye inactivas, y los avisos la siguen igual para que los números coincidan)
- [x] CHK016 - ¿Se cubren las órdenes sin historial de cambios? [Casos límite, Spec §FR-006]

## Requisitos no funcionales

- [x] CHK017 - ¿Está cuantificado el rendimiento de la consulta, con volumen y umbral? [Medibilidad, Spec §SC-006]
- [x] CHK018 - ¿Se especifica que no hay paginación y qué pasa con más de 99 avisos? [Gap → resuelto, Spec §FR-007a] (corregido)

## Notas

- Correcciones aplicadas a la spec durante la revisión: FR-003 (misma población y kilometraje vigente), FR-007 (fecha de referencia por tipo), FR-007a (orden, sin paginación, «99+»).
