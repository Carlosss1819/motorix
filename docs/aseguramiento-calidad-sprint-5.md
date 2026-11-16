# Aseguramiento de la calidad - Sprint 5: Precios de refacciones y cobro completo

Este documento es el registro de calidad del Sprint 5 de Motorix. Reúne las puertas de calidad, las decisiones, los riesgos, la trazabilidad de los criterios de aceptación, los hallazgos, la regresión de los sprints 1 a 4 y el control de calidad final, con sus evidencias.

Resultado general: el sprint está en preparación; no se ha implementado ni cerrado. La línea base del backend incluye una repetición completa del 2026-11-04, ejecutada y declarada por el responsable (49 de 49 suites y 411 de 411 pruebas aprobadas; sin captura ni log), y conserva una advertencia de Jest sobre el cierre forzado de un proceso.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | 5 - Precios de refacciones y cobro completo |
| Insumo | `docs/sprints/sprint-5-precios-refacciones-cobro.md` |
| Rama | `main` (rama actual); la rama específica del Sprint 5 todavía no está creada ni definida; rama base: `main` |
| Responsable | Carlos Castro Rafael — Product Builder (rol asignado en el proyecto escolar) |
| Aprobador | Jorge Francisco — Aprobador (rol asignado en el proyecto escolar) |
| Inicio de las actividades documentadas de aseguramiento | 2026-11-03, según la fecha declarada de la línea base B-1 y F-1 y las capturas conservadas; las imágenes no muestran fecha de ejecución. |
| Fecha formal de inicio del Sprint 5 | No confirmada; no se deduce de la fecha de inicio del aseguramiento. |
| Fecha de cierre | No registrada; el sprint no se ha implementado |
| Estado general | En preparación (provisional; se definirá al cierre) |

## 1. Objetivo y alcance

**Objetivo.** Asegurar que el Sprint 5 salga con calidad: que los requisitos estén completos, sean medibles y no se contradigan, que las pruebas estén planeadas antes del código y que el cambio no rompa lo construido en los sprints 1 a 4.

**Dentro del alcance:**

- Revisar la categoría, la marca y la obligatoriedad de los campos de la refacción según D-01 y D-06.
- Congelar el precio de venta en la línea de la orden al agregar una refacción, para que un cambio posterior del catálogo no altere órdenes abiertas.
- Incluir las refacciones con su precio congelado en el total, el pago y el ticket.
- Conservar el importe y el contenido de los pagos y tickets ya emitidos.
- Restringir el precio de compra según el rol autorizado.
- Validar los precios con dos decimales y límites máximos.
- Revalidar el importe de los pagos pendientes de Mercado Pago cuando cambie el total.
- Migrar el cálculo monetario a centavos enteros.
- Mostrar en el ticket la advertencia «sin precio registrado» cuando una refacción no tenga precio.
- Crear la migración `005` y actualizar los seeds necesarios.
- Inmovilizar el contenido de las órdenes `TERMINADO` que ya tienen un pago, para impedir que modificaciones posteriores alteren el ticket histórico. Esta es la decisión de alcance H-15, tomada por el responsable el 2026-11-04; no está implementada ni probada, y su detalle técnico se precisará en las etapas de especificación y aclaración (G-02 y G-03).

**Fuera del alcance:**

- Costeo, margen de ganancia, utilidad y reportes financieros.
- Impuestos y facturación electrónica.
- Descuentos, promociones y pagos parciales o a plazos.
- Reembolsos dentro del sistema.
- Catálogo de proveedores y órdenes de compra.
- Notificaciones, reportes, configuración del taller y WhatsApp.
- Fotos del vehículo y puesta en producción.

## 2. Criterios de entrada y de salida

La implementación no puede comenzar hasta que se cumplan todos los criterios de entrada. Al 2026-11-04 el documento está en preparación: G-02 a G-08 no se han evaluado como puertas, las decisiones D-01 a D-10 siguen abiertas y H-13 no tiene una enmienda registrada. Ningún criterio de salida se ha cumplido porque el sprint no se ha implementado.

**Criterios de entrada (para comenzar la implementación):**

- [ ] Las 8 puertas de la sección 3 están Aprobadas o Aprobadas con observación. G-01 está aprobada con observación; G-02 a G-08 no se han evaluado como puertas.
- [ ] Si el sprint exige un cambio a la constitución del proyecto, la enmienda está aprobada y registrada (hallazgo H-13). H-13 sigue abierto; no hay enmienda registrada.
- [ ] Las decisiones de la sección 4 están resueltas y registradas. D-01 a D-10 siguen abiertas; H-15 ya fue decidida como asunto de alcance.
- [ ] No hay hallazgos críticos ni altos abiertos en el análisis de consistencia. G-07 no se ha ejecutado; además, H-01, H-02, H-06, H-07 y H-09 son altos y están abiertos, y H-B01 también es alto y sigue abierto, aunque su origen es la línea base.
- [ ] Cada criterio de aceptación tuvo al menos una prueba planeada (sección 6). Hay una propuesta documental para los 14 criterios; falta validarla contra la especificación, las decisiones y las tareas. No constituye aprobación de G-08.
- [ ] La línea base de regresión está registrada y fijada (sección 8). Este criterio es más estricto que el de la plantilla, que solo pide «registrada». No se marca porque la línea base no se considera fijada mientras H-B01 siga abierto; el detalle está en la sección 8.
- [ ] La documentación desfasada de los sprints anteriores está identificada. Se identificó la discrepancia de estado en `README.md` (H-16), sin modificar ese archivo. Sigue sin acreditarse una revisión completa de los temas de CA-14: total, precios y visibilidad por rol.

**Criterios de salida (para cerrar el sprint):**

- [ ] Los 14 criterios de aceptación están Aprobados. El sprint no se ha implementado.
- [ ] Todas las pruebas de los sprints anteriores siguen pasando. No se ha ejecutado la regresión de cierre. La línea base del backend incluye una repetición completa declarada por el responsable (B-4), sin captura ni log, y conserva una advertencia de Jest.
- [ ] No hay defectos críticos ni altos abiertos (sección 7). Los hallazgos altos siguen abiertos.
- [ ] La matriz de calidad final (sección 9) está completa, con evidencia. Todavía no se ha ejecutado.
- [ ] Reporte, análisis y matriz no se contradicen. No aplica todavía porque el sprint no se ha cerrado.

## 3. Puertas de calidad

Las puertas se registran con el estado real al 2026-11-04. Solo G-01 tiene una revisión realizada. G-02 a G-08 no se han evaluado como puertas. G-08 cuenta con una propuesta de pruebas en la sección 6 y resultados históricos en la sección 8; faltan la validación de la propuesta contra especificación y tareas y la fijación de la línea base.

| ID | Puerta | Estado | Evidencia |
|:--:|---|---|---|
| G-01 | Insumo del sprint revisado contra el código | Aprobado con observación | `docs/sprints/sprint-5-precios-refacciones-cobro.md` y sección 7 (hallazgos H-01 a H-15); contraste con `server/utils/order-total.js`, las migraciones `002` a `004` y las pruebas de pagos. Observaciones: H-13 requiere enmienda constitucional y H-15 se incorporó como decisión de alcance. |
| G-02 | Especificación (`/speckit.specify`) | No evaluada | No se ha ejecutado `/speckit.specify`; no existe todavía la especificación del Sprint 5 en `specs/`. |
| G-03 | Aclaraciones (`/speckit.clarify`) | No evaluada | No se ha ejecutado `/speckit.clarify`; D-01 a D-10 siguen abiertas. |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | No evaluada | No se ha ejecutado `/speckit.checklist`; no existe una lista de calidad del Sprint 5. |
| G-05 | Plan (`/speckit.plan`) | No evaluada | No se ha ejecutado `/speckit.plan`; no existen `plan.md`, `data-model.md` ni `contracts/` del Sprint 5. |
| G-06 | Tareas (`/speckit.tasks`) | No evaluada | No se ha ejecutado `/speckit.tasks`; no existe `tasks.md` ni tareas del Sprint 5. |
| G-07 | Consistencia (`/speckit.analyze`) | No evaluada | No se ha ejecutado `/speckit.analyze`; no hay análisis de consistencia del Sprint 5. |
| G-08 | Pruebas planeadas y línea base | No evaluada | Sección 8: línea base documentada con observaciones y sin fijar (H-B01); la repetición B-4 es una declaración del responsable. Sección 6: verificaciones propuestas PP-01 a PP-15, sin validar contra especificación ni tareas. Ni la propuesta ni B-4 aprueban G-08. |

## 4. Decisiones de aclaración

Las decisiones D-01 a D-10 del insumo siguen abiertas. No hay todavía una etapa de aclaraciones ni un `spec.md` del Sprint 5 donde estén resueltas.

| ID | Decisión | Estado |
|:--:|---|---|
| D-01 | Refacciones y líneas existentes sin precio: asignar 0, exigir captura o bloquear su uso. | Abierta |
| D-02 | Orden con solo refacciones: hoy se puede cobrar si el total es positivo; definir si se mantiene. | Abierta |
| D-03 | Precio que tomarán las líneas ya agregadas al aplicar la migración `005`. | Abierta |
| D-04 | Pago de Mercado Pago pendiente cuando cambia el total: cancelar, actualizar o marcar desfasado. | Abierta |
| D-05 | Corrección del precio de una línea de una orden abierta: permiso y motivo. | Abierta |
| D-06 | Categoría como lista cerrada o texto libre; marca como texto libre. | Abierta |
| D-07 | Precio de venta menor al de compra: permitir, advertir o rechazar. | Abierta |
| D-08 | Redondeo del importe por línea y límites máximos de precio y total. | Abierta |
| D-09 | Cómo mostrar tickets anteriores sin precio congelado: versión, copia histórica o marca. | Abierta |
| D-10 | Visibilidad del precio de venta para el mecánico. | Abierta |

Además, el responsable tomó el 2026-11-04 la decisión de alcance H-15: incluir la inmovilización del contenido de las órdenes `TERMINADO` que ya tienen un pago, para impedir que modificaciones posteriores alteren el ticket histórico. Esta decisión no resuelve D-01 a D-10 y todavía no está implementada; su detalle técnico se precisará en G-02 y G-03. Los estados de pago que activan la inmovilización y su relación con D-04 se definirán en G-03.

## 5. Riesgos y mitigaciones

Los siguientes riesgos se derivan del insumo y de los hallazgos de la sección 7. Las mitigaciones y verificaciones son propuestas, sin implementación ni eficacia demostrada. Los identificadores R-01 a R-09 organizan este registro; PP-01 a PP-15 identifican exclusivamente verificaciones futuras propuestas en la sección 6. Todos los riesgos permanecen Abiertos.

| ID | Riesgo y origen | Impacto | Mitigación propuesta | Verificación propuesta | Estado |
|:--:|---|---|---|---|---|
| R-01 | Alteración de importes por cálculo decimal (H-05, H-08). | Alto: cobro incorrecto. | Calcular en centavos; definir redondeo y límites mediante D-08. | PP-02 y PP-04: precisión y valores límite. | Abierto |
| R-02 | Cambios del catálogo o de órdenes pagadas alteran líneas y tickets (H-06, H-15). | Alto: pérdida de integridad histórica. | Congelar precios; definir conservación histórica mediante D-03 y D-09 e inmovilización según H-15. | PP-03, PP-06 y PP-15. | Abierto |
| R-03 | Exposición del precio de compra a roles no autorizados (H-07). | Alto: acceso a información restringida. | Filtrar datos en backend y revisar todas las respuestas que los incluyan. | PP-10: consultas con administrador, recepción y mecánico. | Abierto |
| R-04 | Confirmación de Mercado Pago con importe desfasado (H-09). | Alto: diferencia entre pago y total vigente. | Revalidar importe y aplicar la política que se resuelva en D-04. | PP-09: cambio de total con pago pendiente. | Abierto |
| R-05 | Refacciones sin precio o datos antiguos tratados incorrectamente (H-10, D-01, D-03). | Medio: desglose ambiguo o migración incorrecta. | Resolver tratamiento de datos existentes y mostrar la advertencia exigida en CA-7. | PP-06, PP-07 y PP-12. | Abierto |
| R-06 | Migración o seeds incompletos (H-11). | Alto: pérdida de compatibilidad o demostración sin datos. | Crear migración aditiva y seeds idempotentes; verificar preservación de datos. | PP-12 y PP-06. | Abierto |
| R-07 | Implementar fuera de la constitución vigente (H-13). | Alto: incumplimiento de gobernanza. | Obtener y registrar enmienda aprobada antes de implementar. | Revisión documental de enmienda, versión y aprobación; no sustituible por una prueba automática. | Abierto |
| R-08 | Línea base no reproducible o insuficientemente sustentada (H-B01). | Alto: regresiones difíciles de distinguir. | Investigar timeouts y advertencia de Jest; conservar evidencia de ejecución y contexto. | Investigación técnica y regresión sujetas a ejecución posterior autorizada. | Abierto |
| R-09 | Regresiones o documentación contradictoria (CA-8, CA-11, CA-13, CA-14). | Alto: fallos en flujos anteriores y trazabilidad incompleta. | Planificar cobertura de concurrencia, listados, panel y revisión documental; comparar suites al cierre. | PP-08, PP-11, PP-13 y PP-14. | Abierto |

## 6. Trazabilidad

La matriz siguiente es **planificación documental propuesta**, derivada de los 14 criterios de la sección 7 del [insumo](sprints/sprint-5-precios-refacciones-cobro.md). PP-01 a PP-15 son identificadores propuestos para verificaciones futuras: no son pruebas existentes ni tareas de Spec Kit. No hay archivos de prueba nuevos, ejecuciones ni resultados del Sprint 5.

Para todas las filas, el requisito funcional y la tarea están **sin asignar porque no existen `spec.md` ni `tasks.md` del Sprint 5**. La fuente trazable actual es el CA del insumo. El resultado de todas las verificaciones es **No ejecutado** y no hay evidencia de cumplimiento. Las condiciones sujetas a D-01 a D-10 requieren resolución antes de fijar expectativas definitivas.

| CA | Criterio resumido | Verificación futura propuesta | Resultado esperado para su futura evaluación | Dependencias y referencias |
|:--:|---|---|---|---|
| CA-1 | Registro, edición y persistencia de categoría, marca y precios. | PP-01: registrar, editar y consultar desde API e interfaz; comprobar persistencia. | Los datos consultados coinciden con los guardados conforme a campos obligatorios definidos. | D-01, D-06, D-07; H-02. |
| CA-2 | Validación de precios. | PP-02: enviar negativos, cero, texto, decimales con coma, más de dos decimales y valores en torno al máximo. | Rechazo de entradas inválidas; aceptación de valores válidos dentro del límite acordado. | D-07, D-08; H-08. |
| CA-3 | Precio vigente congelado por línea. | PP-03: agregar refacción, cambiar precio del catálogo y volver a consultar la línea; repetir con un cambio de precio simultáneo al alta y con la misma refacción agregada dos veces. | La línea anterior conserva su precio; una nueva toma el vigente según la especificación futura. | D-03, D-05; H-06. |
| CA-4 | Total en centavos enteros. | PP-04: calcular cantidades por precio congelado más mano de obra; cubrir precisión y límites. | Total exacto según D-08, sin componente monetario independiente en `order_services`. | D-02, D-08; H-05, H-14. |
| CA-5 | Pago por el total con refacciones. | PP-05: intentar pago por el total correcto y por un importe distinto. | Registro por el total vigente y rechazo del importe que no coincida. | CA-4; H-01, H-03. |
| CA-6 | Conservación de pagos y tickets anteriores. | PP-06: comparar importe y contenido antes y después de migración y cambios del catálogo. | Pagos y tickets históricos conservados y consultables conforme a D-09. | D-03, D-09; H-06, H-11. |
| CA-7 | Desglose y advertencia en ticket nuevo. | PP-07: consultar ticket con refacciones y caso sin precio según política definida. | Cantidad, precio unitario, importe, subtotal y total coherentes; advertencia «sin precio registrado» cuando corresponda. | D-01, D-08; H-10. |
| CA-8 | Un pago vigente y ausencia de datos de tarjeta. | PP-08: solicitar pagos simultáneos y revisar persistencia y respuestas del flujo. | Un solo pago vigente por orden; ningún dato de tarjeta almacenado. | Reglas heredadas del Sprint 4. |
| CA-9 | Mercado Pago e importe desfasado. | PP-09: iniciar pago con refacciones, modificar total y consultar o confirmar el pendiente. | Importe inicial correcto y detección y resolución de desfase según D-04. | D-04; H-09. |
| CA-10 | Precio de compra solo para administrador. | PP-10: consultar con los tres roles todas las rutas que devuelven refacciones o precios (según el mapa de rutas del backend), buscando la clave y el valor del precio de compra, con un control positivo para el administrador. | Administrador recibe el precio de compra; recepción y mecánico no lo reciben en la API. | H-07; D-10 afecta adicionalmente la venta al mecánico. |
| CA-11 | Compatibilidad de panel y listados. | PP-11: recorrer panel, órdenes y pagos con totales que incluyan refacciones. | Consultas y presentación funcionan sin errores ni discrepancias monetarias. | CA-4 y CA-5. |
| CA-12 | Seeds con precios congelados e idempotencia. | PP-12: revisar migración aditiva, aplicar seeds en base de pruebas y repetirlos. | Datos demostrables y líneas compatibles, sin duplicados ni alteración histórica. | D-01, D-03; H-11. |
| CA-13 | Cobertura automatizada y resultados. | PP-13: revisar cobertura de total, instantáneas, centavos, roles, concurrencia y compatibilidad; ejecutar suites cuando se autorice. | Pruebas reales para los temas exigidos y resultados conservados; comparación con línea base fijada. | PP-03, PP-04, PP-06, PP-08, PP-10; H-B01. |
| CA-14 | Actualización documental. | PP-14: identificar documentos sobre total, precios y roles y contrastarlos con el cambio implementado. | Documentación concreta identificada y actualizada sin contradicciones. | H-01, H-02, H-03, H-04, H-12, H-14, H-16. El insumo corregido registra que no hay comentarios de código que digan que las refacciones no suman. |

**Cobertura adicional de H-15:** PP-15 propone intentar modificar servicios, refacciones y mano de obra de una orden `TERMINADO` con pago y comprobar que no cambian el contenido ni el ticket histórico. El detalle de estados de pago, operaciones bloqueadas (servicios, refacciones y mano de obra) y respuestas requiere G-02 y G-03, y debe definir su relación con D-04: si un pago pendiente ya inmoviliza la orden, el desfase de importe de CA-9 cambia. No se añade un CA-15 al insumo ni se presenta esta propuesta como prueba ejecutada.

## 7. Hallazgos y defectos

Se registra todo lo que se encuentre, sea en los documentos, en el análisis o en las pruebas. Todos los hallazgos quedan en estado Abierto. Los de implementación (H-05 a H-11 y H-15) siguen abiertos porque no hay cambio de código. Los documentales H-01, H-02, H-03, H-04, H-12 y H-14 se corrigieron en el texto del insumo; por decisión expresa del responsable conservan el estado Abierto. H-13, H-16 y H-B01 siguen abiertos porque no tienen corrección ni aprobación.

Clasificación: H-01, H-02, H-03, H-04, H-12, H-14 y H-16 son hallazgos documentales; H-05, H-06, H-07, H-08, H-09, H-10, H-11 y H-15 son brechas o defectos de implementación; H-13 es un asunto de gobernanza; H-B01 es una discrepancia de línea base.

Conteo: 17 hallazgos abiertos; 0 de severidad Crítica, 6 de severidad Alta, 8 de severidad Media y 3 de severidad Baja. H-04 pasa de Alta a Media porque la discrepancia está en la denominación documental, mientras la configuración citada ya usa la base correcta. Esta reclasificación documental no implica corrección de código, ejecución de pruebas ni resolución del hallazgo.

| ID | Descripción | Severidad (crítica, alta, media, baja) | Origen (puerta o prueba) | Estado | Resolución | Evidencia |
|:--:|---|---|---|---|---|---|
| H-01 | El insumo original afirmaba que las refacciones no sumaban al total; el código ya suma `parts.sale_price` × `order_parts.quantity`. | Alta | G-01, revisión del insumo contra el código | Abierto | Se corrigió el texto del insumo; el código ya tenía el comportamiento. No hay cambio de código ni validación posterior. | `server/utils/order-total.js:41-70`; `server/models/payment.js:131-158`; `server/services/payment.service.js:118-124`; prueba en `server/tests/integration/payments.test.js:148-188` |
| H-02 | El insumo original afirmaba que el Sprint 3 difirió categoría, marca y precios, y la tabla de entidades decía «agregar» campos que ya existen. | Alta | G-01 | Abierto | Se corrigió el texto del insumo; los campos ya existían desde la migración `003`. No hay cambio de código. | `database/migrations/003_historial_mantenimiento_inventario.sql:8-27`; `server/services/part.service.js:34-47`; `server/validators/part.validator.js:31-46`; `database/seeds/003_ejemplos_historial_inventario.sql:13-19` |
| H-03 | `NOTHING_TO_CHARGE` no existe en el código; los rechazos actuales son `ORDEN_NO_COBRABLE` y `MONTO_NO_COINCIDE`, y el monto 0 se rechaza por validación y por `CHECK (amount > 0)`. | Media | G-01 | Abierto | Se corrigió el texto del insumo; no existe `NOTHING_TO_CHARGE` en el código. No hay cambio de código. | `server/services/payment.service.js:86-93` y `118-124`; `server/validators/payment.validator.js:13-16`; `database/migrations/004_pagos_tickets_dashboard.sql:36` |
| H-04 | La base de pruebas es `motorix_v2_test`, no `motorix_test`. | Media | G-01 | Abierto | Se corrigió el nombre en el insumo; la configuración real usa `motorix_v2_test`. Reclasificación documental de Alta a Media: la discrepancia afecta la documentación, no acredita una configuración incorrecta. Sin corrección de código; permanece Abierto por decisión expresa del responsable. | `server/tests/helpers/env.js:6`; `server/config/env.js:43`; `docs/project-context.md:791-794` |
| H-05 | El cálculo actual usa números decimales y `Math.round` a dos decimales; no usa centavos enteros. | Media | G-01 | Abierto | Sin resolución de implementación; el cálculo sigue en decimales. | `server/utils/order-total.js:17-21` y `26-70`; `database/migrations/002_citas_ordenes_servicio.sql:118`; `database/migrations/004_pagos_tickets_dashboard.sql:15` |
| H-06 | El ticket se reconstruye al consultarlo; no hay columna `content` ni `format_version`, y usa el precio actual del catálogo. Un cambio de precio puede alterar tickets ya emitidos. Además, `order_parts` solo guarda `part_id`, `description` y `quantity`; no guarda precio, por lo que el total de una orden abierta cambia cuando cambia `parts.sale_price`. | Alta | G-01 | Abierto | Sin resolución de implementación; el ticket sigue reconstruyéndose y `order_parts` sigue sin guardar precio. | `database/migrations/002_citas_ordenes_servicio.sql:132-142`; `database/migrations/003_historial_mantenimiento_inventario.sql:99-108`; `server/models/order_items.js:68-77`; `database/migrations/004_pagos_tickets_dashboard.sql:39-62`; `server/services/ticket.service.js:43-50`, `63-72` y `108-111`; `server/models/payment.js:131-158` |
| H-07 | El precio de compra se devuelve a los tres roles; no hay filtro por rol en la API. | Alta | G-01 | Abierto | Sin resolución de implementación; el precio de compra sigue expuesto a los tres roles. | `server/routes/parts.routes.js:33-43`; `server/services/part.service.js:34-47` |
| H-08 | La validación de precios solo exige número mayor o igual a 0; no limita a dos decimales ni define topes máximos. | Media | G-01 | Abierto | Sin resolución de implementación; faltan las validaciones. | `server/validators/part.validator.js:15-18`, `45-46` y `70-71` |
| H-09 | La confirmación de un pago pendiente de Mercado Pago no revalida el importe contra el total actual. | Alta | G-01 | Abierto | Sin resolución de implementación; `confirmPayment` no revalida el importe. | `server/services/payment.service.js:212-230` |
| H-10 | El ticket no incluye la advertencia «sin precio registrado» que sí trae el desglose del pago. | Baja | G-01 | Abierto | Sin resolución de implementación; el ticket no incluye el aviso. | `server/utils/order-total.js:58-60` frente a `server/services/ticket.service.js:63-72` |
| H-11 | No existe la migración `005` ni un seed `005`; la más alta en ambas carpetas es la `004`. | Media | G-01 | Abierto | Sin resolución de implementación; no existe la migración `005`. | `database/migrations/` y `database/seeds/` |
| H-12 | La referencia `docs/sprints/propuesta-sprints-post-mvp.md` no existe y no tiene historial en Git. | Baja | G-01 | Abierto | La referencia se retiró del insumo; se mantiene abierto hasta la revisión de G-02. | Archivo no encontrado; `git log --all -- docs/sprints/propuesta-sprints-post-mvp.md` sin resultados |
| H-13 | El principio I de la constitución limita el MVP a los sprints 1 a 4 y exige aprobación del equipo para ampliar el alcance; el Sprint 5 es posterior al MVP y requiere una enmienda antes de implementar. Según la Gobernanza, las enmiendas las aprueba el equipo, coordinado por el director del proyecto, y se documentan con nueva versión, fecha de última enmienda y reporte de impacto. La constitución figura con «Ratificación: pendiente del equipo». | Media | G-01, revisión de la constitución | Abierto | No hay enmienda registrada; el principio I sigue limitando el MVP a los sprints 1 a 4. No se afirma que exista una aprobación. | `docs/reglas.md:44-45`; `.specify/memory/constitution.md:37`; versión 1.0.0 en `.specify/memory/constitution.md:251` |
| H-14 | El insumo original incluía «servicios» como componente separado del total; `order_services` solo guarda la descripción y el precio del servicio vive en `order_labor.price`. | Media | G-01 | Abierto | Se corrigió el texto del insumo; no hay cambio de código. | `database/migrations/002_citas_ordenes_servicio.sql:98-127`; `server/utils/order-total.js:7-13` y `30-39` |
| H-15 | El guard de contenido solo bloquea la orden `ENTREGADO`; una orden `TERMINADO` que ya tiene un pago puede cambiar sus servicios o refacciones, lo cual puede alterar el ticket histórico reconstruido. El responsable decidió el 2026-11-04 incluir la inmovilización del contenido de esas órdenes en el alcance del Sprint 5. | Media | G-01, observación de alcance | Abierto | Decisión de alcance ya tomada por el responsable el 2026-11-04: incluir la inmovilización del contenido de órdenes `TERMINADO` y pagadas para impedir que modificaciones posteriores alteren el ticket histórico. No está implementada; el detalle técnico se precisará en G-02 y G-03: estados de pago que activan la inmovilización, operaciones bloqueadas (servicios, refacciones y mano de obra) y relación con D-04. El principio I pide aprobación del equipo para ampliar el alcance; no hay una aprobación registrada. | `server/services/service_order.service.js:323-335` y `414-446` |
| H-16 | `README.md` mantiene «Estado actual: Sprint 1 en implementación», mientras el reporte del Sprint 4 registra ese sprint completo, con T001 a T061 cerradas y seis historias entregadas. | Baja | Revisión documental final | Abierto | Sin corrección; README.md se conserva intacto. Severidad Baja por desactualización informativa del estado del proyecto, sin evidencia de defecto funcional. La discrepancia documental no acredita por sí misma la calidad de la implementación. | `README.md:6-7`; `specs/004-pagos-tickets-dashboard/reporte-implementacion.md:1-5`; existen además `server/routes/payments.routes.js` y `server/routes/tickets.routes.js`. |
| H-B01 | La captura original mostró 2 fallos en pruebas de autenticación (uno con tiempo agotado de 5000 ms visible; el mensaje del otro no es visible en la captura); la salida versionada registra 49 suites y 411 pruebas aprobadas. El responsable confirma que la repetición del 2026-11-04 obtuvo 49/49 suites y 411/411 pruebas aprobadas, con advertencia de Jest; no conserva captura ni log. La causa de los fallos y de la advertencia no está investigada. | Alta | Línea base | Abierto | La repetición es un resultado declarado por el responsable, no verificado independientemente. La salida versionada ya registraba todos los casos aprobados y una advertencia de Jest. H-B01 permanece Abierto; no se atribuye una causa ni se considera fijada la línea base. | `docs/evidencias/sprint 5/npm test.png`; `docs/evidencias/salida-npm-test.txt`; commit `a01b8b1` de la línea base original. B-4 identifica la repetición sin captura ni log conservados. |

## 8. Línea base de regresión

La línea base corresponde al estado del repositorio anterior a la implementación del Sprint 5. El registro sitúa el HEAD en `a01b8b1`, rama `main`, sin rama del Sprint 5. Reúne dos capturas originales, dos salidas de texto versionadas y dos ejecuciones confirmadas por el responsable sin captura ni log conservados: la ejecución aislada B-3 y la repetición B-4 del 2026-11-04. La captura original del backend registra dos fallos en pruebas de autenticación; la salida versionada muestra 49 suites y 411 pruebas aprobadas, cifras también declaradas para B-4, sin verificación independiente de esta última. La captura original del frontend y su salida versionada registran 127 pruebas aprobadas y «All tests passed!». La advertencia del worker forzado aparece en `salida-npm-test.txt` y fue declarada para la repetición. H-B01 sigue Abierto. La regresión de cierre todavía no se ha ejecutado.

**Tabla 1. Comparación antes/después del sprint**

| Suite | Comando | Antes del sprint 5 | Después del sprint 5 | Diferencia | Evidencia |
|---|---|---|---|---|---|
| Backend (Jest) | `npm test` en `server/` | Línea base documentada con cuatro ejecuciones y resultados no concluyentes; H-B01 abierto. Ver tabla 2 (B-1 a B-4). | No ejecutada; el sprint no se ha implementado. | No calculable todavía; falta la regresión de cierre. | Captura y TXT del backend enlazados en la tabla 2; repetición declarada sin captura. |
| Frontend (Flutter) | `flutter test` en `client/` | 127 pruebas aprobadas y «All tests passed!»; ver tabla 2 (F-1 y F-2). | No ejecutada; el sprint no se ha implementado. | No calculable todavía; falta la regresión de cierre. | Captura y TXT del frontend enlazados en la tabla 2. |

**Tabla 2. Ejecuciones de línea base**

| ID | Suite | Ejecución | Comando | Fecha | Resultado | Evidencia | Limitaciones |
|:--:|---|---|---|---|---|---|---|
| B-1 | Backend (Jest) | Captura original | `npm test` en `server/` (declarado; no visible en la imagen) | Ejecución declarada: 2026-11-03. La imagen no muestra fecha; timestamp del PNG: 2026-11-03 09:53:32. | 49 suites: 47 aprobadas y 2 fallidas; 411 pruebas: 409 aprobadas y 2 fallidas; 0 snapshots; `Time: 16.985 s`; 2 pruebas fallidas en auth: una con tiempo agotado de 5000 ms visible (`tests/integration/auth.test.js`) y una de `tests/contract/auth.test.js` cuyo mensaje de error no es visible en la captura. | [npm test.png](evidencias/sprint%205/npm%20test.png); SHA-256 `C72C68D38652256CD40EFC25AAE7564C6667BF9D38428A6A816E47DA55E29415` (recalculado con `certutil` el 2026-11-04; coincide). La imagen muestra `git log -1 --oneline` con `a01b8b1 (HEAD -> main, origin/main)`. | Sin fecha ni línea del comando `npm test` en la imagen; al final se ve `git log -1 --oneline` con el commit y la rama; PNG no versionado. |
| B-2 | Backend (Jest) | Salida versionada | `npm test` en `server/` (el archivo muestra `node --experimental-vm-modules node_modules/jest/bin/jest.js --forceExit`) | Sin fecha de ejecución registrada. Fecha del commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. | 49/49 suites; 411/411 pruebas; 0 snapshots; `Time: 7.618 s`; warning del worker en línea 76. | [salida-npm-test.txt](evidencias/salida-npm-test.txt); SHA-256 `95D59C706AE0BCA651D78FE48BD0EAF618AD3960F5270BDA444F2C4DD7C36DA9`; versionado en `a01b8b1`. | Sin commit, rama ni fecha dentro del archivo; es una corrida distinta de B-1; la advertencia ya está en esta salida limpia. |
| B-3 | Backend (Jest) | Ejecución aislada de autenticación | `npm test -- tests/integration/auth.test.js tests/contract/auth.test.js` (declarado) | Anterior al 2026-11-04 07:47 (hora de México), según el registro de trabajo del responsable; fecha exacta no anotada. | El responsable declara 2 suites y 16 pruebas aprobadas, `Time: 3.853 s` y la advertencia del worker. | Resultado declarado por el responsable; no conserva captura ni log. | Ejecución no verificada independientemente; commit no registrado. No se utiliza para fijar la línea base. |
| B-4 | Backend (Jest) | Repetición | `npm test` en `server/` (declarado) | Ejecución confirmada por el responsable: 2026-11-04. | El responsable declara 49/49 suites y 411/411 pruebas aprobadas, 0 snapshots, `Time: 24.712 s` y la advertencia de Jest; sin salida conservada que permita comprobarlos. | Resultado declarado por el responsable; no conserva captura ni log; commit y rama no confirmados. | Ejecución no verificada independientemente; H-B01 sigue Abierto. |
| F-1 | Frontend (Flutter) | Captura original | `flutter test` en `client/` (visible) | Ejecución declarada: 2026-11-03. La imagen no muestra fecha; timestamp del PNG: 2026-11-03 09:54:33. | 127 pruebas aprobadas; `00:32 +127: All tests passed!` | [flutter test.png](evidencias/sprint%205/flutter%20test.png); SHA-256 `97352F7695F7B830AEC636E2A1F3320F542C0603CEB4546B6FA2E630CA5EE03E` (recalculado con `certutil` el 2026-11-04; coincide). La imagen muestra `git log -1 --oneline` con `a01b8b1 (HEAD -> main, origin/main)`. | Sin fecha en la imagen; commit y rama visibles al final; PNG no versionado. |
| F-2 | Frontend (Flutter) | Salida versionada | `flutter test` (no visible en el archivo; salida de Flutter test) | Sin fecha de ejecución registrada. Fecha del commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. | 127 pruebas aprobadas; `00:22 +127: All tests passed!` | [salida-flutter-test.txt](evidencias/salida-flutter-test.txt); SHA-256 `5DBC511F6C8F07E91BD10EEBDB1C2555FE8AFB0BEE93B35628DE3D9817EF5450`; versionado en `a01b8b1`. | Sin comando, commit, rama ni fecha dentro; es una corrida distinta de F-1. |

**Fechas y contexto.** No son equivalentes:

- Commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. Es el HEAD actual, en `main` y `origin/main`; no existe una rama del Sprint 5.
- Capturas originales: timestamp de modificación 2026-11-03 09:53:32 (backend) y 2026-11-03 09:54:33 (frontend). Las imágenes no muestran fecha; la fecha de ejecución declarada es 2026-11-03.
- Salidas TXT versionadas: no registran fecha de ejecución; se incorporaron en el commit `a01b8b1` (2026-10-18). No deben fecharse con la fecha del commit como si fuera la de ejecución.
- Ejecución aislada de autenticación: anterior al 2026-11-04 07:47 (hora de México); fecha exacta no anotada.
- Repetición: fecha declarada 2026-11-04; sin captura ni log; commit y rama no confirmados.

**Advertencia de Jest.** La advertencia del worker forzado no es exclusiva de la repetición: ya aparece en `salida-npm-test.txt` línea 76 («A worker process has failed to exit gracefully and has been force exited. This is likely caused by tests leaking due to improper teardown. Try running with --detectOpenHandles to find leaks. Active timers can also cause this, ensure that .unref() was called on them.») y en la línea 83 aparece «Force exiting Jest: Have you considered using `--detectOpenHandles` to detect async operations that kept running after all tests finished?». La captura original del backend también muestra `Force exiting Jest`, pero no la advertencia del worker. El script versionado incluye `--forceExit` en la línea 3; no se atribuye la causa a esa opción. La repetición del 2026-11-04 también reportó la advertencia, pero no conserva captura ni log. H-B01 sigue Abierto y no se cierra.

**Evidencias enlazadas.** Las cuatro evidencias existentes son:

- [npm test.png](evidencias/sprint%205/npm%20test.png)
- [flutter test.png](evidencias/sprint%205/flutter%20test.png)
- [salida-npm-test.txt](evidencias/salida-npm-test.txt)
- [salida-flutter-test.txt](evidencias/salida-flutter-test.txt)

Las huellas SHA-256 de las dos capturas son distintas, por lo que no son la misma imagen. Las huellas completas están en la tabla 2.

Se comprobó que los cuatro destinos de evidencia existen y que sus enlaces relativos, incluidos los espacios codificados como `%20`, resuelven a los archivos locales correspondientes. Se abrió visualmente la captura del backend y se confirmó `Time: 16.985 s`. Las huellas SHA-256 de las dos capturas se recalcularon con `certutil` el 2026-11-04 y coinciden con las de la tabla 2. En `salida-npm-test.txt` se verificaron la advertencia del worker (línea 76) y `Time: 7.618 s` (línea 81); en `salida-flutter-test.txt`, `00:22 +127: All tests passed!` (línea 150).

![Línea base del backend](evidencias/sprint%205/npm%20test.png)

![Línea base del frontend](evidencias/sprint%205/flutter%20test.png)

**Capturas del cierre:** no generadas; el sprint no se ha implementado y no hay cierre.

**Duración:** el responsable no registró mediciones con cronómetro. Tiempos visibles de Jest: captura original del backend 16.985 s; salida versionada del backend 7.618 s. Para la repetición, el responsable declara 24.712 s, sin captura ni log y sin verificación independiente. Tiempos del runner de Flutter: 00:32 en la captura y 00:22 en la salida TXT. No son mediciones de interacción con la aplicación.

**Estado de la línea base:** documentada con observaciones, no fijada ni aprobada. H-B01 sigue Abierto; G-08 sigue No evaluada; la casilla de línea base de la sección 2 sigue sin marcar.

**Fecha del cierre:** no registrada; el sprint no se ha cerrado.

## 9. Control de calidad final

**No evaluable en esta etapa.** No existe especificación ni implementación del Sprint 5, y no se han ejecutado sus pruebas ni la regresión de cierre. La siguiente selección organiza cinco temas para la evaluación futura; no asigna identificadores FR ni acredita requisitos aprobados. Las referencias E-01 a E-05 corresponden al anexo y no son evidencias de ejecución.

| Tema propuesto | Fuente | Criterio observable propuesto | Prueba ejecutada | Estado de evaluación | Referencia |
|---|---|---|---|---|---|
| Instantánea de precio | CA-3 | Cambiar el catálogo no altera una línea existente. | Ninguna del Sprint 5. | No evaluable; falta implementación. | PP-03; E-01. |
| Orden pagada | H-15 | El contenido y el ticket histórico permanecen sin cambios ante intentos de modificación. | Ninguna del Sprint 5. | No evaluable; falta precisar e implementar el bloqueo. | PP-15; E-02. |
| Pago pendiente desfasado | CA-9 | Se detecta y resuelve el desfase según la política acordada. | Ninguna del Sprint 5. | No evaluable; D-04 abierta. | PP-09; E-03. |
| Permisos por rol | CA-10 | Solo el administrador recibe precio de compra. | Ninguna del Sprint 5. | No evaluable; H-07 abierto. | PP-10; E-04. |
| Compatibilidad histórica | CA-6 | Los pagos y tickets anteriores conservan importe y contenido. | Ninguna del Sprint 5. | No evaluable; D-09 abierta. | PP-06; E-05. |

## 10. Cierre

**Sin cierre técnico ni aprobación final.** Esta revisión organiza la preparación documental; no acredita la ejecución del sprint. Los roles del responsable y del aprobador son los registrados en la sección 0.

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | 0 de 5: el sprint no se ha implementado |
| Defectos abiertos | 17 hallazgos: implementación, H-05, H-06, H-07, H-08, H-09, H-10, H-11 y H-15; línea base, H-B01; documentales y gobernanza, H-01, H-02, H-03, H-04, H-12, H-13, H-14 y H-16. Todos Abiertos: 0 críticos, 6 altos, 8 medios y 3 bajos; ver sección 7. De los 6 altos, H-01 y H-02 son documentales y ya se corrigieron en el texto del insumo (permanecen Abiertos por decisión del responsable); H-06, H-07 y H-09 son brechas de implementación; H-B01 es de línea base. |
| Observaciones | Documento en preparación; G-02 a G-08 no evaluadas; D-01 a D-10 abiertas; H-13 sin enmienda registrada. Repetición B-4 (2026-11-04) declarada por el responsable, sin captura, sin log y sin verificación independiente (sección 8). H-B01 permanece Abierto. Inicio de actividades documentadas de aseguramiento: 2026-11-03; inicio formal del Sprint 5 no confirmado y fecha de cierre no registrada. |
| Aprobado por | Sin aprobación de cierre registrada. Aprobador definido: Jorge Francisco — Aprobador (rol asignado en el proyecto escolar) |
| Fecha | No registrada |

### Revisión de los 16 pasos de la guía

Estados al 2026-11-04. Las actividades anteriores se describen según las evidencias conservadas. Hasta esta fecha no se ha ejecutado ningún comando de Spec Kit del Sprint 5 ni se ha implementado código del sprint.

| Paso | Actividad | Estado real y limitación |
|:--:|---|---|
| 1 | Preparar y contrastar el insumo. | Realizado: revisión del insumo contra el código, registrada en G-01 con observaciones; hallazgos H-01 a H-15 en la sección 7. |
| 2 | Crear el documento. | Realizado; el documento está en `docs/aseguramiento-calidad-sprint-5.md`. |
| 3 | Medir línea base. | Ejecuciones históricas documentadas en sección 8; sin nueva ejecución. Línea base no fijada por H-B01. |
| 4 | Evaluar puertas. | G-01 aprobada con observación; G-02 a G-08 no evaluadas. |
| 5 | Resolver aclaraciones. | No realizado; D-01 a D-10 abiertas. H-15 es decisión de alcance, sin detalle técnico resuelto. |
| 6 | Revisar checklist. | No ejecutado; no existe checklist del Sprint 5. |
| 7 | Plan, tareas y análisis. | No ejecutados; faltan los artefactos del Sprint 5. |
| 8 | Enmienda constitucional. | Necesidad documentada; H-13 abierto, sin aprobación ni enmienda registrada. |
| 9 | Riesgos y trazabilidad. | Propuesta documental en secciones 5 y 6; faltan enlace a FR y tareas, validación y resultados. |
| 10 | Implementar por historias. | No ejecutado; Sprint 5 sin implementar. |
| 11 | Regresión de cierre. | No ejecutada; no hay comparación posterior al sprint. |
| 12 | Control de calidad final. | Selección propuesta en sección 9; sin pruebas ejecutadas ni evidencias de cumplimiento. |
| 13 | Recorrido por API real. | No ejecutado para Sprint 5; no hay quickstart ni resultados propios. Véase E-06. |
| 14 | Recorrido manual. | No hay evidencia de recorrido funcional del Sprint 5 ni tiempos medidos por la persona. Véase E-07. |
| 15 | Cierre y aprobación. | No realizado; 0 de 5 criterios de salida acreditados, sin aprobación ni fecha. No se hizo commit. |
| 16 | Conversión a Word y publicación. | No realizadas; el alcance actual comprende únicamente el documento Markdown. |

# Anexo de evidencias

Este anexo registra las limitaciones reales de evidencia. No hay citas de `spec.md`, código nuevo de pruebas ni capturas de cierre del Sprint 5. Las únicas capturas propias de ejecución disponibles son las de línea base de la sección 8; se abrieron y se contrastaron con las salidas de texto. El ejemplo de la guía se utilizó solo como referencia de estructura, sin trasladar sus datos, cuentas, archivos de pruebas, resultados ni aprobaciones.

| Evidencia | Requisito | Prueba | Resultado |
|:--:|---|---|---|
| E-01 | CA-3 del insumo; sin FR formal. | PP-03 propuesta; sin archivo implementado. | No ejecutado; sin log ni captura funcional. |
| E-02 | H-15, decisión del 2026-11-04; sin FR formal. | PP-15 propuesta; sin archivo implementado. | No ejecutado; bloqueo sin implementar ni probar. |
| E-03 | CA-9; D-04 abierta. | PP-09 propuesta; expectativa final depende de D-04. | No ejecutado; sin respuesta de API ni evidencia del proveedor para Sprint 5. |
| E-04 | CA-10; H-07 abierto. | PP-10 propuesta; sin archivo implementado. | No ejecutado; permisos nuevos sin acreditar. |
| E-05 | CA-6; D-09 abierta. | PP-06 propuesta; mecanismo histórico sin definir. | No ejecutado; sin comparación posterior a la migración. |

## E-06 Recorrido de los escenarios contra la API real

No ejecutado. No existe `quickstart.md` del Sprint 5 ni una implementación que recorrer. No se arrancó la API, no se hicieron peticiones ni se modificaron bases de datos. No hay escenarios aprobados, fecha de recorrido, cuentas utilizadas ni resultados de API acreditados para este sprint. Las verificaciones propuestas están en la sección 6; no sustituyen el recorrido real.

## E-07 Recorrido manual y mediciones de uso

No existe evidencia de un recorrido manual del Sprint 5. Las capturas de terminal de la sección 8 demuestran resultados históricos de suites, no comportamiento de pantallas. No se registran tiempos de uso medidos con cronómetro ni se convierten los tiempos del runner en mediciones de interacción. El recorrido y sus datos deberán definirse después de las aclaraciones y la implementación; las capturas funcionales tendrán que mostrar los comportamientos acordados antes de acreditar resultados.
