# Lista de calidad de requisitos: seguridad, permisos y datos

**Propósito**: validar que los requisitos de seguridad, permisos y datos del Sprint 7 (Entregas A y B) estén completos, claros y sean verificables antes de planear.
**Fecha de creación**: 2026-11-26
**Funcionalidad**: [spec.md](../spec.md)

> **Propiedad de las marcas**: `[x]` significa que el criterio de calidad del requisito se cumple, no que el código esté hecho. Carlos pidió expresamente que el agente evaluara y marcara los ítems (prompt del sprint, paso 5); los que no aplican se marcan con su justificación para que `/speckit-implement` no se detenga.

## Completitud de los requisitos

- [x] CHK001 - ¿Está definido qué rol puede leer y cuál escribir cada recurso nuevo (configuración, tipos de servicio, términos, aceptaciones, bitácora, reportes)? [Completitud, Spec §FR-006, §FR-009, §FR-021, §FR-024, §FR-038]
- [x] CHK002 - ¿Está listada de forma cerrada cada acción que entra a la bitácora? [Completitud, Spec §FR-022]
- [x] CHK003 - ¿Se especifica qué datos NUNCA se guardan en la bitácora? [Completitud, Spec §FR-023, §SC-005]
- [x] CHK004 - ¿Están definidas las excepciones a la aceptación obligatoria (qué operaciones se permiten sin aceptar)? [Completitud, Spec §FR-020]
- [x] CHK005 - ¿Se define qué pasa con los usuarios existentes y los creados después de publicar una versión? [Completitud, Spec §FR-016, Casos límite]
- [x] CHK006 - ¿Se enumeran los elementos mínimos del aviso de privacidad? [Completitud, Spec §Clarifications, §FR-015]
- [x] CHK007 - ¿Están acotados los valores válidos (longitudes y rangos) de configuración y tipos de servicio? [Completitud, Spec §FR-001, §FR-004, §FR-007]
- [x] CHK008 - ¿Se define el comportamiento de respaldo cuando no hay configuración guardada? [Completitud, Spec §FR-003, §FR-005]
- [x] CHK009 - ¿Se especifica qué endpoints deben probarse contra la exposición de hash, token y precios? [Completitud, Spec §FR-028]

## Claridad de los requisitos

- [x] CHK010 - ¿Se define con precisión la "inactividad" (duración y a qué roles aplica)? [Claridad, Spec §FR-027]
- [x] CHK011 - ¿La política de contraseñas está cuantificada (longitud y clases de caracteres)? [Claridad, Spec §FR-026]
- [x] CHK012 - ¿Se distingue "pago anulado" de "pago cancelado" sin ambigüedad? [Claridad, Spec §Clarifications, H-S7-03]
- [x] CHK013 - ¿Está claro el código de rechazo que recibe un usuario con aceptación pendiente? [Claridad, Spec §FR-020]
- [x] CHK014 - ¿Se define qué fecha determina el periodo de cada reporte y su huso horario? [Claridad, Spec §FR-031, §Clarifications]
- [x] CHK015 - ¿Están definidas las fórmulas de margen y rotación, incluidos los casos sin costo y sin existencia? [Claridad, Spec §FR-035, §FR-036]

## Consistencia de los requisitos

- [x] CHK016 - ¿Son consistentes la regla "el mecánico no ve importes" del Sprint 5 y los requisitos nuevos (tickets, reportes, tipos de servicio)? [Consistencia, Spec §FR-038] — los tipos de servicio no llevan importes; reportes y configuración son solo de ADMIN.
- [x] CHK017 - ¿Es consistente el margen global de "Próximo" con la antelación guardada en cada mantenimiento? [Consistencia, Spec §FR-005, H-S7-01]
- [x] CHK018 - ¿Es consistente la publicación de términos por script con CA-17 del insumo ("el administrador publica")? [Consistencia, Spec §FR-016, H-S7-04]
- [x] CHK019 - ¿Son consistentes los requisitos de copia del ticket (datos del taller y próximo servicio) con la regla del Sprint 5 de que el ticket emitido no cambia? [Consistencia, Spec §FR-002, §FR-013]

## Calidad de los criterios de aceptación

- [x] CHK020 - ¿Se puede verificar objetivamente que ninguna operación pase sin aceptación? [Medibilidad, Spec §SC-004]
- [x] CHK021 - ¿Se puede medir que los reportes cuadren al centavo con su origen y con el archivo exportado? [Medibilidad, Spec §SC-007]
- [x] CHK022 - ¿Tiene el rendimiento de los reportes un umbral numérico? [Medibilidad, Spec §SC-008]

## Cobertura de escenarios y casos límite

- [x] CHK023 - ¿Se cubre el caso de login fallido con usuario inexistente en la bitácora? [Casos límite]
- [x] CHK024 - ¿Se define qué pasa si falla la escritura de la bitácora durante una operación? [Excepción, Spec §FR-025]
- [x] CHK025 - ¿Se cubre la edición simultánea de la configuración? [Casos límite, §Clarifications]
- [x] CHK026 - ¿Se cubren los rangos inválidos de los reportes (más de un año, inicio posterior al fin)? [Excepción, Spec §US4 escenario 3]
- [x] CHK027 - ¿Se cubre el cierre de la app en la pantalla de términos sin decidir? [Casos límite]

## Requisitos no funcionales

- [x] CHK028 - ¿Se exigen consultas parametrizadas y validación de entradas con una prueba de inyección? [Seguridad, Spec §FR-029]
- [x] CHK029 - ¿Se exigen cabeceras de seguridad HTTP? [Seguridad, Spec §FR-030]
- [x] CHK030 - No aplica: cifrado en disco, HTTPS, respaldos y 2FA. Justificación: fuera de alcance por el insumo, sección 8 (se descartó el antiguo Sprint 8). [Supuesto]
- [x] CHK031 - No aplica: retención o depuración de la bitácora. Justificación: Carlos decidió "sin borrado automático" (Clarifications); no hay requisito de retención que medir. [Supuesto]
- [x] CHK032 - No aplica: validez legal del texto de los términos. Justificación: es una plantilla académica para un responsable ficticio, con nota visible (insumo §8, Clarifications). [Supuesto]

## Dependencias y supuestos

- [x] CHK033 - ¿Se documenta la nueva dependencia de cabeceras de seguridad y su justificación frente a la constitución? [Dependencia, insumo H-S7-05] — la justificación concreta queda en `plan.md`.
- [x] CHK034 - ¿Se documenta cómo las pruebas existentes cumplirán la aceptación obligatoria? [Supuesto, Spec §FR-020, §SC-009]

## Notas

- Evaluación del agente (2026-11-26, a pedido de Carlos): 34/34 ítems marcados; 3 de ellos (CHK030 a CHK032) son "no aplica" con justificación.
- `/speckit-implement` lee estas marcas pero no las modifica.
