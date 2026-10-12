# Especificación de la funcionalidad: Gestión de citas y órdenes de servicio

**Rama de la funcionalidad**: `002-citas-ordenes-servicio`

**Creada**: 2026-10-11

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa la descripcion de @docs/sprints/sprint-2-citas-ordenes.md"

## Clarifications

### Session 2026-10-11

- P: ¿En qué estado queda una orden de servicio recién creada? → R: `RECIBIDO` en todos los casos, sea sin cita o derivada de una cita; el avance a `DIAGNOSTICO` lo hace el mecánico.
- P: Cuando se marca una cita como recibida, ¿la orden se crea automáticamente? → R: No; solo se habilita la creación manual con el formulario precargado desde la cita (cliente, vehículo y motivo), y el recepcionista confirma o ajusta antes de generarla.
- P: ¿Quién puede realizar cada cambio de estado de la orden? → R: El mecánico asignado gestiona `DIAGNOSTICO → EN_REPARACION → TERMINADO` (y `ESPERANDO_REFACCION`); el recepcionista gestiona el ingreso (`RECIBIDO`, asignación de mecánico) y la entrega (`ENTREGADO`). El administrador puede realizar cualquier transición válida.
- P: ¿La orden debe tener mecánico asignado al crearse? → R: No; la asignación es opcional al alta y el recepcionista puede asignar o reasignar el mecánico después desde el detalle. Las órdenes sin asignar solo las ven recepción y administrador.
- P: ¿Hasta cuándo puede cancelar una cita el recepcionista y debe registrar un motivo? → R: Cancelación libre mientras la cita esté `PROGRAMADA`, en cualquier momento y sin motivo obligatorio; el motivo es opcional y, si se indica, queda guardado.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Crear y consultar órdenes de servicio con cliente y vehículo (Prioridad: P1)

Como recepcionista, quiero registrar una orden de servicio que asocie a un cliente y un vehículo, y consultarla después, para que el trabajo del taller quede documentado desde la llegada del vehículo.

**Por qué esta prioridad**: Es el corazón del sprint: sin orden no hay diagnóstico, ni servicios, ni cierre. Además, las órdenes solo existen si cliente y vehículo están correctamente asociados (RN-01, RN-02), por lo que esta historia absorbe la HU3 original ("asociar orden con cliente y vehículo") y es un MVP entregable por sí sola.

**Prueba independiente**: Se puede crear una orden con un cliente y vehículo ya existentes, verla en el listado y en su detalle, y comprobar que los datos asociados se muestran correctamente, sin intervención de citas ni del rol mecánico.

#### Escenarios de aceptación

1. **Dado** un cliente y un vehículo registrados, **cuando** el recepcionista crea una orden con motivo de visita y fecha, **entonces** la orden queda guardada con estado inicial `RECIBIDO`, se le asigna el cliente y el vehículo elegidos, y aparece en el listado de órdenes.
2. **Dado** el formulario de nueva orden vacío, **cuando** el recepcionista confirma el guardado sin motivo de visita, **entonces** se muestra un error que impide el guardado y la orden no se crea.
3. **Dado** una orden existente, **cuando** el recepcionista abre su detalle, **entonces** se muestran cliente, vehículo, motivo de visita, estado y fecha de la orden.
4. **Dado** un listado con varias órdenes, **cuando** el recepcionista filtra por estado o busca por placas o nombre de cliente, **entonces** el listado muestra solo las órdenes coincidentes.
5. **Dado** un cliente sin vehículos, **cuando** el recepcionista intenta crear una orden seleccionando ese cliente, **entonces** se le pide registrar primero un vehículo (o elegir otro cliente) y no se crea una orden huérfana.

### Historia de usuario 2 - Gestionar citas de recepción (Prioridad: P2)

Como recepcionista, quiero registrar, consultar, cancelar y marcar como recibida una cita, para organizar la llegada de vehículos y poder derivarla a una orden de servicio cuando el cliente llega.

**Por qué esta prioridad**: Es el primer punto de contacto con el cliente y alimenta el flujo de órdenes, pero un taller puede operar con llegadas sin cita, por lo que va después del núcleo de órdenes.

**Prueba independiente**: Se puede crear una cita para un cliente y vehículo, verla en el calendario/listado del día, cancelarla y marcarla como recibida sin necesidad de crear ninguna orden.

#### Escenarios de aceptación

1. **Dado** un cliente y un vehículo registrados, **cuando** el recepcionista crea una cita con fecha, hora y motivo, **entonces** la cita queda guardada con estado `PROGRAMADA` y aparece en la consulta de citas.
2. **Dado** una cita `PROGRAMADA` cuya fecha ya pasó, **cuando** el recepcionista la consulta, **entonces** el sistema la marca (o permite marcarla) como `NO_PRESENTADA`.
3. **Dado** una cita `PROGRAMADA`, **cuando** el recepcionista la cancela, **entonces** la cita pasa a `CANCELADA` y deja de aparecer como cita activa del día.
4. **Dado** una cita `PROGRAMADA` y el cliente llega al taller, **cuando** el recepcionista la marca como recibida, **entonces** la cita pasa a `RECIBIDA` y se habilita la creación de la orden de servicio derivada, con el formulario precargado con los datos de la cita.
5. **Dado** dos citas en la misma fecha y hora, **cuando** el recepcionista intenta guardar la segunda, **entonces** se muestra un aviso de conflicto de horario y la cita no se guarda sin confirmación explícita.

### Historia de usuario 3 - Consultar las órdenes asignadas (Prioridad: P3)

Como mecánico, quiero ver solo las órdenes de servicio que están asignadas a mí, para saber qué trabajos atender sin ver trabajo ajeno.

**Por qué esta prioridad**: Es el punto de entrada del rol mecánico al sistema; el resto de historias de diagnóstico y servicios dependen de poder abrir "su" orden.

**Prueba independiente**: Con dos mecánicos y órdenes asignadas a cada uno, cada mecánico ve en su listado únicamente sus órdenes y puede abrir el detalle de cualquiera de ellas.

#### Escenarios de aceptación

1. **Dado** un mecánico con órdenes asignadas, **cuando** inicia sesión y abre la lista de órdenes, **entonces** ve solo las órdenes cuyo mecánico asignado es él.
2. **Dado** un recepcionista, **cuando** abre la lista de órdenes, **entonces** ve todas las órdenes del taller.
3. **Dado** una orden sin mecánico asignado, **cuando** el recepcionista la abre, **entonces** puede asignarle uno de los mecánicos disponibles; desde ese momento esa orden aparece en el listado de ese mecánico.
4. **Dado** una orden en estado `TERMINADO` o `ENTREGADO`, **cuando** el recepcionista intenta reasignarla, **entonces** el sistema lo impide con un mensaje claro.

### Historia de usuario 4 - Registrar diagnóstico y servicios realizados (Prioridad: P4)

Como mecánico, quiero registrar el diagnóstico, los servicios realizados, las recomendaciones y los repuestos utilizados en una orden asignada, para que quede constancia técnica del trabajo.

**Por qué esta prioridad**: Aporta el valor técnico del taller y alimenta el historial del vehículo, pero requiere que la orden ya exista y esté asignada.

**Prueba independiente**: Sobre una orden asignada en `DIAGNOSTICO`, se guarda un diagnóstico, se agregan uno o más servicios con su descripción y duración de mano de obra, se agregan repuestos usados y una recomendación, y todo persiste al volver a abrir la orden.

#### Escenarios de aceptación

1. **Dado** una orden asignada al mecánico en estado `DIAGNOSTICO`, **cuando** guarda el diagnóstico, **entonces** el texto queda asociado a la orden y se muestra al reabrir el detalle.
2. **Dado** una orden en `DIAGNOSTICO` con diagnóstico guardado, **cuando** el mecánico agrega servicios con su nombre y duración, **entonces** los servicios quedan listados en la orden con su mano de obra asociada.
3. **Dado** una orden, **cuando** el mecánico agrega repuestos utilizados, **entonces** cada repuesto queda registrado con su cantidad junto a la orden.
4. **Dado** una orden, **cuando** el mecánico guarda recomendaciones, **entonces** quedan visibles en el detalle de la orden para la entrega.
5. **Dado** una orden `ENTREGADO`, **cuando** el mecánico intenta editar diagnóstico o servicios, **entonces** el sistema lo impide.
6. **Dado** servicios y mano de obra registrados en una orden, **cuando** se consulta el historial del vehículo, **entonces** esos trabajos aparecen en el historial junto con el kilometraje registrado.

### Historia de usuario 5 - Cambiar el estado de la orden a lo largo del flujo (Prioridad: P5)

Como recepcionista o mecánico, quiero avanzar la orden por sus estados (recibido, diagnóstico, en reparación, esperando refacción, terminado, entregado), para que todos vean en qué punto está el trabajo.

**Por qué esta prioridad**: Es la columna vertebral operativa del flujo; complementa a las otras historias y solo tiene sentido con órdenes existentes.

**Prueba independiente**: Sobre una orden creada, se la recorre por toda la secuencia permitida comprobando que cada cambio se guarda y que las transiciones inválidas quedan rechazadas.

#### Escenarios de aceptación

1. **Dado** una orden en `RECIBIDO`, **cuando** el mecánico la pasa a `DIAGNOSTICO`, **entonces** el estado se actualiza y queda registrado quién hizo el cambio y cuándo.
2. **Dado** una orden en `DIAGNOSTICO`, **cuando** se intenta pasar directamente a `ENTREGADO`, **entonces** el cambio se rechaza porque viola la secuencia (RN-05 y la secuencia de `docs/project-context.md` §6.4).
3. **Dado** una orden en `DIAGNOSTICO`, **cuando** el responsable la pasa a `ESPERANDO_REFACCION`, **entonces** el estado queda registrado y la orden puede volver al flujo normal (por ejemplo a `EN_REPARACION`).
4. **Dado** una orden en `TERMINADO`, **cuando** el recepcionista la entrega al cliente, **entonces** la orden pasa a `ENTREGADO` y se registra la fecha de entrega.
5. **Dado** una orden en `DIAGNOSTICO` y un recepcionista intentando pasarla a `EN_REPARACION`, **cuando** intenta el cambio, **entonces** el sistema lo rechaza porque esa transición corresponde al mecánico asignado (FR-022).
6. **Dado** una orden `ENTREGADO`, **cuando** se intenta modificar su estado o eliminarla, **entonces** el sistema lo impide.

### Historia de usuario 6 - Agendar citas desde el panel de recepción (Prioridad: P6)

Como recepcionista, quiero ver las citas del día y las órdenes abiertas en una sola vista, para planificar el trabajo del taller.

**Por qué esta prioridad**: Es comodidad operativa sobre las historias ya existentes; su ausencia no impide usar el sistema.

**Prueba independiente**: Con citas y órdenes creadas, la vista de recepción muestra ambas listas con sus estados sin necesidad de abrir cada registro.

#### Escenarios de aceptación

1. **Dado** citas creadas para el día, **cuando** el recepcionista abre su vista principal, **entonces** ve las citas del día con su hora, cliente, vehículo y estado.
2. **Dado** órdenes abiertas, **cuando** el recepcionista abre su vista principal, **entonces** ve las órdenes pendientes con su estado y mecánico asignado.
3. **Dado** un día sin citas ni órdenes, **cuando** abre la vista, **entonces** ve un mensaje de "sin actividades" y no un error.

## Requisitos funcionales *(obligatorio)*

- **FR-001**: El sistema permitirá crear órdenes de servicio que asocien obligatoriamente un cliente y un vehículo existentes, un motivo de visita y una fecha de ingreso. El mecánico asignado será opcional al alta.
- **FR-002**: El sistema impedirá crear órdenes sin cliente o sin vehículo (RN-01, RN-02).
- **FR-003**: El sistema permitirá listar y buscar órdenes por estado, placas del vehículo o nombre/apellido del cliente, con paginación.
- **FR-004**: El sistema mostrará el detalle de la orden con su cliente, vehículo, motivo, estado, mecánico asignado, diagnóstico, servicios, repuestos y recomendaciones.
- **FR-005**: El sistema permitirá registrar citas con cliente, vehículo, fecha, hora y motivo; la cita nacerá en estado `PROGRAMADA`.
- **FR-006**: El sistema permitirá cancelar citas (estado `CANCELADA`) en cualquier momento mientras estén `PROGRAMADA`, con motivo opcional que se guarda si se indica; permitirá marcarlas como recibidas (`RECIBIDA`) y detectar las no presentadas (`NO_PRESENTADA`) cuando su fecha/hora ya pasó.
- **FR-007**: Al marcar una cita como recibida, el sistema habilitará la creación manual de la orden de servicio derivada, con el formulario precargado con el cliente, el vehículo y el motivo de la cita para que el recepcionista confirme o ajuste antes de generarla; la orden guardará la referencia a la cita de origen. El sistema no creará órdenes automáticamente.
- **FR-008**: El sistema avisará sobre conflictos de fecha y hora entre citas antes de guardar.
- **FR-009**: El sistema permitirá asignar un mecánico a una orden desde recepción (opcional al alta, con asignación y reasignación posterior desde el detalle) y rechazará la reasignación de órdenes `TERMINADO` o `ENTREGADO`.
- **FR-010**: El rol mecánico solo verá en sus listados las órdenes asignadas a él (las órdenes sin asignar no aparecen en sus listados); el recepcionista y el administrador verán todas, incluidas las aún sin mecánico (RN-05, RN-15).
- **FR-011**: El sistema permitirá al mecánico guardarse como borrador el diagnóstico antes de continuar.
- **FR-012**: El sistema permitirá agregar servicios a la orden con su descripción y su mano de obra asociada, y repuestos utilizados con su cantidad (RN-06, RN-15).
- **FR-013**: El sistema permitirá guardar recomendaciones para la entrega del vehículo.
- **FR-014**: El sistema gestionará los estados de la orden según la secuencia `RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO`, con la excepción `ESPERANDO_REFACCION` (CA-05, RN-05 y la secuencia de `docs/project-context.md` §6.4), rechazando cualquier otra transición con un mensaje claro. Toda orden nacerá en estado `RECIBIDO`, sea que provenga de una cita o no, y el avance a `DIAGNOSTICO` lo realizará el mecánico.
- **FR-015**: Cada cambio de estado quedará registrado con usuario y fecha, y la entrega guardará su fecha (RN-09).
- **FR-016**: El sistema impedirá modificar o eliminar órdenes en estado `ENTREGADO` (RN-09).
- **FR-017**: El sistema mantendrá un historial por vehículo con los servicios realizados, los repuestos usados y el kilometraje registrado en cada orden (RN-10, RN-03, RN-04).
- **FR-018**: El sistema impedirá guardar un kilometraje menor al registrado en la última orden del vehículo, y aceptará el primer kilometraje cuando no exista valor previo.
- **FR-019**: El sistema borrará los diagnósticos no guardados al navegar fuera de la orden, salvo que se hayan guardado explícitamente (FR-011).
- **FR-020**: Las operaciones de citas y órdenes estarán reservadas al recepcionista y al administrador salvo las expresamente permitidas al mecánico (diagnóstico, servicios, repuestos, recomendaciones y cambio de estado de sus órdenes) (RN-05, RN-15).
- **FR-021**: El sistema cargará datos de ejemplo idempotentes al iniciar: al menos 5 citas y 4 órdenes de ejemplo con estados variados, sin duplicarlos en reinicios sucesivos (CA-06).
- **FR-022**: El sistema restringirá quién puede realizar cada transición de estado: el mecánico asignado gestionará `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION` y `TERMINADO` de sus órdenes; el recepcionista gestionará la entrega (`ENTREGADO`) y el ingreso (asignación del mecánico al crear o editar la orden); el administrador podrá realizar cualquier transición válida.

## Entidades clave *(obligatorio)*

- **Cita**: cita de recepción; tiene cliente, vehículo, fecha, hora, motivo, estado (`PROGRAMADA`, `RECIBIDA`, `CANCELADA`, `NO_PRESENTADA`), motivo de cancelación opcional y opcionalmente la orden de servicio en la que se convirtió.
- **Orden de servicio**: trabajo solicitado para un vehículo de un cliente; tiene motivo de visita, fecha de ingreso, estado, mecánico asignado, kilometraje, diagnóstico, recomendaciones, fecha de entrega y referencia opcional a la cita de origen.
- **Servicio de la orden**: partida de trabajo aplicada a la orden; descripción, duración/precio de mano de obra y fecha.
- **Repuesto utilizado**: refacción empleada en la orden; descripción y cantidad.
- **Cliente y vehículo**: existentes desde el Sprint 1; la orden y la cita siempre los referencian.
- **Usuario**: recepcionista, mecánico o administrador; interviene como creador, mecánico asignado y autor de cambios de estado.

## Criterios de éxito *(obligatorio)*

- **SC-001**: El recepcionista puede crear una orden completa (cliente + vehículo + motivo) en menos de 3 minutos.
- **SC-002**: El 100 % de las órdenes creadas tienen cliente y vehículo asociados; ninguna queda "huérfana".
- **SC-003**: Cada mecánico ve únicamente sus órdenes en el listado (0 órdenes ajenas visibles para el rol mecánico).
- **SC-004**: El 100 % de las transiciones de estado inválidas quedan rechazadas con un mensaje comprensible, y las válidas se persisten con usuario y fecha.
- **SC-005**: El flujo completo demostrable (cita → recepción → orden → asignación → diagnóstico → servicios → terminado → entregado) se completa sin errores en una sola pasada.
- **SC-006**: Al iniciar la aplicación con datos vacíos se muestran al menos 5 citas y 4 órdenes de ejemplo; reiniciar la carga no duplica registros.
- **SC-007**: Ninguna orden `ENTREGADO` puede ser modificada ni eliminada en la interfaz ni en el servicio (0 bypass).
- **SC-008**: El historial de un vehículo refleja todos los servicios y repuestos de sus órdenes y el kilometraje no permite valores inferiores al anterior en el 100 % de los intentos.

## Supuestos

1. **Secuencia de estados**: se adopta la secuencia fijada en CA-05 del sprint (`RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO` con `ESPERANDO_REFACCION` como excepción); confirmado en la clarificación del 2026-10-11 que toda orden nace en `RECIBIDO`.
2. **Asignación de mecánico**: manual por parte de recepción (sin algoritmo automático de carga de trabajo); opcional al alta y reasignable después. Confirmado en la clarificación del 2026-10-11.
3. **Primer kilometraje**: si el vehículo no tiene orden anterior, se acepta el valor indicado sin validación de coherencia. *Supuesto diferido: no se preguntó por cuota de clarificación; conviene confirmarlo con el equipo durante la planificación.*
4. **Cancelación de citas**: una cita puede cancelarse libremente mientras esté `PROGRAMADA`, con motivo opcional; cancelarla no afecta a órdenes ya existentes. Confirmado en la clarificación del 2026-10-11.
5. **Servicios y mano de obra**: se registran con descripción y datos de mano de obra; la facturación y los pagos quedan fuera de este sprint (ver `docs/reglas.md`).
6. **Repuestos**: se registran como consumo en la orden, pero el control de inventario y el pedido a proveedores quedan fuera de este sprint.
7. **Borradores**: el diagnóstico es el único borrador previsto (FR-011).
8. **Usuarios**: se reutilizan los usuarios y roles del Sprint 1 (recepcionista, mecánico, administrador) con las mismas reglas de acceso.
9. **Datos de ejemplo**: la carga de datos de ejemplo de este sprint es idempotente y no duplica ni interfiere con los datos de ejemplo del Sprint 1.

## Casos límite

- Crear una orden para un cliente que no tiene vehículos registrados.
- Intentar crear una orden sin motivo de visita o con campos obligatorios vacíos.
- Guardar dos citas con la misma fecha y hora para el mismo vehículo o mecánico.
- Cancelar o recibir una cita que ya fue cancelada, recibida o que ya pasó.
- Derivar a orden una cita ya usada en otra orden.
- Intentar transiciones inválidas (p. ej. `RECIBIDO → ENTREGADO` o retroceder de `TERMINADO` a `DIAGNOSTICO`).
- Reasignar el mecánico de una orden `TERMINADO` o `ENTREGADO`.
- Editar diagnóstico, servicios o repuestos de una orden `ENTREGADO`.
- Registrar un kilometraje menor al de la orden anterior del vehículo.
- Que un mecánico intente abrir u operar una orden no asignada a él.
- Recargar la aplicación con datos de ejemplo ya cargados (duplicación).
- Recibir una cita desde el panel que no tiene fecha u hora válidas.

## Restricciones no funcionales heredadas

- El sistema seguirá las reglas de negocio RN-01, RN-02, RN-03, RN-04, RN-05, RN-06, RN-09, RN-10 y RN-15 definidas en `docs/project-context.md` (§13 "Reglas de negocio iniciales").
- El diseño visual y el acceso por rol seguirán el design system y los permisos establecidos en el Sprint 1.
