# Especificación de la Funcionalidad: Precios de refacciones y cobro completo

**Rama de la funcionalidad**: `005-precios-refacciones-cobro`

**Fecha de creación**: 2026-11-14

**Estado**: Borrador (aclarado el 2026-11-14)

**Input**: Descripción del usuario: "Sprint 5 de Motorix: precios de refacciones y cobro completo. Fuente única: `docs/sprints/sprint-5-precios-refacciones-cobro.md` (secciones 1 a 10); el anexo de hallazgos solo es contexto. Respeta la constitución 1.1.0 y `docs/project-context.md`. Las decisiones D-01 a D-10 se toman en `/speckit-clarify`."

> **Gobernanza**: el Sprint 5 está dentro del alcance oficial posterior al MVP por la enmienda 1.1.0 de la constitución (2026-11-13, principio I).

## Clarifications

### Session 2026-11-14

Decisiones tomadas por el responsable del sprint. Se registran tal cual y se aplican en los requisitos citados.

- Q: D-01 - ¿Qué pasa con las refacciones y las líneas sin precio? → A: El precio de venta es obligatorio para agregar una refacción del catálogo a una orden. Las líneas sin refacción del catálogo asociada (texto libre) siguen valiendo 0 y muestran «sin precio registrado». (FR-005, FR-018)
- Q: D-02 - ¿Cómo se cobra una orden con solo refacciones? → A: Se mantiene lo actual: una orden `TERMINADO` con solo refacciones se cobra si el total es mayor que 0; un total de 0 se rechaza. (FR-012)
- Q: D-03 - ¿Qué precio toman las líneas ya registradas en órdenes abiertas al desplegar el sprint? → A: El precio de venta vigente del catálogo en el momento de la migración. (FR-010)
- Q: D-04 - ¿Qué pasa con un pago pendiente de Mercado Pago cuyo importe ya no coincide con el total? → A: Al intentar confirmarlo se rechaza la confirmación y ese pago se cancela; recepción genera uno nuevo con el total correcto. (FR-016)
- Q: D-05 - ¿Puede el administrador corregir el precio de una línea de una orden abierta? → A: No en este sprint. Para corregirlo se quita la línea y se vuelve a agregar, mientras la orden no esté bloqueada. (FR-011)
- Q: D-06 - ¿Cómo se capturan la categoría y la marca? → A: Ambas siguen como texto libre; la marca sigue siendo opcional. (FR-001)
- Q: D-07 - ¿Se permite un precio de venta menor que el de compra? → A: Sí, pero el sistema le muestra una advertencia al administrador. (FR-004)
- Q: D-08 - ¿Cómo se redondea y qué topes hay? → A: El cálculo se hace en centavos enteros; el importe de cada línea (cantidad × precio) se redondea al centavo, hacia arriba desde 0.5, si la cantidad admite decimales. Tope de precio por refacción: 999,999.99. El total no puede exceder lo que cabe en el formato de importe actual (99,999,999.99). (FR-003, FR-008)
- Q: D-09 - ¿Cómo se conservan los tickets? → A: Al emitir un ticket se guarda una copia de su contenido con un número de versión de formato. A los tickets anteriores al sprint se les genera la copia durante la migración y se marcan como «formato anterior». (FR-019, FR-020)
- Q: D-10 - ¿Qué precios recibe cada rol? → A: El mecánico no recibe ningún precio de refacción (solo nombre, código, unidad y existencia; la lista de campos se precisa en la entrada «D-10 (campos del mecánico)», porque el catálogo no tiene un campo «unidad»); recepción recibe el precio de venta; solo el administrador recibe el precio de compra. Se valida en el servidor. (FR-024 a FR-026)
- Q: D-10 (alcance) - ¿La restricción del mecánico incluye el precio de la mano de obra, que hoy él mismo captura al agregar un servicio? → A: No. D-10 aplica solo a los precios de refacciones (de compra, de venta y el precio congelado de las líneas); el mecánico sigue capturando y viendo el precio de la mano de obra de sus servicios, como hoy. (FR-026)
- Q: H15-a - ¿Qué estado de pago inmoviliza el contenido de una orden `TERMINADO`? → A: Solo un pago `PAGADO`; uno `PENDIENTE` no la bloquea (si el total cambia mientras está pendiente, aplica D-04). (FR-021)
- Q: H15-b - ¿Qué pasa si se anula el pago `PAGADO`? → A: Si el sistema permite anularlo, la orden vuelve a admitir cambios; si esa función no existe, no aplica (los reembolsos quedan fuera de alcance). La anulación existe desde el Sprint 4 (solo administración, con motivo), así que la regla aplica. (FR-022)
- Q: Permisos CHK002 - ¿El mecánico puede recibir el total de la orden, el subtotal de refacciones u otro importe? → A: No. No recibe el total de la orden, el subtotal de refacciones ni ningún importe del que se pueda deducir un precio de refacción; hoy ya no los recibe y el requisito es que siga así. Sí recibe la mano de obra de sus servicios (alcance de D-10). (FR-034)
- Q: Permisos CHK003 - ¿El mecánico tiene acceso a pagos, tickets o panel de control? → A: No, como hoy; se conserva como requisito. (FR-035)
- Q: Permisos CHK019 y CHK021 - ¿Un precio restringido puede salir por vías indirectas? → A: No. Ningún precio restringido para un rol sale por filtros, búsquedas, ordenamientos, mensajes de error ni registros del servidor. (FR-036)
- Q: Permisos CHK006 - ¿Se registra quién y cuándo cambió un precio? → A: No; la bitácora de cambios de precio queda fuera de alcance. (Fuera de alcance)
- Q: Pagos CHK003 y CHK004 - ¿Cuántos tickets puede tener una orden y qué pasa con el del pago anulado? → A: Un ticket por cada pago `PAGADO`, no uno por orden; una orden puede tener varios tickets. El ticket del pago anulado se conserva con su copia sin cambios y, al consultarlo, muestra la marca «pago anulado», tomada del estado actual del pago y no guardada en la copia. El ticket vigente de la orden es el del pago `PAGADO` no anulado. Contexto: hoy hay una restricción de un ticket por orden y, tras anular y volver a cobrar, se devuelve el ticket viejo ligado al pago anulado; este sprint lo corrige. (FR-022, FR-033)
- Q: Pagos CHK001 - ¿El pago cancelado por importe desfasado guarda un motivo? → A: Sí, el motivo «importe desfasado», que lo distingue de una cancelación manual. (FR-016)
- Q: Monetario CHK021 - ¿Qué pasa si, al migrar, el desglose de un ticket anterior no suma el importe pagado? → A: La copia conserva como total el importe pagado (nunca se altera lo cobrado) y agrega una nota visible de que el desglose no coincide con lo cobrado. Contexto: en la base local de desarrollo, 1 de 2 órdenes pagadas tiene diferencia (orden 5: pagado 1390.00, calculado 1090.00). (FR-020)
- Q: Monetario CHK001 - ¿Qué validaciones tiene el precio de la mano de obra? → A: Las mismas que los precios de refacciones: sin negativos, numérico, máximo dos decimales y tope de 999,999.99, validado en el servidor y en Flutter como apoyo. Hoy solo se rechazan los negativos. (FR-032)
- Q: Monetario CHK019 y CHK020 - ¿Cómo se mide el éxito de la migración? → A: (a) El 100 % de las líneas de refacción del catálogo con precio de venta quedan con precio congelado igual al precio vigente al migrar, y las que no tienen precio quedan en 0 con «sin precio registrado»; (b) el 100 % de los tickets anteriores al sprint tienen copia marcada «formato anterior» y su total es igual al importe de su pago. (SC-011, SC-012)
- Q: Riesgo de D-04 (ampliado) - ¿Qué limitaciones de Mercado Pago agravan el riesgo? → A: Hoy no hay webhook, la confirmación es manual y la preferencia se crea sin expiración, así que el enlace de un pago cancelado sigue vivo en el proveedor. Antes de generar un pago nuevo, recepción debe revisar en el panel de Mercado Pago si el cliente ya pagó. Los webhooks quedan fuera de alcance; si conviene ponerle expiración a las preferencias nuevas se decide en `/speckit-plan`. (Supuestos, Fuera de alcance)
- Q: Decisión del plan - ¿Las preferencias nuevas de Mercado Pago se crean con vencimiento? → A: Sí, aprobado: vencen a las 24 horas por defecto, configurable por variable de entorno. La documentación de México no se pudo verificar y se confirma con una prueba manual en sandbox que hace el responsable durante la implementación. (FR-037, SC-014)
- Q: Decisión del plan - ¿Se cierran las sesiones de un usuario cuando cambia su rol? → A: No, no aprobado. Queda como limitación conocida: el servidor aplica el rol nuevo en la siguiente petición y Flutter muestra el anterior hasta volver a iniciar sesión; los precios siguen protegidos en el servidor. (Supuestos, Fuera de alcance)
- Q: D-10 (campos del mecánico) - ¿Qué campos de la refacción recibe exactamente el mecánico? → A: Todos los campos de la refacción que no son importes: nombre, código, categoría, marca, existencia, stock mínimo, stock bajo y si está activa. No recibe ningún precio (de compra, de venta ni congelado de la línea). El catálogo no tiene un campo «unidad», así que no se incluye. (FR-025, US5)
- Q: Revisión de checklists - ¿Qué significa «vigente» para pagos y tickets? → A: «Pago vigente» es un pago en estado `PENDIENTE` o `PAGADO`; «ticket vigente» es el ticket del pago `PAGADO` no anulado de la orden. (FR-014, FR-033, Entidades clave)
- Q: Revisión de checklists - ¿La mano de obra sin precio lleva aviso en el ticket? → A: Sí, muestra «sin precio registrado», igual que en el desglose del pago. (FR-018)

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Mantener los datos y precios de una refacción (Prioridad: P1)

Como administrador, quiero registrar y mantener la categoría, la marca y los precios de compra y de venta de una refacción, con validaciones, para conocer el costo y el precio de cada pieza.

**Por qué esta prioridad**: el precio de venta del catálogo es el que se congela en cada orden; si entra mal capturado, todo el cobro posterior hereda el error.

**Prueba independiente**: se prueba sola dando de alta y editando refacciones con precios válidos e inválidos, y comprobando qué se guarda y qué se rechaza, sin tocar órdenes.

**Escenarios de aceptación**:

1. **Dado** un administrador autenticado, **Cuando** registra una refacción con categoría y marca en texto libre, precio de compra y precio de venta válidos, **Entonces** la refacción queda guardada con esos datos y se consulta igual después.
2. **Dado** una refacción existente, **Cuando** el administrador edita su categoría, marca o precios con valores válidos, o deja la marca vacía, **Entonces** los cambios quedan guardados.
3. **Dado** el formulario de la refacción, **Cuando** el administrador captura un precio negativo, no numérico o con más de dos decimales, **Entonces** el sistema rechaza el registro con un mensaje claro que indica el campo y el motivo, y no guarda nada.
4. **Dado** el formulario de la refacción, **Cuando** el administrador captura un precio mayor que 999,999.99, **Entonces** el sistema lo rechaza con un mensaje claro.
5. **Dado** el formulario de la refacción, **Cuando** el administrador captura un precio de venta menor que el de compra, **Entonces** el sistema guarda la refacción y le muestra una advertencia.
6. **Dado** un usuario recepcionista o mecánico, **Cuando** intenta crear o editar una refacción, **Entonces** el sistema lo rechaza por permisos, aunque la petición no venga de la interfaz.

---

### Historia de usuario 2 - Total de la orden con precio congelado (Prioridad: P2)

Como recepcionista, quiero que el total de la orden incluya las refacciones con el precio de venta congelado al agregarlas, para cobrar el trabajo completo sin que un cambio posterior del catálogo altere el importe.

**Por qué esta prioridad**: es el núcleo del sprint; sin el precio congelado, el pago, el ticket y la integridad del historial no se pueden garantizar.

**Prueba independiente**: se agrega una refacción a una orden, se cambia el precio del catálogo y se comprueba que el total de la orden no cambia.

**Escenarios de aceptación**:

1. **Dado** una refacción con precio de venta vigente de 250.00, **Cuando** el mecánico la agrega a su orden con cantidad 2, **Entonces** la línea de la orden guarda el precio unitario 250.00 y su importe es 500.00.
2. **Dado** una orden con esa línea, **Cuando** el administrador cambia el precio de venta del catálogo a 300.00, **Entonces** la línea conserva 250.00 y el total de la orden no cambia.
3. **Dado** una orden con mano de obra de 400.00 y refacciones congeladas por 500.00, **Cuando** recepción consulta el total, **Entonces** el total es 900.00, exacto al centavo.
4. **Dado** una orden con varias líneas cuyos importes tienen centavos (por ejemplo, 3 × 33.33), **Cuando** se calcula el total, **Entonces** el resultado coincide exactamente con la suma hecha a mano.
5. **Dado** una refacción del catálogo sin precio de venta, **Cuando** alguien intenta agregarla a una orden, **Entonces** el sistema lo rechaza con un mensaje que indica que primero debe registrarse su precio de venta.
6. **Dado** una refacción que se desactiva después de agregarse a una orden, **Cuando** se consulta la orden, **Entonces** la línea conserva su descripción, su cantidad y su precio congelado.
7. **Dado** una línea con un precio congelado que hay que corregir, **Cuando** la orden todavía admite cambios en sus refacciones, **Entonces** la corrección se hace quitando la línea y volviéndola a agregar; no existe la edición directa del precio de la línea.

---

### Historia de usuario 3 - Pago y ticket con el total completo (Prioridad: P3)

Como recepcionista, quiero que el pago y el ticket reflejen el total con refacciones congeladas, para entregar un comprobante correcto al cliente.

**Por qué esta prioridad**: es el resultado visible para el cliente; depende de la historia 2.

**Prueba independiente**: con una orden terminada que tiene mano de obra y refacciones, se registra el pago por el total y se genera el ticket; se comprueba que el ticket desglosa cada refacción y que la suma coincide con lo cobrado.

**Escenarios de aceptación**:

1. **Dado** una orden `TERMINADO` con total 900.00, **Cuando** recepción registra un pago por 900.00, **Entonces** el pago se acepta.
2. **Dado** la misma orden, **Cuando** recepción envía un importe distinto del total, **Entonces** el pago se rechaza, como en el Sprint 4.
3. **Dado** una orden `TERMINADO` con solo refacciones y total mayor que 0, **Cuando** recepción registra el pago por ese total, **Entonces** el pago se acepta; **y dado** un total de 0, el cobro se rechaza.
4. **Dado** un pago aprobado, **Cuando** se genera el ticket, **Entonces** el ticket muestra, por cada refacción, la cantidad, el precio unitario congelado y el importe, y el subtotal y el total las suman.
5. **Dado** una línea de texto libre sin refacción del catálogo, **Cuando** se genera el ticket, **Entonces** esa línea vale 0 y muestra la advertencia «sin precio registrado».
6. **Dado** un cobro por Mercado Pago, **Cuando** se inicia, **Entonces** el importe enviado incluye las refacciones con su precio congelado.
7. **Dado** un pago pendiente de Mercado Pago cuyo importe ya no coincide con el total de la orden, **Cuando** recepción intenta confirmarlo, **Entonces** el sistema rechaza la confirmación, cancela ese pago con un mensaje que explica la diferencia, y la orden queda libre para generar un pago nuevo por el total correcto.
8. **Dado** dos solicitudes de pago simultáneas para la misma orden, **Cuando** se procesan, **Entonces** solo una queda vigente.
9. **Dado** un cobro nuevo por Mercado Pago, **Cuando** se crea su enlace de pago, **Entonces** el enlace vence a las 24 horas (o en el plazo configurado), y después de vencer el cliente ya no puede pagar con él.

---

### Historia de usuario 4 - Integridad del historial ante cambios de precio (Prioridad: P4)

Como administrador, quiero que un cambio de precio no altere órdenes abiertas ni pagos y tickets ya emitidos, para conservar la integridad del historial.

**Por qué esta prioridad**: protege lo ya cobrado y entregado (RN-9); se apoya en las historias 2 y 3.

**Prueba independiente**: se emite un ticket, se cambia el precio del catálogo de sus refacciones y se vuelve a consultar el ticket y el pago; nada debe cambiar.

**Escenarios de aceptación**:

1. **Dado** un pago y un ticket emitidos, **Cuando** el administrador cambia el precio de venta de las refacciones que incluyen, **Entonces** el pago y el ticket conservan su importe y su contenido.
2. **Dado** un ticket emitido en este sprint, **Cuando** se consulta, **Entonces** se muestra a partir de la copia guardada al emitirlo, con su número de versión de formato.
3. **Dado** tickets emitidos antes de este sprint, **Cuando** se consultan después de desplegarlo, **Entonces** se muestran a partir de la copia generada en la migración, conservan su importe y llevan la marca «formato anterior».
4. **Dado** una orden `TERMINADO` con un pago `PAGADO`, **Cuando** alguien intenta agregar o quitar un servicio o su mano de obra, **Entonces** el sistema lo rechaza con un mensaje claro y el ticket no cambia.
5. **Dado** una orden `TERMINADO` con un pago `PENDIENTE`, **Cuando** el usuario autorizado agrega o quita un servicio, **Entonces** la operación se permite.
6. **Dado** una orden `TERMINADO` cuyo pago `PAGADO` fue anulado por administración, **Cuando** el usuario autorizado agrega o quita un servicio, **Entonces** la operación se permite de nuevo, y el ticket emitido con el pago anulado conserva su copia sin cambios y se muestra con la marca «pago anulado».
7. **Dado** esa misma orden, **Cuando** recepción registra un pago nuevo y genera el ticket, **Entonces** se emite un ticket nuevo ligado al pago nuevo, que pasa a ser el ticket vigente de la orden; el ticket anterior sigue consultable.
8. **Dado** un ticket anterior al sprint cuyo desglose no suma el importe pagado, **Cuando** se consulta después de la migración, **Entonces** muestra como total el importe pagado y una nota visible de que el desglose no coincide con lo cobrado.

---

### Historia de usuario 5 - Precios de refacciones visibles según el rol (Prioridad: P5)

Como mecánico, quiero seguir usando las refacciones en una orden sin recibir sus precios (de compra, de venta ni el precio congelado de la línea), para no exponer información financiera del taller; recepción recibe el precio de venta y solo el administrador el de compra.

**Por qué esta prioridad**: es una restricción de seguridad acotada; no bloquea el cobro.

**Prueba independiente**: con sesiones de los tres roles se consultan el catálogo, el detalle de una refacción y el detalle de una orden, y se comprueba qué precios de refacción recibe cada uno.

**Escenarios de aceptación**:

1. **Dado** un mecánico autenticado, **Cuando** consulta el catálogo, el detalle de una refacción o el detalle o el listado de órdenes, **Entonces** recibe de cada refacción el nombre, el código, la categoría, la marca, la existencia, el stock mínimo, el indicador de stock bajo y si está activa, sin precio de compra, de venta ni precio congelado de línea, y sin el total de la orden ni el subtotal de refacciones.
2. **Dado** un recepcionista autenticado, **Cuando** hace las mismas consultas, **Entonces** recibe el precio de venta y el precio congelado de las líneas, pero no el precio de compra.
3. **Dado** un administrador autenticado, **Cuando** hace las mismas consultas, **Entonces** recibe el precio de compra y el de venta.
4. **Dado** un mecánico asignado a una orden, **Cuando** busca una refacción y la agrega, **Entonces** puede hacerlo sin recibir sus precios.
5. **Dado** un mecánico, **Cuando** agrega un servicio a su orden, **Entonces** sigue capturando y viendo el precio de la mano de obra de ese servicio, como hoy.
6. **Dado** un mecánico o un recepcionista, **Cuando** piden directamente al servidor, sin pasar por la interfaz, un precio que su rol no debe recibir, **Entonces** no lo reciben.
7. **Dado** un mecánico, **Cuando** intenta consultar pagos, tickets o el panel de control, **Entonces** el sistema lo rechaza por permisos.
8. **Dado** un mecánico, **Cuando** filtra, busca u ordena el catálogo, o provoca un error en una petición, **Entonces** ni el resultado ni el mensaje de error revelan precios de refacción.

---

### Flujo demostrable al cierre del sprint

1. El administrador registra una refacción con categoría, marca, precio de compra y precio de venta, y el sistema los valida.
2. El mecánico agrega la refacción a una orden y la línea guarda el precio de venta vigente.
3. La orden pasa a Terminada.
4. Recepción consulta el total: mano de obra más refacciones con precio congelado.
5. Recepción registra el pago por ese total.
6. Se genera el ticket con las refacciones, su precio unitario, su importe, el subtotal y el total.
7. El administrador cambia el precio de venta del catálogo.
8. La línea de la orden conserva el precio congelado, y el pago y el ticket ya emitidos conservan su importe y su contenido.
9. Si una línea no tiene precio, el ticket muestra la advertencia «sin precio registrado».

### Casos límite

- Cambio del precio del catálogo mientras una orden está abierta: la línea conserva el precio congelado (FR-007).
- Refacción del catálogo sin precio de venta: no se puede agregar a una orden hasta que lo tenga (FR-005).
- Línea de texto libre sin refacción del catálogo: vale 0 y muestra «sin precio registrado» (FR-005, FR-018).
- Importes de línea con centavos y sumas de muchas líneas: resultado exacto al centavo (FR-008).
- Precio mayor que 999,999.99: se rechaza (FR-003).
- Operación que haría que el total de la orden pase de 99,999,999.99: se rechaza con un mensaje claro (FR-008).
- Precio de venta menor que el de compra: se guarda con una advertencia al administrador (FR-004).
- Orden con solo refacciones: se cobra si el total es mayor que 0; un total de 0 se rechaza (FR-012).
- Líneas que ya existían cuando se despliega el sprint: toman el precio de venta vigente al migrar (FR-010).
- Pago pendiente de Mercado Pago con importe desfasado: se rechaza la confirmación y se cancela el pago (FR-016).
- Corrección del precio de una línea: solo quitando y volviendo a agregar la línea, mientras la orden lo permita (FR-011).
- Refacción desactivada después de usarse en una orden: la línea conserva su precio y su descripción (FR-007).
- Dos pagos simultáneos para la misma orden: solo uno queda vigente (FR-014).
- Enlace de Mercado Pago vencido antes de que el cliente pague: el pago sigue `PENDIENTE` en el sistema hasta que recepción lo confirme como rechazado o cancelado; los enlaces creados antes del sprint no vencen (FR-037).
- Alta o baja de servicios en una orden `TERMINADO` con pago `PAGADO`: se rechaza; con pago `PENDIENTE` o con el pago anulado, se permite (FR-021, FR-022).
- Consulta de tickets emitidos antes del sprint: se muestran desde su copia con la marca «formato anterior» (FR-020).
- Ticket anterior al sprint cuyo desglose no suma el importe pagado: la copia conserva el importe pagado como total y muestra una nota de que el desglose no coincide (FR-020).
- Orden con un pago anulado y un pago nuevo: tiene dos tickets; el vigente es el del pago `PAGADO` no anulado y el otro se muestra con la marca «pago anulado» (FR-022, FR-033).
- Precio de mano de obra negativo, no numérico, con más de dos decimales o mayor que 999,999.99: se rechaza (FR-032).
- Mecánico o recepcionista que pide un precio que su rol no debe recibir, por cualquier vía (respuestas, filtros, búsquedas, ordenamientos, mensajes de error o registros del servidor): no lo reciben (FR-024, FR-025, FR-036).
- Mecánico que intenta deducir el precio de una refacción a partir del total o del subtotal de la orden: no recibe esos importes (FR-034).
- Mecánico que intenta consultar pagos, tickets o el panel de control: se rechaza por permisos (FR-035).

## Requisitos *(obligatorio)*

### Requisitos funcionales

**Catálogo de refacciones (US1)**

- **FR-001**: El sistema DEBE permitir al administrador registrar y editar una refacción con categoría y marca en texto libre, precio de compra y precio de venta, y conservar esos datos para consultas posteriores. La categoría es obligatoria y la marca es opcional, como hoy.
- **FR-002**: El sistema DEBE permitir crear y editar refacciones y sus precios solo al rol administrador, validándolo en el servidor y no solo en la interfaz.
- **FR-003**: El sistema DEBE rechazar, con un mensaje que indique el campo y el motivo, todo precio negativo, no numérico, con más de dos decimales o mayor que 999,999.99.
- **FR-004**: El sistema DEBE permitir guardar un precio de venta menor que el precio de compra y, en ese caso, DEBE mostrarle una advertencia al administrador.
- **FR-005**: El sistema DEBE rechazar agregar a una orden una refacción del catálogo que no tenga precio de venta, con un mensaje que indique que primero debe registrarse. Las líneas de texto libre, sin refacción del catálogo asociada, DEBEN seguir valiendo 0.
- **FR-032**: El precio de la mano de obra DEBE tener las mismas validaciones que los precios de refacciones: se rechaza, con un mensaje que indique el campo y el motivo, todo valor negativo, no numérico, con más de dos decimales o mayor que 999,999.99. Se valida en el servidor y también en la interfaz como apoyo. Sigue siendo opcional, como hoy.

**Precio congelado y total de la orden (US2)**

- **FR-006**: Al agregar una refacción a una orden, el sistema DEBE guardar en la línea el precio de venta vigente del catálogo en ese momento.
- **FR-007**: Un cambio posterior del precio del catálogo, o la desactivación de la refacción, NO DEBE modificar el precio guardado en la línea.
- **FR-008**: El total de la orden DEBE ser la suma de la mano de obra más, por cada línea de refacción, la cantidad por el precio congelado. El cálculo DEBE hacerse en centavos enteros, con resultado exacto al centavo. El importe de cada línea se redondea al centavo, hacia arriba desde 0.5, cuando la cantidad admita decimales. El sistema DEBE rechazar, con un mensaje claro, toda operación que haga que el total pase de 99,999,999.99.
- **FR-009**: El total NO DEBE sumar un precio de servicio aparte de su mano de obra: el precio de cada servicio es el de su mano de obra.
- **FR-010**: Al desplegar el sprint, **todas** las líneas de refacción ya registradas DEBEN tomar como precio congelado el precio de venta vigente del catálogo en el momento de la migración, sea cual sea el estado de su orden: abiertas, `TERMINADO` y `ENTREGADO` (D-03 y el supuesto correspondiente). Las líneas cuya refacción no tiene precio de venta, y las de texto libre, quedan sin precio congelado (valen 0 y muestran «sin precio registrado»). Los tickets ya emitidos se conservan con su copia (FR-020).
- **FR-011**: El sistema NO DEBE permitir editar el precio de una línea. Para corregirlo, la línea se quita y se vuelve a agregar, mientras la orden admita cambios en sus refacciones.
- **FR-012**: El sistema DEBE permitir cobrar una orden `TERMINADO` con solo refacciones si su total es mayor que 0, y DEBE rechazar el cobro de un total de 0, como hoy.

**Pago (US3)**

- **FR-013**: El sistema DEBE registrar un pago nuevo solo por el total de la orden calculado según FR-008, y DEBE seguir rechazando el importe enviado que no coincida.
- **FR-014**: El sistema DEBE conservar las reglas del Sprint 4: como máximo un **pago vigente** (`PENDIENTE` o `PAGADO`) por orden, también con solicitudes simultáneas, y ningún dato de tarjeta almacenado (RN-14).
- **FR-015**: El importe que se envía a Mercado Pago DEBE ser el total de la orden con las refacciones a precio congelado.
- **FR-016**: Al intentar confirmar un pago pendiente de Mercado Pago, el sistema DEBE comparar su importe con el total actual de la orden. Si no coinciden, DEBE rechazar la confirmación, cancelar ese pago guardando el motivo «importe desfasado» (que lo distingue de una cancelación manual) y avisar del motivo, para que recepción genere un pago nuevo por el total correcto.
- **FR-037**: Toda preferencia nueva de Mercado Pago DEBE crearse con vencimiento: válida desde su creación y hasta 24 horas después por defecto. El plazo DEBE poder configurarse con una variable de entorno, sin cambiar código. Las preferencias creadas antes del sprint no se modifican.

**Ticket e integridad del historial (US3 y US4)**

- **FR-017**: El ticket nuevo DEBE incluir, por cada refacción, la cantidad, el precio unitario congelado y el importe, y el subtotal y el total DEBEN sumarlas.
- **FR-018**: El ticket DEBE mostrar la advertencia «sin precio registrado» en cada línea sin precio, tanto de refacción como de mano de obra, igual que ya lo hace el desglose del pago.
- **FR-019**: Al emitir un ticket, el sistema DEBE guardar una copia de su contenido con un número de versión de formato, y DEBE mostrar el ticket a partir de esa copia, de modo que un cambio posterior del catálogo o de la orden no altere su importe ni su contenido.
- **FR-020**: Durante la migración, el sistema DEBE generar la copia del contenido de cada ticket emitido antes del sprint y marcarlo como «formato anterior». Esos tickets DEBEN seguir consultándose y mostrándose correctamente, con su importe original. Si el desglose reconstruido no suma el importe pagado, la copia DEBE conservar como total el importe pagado (nunca se altera lo cobrado) y DEBE agregar una nota visible de que el desglose no coincide con lo cobrado.
- **FR-033**: El sistema DEBE emitir un ticket por cada pago `PAGADO`, no uno por orden, de modo que una orden pueda tener varios tickets. El **ticket vigente** de la orden DEBE ser el del pago `PAGADO` no anulado; los demás tickets de la orden no son vigentes. Al generar el ticket de un pago nuevo, el sistema NO DEBE devolver el ticket de un pago anulado anterior.

**Inmovilización del contenido de órdenes terminadas y pagadas (H-15)**

- **FR-021**: Mientras una orden `TERMINADO` tenga un pago en estado `PAGADO`, el sistema DEBE rechazar, con un mensaje claro y validándolo en el servidor, toda alta o baja de servicios y de su mano de obra. Un pago `PENDIENTE` NO bloquea el contenido; si el total cambia mientras está pendiente, aplica FR-016. Las altas y bajas de refacciones ya se rechazan hoy en toda orden `TERMINADO` y DEBEN seguir rechazándose.
- **FR-022**: Cuando administración anula el pago `PAGADO` de una orden `TERMINADO`, la orden DEBE volver a admitir altas y bajas de servicios y de su mano de obra. El ticket emitido con el pago anulado DEBE conservar su copia sin cambios y, al consultarlo, DEBE mostrar la marca «pago anulado», tomada del estado actual del pago y no guardada en la copia.
- **FR-023**: Una orden `ENTREGADO` DEBE seguir sin admitir cambios en su contenido (RN-9).

**Visibilidad de precios de refacciones por rol (US5)**

- **FR-024**: El sistema DEBE entregar el precio de compra solo al administrador. El mecánico y el recepcionista NO DEBEN recibirlo en ninguna respuesta del servidor (catálogo, detalle de la refacción, detalle de la orden u otra).
- **FR-025**: El sistema DEBE entregar el precio de venta y el precio congelado de las líneas solo al administrador y al recepcionista. El mecánico NO DEBE recibir ningún precio de refacción. De cada refacción recibe todos los campos que no son importes: nombre, código, categoría, marca, existencia, stock mínimo, stock bajo y si está activa.
- **FR-026**: Las restricciones de FR-024 y FR-025 DEBEN validarse en el servidor y aplican solo a los precios de refacciones. El mecánico DEBE poder seguir buscando refacciones y agregándolas a las órdenes que tiene asignadas, y DEBE seguir capturando y viendo el precio de la mano de obra de sus servicios, como hoy.
- **FR-034**: El mecánico NO DEBE recibir el total de la orden, el subtotal de refacciones ni ningún importe del que se pueda deducir un precio de refacción, en ninguna respuesta del servidor. Hoy ya no los recibe; el requisito es que siga así. Sí recibe la mano de obra de sus servicios (FR-026).
- **FR-035**: El mecánico NO DEBE tener acceso a pagos, tickets ni al panel de control, como hoy; el sistema DEBE rechazarlo por permisos, validándolo en el servidor.
- **FR-036**: Ningún precio restringido para un rol DEBE salir por filtros, búsquedas, ordenamientos, mensajes de error ni registros del servidor.

**No regresión**

- **FR-027**: El panel de control y los listados de órdenes y de pagos DEBEN seguir funcionando, y todo importe que muestren DEBE coincidir al centavo con el total calculado según FR-008.
- **FR-028**: El uso de una refacción en una orden DEBE seguir reflejando su salida de inventario, y el stock NO DEBE quedar negativo (RN-7, RN-8).

**Entregables del sprint**

- **FR-029**: Los datos de ejemplo DEBEN actualizarse para incluir refacciones con precios, al menos una orden cobrable con refacciones a precio congelado y su pago y ticket con copia guardada, de modo que el flujo demostrable se pueda recorrer al arrancar sin capturar datos a mano. Volver a cargarlos NO DEBE duplicar registros.
- **FR-030**: DEBEN existir pruebas automatizadas que pasen y cubran: el cálculo del total en centavos, el precio congelado, el redondeo al centavo, los topes, la regla del precio de venta obligatorio, los permisos y precios por rol, la concurrencia del pago, la cancelación del pago pendiente desfasado con su motivo, el vencimiento de las preferencias nuevas de Mercado Pago, la copia y versión de los tickets (nuevos, de formato anterior y con desglose que no coincide), los tickets por pago y la marca «pago anulado», las validaciones del precio de la mano de obra, la exposición indirecta de precios (FR-034 a FR-036) y la inmovilización de FR-021 y FR-022.
- **FR-031**: La documentación desfasada sobre el total, los precios y la visibilidad por rol DEBE actualizarse en el mismo sprint, incluido `docs/project-context.md` (principio I de la constitución).

### Reglas de negocio aplicables

- **RN-6**: Las refacciones utilizadas deben estar relacionadas con una orden.
- **RN-7**: El uso de una refacción debe generar o reflejar una salida de inventario.
- **RN-8**: No permitir stock negativo.
- **RN-9**: Una orden entregada debe conservarse como historial.
- **RN-13**: Todo pago debe estar relacionado con una orden.
- **RN-14**: Los datos sensibles del procesamiento de pagos no deben almacenarse en la aplicación.
- **RN-15**: Los permisos deben validarse en backend.

### Entidades clave *(incluido porque la funcionalidad implica datos)*

- **Refacción (catálogo)**: pieza del inventario con código, nombre, categoría (texto libre, obligatoria), marca (texto libre, opcional), existencia, stock mínimo, indicador de stock bajo, si está activa, precio de compra y precio de venta vigente (tope 999,999.99). El precio de compra solo lo recibe el administrador; el de venta, el administrador y recepción.
- **Línea de refacción de la orden**: uso de una refacción en una orden de servicio, con descripción, cantidad y el precio de venta congelado al agregarla (o al migrar, para las líneas anteriores). Su importe es cantidad por precio congelado. Las líneas de texto libre, sin refacción del catálogo, valen 0.
- **Servicio y mano de obra**: trabajo registrado en la orden; el servicio guarda la descripción y su mano de obra guarda el precio que suma al total (opcional, con las mismas validaciones y el mismo tope de 999,999.99 que los precios de refacciones).
- **Orden de servicio**: agrupa servicios y refacciones; su total es mano de obra más refacciones a precio congelado, sin pasar de 99,999,999.99. Su estado (`TERMINADO`, `ENTREGADO`) y la existencia de un pago `PAGADO` no anulado determinan si su contenido puede cambiar.
- **Pago**: cobro de una orden por su total, con método y estado (`PENDIENTE`, `PAGADO`, `RECHAZADO`, `CANCELADO`, `ANULADO`). **Pago vigente** = un pago en estado `PENDIENTE` o `PAGADO`; una orden tiene como máximo un pago vigente (FR-014). Un pago pendiente cuyo importe ya no coincide con el total se cancela al intentar confirmarlo, con el motivo «importe desfasado».
- **Ticket**: comprobante de un pago `PAGADO`. **Ticket vigente** = el ticket del pago `PAGADO` no anulado de la orden (FR-033). Hay un ticket por cada pago `PAGADO`, así que una orden puede tener varios, y el vigente es el del pago no anulado. Guarda una copia de su contenido (desglose de servicios y refacciones, subtotal y total) con un número de versión de formato; los tickets anteriores al sprint llevan la marca «formato anterior» y, si su desglose no suma lo cobrado, conservan el importe pagado como total con una nota visible. La marca «pago anulado» no se guarda en la copia: se toma del estado actual del pago al consultarlo.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: En el 100 % de las pruebas en que se cambia el precio del catálogo después de agregar una refacción a una orden, el importe de la línea y el total de la orden quedan iguales que antes del cambio.
- **SC-002**: Ningún pago ni ticket emitido cambia su importe ni su contenido después de un cambio de precio del catálogo. El conjunto de referencia es: los tickets del seed 004 (`T000001-2026` y `T000002-2026`, formato anterior), los tickets del seed 005 y los tickets que crean las pruebas. Se mide en las pruebas de integración de tickets por pago (comparando cada ticket antes y después de cambiar el precio de sus refacciones) y en la prueba de los datos de ejemplo.
- **SC-003**: En el 100 % de los casos de prueba de cálculo, incluidos importes con centavos y órdenes con al menos 10 líneas, el total coincide al centavo con el cálculo hecho a mano.
- **SC-004**: El precio de compra aparece en 0 respuestas para mecánicos y recepcionistas; ningún precio de refacción, total de orden ni subtotal de refacciones aparece en las respuestas, mensajes de error o registros para mecánicos; el precio de venta aparece en el 100 % de las respuestas equivalentes para recepción y administración.
- **SC-005**: Ante dos solicitudes de pago simultáneas para la misma orden, exactamente una queda vigente, en el 100 % de las repeticiones de la prueba.
- **SC-006**: El flujo demostrable completo (pasos 1 a 9) se recorre de principio a fin con los datos de ejemplo, sin capturar datos a mano, en menos de 10 minutos.
- **SC-007**: El 100 % de las pruebas automatizadas existentes antes del sprint (línea base: 49 suites y 411 pruebas del backend) sigue pasando, junto con las nuevas.
- **SC-008**: El 100 % de las líneas sin precio muestran la advertencia «sin precio registrado» en el ticket.
- **SC-009**: El 100 % de los intentos de agregar o quitar servicios en órdenes `TERMINADO` con un pago `PAGADO` se rechazan con un mensaje claro, y el 100 % de los intentos equivalentes se permiten cuando el pago de la orden está `PENDIENTE`, `RECHAZADO`, `CANCELADO` o `ANULADO`, o cuando no hay pago.
- **SC-010**: El 100 % de los intentos de confirmar un pago pendiente con importe desfasado terminan con la confirmación rechazada y el pago cancelado con el motivo «importe desfasado», y la orden admite un pago nuevo por el total correcto.
- **SC-011**: Tras la migración, el 100 % de las líneas de refacción del catálogo con precio de venta quedan con un precio congelado igual al precio vigente al migrar, y el 100 % de las que no tienen precio quedan en 0 con «sin precio registrado».
- **SC-012**: Tras la migración, el 100 % de los tickets anteriores al sprint tienen copia marcada «formato anterior» y su total es igual al importe de su pago.
- **SC-013**: En el 100 % de las órdenes con un pago anulado y un pago nuevo, cada pago `PAGADO` tiene su propio ticket, el ticket vigente es el del pago no anulado y el ticket del pago anulado se muestra con la marca «pago anulado».
- **SC-014**: El 100 % de las preferencias de Mercado Pago creadas después del sprint se envían con un vencimiento igual al plazo configurado (24 horas por defecto) contado desde su creación.
- **SC-015**: En el 100 % de las órdenes `TERMINADO` cuyo pago `PAGADO` se anuló, el paso a `ENTREGADO` se rechaza mientras no exista un pago `PAGADO` nuevo, y se permite una vez registrado ese pago nuevo.

## Supuestos

- La categoría, la marca y los precios de compra y de venta ya existen en el catálogo desde el Sprint 3, y el Sprint 4 ya suma las refacciones al total. Este sprint corrige y completa ese comportamiento; no agrega esos campos desde cero.
- Los importes se siguen guardando con el formato actual de dos decimales; el cálculo en centavos enteros (D-08) es la forma de operar con ellos. El tope del total (99,999,999.99) es el máximo que cabe en ese formato.
- Hoy la cantidad de una línea de refacción es un número entero, así que su importe siempre es exacto al centavo; la regla de redondeo hacia arriba desde 0.5 aplica si en el futuro la cantidad admite decimales.
- Hoy no se pueden crear líneas de texto libre nuevas; las que existen vienen de datos anteriores (Sprint 2). FR-005 conserva su comportamiento.
- Al migrar (FR-010), una línea cuya refacción del catálogo no tenga precio de venta queda sin precio congelado: vale 0 y muestra «sin precio registrado», que es lo mismo que el sistema hace hoy con ella. A partir del sprint ya no se pueden agregar líneas así (FR-005).
- D-03 se decidió para las órdenes abiertas. FR-010 lo extiende a todas las líneas existentes, incluidas las de órdenes `TERMINADO` y `ENTREGADO`, porque el precio vigente es el mismo valor que el sistema usa hoy para ellas; sus tickets ya emitidos se conservan con la copia de FR-020.
- La copia de los tickets anteriores (FR-020) refleja el desglose que el sistema muestra para ellos en el momento de la migración, que es la mejor información histórica disponible; el total de la copia siempre es el importe pagado. En la base local de desarrollo ya existe un caso con diferencia (orden 5: pagado 1390.00, calculado 1090.00), así que la nota de FR-020 se ejercitará con datos reales.
- Hoy existe una restricción de un ticket por orden y, tras anular y volver a cobrar, el sistema devuelve el ticket viejo ligado al pago anulado. FR-033 corrige este comportamiento en este sprint.
- Hoy el mecánico no recibe el total de la orden ni el subtotal de refacciones, y no tiene acceso a pagos, tickets ni panel de control; FR-034 y FR-035 conservan ese comportamiento como requisito.
- Hoy el precio de la mano de obra solo rechaza valores negativos; FR-032 agrega la validación de decimales y el tope.
- El diagnóstico y las recomendaciones de la orden no aparecen en el ticket; este sprint no cambia cuándo pueden editarse.
- Las refacciones ya se rechazan hoy en toda orden `TERMINADO`; FR-021 solo agrega el bloqueo de servicios y mano de obra cuando hay un pago `PAGADO`. Por eso, en una orden `TERMINADO` la corrección de una línea (FR-011) ya no es posible, aunque se anule el pago.
- La anulación de un pago `PAGADO` existe desde el Sprint 4 (solo administración, con motivo) y no es un reembolso; los reembolsos siguen fuera de alcance.
- **Riesgo (D-04)**: si Mercado Pago ya le cobró al cliente el importe anterior y el sistema cancela ese pago por importe desfasado (FR-016), la devolución de ese dinero queda fuera del sistema, porque los reembolsos están fuera de alcance. El taller tendría que resolverla por fuera del sistema, en el panel del proveedor. El riesgo crece porque hoy no hay webhook de Mercado Pago, la confirmación es manual y la preferencia se crea sin expiración, así que el enlace de un pago cancelado sigue vivo en el proveedor. Antes de generar un pago nuevo, recepción debe revisar en el panel de Mercado Pago si el cliente ya pagó. Si conviene ponerle expiración a las preferencias nuevas se decide en `/speckit-plan`.
- Una orden `TERMINADO` solo puede pasar a `ENTREGADO`; no existe hoy una transición para reabrirla.
- El vencimiento de las preferencias de Mercado Pago (FR-037) se verificó en la documentación oficial de Brasil. La de México no se pudo verificar (sus páginas respondieron 404); se confirma con una prueba manual en sandbox que hace el responsable durante la implementación. No hay una forma documentada de desactivar una preferencia ya creada, así que los enlaces creados antes del sprint no vencen.
- **Limitación conocida (cambio de rol)**: si un administrador cambia el rol de un usuario con la sesión abierta, el servidor aplica el rol nuevo desde la siguiente petición, pero Flutter sigue mostrando la interfaz del rol anterior hasta que la persona vuelva a iniciar sesión. Los precios siguen protegidos, porque el servidor decide qué campos envía según el rol actual.
- Los roles siguen siendo ADMIN, RECEPTIONIST y MECHANIC; el mecánico solo opera las órdenes que tiene asignadas, y hoy solo el administrador y el mecánico pueden agregar servicios con su mano de obra.
- Las restricciones técnicas heredadas de la sección 10 del insumo (organización del servidor, base local de pruebas, migraciones aditivas y numeradas, datos de ejemplo idempotentes, idioma y sistema de diseño) se trasladan sin cambios a `/speckit-plan`.

## Fuera de alcance

- Costeo, margen de ganancia, utilidad y reportes financieros (Sprint 7).
- Impuestos y facturación electrónica.
- Descuentos, promociones y pagos parciales o a plazos.
- Reembolsos dentro del sistema.
- Catálogo de proveedores y órdenes de compra.
- Catálogo administrable de categorías o marcas (D-06).
- Edición directa del precio de una línea de la orden (D-05).
- Bitácora de quién y cuándo cambió un precio del catálogo.
- Webhooks de Mercado Pago (la confirmación sigue siendo manual).
- Desactivar o hacer vencer en Mercado Pago una preferencia ya creada, incluidas las anteriores al sprint.
- Cierre automático de las sesiones abiertas de un usuario cuando cambia su rol (limitación conocida en «Supuestos»).
- Notificaciones, reportes, configuración del taller y WhatsApp (Sprints 6 a 9).
- Fotos del vehículo y puesta en producción (Sprint 10).

## Trazabilidad

| Criterio del insumo | Requisitos | Criterios de éxito |
|---|---|---|
| CA-1 Registro y edición de categoría, marca y precios | FR-001, FR-002 | SC-006 |
| CA-2 Validación de precios (negativos, no numéricos, dos decimales, topes) | FR-003, FR-004, FR-032 | SC-007 |
| CA-3 Precio congelado en la línea | FR-005, FR-006, FR-007, FR-010, FR-011 | SC-001, SC-011 |
| CA-4 Total = mano de obra + refacciones congeladas, en centavos | FR-008, FR-009, FR-012 | SC-003 |
| CA-5 Pago por el total; importe distinto se rechaza | FR-013 | SC-006 |
| CA-6 Pagos y tickets anteriores sin cambios | FR-019, FR-020, FR-033 | SC-002, SC-012, SC-013 |
| CA-7 Ticket con desglose de refacciones y advertencia de precio | FR-017, FR-018 | SC-008 |
| CA-8 Un solo pago vigente, concurrencia, sin datos de tarjeta | FR-014 | SC-005 |
| CA-9 Mercado Pago con refacciones; pendiente desfasado; vencimiento de preferencias | FR-015, FR-016, FR-037 | SC-010, SC-014 |
| CA-10 Precios de refacción según el rol, validado en servidor | FR-024, FR-025, FR-026, FR-034, FR-035, FR-036 | SC-004 |
| CA-11 Panel y listados sin romperse, importes al centavo | FR-027 | SC-007 |
| CA-12 Datos de ejemplo actualizados e idempotentes | FR-029 | SC-006 |
| CA-13 Pruebas del total, instantáneas, redondeo, permisos, concurrencia y compatibilidad | FR-030 | SC-007 |
| CA-14 Documentación actualizada | FR-031 | — |
| H-15 Inmovilización de órdenes `TERMINADO` pagadas | FR-021, FR-022, FR-023 | SC-009, SC-015 |

| Historia | Requisitos |
|---|---|
| US1 | FR-001 a FR-005, FR-032 |
| US2 | FR-006 a FR-012 |
| US3 | FR-013 a FR-018, FR-037 |
| US4 | FR-019 a FR-023, FR-033 |
| US5 | FR-024 a FR-026, FR-034 a FR-036 |
