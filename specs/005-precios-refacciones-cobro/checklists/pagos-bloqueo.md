# Checklist de pagos con Mercado Pago y bloqueo de órdenes pagadas: Precios de refacciones y cobro completo

**Propósito**: evaluar la calidad de los requisitos sobre el pago pendiente con importe desfasado (D-04) y la inmovilización de órdenes `TERMINADO` pagadas (H15-a y H15-b). Evalúa lo escrito en la spec, no la implementación.
**Fecha de creación**: 2026-11-14
**Funcionalidad**: [spec.md](../spec.md)

**Nota**: checklist personalizado generado por `/speckit-checklist` a partir de la spec y sus aclaraciones de la sesión 2026-11-14.
**Responsable de la revisión**: es un artefacto de revisión de la calidad de los requisitos y pertenece a quien revisa. Marca un ítem `[x]` solo cuando quien revisa determine que el requisito cumple el criterio.
**Significado de las marcas**: `[x]` significa que el criterio se revisó y se cumple para la calidad de los requisitos. No significa que la implementación esté terminada.

## Completitud de los requisitos

- [x] CHK001 ¿Se especifica si el pago cancelado por importe desfasado guarda un motivo registrado (por ejemplo, «importe desfasado») que lo distinga de una cancelación manual? [Gap, Spec §FR-016]
- [x] CHK002 ¿Se define qué datos debe mostrar el aviso de FR-016 (importe del pago, total actual y diferencia)? [Completitud, Spec §FR-016]
- [x] CHK003 ¿Se especifica si una orden admite más de un ticket (uno por cada pago `PAGADO`, incluido el del pago anulado) y cómo se distinguen? [Gap, Spec §FR-022, §FR-019]
- [x] CHK004 ¿Se define si el ticket emitido con un pago anulado se muestra con alguna marca de «pago anulado»? [Gap, Spec §FR-022]
- [x] CHK005 ¿Está documentado en los supuestos o riesgos el caso en que Mercado Pago ya cobró el importe anterior y el sistema cancela el pago, quedando la devolución fuera del sistema? [Completitud, Spec §Supuestos]
- [x] CHK006 ¿Define la spec qué operaciones cuentan como «contenido» bloqueado: solo altas y bajas de servicios y mano de obra, o también una edición del precio de la mano de obra si existiera? [Completitud, Spec §FR-021]

## Claridad de los requisitos

- [x] CHK007 ¿Queda claro que la regla de D-04 se aplica solo cuando recepción intenta confirmar el pago como aprobado, y no cuando lo marca como rechazado o lo cancela? [Ambigüedad, Spec §FR-016]
- [x] CHK008 ¿Está definido el mensaje, o al menos su contenido mínimo, que recibe el usuario cuando FR-021 rechaza una alta o baja de servicio? [Claridad, Spec §FR-021]
- [x] CHK009 ¿Se especifica qué rol puede anular el pago `PAGADO` en el contexto de FR-022 (hoy solo administración) y que la anulación exige un motivo? [Claridad, Spec §FR-022, §Supuestos]
- [x] CHK010 ¿Queda claro que «pago `PAGADO` no anulado» (entidad Orden) y «tenga un pago en estado `PAGADO`» (FR-021) describen la misma condición? [Claridad, Spec §FR-021, Entidad «Orden de servicio»]

## Consistencia de los requisitos

- [x] CHK011 ¿Son consistentes H15-a (un pago `PENDIENTE` no bloquea) y D-04 (el pendiente desfasado se cancela al confirmarlo) en todos los escenarios de US3 y US4? [Consistencia, Spec §FR-016, §FR-021]
- [x] CHK012 ¿Es consistente FR-022 (tras anular, se admiten cambios de servicios) con FR-021 y el supuesto de que las refacciones siguen bloqueadas en toda orden `TERMINADO`? [Consistencia, Spec §FR-021, §FR-022, §Supuestos]
- [x] CHK013 ¿Es consistente FR-011 (corregir una línea quitándola y volviéndola a agregar) con el bloqueo de refacciones en `TERMINADO`, que impide esa corrección aunque se anule el pago? [Consistencia, Spec §FR-011, §Supuestos]
- [x] CHK014 ¿Mantienen FR-014 (un solo pago vigente) y FR-016 (cancelar y generar uno nuevo) la misma definición de «pago vigente»? [Consistencia, Spec §FR-014, §FR-016]

## Calidad de los criterios de aceptación

- [x] CHK015 ¿Se pueden medir SC-009 y SC-010 con casos definidos para cada estado de pago (`PENDIENTE`, `PAGADO`, `RECHAZADO`, `CANCELADO`, `ANULADO`)? [Medibilidad, Spec §SC-009, §SC-010]
- [x] CHK016 ¿Existe un criterio de éxito para la entrega de la orden (`ENTREGADO`) después de anular un pago, que hoy exige un pago `PAGADO`? [Gap, Spec §FR-022, §FR-023]

## Cobertura de escenarios y casos límite

- [x] CHK017 ¿Se cubre la carrera entre confirmar un pago pendiente y agregar o quitar un servicio al mismo tiempo en la misma orden? [Gap, Concurrencia, Spec §FR-016, §FR-021]
- [x] CHK018 ¿Se cubre el caso de un pago pendiente cuyo importe vuelve a coincidir con el total (por ejemplo, se agrega y luego se quita un servicio) antes de confirmarlo? [Cobertura, Spec §FR-016]
- [x] CHK019 ¿Se define qué pasa con el enlace de cobro de Mercado Pago del pago cancelado por desfase (si queda inutilizable o si hay que avisar al cliente)? [Gap, Dependencia externa, Spec §FR-016]
- [x] CHK020 ¿Se cubre que un pago `RECHAZADO` o `CANCELADO` tampoco bloquea el contenido de la orden? [Cobertura, Spec §FR-021]
- [x] CHK021 ¿Se cubre un segundo ciclo completo: anular, cambiar servicios, cobrar de nuevo y emitir otro ticket? [Cobertura, Recuperación, Spec §FR-022]

## Dependencias y riesgos

- [x] CHK022 ¿Está documentado que la confirmación de Mercado Pago sigue siendo manual (aclaración del Sprint 4) y que D-04 depende de esa revisión manual? [Dependencia, Supuesto]
- [x] CHK023 ¿Se reconoce como riesgo que recepción no tiene una forma, dentro del sistema, de saber si el cliente ya pagó el enlace cancelado? [Gap, Riesgo, Spec §FR-016]

## Notas

- Marca los ítems `[x]` solo cuando la revisión confirme que el requisito cumple el criterio.
- Deja sin marcar los ítems que todavía necesitan aclaración, corrección o evaluación de quien revisa.
- `/speckit-implement` lee el estado de las casillas como compuerta y no debe modificar las marcas.
- `checklists/requirements.md` tiene su propio ciclo, que mantienen `/speckit-specify` y `/speckit-clarify`.
- Anota los comentarios o hallazgos junto a cada ítem.
- Los ítems se numeran en orden para poder citarlos.
