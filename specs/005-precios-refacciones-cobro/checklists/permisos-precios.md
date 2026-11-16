# Checklist de permisos por rol y exposición de precios: Precios de refacciones y cobro completo

**Propósito**: evaluar la calidad de los requisitos sobre qué precios recibe cada rol en las respuestas del servidor (D-10 y su alcance). Evalúa lo escrito en la spec, no la implementación.
**Fecha de creación**: 2026-11-14
**Funcionalidad**: [spec.md](../spec.md)

**Nota**: checklist personalizado generado por `/speckit-checklist` a partir de la spec y sus aclaraciones de la sesión 2026-11-14.
**Responsable de la revisión**: es un artefacto de revisión de la calidad de los requisitos y pertenece a quien revisa. Marca un ítem `[x]` solo cuando quien revisa determine que el requisito cumple el criterio.
**Significado de las marcas**: `[x]` significa que el criterio se revisó y se cumple para la calidad de los requisitos. No significa que la implementación esté terminada.

## Completitud de los requisitos

- [x] CHK001 ¿Enumera la spec todas las respuestas del servidor donde puede aparecer un precio de refacción (catálogo, detalle, detalle y listado de órdenes, desglose del pago, ticket, panel e historial de movimientos), en lugar de terminar en «u otra»? [Completitud, Spec §FR-024]
- [x] CHK002 ¿Se define si el mecánico recibe el total o los subtotales de la orden? Esos importes incluyen las refacciones y permitirían deducir sus precios. [Gap, Spec §FR-025, §FR-026]
- [x] CHK003 ¿Se documenta que el mecánico no tiene acceso a pagos ni a tickets (hoy son solo de administración y recepción) y que eso forma parte de la restricción de D-10? [Supuesto, Gap, Spec §FR-025]
- [x] CHK004 ¿Se especifican los requisitos de interfaz para cada rol (columnas, campos o formularios de precio ocultos al mecánico), además de la restricción en el servidor? [Gap, Spec §US5]
- [x] CHK005 ¿Se define a qué rol se le muestra la advertencia de D-07 y si recepción o el mecánico pueden llegar a verla? [Completitud, Spec §FR-004]
- [x] CHK006 ¿Se especifica si los cambios de precio del catálogo dejan un registro de quién los hizo y cuándo, o se excluye a propósito? [Gap, Spec §FR-002]

## Claridad de los requisitos

- [x] CHK007 ¿Se especifica cómo «no recibe» el precio un rol no autorizado: el campo se omite, llega vacío o la petición se rechaza? [Ambigüedad, Spec §FR-024, §FR-025]
- [x] CHK008 ¿Queda claro que «precio congelado de las líneas» de FR-025 incluye también el importe de cada línea (cantidad × precio), que expone el mismo dato? [Claridad, Spec §FR-025]
- [x] CHK009 ¿Se define si la restricción del mecánico depende del rol o de si la orden le está asignada (órdenes propias frente a ajenas)? [Claridad, Spec §FR-026]
- [x] CHK010 ¿Está definida la lista exacta de campos de refacción que recibe el mecánico (nombre, código, unidad, existencia) y si incluye otros datos no monetarios como categoría, marca o si está activa? [Claridad, Spec §FR-025]

## Consistencia de los requisitos

- [x] CHK011 ¿Son consistentes FR-025 (el mecánico no recibe precios de refacción) y FR-026 (sí captura y ve el precio de la mano de obra) con la aclaración del alcance de D-10? [Consistencia, Spec §FR-025, §FR-026, §Clarifications]
- [x] CHK012 ¿Es consistente el título de US5 («Precios de refacciones visibles según el rol») con su historia, que solo menciona el precio de compra? [Consistencia, Spec §US5]
- [x] CHK013 ¿Es consistente FR-002 (solo el administrador edita precios) con los escenarios de US1 que rechazan a recepción y al mecánico? [Consistencia, Spec §FR-002, §US1]
- [x] CHK014 ¿Es consistente el panel de control (solo administración) con FR-027, sin requisitos de precio distintos por rol? [Consistencia, Spec §FR-027]

## Calidad de los criterios de aceptación

- [x] CHK015 ¿Se puede medir SC-004 con una lista cerrada de respuestas que hay que revisar por rol? [Medibilidad, Spec §SC-004]
- [x] CHK016 ¿Indica SC-004 cómo se comprueba que el mecánico no puede deducir precios de refacción a partir de totales u otros importes? [Gap, Spec §SC-004]

## Cobertura de escenarios

- [x] CHK017 ¿Se cubren las peticiones directas al servidor (sin la interfaz) para cada tipo de respuesta y cada rol, no solo para el catálogo? [Cobertura, Spec §US5 escenario 6]
- [x] CHK018 ¿Se cubre el caso de un usuario cuyo rol cambia mientras tiene una sesión abierta (por ejemplo, de recepción a mecánico)? [Gap, Excepción]
- [x] CHK019 ¿Se cubren las búsquedas, filtros u ordenamientos del catálogo por precio, para que no expongan precios al mecánico de forma indirecta? [Gap, Cobertura]
- [x] CHK020 ¿Se definen los mensajes de error y el código que recibe un rol no autorizado al intentar crear o editar precios? [Completitud, Spec §FR-002]

## Requisitos no funcionales (seguridad)

- [x] CHK021 ¿Se especifica que los mensajes de error y los registros no exponen precios restringidos ni trazas internas al rol no autorizado? [Gap, Seguridad, constitución principio IV]
- [x] CHK022 ¿Están las restricciones por rol de FR-024 a FR-026 ligadas de forma explícita a RN-15 (validación en el servidor) y al principio IV de la constitución? [Trazabilidad, Spec §FR-026]

## Notas

- Marca los ítems `[x]` solo cuando la revisión confirme que el requisito cumple el criterio.
- Deja sin marcar los ítems que todavía necesitan aclaración, corrección o evaluación de quien revisa.
- `/speckit-implement` lee el estado de las casillas como compuerta y no debe modificar las marcas.
- `checklists/requirements.md` tiene su propio ciclo, que mantienen `/speckit-specify` y `/speckit-clarify`.
- Anota los comentarios o hallazgos junto a cada ítem.
- Los ítems se numeran en orden para poder citarlos.
