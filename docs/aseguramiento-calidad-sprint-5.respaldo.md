# Aseguramiento de la calidad - Sprint 5: Precios de refacciones y cobro completo

Este documento es el registro de calidad del Sprint 5 de Motorix. Reúne las puertas de calidad, las decisiones, los riesgos, la trazabilidad de los criterios de aceptación, los hallazgos, la regresión de los sprints 1 a 4 y el control de calidad final, con sus evidencias.

Resultado general: el sprint está en preparación; no se ha implementado ni cerrado. La línea base del backend ya tiene una repetición exitosa, pero conserva una advertencia de Jest sobre el cierre forzado de un proceso.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | 5 - Precios de refacciones y cobro completo |
| Insumo | `docs/sprints/sprint-5-precios-refacciones-cobro.md` |
| Rama | `main` (rama actual); la rama específica del Sprint 5 todavía no está creada ni confirmada; rama base: `main` |
| Responsable | Carlos Castro Rafael — Product Builder (rol ficticio del proyecto escolar) |
| Aprobador | Jorge Francisco — Aprobador (rol ficticio del proyecto escolar) |
| Fecha de inicio | No registrada |
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
- [ ] No hay hallazgos críticos ni altos abiertos en el análisis de consistencia. G-07 no se ha ejecutado; además, H-01, H-02, H-04, H-06, H-07 y H-09 son altos y están abiertos, y H-B01 también es alto y sigue abierto, aunque su origen es la línea base.
- [ ] Cada criterio de aceptación tuvo al menos una prueba planeada (sección 6). Todavía no hay pruebas del Sprint 5 planificadas.
- [ ] La línea base de regresión está registrada y fijada (sección 8). No se marca porque no se considera fijada mientras H-B01 siga abierto: la captura original del backend muestra 2 fallos por timeout, la repetición del 2026-11-04 no tiene captura nueva y Jest advierte sobre un proceso forzado a salir.
- [ ] La documentación desfasada de los sprints anteriores está identificada. No se marca porque el insumo solo delimita los temas en CA-14 (total, precios y visibilidad por rol); no se ha identificado la documentación concreta ni se ha actualizado.

**Criterios de salida (para cerrar el sprint):**

- [ ] Los 14 criterios de aceptación están Aprobados. El sprint no se ha implementado.
- [ ] Todas las pruebas de los sprints anteriores siguen pasando. No se ha ejecutado la regresión de cierre; la línea base del backend ya tiene una repetición exitosa, pero conserva una advertencia de Jest.
- [ ] No hay defectos críticos ni altos abiertos (sección 7). Los hallazgos altos siguen abiertos.
- [ ] La matriz de calidad final (sección 9) está completa, con evidencia. Todavía no se ha ejecutado.
- [ ] Reporte, análisis y matriz no se contradicen. No aplica todavía porque el sprint no se ha cerrado.

## 3. Puertas de calidad

Las puertas se registran con el estado real al 2026-11-04. Solo G-01 tiene una revisión realizada. G-02 a G-08 no se han evaluado como puertas; G-08 cuenta con resultados de línea base documentados en la sección 8, pero no se ha evaluado porque falta la planeación de pruebas del Sprint 5.

| ID | Puerta | Estado | Evidencia |
|:--:|---|---|---|
| G-01 | Insumo del sprint revisado contra el código | Aprobado con observación | `docs/sprints/sprint-5-precios-refacciones-cobro.md` y anexo de hallazgos H-01 a H-15; contraste con `server/utils/order-total.js`, las migraciones `002` a `004` y las pruebas de pagos. Observaciones: H-13 requiere enmienda constitucional y H-15 se incorporó como decisión de alcance. |
| G-02 | Especificación (`/speckit.specify`) | No evaluada | No se ha ejecutado `/speckit.specify`; no existe todavía la especificación del Sprint 5 en `specs/`. |
| G-03 | Aclaraciones (`/speckit.clarify`) | No evaluada | No se ha ejecutado `/speckit.clarify`; D-01 a D-10 siguen abiertas. |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | No evaluada | No se ha ejecutado `/speckit.checklist`; no existe una lista de calidad del Sprint 5. |
| G-05 | Plan (`/speckit.plan`) | No evaluada | No se ha ejecutado `/speckit.plan`; no existen `plan.md`, `data-model.md` ni `contracts/` del Sprint 5. |
| G-06 | Tareas (`/speckit.tasks`) | No evaluada | No se ha ejecutado `/speckit.tasks`; no existe `tasks.md` ni tareas del Sprint 5. |
| G-07 | Consistencia (`/speckit.analyze`) | No evaluada | No se ha ejecutado `/speckit.analyze`; no hay análisis de consistencia del Sprint 5. |
| G-08 | Pruebas planeadas y línea base | No evaluada | Sección 8: resultados de línea base. Frontend: 127 pruebas aprobadas. Backend: la captura original muestra 49 suites, 47 aprobadas y 2 fallidas, y 409 pruebas aprobadas y 2 fallidas de 411; el archivo `docs/evidencias/salida-npm-test.txt` del mismo commit registra 49 suites y 411 pruebas aprobadas; la repetición del 2026-11-04 terminó con 49 suites y 411 pruebas aprobadas y los dos timeouts no se reprodujeron. Jest mantiene una advertencia de proceso forzado a salir. No existen pruebas del Sprint 5 planificadas y vinculadas a los criterios de aceptación en la sección 6. La repetición exitosa de la regresión no sustituye esa planeación; por eso G-08 sigue No evaluada. |

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

Además, el responsable tomó el 2026-11-04 la decisión de alcance H-15: incluir la inmovilización del contenido de las órdenes `TERMINADO` que ya tienen un pago, para impedir que modificaciones posteriores alteren el ticket histórico. Esta decisión no resuelve D-01 a D-10 y todavía no está implementada; su detalle técnico se precisará en G-02 y G-03.

## 5. Riesgos y mitigaciones

Esta sección se completará en la etapa de planificación (G-05) y de tareas (G-06), cuando el plan permita asociar cada riesgo con una mitigación y una prueba concreta. En esta etapa no se registran riesgos, mitigaciones ni pruebas inventadas. Los riesgos candidatos se derivarán de los hallazgos H-05 a H-11, H-13 y H-15, que ya están registrados en la sección 7.

## 6. Trazabilidad

Esta sección se completará en G-06 y G-07, cuando existan `spec.md`, `tasks.md` y pruebas planificadas. El insumo define los criterios de aceptación CA-1 a CA-14, pero todavía no tienen requisito funcional, tarea, prueba ni resultado asociados. No se asignan identificadores ni resultados antes de esas etapas.

## 7. Hallazgos y defectos

Se registra todo lo que se encuentre, sea en los documentos, en el análisis o en las pruebas. Todos los hallazgos quedan en estado Abierto porque no existe evidencia de una corrección implementada o aprobada. La corrección del texto del insumo no se considera una resolución.

Clasificación: H-01, H-02, H-03, H-04, H-12 y H-14 son hallazgos documentales; H-05, H-06, H-07, H-08, H-09, H-10, H-11 y H-15 son brechas o defectos de implementación; H-13 es un asunto de gobernanza; H-B01 es una discrepancia de línea base.

| ID | Descripción | Severidad (crítica, alta, media, baja) | Origen (puerta o prueba) | Estado | Resolución | Evidencia |
|:--:|---|---|---|---|---|---|
| H-01 | El insumo original afirmaba que las refacciones no sumaban al total; el código ya suma `parts.sale_price` × `order_parts.quantity`. | Alta | G-01, revisión del insumo contra el código | Abierto | Se corrigió el texto del insumo; el código ya tenía el comportamiento. No hay cambio de código ni validación posterior. | `server/utils/order-total.js:41-70`; `server/models/payment.js:131-158`; `server/services/payment.service.js:118-124`; prueba en `server/tests/integration/payments.test.js:148-188` |
| H-02 | El insumo original afirmaba que el Sprint 3 difirió categoría, marca y precios, y la tabla de entidades decía «agregar» campos que ya existen. | Alta | G-01 | Abierto | Se corrigió el texto del insumo; los campos ya existían desde la migración `003`. No hay cambio de código. | `database/migrations/003_historial_mantenimiento_inventario.sql:8-27`; `server/services/part.service.js:34-47`; `server/validators/part.validator.js:31-46`; `database/seeds/003_ejemplos_historial_inventario.sql:13-19` |
| H-03 | `NOTHING_TO_CHARGE` no existe en el código; los rechazos actuales son `ORDEN_NO_COBRABLE` y `MONTO_NO_COINCIDE`, y el monto 0 se rechaza por validación y por `CHECK (amount > 0)`. | Media | G-01 | Abierto | Se corrigió el texto del insumo; no existe `NOTHING_TO_CHARGE` en el código. No hay cambio de código. | `server/services/payment.service.js:86-93` y `118-124`; `server/validators/payment.validator.js:13-16`; `database/migrations/004_pagos_tickets_dashboard.sql:36` |
| H-04 | La base de pruebas es `motorix_v2_test`, no `motorix_test`. | Alta | G-01 | Abierto | Se corrigió el nombre en el insumo; la configuración real usa `motorix_v2_test`. No hay cambio de código. | `server/tests/helpers/env.js:6`; `server/config/env.js:43`; `docs/project-context.md:791-794` |
| H-05 | El cálculo actual usa números decimales y `Math.round` a dos decimales; no usa centavos enteros. | Media | G-01 | Abierto | Sin resolución de implementación; el cálculo sigue en decimales. | `server/utils/order-total.js:17-21` y `26-70`; `database/migrations/002_citas_ordenes_servicio.sql:118`; `database/migrations/004_pagos_tickets_dashboard.sql:15` |
| H-06 | El ticket se reconstruye al consultarlo; no hay columna `content` ni `format_version`, y usa el precio actual del catálogo. Un cambio de precio puede alterar tickets ya emitidos. | Alta | G-01 | Abierto | Sin resolución de implementación; el ticket sigue reconstruyéndose. | `database/migrations/004_pagos_tickets_dashboard.sql:39-62`; `server/services/ticket.service.js:43-50`, `63-72` y `108-111`; `server/models/payment.js:131-158` |
| H-07 | El precio de compra se devuelve a los tres roles; no hay filtro por rol en la API. | Alta | G-01 | Abierto | Sin resolución de implementación; el precio de compra sigue expuesto a los tres roles. | `server/routes/parts.routes.js:33-43`; `server/services/part.service.js:34-47` |
| H-08 | La validación de precios solo exige número mayor o igual a 0; no limita a dos decimales ni define topes máximos. | Media | G-01 | Abierto | Sin resolución de implementación; faltan las validaciones. | `server/validators/part.validator.js:15-18`, `45-46` y `70-71` |
| H-09 | La confirmación de un pago pendiente de Mercado Pago no revalida el importe contra el total actual. | Alta | G-01 | Abierto | Sin resolución de implementación; `confirmPayment` no revalida el importe. | `server/services/payment.service.js:212-230` |
| H-10 | El ticket no incluye la advertencia «sin precio registrado» que sí trae el desglose del pago. | Baja | G-01 | Abierto | Sin resolución de implementación; el ticket no incluye el aviso. | `server/utils/order-total.js:58-60` frente a `server/services/ticket.service.js:63-72` |
| H-11 | No existe la migración `005` ni un seed `005`; la más alta en ambas carpetas es la `004`. | Media | G-01 | Abierto | Sin resolución de implementación; no existe la migración `005`. | `database/migrations/` y `database/seeds/` |
| H-12 | La referencia `docs/sprints/propuesta-sprints-post-mvp.md` no existe y no tiene historial en Git. | Baja | G-01 | Abierto | La referencia se retiró del insumo; se mantiene abierto hasta la revisión de G-02. | Archivo no encontrado; `git log --all -- docs/sprints/propuesta-sprints-post-mvp.md` sin resultados |
| H-13 | El principio I de la constitución limita el MVP a los sprints 1 a 4; el Sprint 5 es posterior al MVP y requiere una enmienda aprobada por la autoridad del proyecto antes de implementar. | Media | G-01, revisión de la constitución | Abierto | No hay enmienda registrada; el principio I sigue limitando el MVP a los sprints 1 a 4. No se afirma que exista una aprobación. | `docs/reglas.md:44-45`; `.specify/memory/constitution.md:37`; versión 1.0.0 en `.specify/memory/constitution.md:251` |
| H-14 | El insumo original incluía «servicios» como componente separado del total; `order_services` solo guarda la descripción y el precio del servicio vive en `order_labor.price`. | Media | G-01 | Abierto | Se corrigió el texto del insumo; no hay cambio de código. | `database/migrations/002_citas_ordenes_servicio.sql:98-127`; `server/utils/order-total.js:7-13` y `30-39` |
| H-15 | El guard de contenido solo bloquea la orden `ENTREGADO`; una orden `TERMINADO` que ya tiene un pago puede cambiar sus servicios o refacciones, lo cual puede alterar el ticket histórico reconstruido. El responsable decidió el 2026-11-04 incluir la inmovilización del contenido de esas órdenes en el alcance del Sprint 5. | Media | G-01, observación de alcance | Abierto | Decisión de alcance ya tomada por el responsable el 2026-11-04: incluir la inmovilización del contenido de órdenes `TERMINADO` y pagadas para impedir que modificaciones posteriores alteren el ticket histórico. No está implementada; el detalle técnico se precisará en G-02 y G-03. | `server/services/service_order.service.js:323-335` y `414-446` |
| H-B01 | La captura de `npm test` del 2026-11-03 mostró 2 fallos por timeout en pruebas de autenticación; el archivo versionado del mismo commit registraba 49 suites y 411 pruebas aprobadas. La repetición del 2026-11-04 terminó con 49 suites y 411 pruebas aprobadas; los dos timeouts no se reprodujeron. Jest todavía advirtió que tuvo que forzar la salida de un proceso. La causa de los timeouts y de la advertencia no está investigada. | Alta | Línea base | Abierto | Repetición del 2026-11-04 ejecutada en `server/` con `npm test`: 49 suites y 411 pruebas aprobadas; los dos timeouts de autenticación de la captura anterior no se reprodujeron. El archivo versionado del mismo commit ya registraba una ejecución limpia. H-B01 permanece Abierto mientras no se investigue y documente la advertencia de Jest sobre el proceso forzado a salir; no se atribuye una causa. | `docs/evidencias/sprint 5/npm test.png`; `docs/evidencias/salida-npm-test.txt`; commit `a01b8b1` de la línea base original. La repetición del 2026-11-04 no tiene captura nueva; se registra el resultado proporcionado. |

## 8. Línea base de regresión

La línea base corresponde al estado del repositorio anterior a la implementación del Sprint 5. El HEAD es `a01b8b1`, en `main`; no existe una rama del Sprint 5. Reúne dos capturas originales, dos salidas de texto versionadas, una ejecución aislada de autenticación declarada y una repetición del 2026-11-04 proporcionada en la conversación. La captura original del backend registra dos timeouts; la salida versionada del backend y la repetición registran 49 suites y 411 pruebas aprobadas. La captura original del frontend y su salida versionada registran 127 pruebas aprobadas y «All tests passed!». La advertencia del worker forzado ya aparece en `salida-npm-test.txt` y también se reportó en la repetición. H-B01 sigue Abierto. La suite se ejecutará de nuevo al cierre; ninguna prueba de los sprints 1 a 4 debe pasar de verde a rojo.

**Tabla 1. Comparación antes/después del sprint**

| Suite | Comando | Antes del sprint 5 | Después del sprint 5 | Diferencia | Evidencia |
|---|---|---|---|---|---|
| Backend (Jest) | `npm test` en `server/` | Línea base documentada con cuatro ejecuciones y resultados no concluyentes; H-B01 abierto. Ver tabla 2 (B-1 a B-4). | No ejecutada; el sprint no se ha implementado. | No calculable todavía; falta la regresión de cierre. | Captura y TXT del backend enlazados en la tabla 2; repetición declarada sin captura. |
| Frontend (Flutter) | `flutter test` en `client/` | 127 pruebas aprobadas y «All tests passed!»; ver tabla 2 (F-1 y F-2). | No ejecutada; el sprint no se ha implementado. | No calculable todavía; falta la regresión de cierre. | Captura y TXT del frontend enlazados en la tabla 2. |

**Tabla 2. Ejecuciones de línea base**

| ID | Suite | Ejecución | Comando | Fecha | Resultado | Evidencia | Limitaciones |
|:--:|---|---|---|---|---|---|---|
| B-1 | Backend (Jest) | Captura original | `npm test` en `server/` (declarado; no visible en la imagen) | Ejecución declarada: 2026-11-03. La imagen no muestra fecha; timestamp del PNG: 2026-11-03 09:53:32. | 49 suites: 47 aprobadas y 2 fallidas; 411 pruebas: 409 aprobadas y 2 fallidas; 0 snapshots; `Time: 10.985 s`; 2 timeouts de 5000 ms en auth. | [npm test.png](evidencias/sprint%205/npm%20test.png); SHA-256 `C72C68D38652256CD40EFC25AAE7564C6667BF9D38428A6A816E47DA55E29415`. La imagen muestra `git log -1 --oneline` con `a01b8b1 (HEAD -> main, origin/main)`. | Sin fecha ni línea del comando `npm test` en la imagen; al final se ve `git log -1 --oneline` con el commit y la rama; PNG no versionado. |
| B-2 | Backend (Jest) | Salida versionada | `npm test` en `server/` (el archivo muestra `node --experimental-vm-modules node_modules/jest/bin/jest.js --forceExit`) | Sin fecha de ejecución registrada. Fecha del commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. | 49/49 suites; 411/411 pruebas; 0 snapshots; `Time: 7.618 s`; warning del worker en línea 76. | [salida-npm-test.txt](evidencias/salida-npm-test.txt); SHA-256 `95D59C706AE0BCA651D78FE48BD0EAF618AD3960F5270BDA444F2C4DD7C36DA9`; versionado en `a01b8b1`. | Sin commit, rama ni fecha dentro del archivo; es una corrida distinta de B-1; la advertencia ya está en esta salida limpia. |
| B-3 | Backend (Jest) | Ejecución aislada de autenticación | `npm test -- tests/integration/auth.test.js tests/contract/auth.test.js` (declarado) | No registrada. | 2 suites y 16 pruebas aprobadas; warning del worker (según el documento). | Sin evidencia independiente enlazada; solo la declaración de esta sección. | Declarada, no verificable; sin captura, log, fecha ni commit; no se usa para fijar la línea base. |
| B-4 | Backend (Jest) | Repetición | `npm test` en `server/` (declarado) | Ejecución declarada: 2026-11-04. | 49/49 suites; 411/411 pruebas; 0 snapshots; `24.712 s`; auth aprobada; warning del worker. | Sin captura ni log en el repositorio; resultado proporcionado por el usuario en la conversación; commit y rama no confirmados. | No verificable independientemente; no hay archivo de salida; H-B01 sigue abierto. |
| F-1 | Frontend (Flutter) | Captura original | `flutter test` en `client/` (visible) | Ejecución declarada: 2026-11-03. La imagen no muestra fecha; timestamp del PNG: 2026-11-03 09:54:33. | 127 pruebas aprobadas; `00:32 +127: All tests passed!` | [flutter test.png](evidencias/sprint%205/flutter%20test.png); SHA-256 `97352F7695F7B830AEC636E2A1F3320F542C0603CEB4546B6FA2E630CA5EE03E`. La imagen muestra `git log -1 --oneline` con `a01b8b1 (HEAD -> main, origin/main)`. | Sin fecha en la imagen; commit y rama visibles al final; PNG no versionado. |
| F-2 | Frontend (Flutter) | Salida versionada | `flutter test` (no visible en el archivo; salida de Flutter test) | Sin fecha de ejecución registrada. Fecha del commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. | 127 pruebas aprobadas; `00:22 +127: All tests passed!` | [salida-flutter-test.txt](evidencias/salida-flutter-test.txt); SHA-256 `5DBC511F6C8F07E91BD10EEBDB1C2555FE8AFB0BEE93B35628DE3D9817EF5450`; versionado en `a01b8b1`. | Sin comando, commit, rama ni fecha dentro; es una corrida distinta de F-1. |

**Fechas y contexto.** No son equivalentes:

- Commit `a01b8b1`: 2026-10-18 21:11:18 -06:00. Es el HEAD actual, en `main` y `origin/main`; no existe una rama del Sprint 5.
- Capturas originales: timestamp de modificación 2026-11-03 09:53:32 (backend) y 2026-11-03 09:54:33 (frontend). Las imágenes no muestran fecha; la fecha de ejecución declarada es 2026-11-03.
- Salidas TXT versionadas: no registran fecha de ejecución; se incorporaron en el commit `a01b8b1` (2026-10-18). No deben fecharse con la fecha del commit como si fuera la de ejecución.
- Ejecución aislada de autenticación: sin fecha registrada.
- Repetición: fecha declarada 2026-11-04; sin captura ni log; commit y rama no confirmados.

**Advertencia de Jest.** La advertencia del worker forzado no es exclusiva de la repetición: ya aparece en `salida-npm-test.txt` línea 76 («A worker process has failed to exit gracefully and has been force exited. This is likely caused by tests leaking due to improper teardown. Try running with --detectOpenHandles to find leaks. Active timers can also cause this, ensure that .unref() was called on them.») y en la línea 83 aparece «Force exiting Jest: Have you considered using `--detectOpenHandles` to detect async operations that kept running after all tests finished?». La captura original del backend también muestra `Force exiting Jest`, pero no la advertencia del worker. El script versionado incluye `--forceExit` en la línea 3; no se atribuye la causa a esa opción. La repetición del 2026-11-04 también reportó la advertencia, pero no conserva captura ni log. H-B01 sigue Abierto y no se cierra.

**Evidencias enlazadas.** Las cuatro evidencias existentes son:

- [npm test.png](evidencias/sprint%205/npm%20test.png)
- [flutter test.png](evidencias/sprint%205/flutter%20test.png)
- [salida-npm-test.txt](evidencias/salida-npm-test.txt)
- [salida-flutter-test.txt](evidencias/salida-flutter-test.txt)

Las huellas SHA-256 de las dos capturas son distintas, por lo que no son la misma imagen. Las huellas completas están en la tabla 2.

![Línea base del backend](evidencias/sprint%205/npm%20test.png)

![Línea base del frontend](evidencias/sprint%205/flutter%20test.png)

**Capturas del cierre:** no generadas; el sprint no se ha implementado y no hay cierre.

**Duración:** el usuario no midió con cronómetro. Tiempos reportados por Jest: captura original del backend 10.985 s; salida versionada del backend 7.618 s; repetición 24.712 s. Tiempos del runner de Flutter: 00:32 en la captura y 00:22 en la salida TXT. No son mediciones con cronómetro.

**Estado de la línea base:** documentada con observaciones, no fijada ni aprobada. H-B01 sigue Abierto; G-08 sigue No evaluada; la casilla de línea base de la sección 2 sigue sin marcar.

**Fecha del cierre:** no registrada; el sprint no se ha cerrado.

## 9. Control de calidad final

Esta sección se completará al cierre, después de la implementación y de la regresión. Los cinco requisitos se elegirán entre los criterios de mayor riesgo (instantáneas de precio, órdenes pagadas, pagos pendientes desfasados, permisos por rol y compatibilidad con tickets anteriores), pero todavía no se asignan requisitos funcionales, pruebas ni resultados porque no existe la especificación del Sprint 5 ni una implementación que probar.

## 10. Cierre

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | 0 de 5: el sprint no se ha implementado |
| Defectos abiertos | Implementación: H-05, H-06, H-07, H-08, H-09, H-10, H-11 y H-15. Línea base: H-B01. Hallazgos documentales y de gobernanza: H-01, H-02, H-03, H-04, H-12, H-13 y H-14. Todos abiertos; ver sección 7 |
| Observaciones | Documento en preparación; G-02 a G-08 no evaluadas; D-01 a D-10 abiertas; H-13 sin enmienda registrada; repetición backend del 2026-11-04 con 49 suites y 411 pruebas aprobadas y sin reproducir los timeouts; H-B01 sigue abierto por la advertencia de Jest sobre el proceso forzado a salir; rama del Sprint 5 no creada; fechas de inicio y cierre no registradas |
| Aprobado por | Sin aprobación de cierre registrada. Aprobador definido: Jorge Francisco — Aprobador (rol ficticio del proyecto escolar) |
| Fecha | No registrada |

# Anexo de evidencias

Cada evidencia tendrá tres bloques cuando existan la especificación, la prueba y el resultado: **Requisito**, **Prueba** y **Resultado**. En esta etapa no existen `spec.md`, pruebas ni resultados del Sprint 5; por eso no se citan requisitos funcionales, fragmentos de código ni capturas de cierre. Las capturas de línea base están en la sección 8 y conservan sus rutas reales.

| Evidencia | Requisito | Prueba | Resultado |
|:--:|---|---|---|
| E-01 | Se completará en G-02 | Se planificará en G-06 | No ejecutado |
| E-02 | Se completará en G-02 | Se planificará en G-06 | No ejecutado |
| E-03 | Se completará en G-02 | Se planificará en G-06 | No ejecutado |
| E-04 | Se completará en G-02 | Se planificará en G-06 | No ejecutado |
| E-05 | Se completará en G-02 | Se planificará en G-06 | No ejecutado |

## E-06 Recorrido de los escenarios contra la API real

No ejecutado. No existe todavía un `quickstart.md` del Sprint 5 ni una implementación que recorrer. Se completará al cierre si el plan genera ese documento.
