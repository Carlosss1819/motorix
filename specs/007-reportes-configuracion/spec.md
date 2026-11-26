# Especificación de la Funcionalidad: Reportes y configuración del taller

**Rama de la funcionalidad**: `007-reportes-configuracion`

**Fecha de creación**: 2026-11-26

**Estado**: Borrador (aclarado el 2026-11-26)

**Input**: Descripción del usuario: "Sprint 7 de Motorix: reportes y configuración del taller. Insumo corregido en `docs/sprints/sprint-7-reportes-configuracion.md` (incluye la sección 11 de verificación). Carpeta: `specs/007-reportes-configuracion`."

> **Gobernanza**: el Sprint 7 está dentro del alcance oficial posterior al MVP por la enmienda 1.1.0 de la constitución (principio I: sprints 5, 6 y 7, en orden; el aviso de privacidad visible en la app es parte del alcance). El Sprint 6 está cerrado (commit `c07f962`). No requiere enmienda.

> **Correcciones del insumo**: ya aplicadas en el propio insumo (sección 11, puntos a–i y hallazgos H-S7-01 a H-S7-09). Esta spec parte del insumo corregido.

## Clarifications

### Session 2026-11-26

Respuestas de Carlos (responsable del sprint) a las decisiones de la sección 9 del insumo:

- Q: ¿En qué formato se exportan los reportes? → A: CSV en UTF-8 con BOM, sin librerías nuevas. (FR-037)
- Q: ¿Cómo se divide el sprint si el tiempo no alcanza? → A: Entrega A = US1, US2, US3, US8, US9, US10; Entrega B = US4 a US7 (reportes). La A va primero. (Escenarios)
- Q: ¿Se guardan los datos del taller en cada ticket emitido? → A: Sí, dentro de la copia que el ticket ya guarda desde el Sprint 5 (`FORMATO_ACTUAL = 2`); los tickets anteriores no cambian. Verificado en `server/services/ticket.service.js` (la copia ya incluye `taller`). (FR-002)
- Q: ¿Se enlaza el tipo de servicio a las líneas de la orden? → A: Columna opcional del tipo en las líneas de servicio (vacía por defecto); las líneas existentes quedan sin tipo y no se tocan. (FR-010)
- Q: ¿Cómo se calcula el margen si la refacción no tiene precio de compra? → A: "Sin costo registrado" y no entra al margen total. (FR-035)
- Q: ¿Qué periodos tienen los reportes? → A: Rango libre con atajos (hoy, semana, mes), hora de Ciudad de México (America/Mexico_City), máximo 1 año. (FR-031)
- Q: ¿Cómo se mide la productividad por mecánico? → A: Órdenes terminadas e importe de mano de obra. (FR-034)
- Q: ¿Cómo se calcula la rotación? → A: Unidades que salieron en el periodo / existencia actual; si la existencia es 0, "sin existencia". (FR-036)
- Q: ¿Quién ve reportes y configuración? → A: Solo ADMIN (403 para los demás). El mecánico sigue sin ver importes. (FR-006, FR-038)
- Q: ¿Quién redacta los términos, cómo se publican y cuándo se aceptan? → A: En español, breves, plantilla para un responsable ficticio ("Taller Motorix"); el aviso incluye los elementos mínimos de la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (identidad y domicilio del responsable, datos recabados, finalidades, medios para derechos ARCO y revocación del consentimiento, transferencias, cambios al aviso) y una nota visible de "plantilla académica". Se publican con migración/seed; ADMIN consulta la versión vigente y las aceptaciones, no las edita. Una aceptación por versión; los usuarios existentes aceptan en su siguiente inicio de sesión. (FR-014 a FR-021)
- Q: ¿Qué registra la bitácora y cuánto se conserva? → A: Las acciones de CA-20, sin borrado automático, paginada con filtros (fecha, usuario, acción), sin exportación. (FR-022 a FR-024)
- Q: ¿Cambia la política de contraseñas? → A: Se mantiene la actual; no se obliga a cambiar la de los usuarios sembrados. (FR-026)
- Q: ¿Cuánto dura la inactividad? → A: 30 minutos para todos los roles. (FR-027)
- Q: ¿Cómo se evita que las pruebas existentes fallen por la aceptación obligatoria? → A: El helper de pruebas deja a los usuarios de prueba con la aceptación vigente. (FR-020, SC-009)
- Q: ¿Qué ids usan los seeds del sprint? → A: 70001 a 70099, idempotentes. (FR-040)

Decisiones tomadas por el agente (opción más simple que cumple el insumo):

- Q: ¿Qué cuenta como "pago cancelado" en la bitácora? → A: Tanto `ANULADO` (anulación de ADMIN) como `CANCELADO` (cobro rechazado o desfasado); son dos acciones distintas. (FR-022, H-S7-03)
- Q: ¿El margen global de "Próximo" cambia los mantenimientos ya registrados? → A: No: es la antelación por defecto de los registros nuevos; cada registro conserva la suya. (FR-005, H-S7-01)
- Q: ¿De dónde salen la fecha y el kilometraje base del próximo servicio del ticket? → A: Fecha de emisión del ticket y kilometraje de entrada de la orden. (FR-012)
- Q: ¿Cambia la versión de formato del ticket? → A: No; el próximo servicio es un campo opcional de la copia v2 (ausente en los tickets anteriores). (FR-012, FR-013)
- Q: ¿Qué recibe el usuario con aceptación pendiente si llama a la API? → A: `403` con código `TERMINOS_PENDIENTES`, salvo ver términos, aceptar, consultar su sesión y cerrar sesión. (FR-020)
- Q: ¿Qué fecha define el periodo de cada reporte? → A: Ingresos: fecha de registro de los pagos que están en `PAGADO` (la tabla `payments` no guarda fecha de aprobación; analyze I1); servicios, margen y productividad: órdenes que pasaron a `TERMINADO` en el rango; rotación: movimientos de salida del rango. (FR-032 a FR-036)
- Q: ¿Quién consulta la lista de tipos de servicio activos? → A: Los tres roles (para registrar servicios y mantenimientos); escribir el catálogo es solo de ADMIN. (FR-009)
- Q: ¿Cómo se maneja la edición simultánea de la configuración? → A: Gana el último guardado; ambos cambios quedan en la bitácora. (Casos límite)

## Escenarios de usuario y pruebas *(obligatorio)*

El sprint se entrega en dos partes: la **Entrega A** (US1, US2, US3, US8, US9, US10: configuración, catálogo, ticket, términos y seguridad) y la **Entrega B** (US4 a US7: reportes y exportación). La Entrega A va primero.

### Historia de usuario 1 - Datos del taller editables (Prioridad: P1) — Entrega A

Como administrador, quiero editar el nombre, la dirección y el teléfono del taller para que el ticket muestre datos correctos sin tocar el servidor.

**Por qué esta prioridad**: hoy los datos del taller están fijos en el código; cualquier ticket emitido muestra datos de ejemplo.

**Prueba independiente**: el administrador cambia el nombre del taller, emite un ticket nuevo y el ticket muestra el nombre nuevo; un ticket anterior conserva el nombre con el que se emitió.

**Escenarios de aceptación**:

1. **Dado** que el administrador abre Configuración, **Cuando** cambia nombre, dirección y teléfono y guarda, **Entonces** el sistema confirma el cambio y los datos quedan guardados.
2. **Dado** un ticket emitido antes del cambio, **Cuando** se consulta después del cambio, **Entonces** muestra los datos del taller con los que se emitió.
3. **Dado** un pago aprobado después del cambio, **Cuando** se genera su ticket, **Entonces** el ticket muestra los datos nuevos.
4. **Dado** que nunca se ha guardado la configuración, **Cuando** se genera un ticket, **Entonces** usa los datos de respaldo del sistema.
5. **Dado** un recepcionista o mecánico, **Cuando** intenta consultar o modificar la configuración, **Entonces** el sistema lo rechaza por falta de permiso.

---

### Historia de usuario 2 - Márgenes de "Próximo" del mantenimiento (Prioridad: P1) — Entrega A

Como administrador, quiero ajustar los márgenes de "Próximo" del mantenimiento para adaptarlos a la operación del taller.

**Por qué esta prioridad**: los márgenes (30 días y 500 km) están fijos en el código.

**Prueba independiente**: el administrador cambia el margen a 15 días; un mantenimiento nuevo registrado sin antelación propia toma 15 días como antelación; los registros existentes conservan la suya.

**Escenarios de aceptación**:

1. **Dado** que el administrador abre Configuración, **Cuando** cambia los márgenes a valores válidos y guarda, **Entonces** se guardan y los mantenimientos nuevos los usan como antelación por defecto.
2. **Dado** un valor fuera de límites (0, negativo, no entero o mayor al máximo), **Cuando** intenta guardarlo, **Entonces** el sistema lo rechaza con un mensaje claro.
3. **Dado** que no hay márgenes guardados, **Cuando** se registra un mantenimiento sin antelación, **Entonces** se usan 30 días y 500 km.
4. **Dado** mantenimientos existentes con su propia antelación, **Cuando** cambia el margen global, **Entonces** su estado (Normal, Próximo, Vencido) no cambia.

---

### Historia de usuario 3 - Catálogo de tipos de servicio con intervalo (Prioridad: P1) — Entrega A

Como administrador, quiero mantener un catálogo de tipos de servicio con su intervalo en días y en kilómetros para que el próximo mantenimiento se proponga sin asumir intervalos universales.

**Por qué esta prioridad**: es la base de la propuesta del próximo mantenimiento (RN-11, RN-12) y del próximo servicio en el ticket (US8).

**Prueba independiente**: el administrador crea "Cambio de aceite" con 180 días y 5,000 km; al registrar un mantenimiento eligiendo ese tipo, se proponen la fecha y el kilometraje objetivo y se pueden corregir.

**Escenarios de aceptación**:

1. **Dado** el catálogo, **Cuando** el administrador crea un tipo con nombre único e intervalo en días, en kilómetros o ambos, **Entonces** queda activo.
2. **Dado** un tipo existente, **Cuando** el administrador lo edita, **Entonces** se guardan los cambios; los mantenimientos ya registrados no cambian.
3. **Dado** un tipo usado en órdenes, **Cuando** el administrador lo desactiva, **Entonces** deja de ofrecerse en las listas, pero las órdenes que lo usan lo conservan; no se puede borrar.
4. **Dado** un tipo sin ningún intervalo, **Cuando** se intenta guardar, **Entonces** se rechaza: debe tener al menos un intervalo.
5. **Dado** un nombre repetido (sin distinguir mayúsculas), **Cuando** se intenta guardar, **Entonces** se rechaza por duplicado.
6. **Dado** que se registra un mantenimiento eligiendo un tipo con intervalo, **Cuando** se abre el formulario, **Entonces** se proponen intervalo, fecha objetivo (hoy + días) y kilometraje objetivo (kilometraje actual del vehículo + km), y el usuario puede corregirlos antes de guardar.
7. **Dado** que se agrega un servicio a una orden, **Cuando** se elige un tipo del catálogo, **Entonces** la línea queda enlazada al tipo; también se puede agregar una línea de texto libre sin tipo, como hasta ahora.

---

### Historia de usuario 8 - Próximo servicio en el ticket (Prioridad: P2) — Entrega A

Como cliente, quiero que mi ticket indique cuándo toca mi próximo servicio para recordarlo sin que nadie me escriba.

**Por qué esta prioridad**: aprovecha el catálogo de US3 sin trabajo adicional del personal. El cliente no es usuario del sistema: recibe el ticket impreso o en pantalla (H-S7-06).

**Prueba independiente**: una orden con una línea "Cambio de aceite" (180 días y 5,000 km) se paga; el ticket nuevo muestra "Próximo servicio: Cambio de aceite — fecha y kilometraje"; una orden sin tipos con intervalo no muestra la línea.

**Escenarios de aceptación**:

1. **Dado** una orden con al menos una línea enlazada a un tipo con intervalo, **Cuando** se emite su ticket, **Entonces** el ticket muestra el próximo servicio por tipo: fecha (fecha de emisión + días) y/o kilometraje (kilometraje de entrada + km).
2. **Dado** una orden sin líneas con tipo de servicio, **Cuando** se emite su ticket, **Entonces** no aparece la sección de próximo servicio.
3. **Dado** un ticket emitido antes de este sprint, **Cuando** se consulta, **Entonces** se ve igual que antes, sin próximo servicio.

---

### Historia de usuario 9 - Términos, condiciones y aviso de privacidad (Prioridad: P1) — Entrega A

Como usuario del taller, quiero leer y aceptar los términos y condiciones y el aviso de privacidad al ingresar al sistema para conocer las reglas de uso y cómo se protege la información de los clientes.

**Por qué esta prioridad**: el aviso de privacidad visible en la app es parte del alcance oficial (enmienda 1.1.0).

**Prueba independiente**: un usuario sin aceptación vigente inicia sesión, ve la pantalla de aceptación, no puede usar ninguna otra función hasta aceptar; al aceptar queda registrada la versión, la fecha y el usuario; en el siguiente inicio ya no se le pide.

**Escenarios de aceptación**:

1. **Dado** un usuario sin aceptación de la versión vigente, **Cuando** inicia sesión, **Entonces** ve los términos y el aviso de privacidad antes de cualquier otra pantalla.
2. **Dado** esa pantalla, **Cuando** el usuario rechaza, **Entonces** la sesión se cierra y vuelve al inicio de sesión.
3. **Dado** esa pantalla, **Cuando** el usuario acepta, **Entonces** se guarda usuario, versión y fecha y entra al sistema.
4. **Dado** un usuario que ya aceptó la versión vigente, **Cuando** inicia sesión, **Entonces** no se le vuelve a pedir.
5. **Dado** que se publica una versión nueva, **Cuando** el usuario inicia sesión, **Entonces** se le pide aceptar de nuevo.
6. **Dado** un usuario sin aceptación vigente con una sesión abierta, **Cuando** intenta cualquier operación distinta de ver los términos, aceptar o cerrar sesión, **Entonces** el backend la rechaza.
7. **Dado** el administrador, **Cuando** consulta Términos, **Entonces** ve la versión vigente con su fecha y la lista de aceptaciones (usuario, versión, fecha); no puede editar el texto.

---

### Historia de usuario 10 - Protección de la información (Prioridad: P1) — Entrega A

Como administrador, quiero que la información del sistema esté protegida (bitácora de acciones sensibles, política de contraseñas, cierre de sesión por inactividad y respuestas sin datos reservados) para detectar usos indebidos y proteger los datos del taller y de sus clientes.

**Por qué esta prioridad**: protege datos de clientes y pagos (principio IV).

**Prueba independiente**: tras un login fallido, un cambio de rol, un cambio de precio y una anulación de pago, el administrador abre la bitácora y ve cada acción con usuario y fecha, filtrando por fecha, usuario y acción.

**Escenarios de aceptación**:

1. **Dado** una acción sensible (ver FR-040), **Cuando** ocurre, **Entonces** queda en la bitácora con fecha, usuario (si lo hay), acción, entidad afectada y un detalle sin datos reservados.
2. **Dado** el administrador, **Cuando** abre la bitácora, **Entonces** ve las entradas paginadas de la más reciente a la más antigua y puede filtrar por rango de fechas, usuario y acción.
3. **Dado** cualquier usuario, **Cuando** intenta editar o borrar una entrada, **Entonces** no existe forma de hacerlo desde la aplicación.
4. **Dado** un recepcionista o mecánico, **Cuando** intenta consultar la bitácora, **Entonces** recibe un rechazo por permiso.
5. **Dado** una contraseña que no cumple la política, **Cuando** se crea un usuario o se cambia una contraseña, **Entonces** se rechaza con un mensaje claro.
6. **Dado** una sesión sin actividad por más de 30 minutos, **Cuando** el usuario intenta una operación, **Entonces** el backend la rechaza y la app regresa al inicio de sesión con un aviso.
7. **Dado** cualquier respuesta de usuarios, refacciones, órdenes, pagos y tickets, **Cuando** se revisa, **Entonces** no contiene hashes de contraseña, tokens ni precios reservados al rol.
8. **Dado** un texto de búsqueda con intentos de inyección, **Cuando** se envía a los buscadores, **Entonces** el sistema responde normalmente, sin errores internos ni datos ajenos.

---

### Historia de usuario 4 - Ingresos por periodo (Prioridad: P2) — Entrega B

Como administrador, quiero consultar los ingresos por periodo para conocer cómo avanza el taller.

**Prueba independiente**: con pagos aprobados en el mes, el reporte del mes muestra el total, el desglose por método y por día, y coincide con la suma de esos pagos.

**Escenarios de aceptación**:

1. **Dado** un rango de fechas válido, **Cuando** el administrador consulta, **Entonces** ve el total cobrado (solo pagos aprobados), el número de pagos, el desglose por método y por día.
2. **Dado** un pago anulado o cancelado en el rango, **Cuando** se consulta, **Entonces** no suma en los ingresos.
3. **Dado** un rango mayor a un año o con inicio posterior al fin, **Cuando** se consulta, **Entonces** se rechaza con un mensaje claro.
4. **Dado** los atajos hoy, semana y mes, **Cuando** se eligen, **Entonces** el rango se calcula en la hora de Ciudad de México.

---

### Historia de usuario 5 - Servicios frecuentes y productividad (Prioridad: P2) — Entrega B

Como administrador, quiero ver los servicios más frecuentes y la productividad por mecánico para tomar decisiones de operación.

**Escenarios de aceptación**:

1. **Dado** un rango, **Cuando** se consulta, **Entonces** se listan los servicios más frecuentes de las órdenes terminadas en el periodo, agrupados por tipo de servicio (y las líneas sin tipo agrupadas por descripción), con número de veces e importe de mano de obra.
2. **Dado** un rango, **Cuando** se consulta la productividad, **Entonces** cada mecánico muestra las órdenes que pasaron a terminado en el periodo y el importe de mano de obra de esas órdenes.

---

### Historia de usuario 6 - Margen de refacciones y rotación (Prioridad: P2) — Entrega B

Como administrador, quiero ver el costo, el precio y el margen de las refacciones usadas y la rotación del inventario para controlar la rentabilidad.

**Escenarios de aceptación**:

1. **Dado** refacciones usadas en órdenes terminadas en el periodo, **Cuando** se consulta, **Entonces** cada refacción muestra cantidad, costo (precio de compra), venta (precio congelado de la línea) y margen.
2. **Dado** una refacción sin precio de compra, **Cuando** se consulta, **Entonces** muestra "sin costo registrado" y no entra al margen total.
3. **Dado** un rango, **Cuando** se consulta la rotación, **Entonces** cada refacción muestra unidades que salieron en el periodo, existencia actual y rotación (salidas / existencia); si la existencia es 0, "sin existencia".

---

### Historia de usuario 7 - Exportación de reportes (Prioridad: P3) — Entrega B

Como administrador, quiero exportar cada reporte para compartirlo o archivarlo.

**Escenarios de aceptación**:

1. **Dado** un reporte en pantalla, **Cuando** el administrador lo exporta, **Entonces** obtiene un archivo con las mismas filas y cifras que la pantalla y el mismo rango.
2. **Dado** textos con acentos o eñes, **Cuando** se abre el archivo en una hoja de cálculo, **Entonces** se leen correctamente.

---

### Casos límite

- Configuración guardada a medias (solo el nombre): los campos no guardados usan el respaldo.
- Dos administradores guardan la configuración a la vez: gana el último y ambos cambios quedan en la bitácora.
- Un tipo de servicio desactivado sigue apareciendo en las órdenes que ya lo usan y en el ticket emitido.
- Una orden con dos líneas del mismo tipo: el ticket muestra un solo próximo servicio por tipo.
- Un tipo solo con días (o solo con km): el ticket muestra solo la fecha (o solo el kilometraje).
- El usuario cierra la app en la pantalla de términos sin aceptar ni rechazar: sigue sin aceptación; el siguiente inicio la vuelve a pedir.
- Usuario creado después de publicarse la versión vigente: también debe aceptarla en su primer inicio.
- Login fallido con un usuario inexistente: se registra en la bitácora con el identificador recortado, sin la contraseña.
- Reporte de un rango sin datos: muestra ceros y listas vacías, no un error.
- Pago aprobado en el último minuto del día en Ciudad de México: cuenta para ese día.

## Requisitos *(obligatorio)*

### Requisitos funcionales

**Configuración (US1, US2)**

- **FR-001**: El sistema DEBE permitir al administrador consultar y modificar el nombre (1 a 120 caracteres), la dirección (1 a 200) y el teléfono (1 a 30) del taller.
- **FR-002**: Los tickets emitidos después de un cambio DEBEN usar los datos vigentes al momento de emitirse; los ya emitidos NO cambian (conservan su copia).
- **FR-003**: Si un dato del taller no está guardado, el sistema DEBE usar el valor de respaldo del sistema (los datos fijos actuales).
- **FR-004**: El sistema DEBE permitir al administrador modificar los márgenes de "Próximo": días (entero de 1 a 365) y kilómetros (entero de 1 a 50,000).
- **FR-005**: Los márgenes guardados DEBEN usarse como antelación por defecto de los mantenimientos nuevos que no indiquen la suya; sin valor guardado, 30 días y 500 km. Los mantenimientos existentes conservan su antelación (H-S7-01).
- **FR-006**: Consultar y modificar la configuración DEBE ser exclusivo de ADMIN, validado en backend; los demás roles reciben 403.

**Catálogo de tipos de servicio (US3)**

- **FR-007**: El administrador DEBE poder crear, editar, activar y desactivar tipos de servicio con nombre (único sin distinguir mayúsculas, 1 a 120 caracteres), intervalo en días (opcional, entero 1 a 3,650) e intervalo en km (opcional, entero 1 a 500,000); al menos un intervalo es obligatorio.
- **FR-008**: Los tipos NO se borran; desactivar los oculta de las listas de selección sin afectar órdenes ni mantenimientos existentes.
- **FR-009**: La lista de tipos activos DEBE poder consultarla cualquier rol autenticado (para registrar servicios y mantenimientos); crear, editar y desactivar es exclusivo de ADMIN.
- **FR-010**: Las líneas de servicio de una orden PUEDEN enlazarse opcionalmente a un tipo de servicio activo; las líneas existentes quedan sin tipo y no se modifican.
- **FR-011**: Al registrar un mantenimiento eligiendo un tipo del catálogo, el sistema DEBE proponer el intervalo del tipo, la fecha objetivo (hoy + días) y el kilometraje objetivo (kilometraje actual + km); el usuario PUEDE corregirlos antes de guardar.

**Próximo servicio en el ticket (US8)**

- **FR-012**: Al emitir un ticket, el sistema DEBE incluir en su copia el próximo servicio por cada tipo con intervalo enlazado a la orden (sin repetir tipos): nombre, fecha (fecha de emisión + días) y/o kilometraje (kilometraje de entrada + km).
- **FR-013**: Si la orden no tiene líneas con tipo con intervalo, el ticket NO muestra la sección. Los tickets anteriores se muestran sin cambios.

**Términos y aviso de privacidad (US9)**

- **FR-014**: El sistema DEBE guardar versiones de los términos y condiciones y del aviso de privacidad, con número de versión, fecha de publicación y texto; solo una versión es la vigente.
- **FR-015**: Los términos DEBEN describir el uso permitido del sistema, la confidencialidad de los datos de clientes y vehículos y la responsabilidad de las cuentas personales. El aviso de privacidad DEBE incluir los elementos mínimos de la ley mexicana de datos personales en posesión de particulares, y una nota visible de "plantilla académica".
- **FR-016**: La versión de los términos se publica con los scripts de datos del sistema (migración o seed); el administrador solo la consulta, no la edita desde la aplicación. Los usuarios existentes aceptan en su siguiente inicio de sesión.
- **FR-017**: Al iniciar sesión, la respuesta DEBE indicar si el usuario tiene pendiente aceptar la versión vigente; la app DEBE mostrar la pantalla de aceptación antes de cualquier otra.
- **FR-018**: Aceptar DEBE guardar usuario, versión y fecha; una sola aceptación por usuario y versión (repetir es idempotente).
- **FR-019**: Rechazar DEBE cerrar la sesión.
- **FR-020**: El backend DEBE rechazar (403 `TERMINOS_PENDIENTES`) toda operación de un usuario sin aceptación vigente, excepto ver los términos vigentes, aceptarlos, consultar su propia sesión y cerrar sesión. Las pruebas automatizadas dejan a sus usuarios con la aceptación vigente.
- **FR-021**: El administrador DEBE poder consultar la versión vigente y la lista paginada de aceptaciones.

**Seguridad (US10)**

- **FR-022**: La bitácora DEBE registrar como mínimo: inicio de sesión fallido, bloqueo de cuenta, alta de usuario, cambio de rol, activación o desactivación de usuario, cambio de configuración, alta/edición/desactivación de tipo de servicio, cambio de precio de compra o venta de una refacción, pago anulado, pago cancelado y aceptación de términos.
- **FR-023**: Cada entrada DEBE guardar fecha, usuario que actuó (o vacío si no hay sesión), acción, tipo y id de la entidad afectada y un detalle breve; NUNCA contraseñas, hashes, tokens ni datos de tarjeta.
- **FR-024**: La bitácora DEBE consultarla solo ADMIN, paginada, de la más reciente a la más antigua, con filtros por rango de fechas, usuario y acción; no hay edición, borrado ni exportación desde la aplicación, ni borrado automático.
- **FR-025**: Registrar una entrada de bitácora NO DEBE impedir la operación principal si la escritura de la bitácora falla; el fallo se registra en el servidor.
- **FR-026**: La política de contraseñas vigente (al menos 8 caracteres, una mayúscula, una minúscula y un número) DEBE aplicarse al crear usuarios y al cambiar la contraseña, con un mensaje claro; las contraseñas se guardan solo con hash. No se obliga a cambiar las contraseñas de los usuarios sembrados.
- **FR-027**: La sesión DEBE cerrarse tras 30 minutos de inactividad para todos los roles; el backend rechaza la operación y la app regresa al inicio de sesión con un aviso. La vigencia máxima del token se mantiene.
- **FR-028**: Ninguna respuesta de la API DEBE incluir el hash de contraseña, el token (salvo la respuesta del inicio de sesión) ni precios reservados al rol; DEBE haber pruebas en usuarios, refacciones, órdenes, pagos y tickets.
- **FR-029**: Las consultas DEBEN usar parámetros y las entradas validarse en backend; DEBE haber una prueba automática de intentos de inyección en los buscadores.
- **FR-030**: Las respuestas HTTP DEBEN incluir cabeceras de seguridad estándar.

**Reportes (US4 a US7) — Entrega B**

- **FR-031**: Los reportes DEBEN aceptar un rango libre de fechas (inicio y fin, máximo un año) con atajos hoy, semana y mes, en la hora de Ciudad de México.
- **FR-032**: Ingresos: total de los pagos en estado aprobado cuya fecha de registro cae en el rango, número de pagos, desglose por método y por día; los importes se suman en centavos enteros.
- **FR-033**: Servicios frecuentes: por tipo de servicio (o descripción, si la línea no tiene tipo), número de veces e importe de mano de obra, de las órdenes que pasaron a terminado en el rango.
- **FR-034**: Productividad: por mecánico asignado, número de órdenes que pasaron a terminado en el rango e importe de mano de obra de esas órdenes.
- **FR-035**: Margen de refacciones: por refacción usada en órdenes terminadas en el rango, cantidad, costo, venta y margen; sin precio de compra, "sin costo registrado" y fuera del margen total.
- **FR-036**: Rotación: por refacción, salidas del periodo, existencia actual y rotación; existencia 0 → "sin existencia".
- **FR-037**: Cada reporte DEBE poder exportarse en CSV (UTF-8 con BOM, para que la hoja de cálculo lea acentos y eñes) con el mismo contenido que la pantalla, sin librerías nuevas.
- **FR-038**: Reportes y exportaciones DEBEN ser exclusivos de ADMIN (403 para los demás); el mecánico sigue sin ver importes en ninguna parte.
- **FR-039**: Las listas de los reportes DEBEN limitarse o paginarse para responder en un tiempo razonable.

**Datos de ejemplo y documentación**

- **FR-040**: Los seeds del sprint DEBEN incluir configuración inicial, tipos de servicio, la versión vigente de los términos y datos suficientes para ver los reportes; son idempotentes y usan ids 70001 a 70099.
- **FR-041**: `docs/project-context.md` y `docs/design-system.md` DEBEN actualizarse con lo nuevo; los valores del código quedan documentados como respaldo.

### Entidades clave

- **Configuración del taller**: pares clave-valor (nombre, dirección, teléfono, margen de días, margen de km), con quién y cuándo los cambió.
- **Tipo de servicio**: nombre único, intervalo en días, intervalo en km, activo o inactivo.
- **Línea de servicio de la orden** (existente): se agrega el enlace opcional al tipo de servicio.
- **Versión de términos**: número de versión, fecha de publicación, texto de términos, texto del aviso de privacidad, vigente o no.
- **Aceptación de términos**: usuario, versión, fecha; única por usuario y versión.
- **Entrada de bitácora**: fecha, usuario, acción, tipo de entidad, id de entidad, detalle breve.
- **Ticket** (existente): su copia agrega, opcionalmente, el próximo servicio.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: El administrador cambia los datos del taller en menos de 1 minuto y el siguiente ticket los muestra; el 100 % de los tickets anteriores conserva sus datos.
- **SC-002**: Al registrar un mantenimiento con un tipo del catálogo, la fecha y el kilometraje objetivo aparecen propuestos sin capturarlos (0 cálculos manuales).
- **SC-003**: El 100 % de los tickets de órdenes con tipo con intervalo muestra el próximo servicio, y ninguno de los que no lo tienen.
- **SC-004**: Ningún usuario sin aceptación vigente puede completar una operación distinta de ver, aceptar o cerrar sesión (verificado por pruebas en backend).
- **SC-005**: El 100 % de las acciones sensibles listadas aparece en la bitácora, y ninguna entrada contiene contraseñas, hashes, tokens ni datos de tarjeta.
- **SC-006**: Tras 30 minutos sin actividad, la siguiente operación regresa al inicio de sesión.
- **SC-007**: Los importes de los reportes coinciden al centavo con los pagos y órdenes que los originan, y el archivo exportado coincide con la pantalla.
- **SC-008**: Los reportes de un año de datos de ejemplo se muestran en menos de 3 segundos.
- **SC-009**: Las suites existentes (79 suites y 649 pruebas del backend; 186 de Flutter) siguen pasando.

## Supuestos

- El cliente del taller no usa el sistema: US8 se cumple con el ticket (H-S7-06).
- Una versión nueva de los términos se publica con un script de datos posterior (H-S7-04).
- "Pago cancelado" incluye `ANULADO` y `CANCELADO` (H-S7-03).
- El kilometraje base del próximo servicio es el de entrada de la orden, y la fecha base la de emisión del ticket.
- Los datos del taller del ticket viven dentro de la copia que el ticket ya guarda (formato 2); el próximo servicio es un campo opcional de esa copia.
- La propuesta del próximo mantenimiento (FR-011) no crea registros sola: el usuario sigue guardando el mantenimiento.
- Los textos de términos y aviso son una plantilla para un responsable ficticio; el taller real los revisaría con quien corresponda (fuera de alcance del insumo, sección 8).
