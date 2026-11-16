# Lista de verificación de calidad de la especificación: Precios de refacciones y cobro completo

**Propósito**: validar que la especificación esté completa y tenga calidad antes de pasar a la planeación
**Fecha de creación**: 2026-11-14
**Funcionalidad**: [spec.md](../spec.md)

## Calidad del contenido

- [x] Sin detalles de implementación (lenguajes, frameworks, APIs)
- [x] Enfocada en el valor para el usuario y las necesidades del negocio
- [x] Escrita para personas no técnicas
- [x] Todas las secciones obligatorias están completas

## Completitud de los requisitos

- [x] No quedan marcadores [NEEDS CLARIFICATION]
- [x] Los requisitos se pueden probar y no son ambiguos
- [x] Los criterios de éxito son medibles
- [x] Los criterios de éxito no dependen de la tecnología (sin detalles de implementación)
- [x] Todos los escenarios de aceptación están definidos
- [x] Los casos límite están identificados
- [x] El alcance está claramente delimitado
- [x] Las dependencias y los supuestos están identificados

## Preparación de la funcionalidad

- [x] Todos los requisitos funcionales tienen criterios de aceptación claros
- [x] Los escenarios de usuario cubren los flujos principales
- [x] La funcionalidad cumple los resultados medibles definidos en los criterios de éxito
- [x] No se filtran detalles de implementación en la especificación

## Notas

- **Aclaración del 2026-11-14**: D-01 a D-10, H15-a y H15-b quedaron decididas por el responsable y registradas en la sección «Clarifications» del spec. Se agregó una aclaración sobre el alcance de D-10 (solo precios de refacciones; la mano de obra no cambia), porque el mecánico es quien captura hoy el precio de la mano de obra. Ya no quedan marcadores [NEEDS CLARIFICATION] ni decisiones pendientes.
- **Detalles técnicos que se conservaron a propósito**: el cálculo en centavos enteros y el tope del total (99,999,999.99, lo que cabe en el formato de importe actual) los fijó el responsable en D-08. Los estados de orden y de pago (`TERMINADO`, `PAGADO`, etc.) y la ruta `docs/project-context.md` son vocabulario del negocio y de la constitución. La línea base de SC-007 (49 suites y 411 pruebas) se toma de `CLAUDE.md`.
- **Supuestos derivados de las decisiones** (ver «Supuestos» del spec): la migración de líneas cuya refacción no tiene precio de venta, la migración de líneas de órdenes `TERMINADO` y `ENTREGADO`, y que la regla de redondeo desde 0.5 hoy no aplica porque la cantidad es entera.
