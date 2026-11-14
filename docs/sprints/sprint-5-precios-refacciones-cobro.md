<!--
Insumo de especificación para /speckit.specify.
Sprint 5 post-MVP de Motorix: precios de refacciones y cobro completo.
Versión corregida el 2026-11-04 contra el código real.
Las decisiones D-01 a D-10 siguen abiertas para /speckit.clarify.
Los hallazgos H-01 a H-15 y H-B01 se registran al final para trasladarlos al documento de aseguramiento.
-->

# Insumo de especificación - Sprint 5: Precios de refacciones y cobro completo

> Referencias obligatorias para el agente:
> - Contexto maestro: `docs/project-context.md`
> - Constitución: `docs/reglas.md` y `.specify/memory/constitution.md`
> - Este documento describe únicamente el alcance del Sprint 5.
> - La referencia anterior a `docs/sprints/propuesta-sprints-post-mvp.md` se retiró porque ese archivo no existe en el repositorio. El alcance post-MVP se define en este insumo a partir de las brechas verificadas contra el código.
>
> Nota de gobernanza: el principio I de `docs/reglas.md` limitaba el MVP a los sprints 1 a 4. La enmienda 1.1.0 de la constitución (2026-11-13) fija el alcance oficial posterior al MVP en los sprints 5 a 7, por lo que el Sprint 5 ya está autorizado para implementarse.

## 1. Contexto del sprint

Es el primer sprint posterior al MVP. La categoría, la marca y los precios de compra y venta de las refacciones ya existen desde el Sprint 3 (migración `003`), y el Sprint 4 ya integra las refacciones en el total, el pago y el ticket con el precio de venta vigente del catálogo. La deuda pendiente no es agregar esos campos, sino:

- congelar el precio de venta en la línea de la orden para que un cambio posterior del catálogo no altere órdenes abiertas;
- evitar que los tickets ya emitidos cambien cuando se consultan después de un cambio de precio;
- restringir el precio de compra según el rol;
- validar los precios con dos decimales y límites máximos;
- revalidar el importe de los pagos pendientes de Mercado Pago cuando cambie el total;
- migrar el cálculo monetario a centavos enteros;
- mostrar en el ticket la advertencia de precio no registrado;
- crear la migración `005` y actualizar los seeds necesarios;
- inmovilizar el contenido de las órdenes `TERMINADO` que ya tienen un pago, para que modificaciones posteriores de servicios, refacciones o mano de obra no alteren el ticket histórico (decisión del responsable del 2026-11-04; los estados de pago que la activan y las operaciones bloqueadas se resuelven en `/speckit.specify` y `/speckit.clarify`).

El total actual se calcula como mano de obra (`order_labor.price`) más refacciones (`parts.sale_price` vigente × `order_parts.quantity`). `order_services` solo guarda la descripción del servicio; el precio del servicio vive en `order_labor.price`, no en una columna aparte de `order_services`. Los importes se manejan hoy con números decimales y redondeo a dos decimales, no con centavos enteros.

## 2. Objetivo

Que el precio de venta de una refacción quede congelado al agregarla a una orden, que el total, el pago y el ticket incluyan las refacciones con ese precio, que los pagos y tickets ya emitidos conserven su importe y contenido, y que el precio de compra quede restringido a los roles autorizados.

## 3. Historias de usuario del sprint

- **US1** - Como administrador, quiero registrar y mantener la categoría, la marca y los precios de compra y de venta de una refacción, con validaciones, para conocer el costo y el precio de cada pieza.
- **US2** - Como recepcionista, quiero que el total de la orden incluya las refacciones con el precio de venta congelado al agregarlas, para cobrar el trabajo completo sin que un cambio posterior del catálogo altere el importe.
- **US3** - Como recepcionista, quiero que el pago y el ticket reflejen el total con refacciones congeladas, para entregar un comprobante correcto al cliente.
- **US4** - Como administrador, quiero que un cambio de precio no altere órdenes abiertas ni pagos y tickets ya emitidos, para conservar la integridad del historial.
- **US5** - Como mecánico, quiero seguir usando las refacciones en una orden sin ver el precio de compra, para no exponer información financiera del taller.

## 4. Flujo demostrable al cierre del sprint

    Administrador registra una refacción con categoría, marca, precio de compra y precio de venta (campos ya existentes; se validan)
    -> mecánico agrega la refacción a una orden y la línea guarda el precio de venta vigente
    -> la orden pasa a Terminada
    -> recepción consulta el total (mano de obra + refacciones con precio congelado)
    -> registra el pago por ese total
    -> se genera el ticket con las refacciones, su precio unitario, su importe, el subtotal y el total
    -> el administrador cambia el precio de venta del catálogo
    -> la línea de la orden conserva el precio congelado; el pago y el ticket ya emitidos conservan su importe y contenido
    -> si una refacción no tiene precio, el ticket muestra la advertencia «sin precio registrado»

## 5. Entidades y tablas que toca este sprint

> Basado en las secciones 6.7, 6.8, 6.10 y 14.1 de `project-context.md`. La migración `005` es la primera posterior al MVP.

| Entidad / tabla | Acción en este sprint |
|-----------------|-----------------------|
| `parts` | Los campos `category`, `brand`, `purchase_price` y `sale_price` ya existen desde la migración `003`. En este sprint se revisan la obligatoriedad de los campos según D-01/D-06, la validación de dos decimales y límites, y la visibilidad de `purchase_price` por rol. |
| `order_parts` | Agregar el precio de venta congelado (instantánea) al agregar la refacción; migrar las líneas existentes según D-03. |
| `payments` | Sin cambio de estructura previsto, salvo lo que resulte de D-04. Revalidar el importe de los pagos pendientes de Mercado Pago cuando cambie el total; el importe se sigue guardando como `DECIMAL(10,2)`. |
| `tickets` | No existe una columna `content` ni `format_version`: el ticket se reconstruye al consultarlo desde la orden, el pago y el catálogo actual. En este sprint se define cómo conservar el contenido y el precio histórico (D-09) y se agrega la advertencia de precio no registrado. |
| `order_services` y `order_labor` | `order_services` guarda la descripción del servicio; `order_labor.price` guarda el precio de la mano de obra. Se consultan para el total. |
| migración `005_...sql` y seeds del sprint | Crear la migración aditiva `005` y actualizar los seeds necesarios para el precio congelado y los datos de ejemplo. |

## 6. Reglas de negocio aplicables

- RN-6: Las refacciones utilizadas deben estar relacionadas con una orden.
- RN-7: El uso de una refacción debe generar o reflejar una salida de inventario.
- RN-8: No permitir stock negativo.
- RN-9: Una orden entregada debe conservarse como historial.
- RN-13: Todo pago debe estar relacionado con una orden.
- RN-14: Los datos sensibles del procesamiento de pagos no deben almacenarse en la aplicación.
- RN-15: Los permisos deben validarse en backend.

## 7. Criterios de aceptación

- [ ] CA-1: Una refacción puede registrarse y editarse con categoría, marca, precio de compra y precio de venta, y los datos persisten en MySQL local; los campos ya existen desde la migración `003`.
- [ ] CA-2: Los precios rechazan valores negativos, no numéricos, con más de dos decimales y por encima de los límites máximos que se definan.
- [ ] CA-3: Al agregar una refacción a una orden se guarda su precio de venta vigente en la línea; un cambio posterior del catálogo no modifica esa línea.
- [ ] CA-4: El total de la orden es mano de obra más refacciones (cantidad por precio congelado), calculado en centavos enteros. `order_services` no tiene precio propio; el precio del servicio vive en `order_labor.price`.
- [ ] CA-5: El pago nuevo se registra por el total con refacciones; el importe enviado que no coincida se sigue rechazando.
- [ ] CA-6: Los pagos y tickets generados antes del sprint conservan su importe y su contenido sin cambios, y siguen consultándose y mostrándose correctamente. Como hoy el ticket se reconstruye, el sprint debe definir el mecanismo de conservación (D-09).
- [ ] CA-7: El ticket nuevo incluye cantidad, precio unitario e importe de cada refacción, y el subtotal y el total las suman; si una refacción no tiene precio, muestra la advertencia «sin precio registrado».
- [ ] CA-8: Se mantienen las reglas del Sprint 4: un solo pago vigente por orden, también con solicitudes simultáneas, y ningún dato de tarjeta almacenado.
- [ ] CA-9: Mercado Pago recibe el importe con refacciones; un pago pendiente cuyo importe ya no coincide con el total se detecta y se resuelve según D-04.
- [ ] CA-10: El precio de compra solo es visible para el administrador; el mecánico y recepción no lo reciben en la API, validado en backend. Hoy la API lo devuelve a los tres roles.
- [ ] CA-11: El panel de control y los listados de órdenes y pagos no se rompen con el nuevo total.
- [ ] CA-12: Los seeds existentes ya incluyen refacciones con precios (seed `003`) y una orden cobrable con refacciones (seed `004`); el sprint los actualiza para el precio congelado y mantiene la idempotencia.
- [ ] CA-13: Existen y pasan pruebas de cálculo del total, instantáneas, redondeo a centavos, permisos por rol, concurrencia del pago y compatibilidad con tickets anteriores.
- [ ] CA-14: La documentación desfasada sobre el total, los precios y la visibilidad por rol se actualiza en el mismo sprint. En la revisión no se encontraron comentarios de código que digan que las refacciones no suman; el insumo original era el que lo afirmaba.

## 8. Fuera de alcance de este sprint

- Costeo, margen de ganancia, utilidad y reportes financieros (Sprint 7).
- Impuestos y facturación electrónica.
- Descuentos, promociones y pagos parciales o a plazos.
- Reembolsos dentro del sistema.
- Catálogo de proveedores y órdenes de compra.
- Notificaciones, reportes, configuración del taller y WhatsApp (Sprints 6 a 9).
- Fotos del vehículo y puesta en producción (Sprint 10).

## 9. Decisiones pendientes que deben resolverse en /speckit.clarify

- **D-01**: Refacciones existentes y líneas ya registradas sin precio. Hoy `parts.sale_price` y `parts.purchase_price` admiten `NULL`; las filas de `order_parts` sin `part_id` se valoran en 0 y el desglose del pago muestra «sin precio registrado». ¿Se les asigna 0, se exige capturar el precio o se bloquea agregarlas a una orden hasta que lo tengan?
- **D-02**: Orden con solo refacciones. Hoy no existe `NOTHING_TO_CHARGE`; una orden `TERMINADO` con solo refacciones y total positivo se puede cobrar, y un total 0 se rechaza por la validación `monto > 0` y el `CHECK (amount > 0)`. ¿Se mantiene esa regla o se define otra?
- **D-03**: Órdenes abiertas al desplegar. Hoy el total usa el precio de venta vigente del catálogo porque `order_parts` no guarda precio. Al agregar el precio congelado, ¿qué precio toman las líneas ya agregadas: el vigente al migrar, 0 u otro?
- **D-04**: Pago de Mercado Pago pendiente cuando cambia el total. Hoy `confirmPayment` solo cambia el estado y no revalida el importe. ¿Se cancela y se genera uno nuevo, se actualiza el importe o se marca como desfasado?
- **D-05**: Si el administrador corrige el precio de una línea de una orden abierta, ¿se permite y con qué motivo o permiso? Hoy no existe un precio por línea; solo se puede cambiar el precio del catálogo.
- **D-06**: Categoría: ¿lista cerrada administrable o texto libre? Marca: ¿texto libre? Hoy `parts.category` es `VARCHAR(80) NOT NULL` y `parts.brand` es `VARCHAR(80) NULL`, sin catálogo administrable.
- **D-07**: Precio de venta menor al de compra: ¿se permite, se advierte o se rechaza? Hoy no hay validación que compare ambos precios.
- **D-08**: Redondeo del importe de una línea (cantidad por precio) y límites máximos de precio y de total. Hoy se usan números decimales y `Math.round` a dos decimales; no hay topes.
- **D-09**: Cómo se muestran los tickets anteriores, que no tienen precio congelado, junto a los nuevos. Hoy el ticket se reconstruye desde la orden y el catálogo actual; no hay `content` ni `format_version`. ¿Se versiona el formato, se guarda una copia histórica o se marca el ticket como anterior?
- **D-10**: Visibilidad del precio de venta para el mecánico: ¿lo ve o solo ve nombre, código, unidad y existencia? Hoy la API devuelve `precioCompra` y `precioVenta` a los tres roles.

## 10. Restricciones técnicas heredadas

- Backend en ES Modules, nunca CommonJS.
- Solo el backend accede a MySQL; el frontend nunca se conecta directo.
- Permisos validados en backend, no solo en UI.
- Sin secretos en el repositorio.
- Idioma: español en chat, docs, comentarios y pruebas.
- MySQL local, InnoDB, llaves foráneas, `utf8mb4`.
- Login acepta usuario o correo electrónico en el mismo campo.
- Toda pantalla del frontend sigue `docs/design-system.md`.
- Pruebas de integración contra `motorix_v2_test`, nunca contra `motorix_test` ni contra la base principal. El nombre `motorix_test` pertenece al prototipo anterior.
- Los seeds del sprint DEBEN incluir datos de ejemplo suficientes para que la aplicación muestre información al arrancar. La base no puede quedar vacía tras la instalación.
- Los seeds DEBEN ser idempotentes: si se corren de nuevo, no duplican registros.
- Los importes se guardan como `DECIMAL(10,2)`. Hoy el cálculo usa números decimales y `Math.round` a dos decimales; este sprint debe migrar el cálculo a centavos enteros, manteniendo la persistencia en `DECIMAL(10,2)`.
- Las migraciones son aditivas y numeradas (`005_...sql`); no modifican las migraciones anteriores.

## Anexo. Hallazgos del diagnóstico para el documento de aseguramiento

> Este anexo no forma parte de la especificación. Reúne las discrepancias detectadas al contrastar el insumo con el código para trasladarlas a la sección 7 del futuro documento de aseguramiento. No incluye resolución ni estado de aprobación.

| ID | Hallazgo | Severidad propuesta | Origen | Evidencia |
|:--:|---|---|---|---|
| H-01 | El insumo original afirmaba que las refacciones no sumaban al total; el código ya suma `parts.sale_price` × `order_parts.quantity`. | Alta | G-01, revisión del insumo contra el código | `server/utils/order-total.js:41-70`; `server/models/payment.js:131-158`; `server/services/payment.service.js:118-124`; prueba en `server/tests/integration/payments.test.js:148-188` |
| H-02 | El insumo original afirmaba que el Sprint 3 difirió categoría, marca y precios, y la tabla de entidades decía «agregar» campos que ya existen. | Alta | G-01 | `database/migrations/003_historial_mantenimiento_inventario.sql:8-27`; `server/services/part.service.js:34-47`; `server/validators/part.validator.js:31-46`; `database/seeds/003_ejemplos_historial_inventario.sql:13-19` |
| H-03 | `NOTHING_TO_CHARGE` no existe en el código; los rechazos actuales son `ORDEN_NO_COBRABLE` y `MONTO_NO_COINCIDE`, y el monto 0 se rechaza por validación y por `CHECK (amount > 0)`. | Media | G-01 | `server/services/payment.service.js:86-93` y `118-124`; `server/validators/payment.validator.js:13-16`; `database/migrations/004_pagos_tickets_dashboard.sql:36` |
| H-04 | La base de pruebas es `motorix_v2_test`, no `motorix_test`. | Media | G-01 | `server/tests/helpers/env.js:6`; `server/config/env.js:43`; `docs/project-context.md:791-794` |
| H-05 | El cálculo actual usa números decimales y `Math.round` a dos decimales; no usa centavos enteros. | Media | G-01 | `server/utils/order-total.js:17-21` y `26-70`; `database/migrations/002_citas_ordenes_servicio.sql:118`; `database/migrations/004_pagos_tickets_dashboard.sql:15` |
| H-06 | El ticket se reconstruye al consultarlo; no hay columna `content` ni `format_version`, y usa el precio actual del catálogo. Un cambio de precio puede alterar tickets ya emitidos. Además, `order_parts` solo guarda `part_id`, `description` y `quantity`; no guarda precio, por lo que el total de una orden abierta cambia cuando cambia `parts.sale_price`. | Alta | G-01 | `database/migrations/002_citas_ordenes_servicio.sql:132-142`; `database/migrations/003_historial_mantenimiento_inventario.sql:99-108`; `server/models/order_items.js:68-77`; `database/migrations/004_pagos_tickets_dashboard.sql:39-62`; `server/services/ticket.service.js:43-50`, `63-72` y `108-111`; `server/models/payment.js:131-158` |
| H-07 | El precio de compra se devuelve a los tres roles; no hay filtro por rol en la API. | Alta | G-01 | `server/routes/parts.routes.js:33-43`; `server/services/part.service.js:34-47` |
| H-08 | La validación de precios solo exige número mayor o igual a 0; no limita a dos decimales ni define topes máximos. | Media | G-01 | `server/validators/part.validator.js:15-18`, `45-46` y `70-71` |
| H-09 | La confirmación de un pago pendiente de Mercado Pago no revalida el importe contra el total actual. | Alta | G-01 | `server/services/payment.service.js:212-230` |
| H-10 | El ticket no incluye la advertencia «sin precio registrado» que sí trae el desglose del pago. | Baja | G-01 | `server/utils/order-total.js:58-60` frente a `server/services/ticket.service.js:63-72` |
| H-11 | No existe la migración `005` ni un seed `005`; la más alta en ambas carpetas es la `004`. | Media | G-01 | `database/migrations/` y `database/seeds/` |
| H-12 | La referencia `docs/sprints/propuesta-sprints-post-mvp.md` no existe y no tiene historial en Git. | Baja | G-01 | Archivo no encontrado; `git log --all -- docs/sprints/propuesta-sprints-post-mvp.md` sin resultados |
| H-13 | El principio I de la constitución limita el MVP a los sprints 1 a 4; el Sprint 5 es posterior al MVP y requiere una enmienda antes de implementar; según la Gobernanza, la aprueba el equipo, coordinado por el director del proyecto. **Resuelto el 2026-11-13** con la enmienda 1.1.0 de la constitución. | Media | G-01, revisión de la constitución | `docs/reglas.md:44-45`; `.specify/memory/constitution.md:37`; versión 1.0.0 en `.specify/memory/constitution.md:251` |
| H-14 | El insumo original incluía «servicios» como componente separado del total; `order_services` solo guarda la descripción y el precio del servicio vive en `order_labor.price`. | Media | G-01 | `database/migrations/002_citas_ordenes_servicio.sql:98-127`; `server/utils/order-total.js:7-13` y `30-39` |
| H-15 | El guard de contenido solo bloquea la orden `ENTREGADO`; una orden `TERMINADO` ya pagada puede cambiar sus servicios o refacciones, lo que también altera el ticket reconstruido. El responsable decidió el 2026-11-04 incluir en el alcance la inmovilización del contenido de las órdenes `TERMINADO` que ya tienen un pago; el detalle se precisará en la especificación y las aclaraciones. | Media | G-01, observación de alcance | `server/services/service_order.service.js:323-335` y `414-446` |

### Hallazgo de la línea base

| ID | Hallazgo | Severidad propuesta | Origen | Evidencia |
|:--:|---|---|---|---|
| H-B01 | La captura de `npm test` del 2026-11-03 muestra 2 pruebas de autenticación fallidas (una con timeout de 5000 ms visible; el mensaje de la otra no es visible en la captura); el archivo versionado del mismo commit registra 49 suites y 411 pruebas aprobadas. La diferencia debe explicarse antes de fijar la línea base. **Resuelto el 2026-11-14**: la preparación de la base se movió a un `globalSetup` y el pool de MySQL se cierra al final de cada suite; evidencia en `docs/evidencias/sprint 5/h-b01-*.txt`. | Alta | Línea base | `docs/evidencias/sprint 5/npm test.png`; `docs/evidencias/salida-npm-test.txt`; commit `a01b8b1` |
