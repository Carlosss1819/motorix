# Checklist de integridad monetaria y migración: Precios de refacciones y cobro completo

**Propósito**: evaluar la calidad de los requisitos sobre centavos, topes, precio congelado, copias de ticket y migración (D-03, D-08 y D-09). Evalúa lo escrito en la spec, no la implementación.
**Fecha de creación**: 2026-11-14
**Funcionalidad**: [spec.md](../spec.md)

**Nota**: checklist personalizado generado por `/speckit-checklist` a partir de la spec y sus aclaraciones de la sesión 2026-11-14.
**Responsable de la revisión**: es un artefacto de revisión de la calidad de los requisitos y pertenece a quien revisa. Marca un ítem `[x]` solo cuando quien revisa determine que el requisito cumple el criterio.
**Significado de las marcas**: `[x]` significa que el criterio se revisó y se cumple para la calidad de los requisitos. No significa que la implementación esté terminada.

## Completitud de los requisitos

- [x] CHK001 ¿Se especifican topes y validación de decimales para el precio de la mano de obra, igual que para el precio de refacción (999,999.99 y dos decimales)? [Gap, Spec §FR-003, §FR-008]
- [x] CHK002 ¿Define la spec qué datos, además del desglose y los importes, forman la copia del ticket (cliente, vehículo, número de orden, método de pago, fecha), para que un cambio posterior en esos datos tampoco altere el ticket? [Gap, Spec §FR-019, Entidad «Ticket»]
- [x] CHK003 ¿Se especifica cómo obtienen su copia y su versión de formato los tickets que crean los datos de ejemplo, si se cargan después de la migración que genera las copias de los tickets anteriores? [Gap, Spec §FR-020, §FR-029]
- [x] CHK004 ¿Se definen requisitos de recuperación si la migración falla a la mitad (líneas con precio congelado parcial o tickets sin copia)? [Gap, Recuperación, Spec §FR-010, §FR-020]
- [x] CHK005 ¿Se especifica qué número de versión de formato llevan los tickets nuevos y cómo se relaciona con la marca «formato anterior»? [Completitud, Spec §FR-019, §FR-020]
- [x] CHK006 ¿Se define cómo se le muestra al usuario la marca «formato anterior» en el ticket (texto visible, etiqueta o solo un dato interno)? [Gap, Spec §FR-020]

## Claridad de los requisitos

- [x] CHK007 ¿Está definido qué estados de orden cuentan como «órdenes abiertas» en FR-010? [Ambigüedad, Spec §FR-010]
- [x] CHK008 ¿Queda claro qué operaciones se rechazan cuando el total pasaría de 99,999,999.99 (agregar refacción, agregar servicio u otra)? [Claridad, Spec §FR-008]
- [x] CHK009 ¿Se especifica que «coincide» en FR-013 y FR-016 significa igualdad exacta al centavo? [Claridad, Spec §FR-013, §FR-016]
- [x] CHK010 ¿Queda explícito que, al quitar una línea y volverla a agregar (D-05), la nueva línea toma el precio de venta vigente en ese momento y no el anterior? [Claridad, Spec §FR-006, §FR-011]
- [x] CHK011 ¿Está definido si un precio de 0.00 en el catálogo cuenta como «precio de venta registrado» para FR-005? [Ambigüedad, Spec §FR-005]
- [x] CHK012 ¿Se cuantifica «importes coherentes» en FR-027 (por ejemplo, el mismo total al centavo que FR-008)? [Ambigüedad, Spec §FR-027]

## Consistencia de los requisitos

- [x] CHK013 ¿Es consistente FR-010 (solo «órdenes abiertas») con el supuesto de que las líneas de órdenes `TERMINADO` y `ENTREGADO` también toman el precio vigente al migrar? [Conflicto, Spec §FR-010, §Supuestos]
- [x] CHK014 ¿Es consistente FR-018 («cada línea sin precio») con las partidas de mano de obra sin precio, que hoy también llevan el aviso en el desglose del pago? [Consistencia, Spec §FR-018]
- [x] CHK015 ¿Son consistentes FR-005 (no se agrega una refacción sin precio) y el supuesto de que, al migrar, una línea cuya refacción no tiene precio queda en 0 con advertencia? [Consistencia, Spec §FR-005, §Supuestos]
- [x] CHK016 ¿Es consistente la regla de redondeo hacia arriba desde 0.5 de FR-008 con el supuesto de que hoy la cantidad es entera, sin dejar un requisito que no se pueda probar? [Consistencia, Spec §FR-008, §Supuestos]

## Calidad de los criterios de aceptación

- [x] CHK017 ¿Se puede medir SC-002 con una lista definida de tickets y pagos de referencia (cuáles y cuántos) antes y después del cambio de precio? [Medibilidad, Spec §SC-002]
- [x] CHK018 ¿Define SC-003 los casos de redondeo que deben estar incluidos (importes con centavos, 10 líneas o más y valores cercanos a los topes)? [Medibilidad, Spec §SC-003]
- [x] CHK019 ¿Existe un criterio de éxito medible para la migración de D-03 (por ejemplo, el 100 % de las líneas existentes conserva el total que mostraba antes de migrar)? [Gap, Spec §FR-010]
- [x] CHK020 ¿Existe un criterio de éxito medible para la copia de los tickets anteriores (por ejemplo, el 100 % tiene copia y su importe coincide con el pago)? [Gap, Spec §FR-020]

## Cobertura de casos límite

- [x] CHK021 ¿Se especifica qué pasa si, al migrar, el importe reconstruido de un ticket anterior no coincide con el importe de su pago? [Gap, Excepción, Spec §FR-020]
- [x] CHK022 ¿Se cubre el caso de una línea cuya refacción del catálogo fue desactivada antes de la migración? [Cobertura, Spec §FR-007, §FR-010]
- [x] CHK023 ¿Se definen los valores límite exactos aceptados y rechazados (999,999.99 frente a 1,000,000.00, y 99,999,999.99 en el total)? [Cobertura, Spec §FR-003, §FR-008]

## Dependencias y supuestos

- [x] CHK024 ¿Está validado el supuesto de que la copia de los tickets anteriores, generada con el catálogo del día de la migración, es «la mejor información histórica disponible», y se acepta que puede diferir de lo que se entregó al cliente? [Supuesto, Spec §Supuestos]
- [x] CHK025 ¿Está documentado que el formato de importe actual (dos decimales, máximo 99,999,999.99) es una restricción heredada que el plan debe conservar? [Supuesto, Spec §Supuestos]

## Notas

- Marca los ítems `[x]` solo cuando la revisión confirme que el requisito cumple el criterio.
- Deja sin marcar los ítems que todavía necesitan aclaración, corrección o evaluación de quien revisa.
- `/speckit-implement` lee el estado de las casillas como compuerta y no debe modificar las marcas.
- `checklists/requirements.md` tiene su propio ciclo, que mantienen `/speckit-specify` y `/speckit-clarify`.
- Anota los comentarios o hallazgos junto a cada ítem.
- Los ítems se numeran en orden para poder citarlos.
