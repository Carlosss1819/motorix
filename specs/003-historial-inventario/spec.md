# Especificación de la funcionalidad: Historial, mantenimiento e inventario

**Rama de la funcionalidad**: `003-historial-inventario`

**Creada**: 2026-10-12

**Estado**: Borrador

**Entrada**: Descripción del usuario: `docs/sprints/sprint-3-historial-inventario.md` (Sprint 3 del MVP de Motorix: historial, mantenimiento e inventario).

## Clarifications

### Session 2026-10-13

- P: ¿Con qué antelación se considera que un mantenimiento está «próximo» a vencer? → R: Antelación propia de cada mantenimiento, medida en días y en kilómetros, con valores por defecto de 30 días y 500 km; nunca es un umbral global.
- P: ¿Qué ocurre con un mantenimiento cuando el servicio correspondiente se realiza? → R: El mecánico lo marca como «servicio realizado» y el mismo registro se renueva: actualiza la fecha y el kilometraje del último servicio, recalcula el objetivo con su intervalo configurable y vuelve a estado «normal»; un único registro por vehículo y tipo de servicio, sin duplicados.
- P: ¿Qué nombre canónico usará el sistema para las piezas del inventario: «refacción» o «repuesto»? → R: «Refacción» en toda la aplicación, la documentación y las pruebas; el «repuesto» del Sprint 2 (pantalla y endpoint `/repuestos` de la orden) es el mismo concepto, cuyo nombre se unifica. Los endpoints heredados pueden conservarse por compatibilidad.
- P: ¿Qué roles pueden crear y editar mantenimientos, y quién registra las entradas de inventario por reabastecimiento? → R: Mantenimientos: mecánico y administrador (crean y editan); entradas de inventario por reabastecimiento: solo el administrador. Las consultas quedan abiertas a los tres roles.
- P: ¿Cómo se limita la consulta del historial de un vehículo con muchas órdenes terminadas? → R: Se pagina con el patrón de paginación del proyecto (R‑10): 10 entradas por página por defecto, máximo 50, conservando el orden cronológico.

## Escenarios de usuario y pruebas

### Historia 1 - Consultar el historial de servicios del vehículo (Prioridad: P1)

Como mecánico, quiero consultar el historial de servicios de un vehículo para conocer su estado y antecedentes.

**Por qué esta prioridad**: es la base de todo el sprint: el historial da contexto al mecánico antes de atender un vehículo y de él derivan el seguimiento de mantenimientos. Cumple la regla RN-10 (el historial se deriva de la información ya registrada).

**Prueba independiente**: concluir una orden de servicio y abrir el historial del vehículo para ver esa entrada con sus servicios, refacciones y recomendaciones.

**Escenarios de aceptación**:

1. **Dado** un vehículo con dos órdenes terminadas, **cuando** se abre su historial, **entonces** aparecen ambas en orden cronológico con fecha, kilometraje, orden relacionada, diagnóstico, servicios realizados, refacciones utilizadas, observaciones y recomendaciones.
2. **Dado** un vehículo con una orden todavía en curso, **cuando** se consulta el historial, **entonces** solo aparecen las órdenes terminadas y la orden en curso no se duplica.
3. **Dado** un vehículo sin órdenes terminadas, **cuando** se consulta el historial, **entonces** se muestra un mensaje claro de que aún no hay servicios registrados.

---

### Historia 2 - Registrar el kilometraje del servicio (Prioridad: P2)

Como mecánico, quiero registrar el kilometraje de cada servicio para mantener actualizado el historial.

**Por qué esta prioridad**: el kilometraje es el dato con el que se decide cuándo vence el próximo mantenimiento; sin él, el seguimiento preventivo no funciona.

**Prueba independiente**: registrar un servicio con kilometraje y verificar que el historial del vehículo y el mantenimiento programado reflejan ese valor.

**Escenarios de aceptación**:

1. **Dado** un vehículo cuya última orden registró 12,000 km, **cuando** se intenta registrar un servicio con 11,000 km, **entonces** el sistema lo rechaza con un mensaje claro, salvo que se indique una corrección explícita con motivo.
2. **Dado** un servicio registrado con su kilometraje, **cuando** se consulta el historial del vehículo, **entonces** el kilometraje de ese servicio aparece en su entrada.

---

### Historia 3 - Establecer el próximo mantenimiento (Prioridad: P3)

Como mecánico, quiero establecer el próximo mantenimiento para programar el siguiente servicio.

**Por qué esta prioridad**: convierte el historial en acción preventiva y es el puente entre el trabajo terminado y la siguiente visita del cliente.

**Prueba independiente**: registrar un mantenimiento con fecha y kilometraje objetivo y verificar que aparece en el listado con su estado.

**Escenarios de aceptación**:

1. **Dado** un vehículo, **cuando** se define un mantenimiento con tipo de servicio, fecha y/o kilometraje objetivo, **entonces** queda guardado junto con la recomendación del mecánico.
2. **Dado** un mantenimiento definido solo por kilometraje, **cuando** el vehículo alcanza ese kilometraje, **entonces** el sistema lo marca como vencido.
3. **Dado** un mantenimiento definido por fecha y kilometraje, **cuando** se cumple cualquiera de los dos objetivos, **entonces** el mantenimiento deja de estar en estado normal.

---

### Historia 4 - Consultar los mantenimientos próximos (Prioridad: P4)

Como recepcionista, quiero consultar los mantenimientos próximos para avisar al cliente.

**Por qué esta prioridad**: es la cara visible del mantenimiento preventivo para el personal de recepción y genera visitas al taller.

**Prueba independiente**: abrir el listado de mantenimientos próximos y vencidos y verificar el vehículo, el cliente y la fecha o kilometraje objetivo de cada uno.

**Escenarios de aceptación**:

1. **Dado** un vehículo con un mantenimiento próximo, **cuando** se consulta el listado de mantenimientos, **entonces** aparece el vehículo, el cliente asociado y la fecha o kilometraje objetivo.
2. **Dado** un mantenimiento vencido, **cuando** se consulta el listado, **entonces** aparece destacado como vencido.
3. **Dado** un vehículo sin mantenimientos programados, **cuando** se consulta el listado, **entonces** no aparece y el listado informa que no hay pendientes.

---

### Historia 5 - Registrar y consultar refacciones (Prioridad: P5)

Como administrador, quiero registrar y consultar refacciones para controlar el inventario.

**Por qué esta prioridad**: sin el catálogo de refacciones no hay inventario ni salidas por orden; es el cimiento de las historias 6, 7 y 8.

**Prueba independiente**: registrar una refacción con su código y stock mínimo y verificar que aparece en el inventario con sus existencias.

**Escenarios de aceptación**:

1. **Dado** una refacción ya registrada con un código, **cuando** se intenta registrar otra con el mismo código, **entonces** el sistema lo rechaza con un mensaje claro.
2. **Dado** una refacción registrada, **cuando** se consulta el inventario, **entonces** aparecen su código, nombre, categoría, marca, stock actual, stock mínimo y precios.
3. **Dado** una refacción registrada, **cuando** se desactiva, **entonces** deja de poder usarse en órdenes nuevas pero su historial de uso se conserva.

---

### Historia 6 - Consultar el stock disponible (Prioridad: P6)

Como administrador, quiero consultar el stock disponible para saber qué hay en existencia.

**Por qué esta prioridad**: es la consulta rutinaria del administrador y alimenta la decisión de reabastecimiento.

**Prueba independiente**: buscar una refacción por nombre o código y verificar que se muestra su existencia actual.

**Escenarios de aceptación**:

1. **Dado** el inventario con refacciones registradas, **cuando** se consulta el stock, **entonces** se muestra la existencia actual de cada refacción.
2. **Dado** una búsqueda por nombre o código, **cuando** se filtra el listado, **entonces** solo aparecen las coincidencias.

---

### Historia 7 - Agregar refacciones utilizadas a una orden (Prioridad: P7)

Como mecánico, quiero agregar refacciones utilizadas a una orden para reflejar su uso.

**Por qué esta prioridad**: conecta el trabajo del taller con el inventario (RN-6 y RN-7) y es lo que hace que el stock sea confiable.

**Prueba independiente**: agregar una refacción del catálogo a una orden abierta y verificar que el stock disminuye y que queda un movimiento de salida ligado a la orden.

**Escenarios de aceptación**:

1. **Dado** una orden abierta y una refacción del catálogo con stock suficiente, **cuando** se agrega con cantidad 2, **entonces** el stock disminuye en 2 y queda registrado un movimiento de salida que referencia la orden.
2. **Dado** una refacción con stock insuficiente, **cuando** se intenta agregarla a una orden, **entonces** el sistema la rechaza sin modificar el stock.
3. **Dado** una refacción agregada por error, **cuando** se retira de la orden, **entonces** el stock se repone y queda registrado el ajuste correspondiente.
4. **Dado** una refacción que no existe en el catálogo, **cuando** se intenta agregarla a una orden, **entonces** el sistema la rechaza y pide registrarla primero.

---

### Historia 8 - Visualizar alertas de stock bajo (Prioridad: P8)

Como administrador, quiero visualizar alertas de stock bajo para reabastecer a tiempo.

**Por qué esta prioridad**: es el resultado visible del control de inventario y evita paros por refacciones faltantes.

**Prueba independiente**: dejar una refacción por debajo de su stock mínimo y verificar que aparece marcada como stock bajo.

**Escenarios de aceptación**:

1. **Dado** una refacción cuyo stock actual es menor o igual a su stock mínimo, **cuando** se consulta el inventario, **entonces** aparece marcada como stock bajo.
2. **Dado** una refacción cuyo stock está por encima del mínimo, **cuando** se consulta el inventario, **entonces** no aparece marcada como stock bajo.

---

### Casos límite

- ¿Qué sucede cuando el vehículo tiene muchas órdenes terminadas? El historial se pagina con el patrón de paginación del proyecto (10 entradas por página por defecto, máximo 50) sin perder el orden cronológico.
- ¿Qué sucede cuando dos mecánicos agregan la misma refacción al mismo tiempo y el stock solo alcanza para una unidad? El sistema impide que el stock quede negativo y la segunda operación recibe un error claro.
- ¿Qué sucede cuando una refacción ya usada en órdenes se quiere eliminar? No se elimina: se desactiva y su historial se conserva.
- ¿Qué sucede cuando el kilometraje de un servicio es menor al registrado en la orden anterior? Solo se permite con corrección explícita y motivo.
- ¿Qué sucede cuando un mantenimiento se guarda sin fecha y sin kilometraje? No se guarda, porque no habría forma de saber cuándo vence.
- ¿Qué sucede cuando una orden terminada se intenta modificar para corregir sus refacciones? Se impide (RN-9); la corrección posterior debe hacerse con un movimiento de inventario justificado.
- ¿Qué sucede cuando una refacción tiene stock mínimo igual a 0? No genera alerta de stock bajo.
- ¿Qué sucede cuando una refacción con stock 0 se intenta usar en una orden? Se rechaza con un mensaje claro, sin dejar stock negativo (RN-8).
- ¿Qué sucede cuando el historial de un vehículo que nunca visitó el taller se consulta? Se muestra vacío con una indicación clara, no un error.

## Requisitos funcionales

### Historial del vehículo

- **FR-001**: El sistema mostrará el historial de servicios de un vehículo derivado de sus órdenes terminadas, en orden cronológico, sin crear registros duplicados (RN-10); la consulta se paginará con el patrón de paginación del proyecto (10 entradas por página por defecto, máximo 50).
- **FR-002**: Cada entrada del historial incluirá la fecha del servicio, el kilometraje, la orden relacionada, el diagnóstico, los servicios realizados, las refacciones utilizadas, las observaciones y las recomendaciones.
- **FR-003**: El historial excluirá las órdenes que no estén terminadas ni entregadas.
- **FR-004**: Mecánico, recepcionista y administrador podrán consultar el historial de cualquier vehículo; el mecánico podrá abrirlo desde sus órdenes asignadas.

### Kilometraje de los servicios

- **FR-005**: El sistema usará el kilometraje registrado al abrir la orden como el kilometraje del servicio en el historial.
- **FR-006**: El sistema impedirá registrar un kilometraje menor al de la orden anterior del vehículo, salvo corrección explícita con motivo, que solo el administrador podrá autorizar (regla heredada del Sprint 2).
- **FR-007**: El kilometraje del vehículo se mantendrá actualizado con el valor más alto registrado, para que el seguimiento preventivo use el dato vigente.

### Mantenimiento preventivo

- **FR-008**: El sistema permitirá registrar un próximo mantenimiento por tipo de servicio, indicando fecha objetivo, kilometraje objetivo o ambos (RN-11); solo el mecánico y el administrador podrán crear y editar mantenimientos (RN-15).
- **FR-009**: El sistema impedirá guardar un mantenimiento sin fecha objetivo y sin kilometraje objetivo.
- **FR-010**: El sistema no asumirá intervalos universales: cada mantenimiento se configura por vehículo y tipo de servicio (RN-12).
- **FR-011**: El sistema calculará el estado de cada mantenimiento como normal, próximo o vencido a partir de la fecha y el kilometraje actuales; se marcará como próximo cuando falten, como mínimo, la antelación configurada en el mantenimiento (días antes de la fecha objetivo o kilómetros antes de la kilometraje objetivo), con valores por defecto de 30 días y 500 km.
- **FR-012**: El sistema marcará un mantenimiento como vencido cuando se alcance el kilometraje objetivo o se cumpla la fecha objetivo, lo que ocurra primero.
- **FR-013**: El sistema permitirá consultar los mantenimientos próximos y vencidos con el vehículo y el cliente asociados.
- **FR-014**: El sistema permitirá registrar las recomendaciones del mecánico en cada mantenimiento.
- **FR-015**: El sistema permitirá atender un mantenimiento marcándolo como «servicio realizado»: el mismo registro actualizará la fecha y el kilometraje del último servicio, recalculará su objetivo con el intervalo configurable y volverá al estado «normal», sin crear un registro duplicado por vehículo y tipo de servicio.

### Inventario de refacciones

- **FR-016**: El sistema permitirá registrar refacciones con código único, nombre, categoría, marca, stock actual, stock mínimo, precio de compra y precio de venta.
- **FR-017**: El sistema impedirá registrar dos refacciones con el mismo código.
- **FR-018**: El sistema permitirá consultar el stock disponible y filtrarlo por nombre o código.
- **FR-019**: El sistema permitirá desactivar una refacción para que no se use en órdenes nuevas, conservando siempre su historial de uso.
- **FR-020**: El sistema impedirá que el stock de una refacción quede negativo en cualquier operación (RN-8).
- **FR-021**: El sistema marcará una refacción como stock bajo cuando su stock actual sea menor o igual a su stock mínimo.
- **FR-022**: Solo el administrador podrá registrar, editar, desactivar refacciones y ajustar su stock; el resto de los roles solo podrán consultar el inventario (RN-15).

### Uso de refacciones en órdenes

- **FR-023**: El sistema permitirá agregar a una orden solo refacciones existentes y activas del catálogo, con su cantidad (RN-6).
- **FR-024**: Cada refacción agregada a una orden generará un movimiento de salida de inventario con la cantidad y la orden asociada (RN-7).
- **FR-025**: El sistema rechazará el uso de una refacción si la cantidad supera el stock disponible, sin modificar el inventario.
- **FR-026**: El sistema permitirá retirar una refacción de una orden mientras esta no esté terminada ni entregada, reponiendo el stock y dejando constancia del movimiento.
- **FR-027**: Mecánico, recepcionista y administrador podrán agregar o retirar refacciones en una orden; el mecánico solo en las órdenes que le están asignadas (RN-15).

### Movimientos de inventario

- **FR-028**: El sistema registrará un movimiento por cada entrada, salida o ajuste de stock, con tipo, cantidad, motivo, fecha y la orden asociada cuando corresponda.
- **FR-029**: El administrador podrá registrar ajustes de inventario con motivo obligatorio; las entradas por reabastecimiento también las registrará únicamente el administrador, y las salidas por orden y las entradas quedarán trazadas igualmente (RN-15).
- **FR-030**: El historial de movimientos podrá consultarse por refacción para explicar cualquier cambio de stock.

### Datos de ejemplo

- **FR-031**: El sistema cargará datos de ejemplo idempotentes al iniciar (refacciones con existencias variadas, algunos mantenimientos próximos y vencidos, y movimientos de inventario) de modo que la aplicación muestre información desde el primer arranque, sin duplicarlos en reinicios sucesivos.

### Entidades clave

- **Mantenimiento**: representa un servicio preventivo programado para un vehículo; incluye el tipo de servicio, la fecha del último servicio, el kilometraje del último servicio, la fecha objetivo, el kilometraje objetivo, el intervalo configurable en días y/o kilómetros con el que se renueva el objetivo tras cada servicio, la antelación en días y en kilómetros para el estado «próximo», las notas o recomendaciones del mecánico y su estado. Sus estados posibles son «normal», «próximo» y «vencido». Se relaciona con un vehículo y existe un único registro por vehículo y tipo de servicio.
- **Refacción**: representa una pieza del inventario del taller; incluye un código único, nombre, categoría, marca, stock actual, stock mínimo, precio de compra, precio de venta y su estado activo. Es el catálogo del que se alimentan las órdenes.
- **Movimiento de inventario**: representa un cambio puntual del stock de una refacción; incluye el tipo (entrada, salida o ajuste), la cantidad, el motivo, la fecha y, cuando el cambio proviene de una orden de servicio, la orden asociada.
- **Refacción utilizada en la orden**: representa el vínculo entre una refacción del catálogo y una orden de servicio, con la cantidad usada; su creación o retiro provoca el movimiento de inventario correspondiente.
- **Historial del vehículo**: no es un registro nuevo: es la vista consolidada de las órdenes terminadas del vehículo con sus servicios, refacciones y recomendaciones (RN-10).

## Criterios de éxito

### Resultados medibles

- **SC-001**: Un mecánico puede ver el historial de un vehículo con 10 o más servicios registrados —una página del historial paginado, 10 entradas por defecto— en menos de 5 segundos, en orden cronológico.
- **SC-002**: El 100% de las órdenes terminadas aparecen una sola vez en el historial de su vehículo.
- **SC-003**: El personal de recepción puede identificar los próximos mantenimientos de la semana en menos de 30 segundos desde la pantalla correspondiente.
- **SC-004**: Registrar un próximo nuevo toma menos de 1 minuto y no requiere conocimientos técnicos.
- **SC-005**: Registrar una refacción nueva toma menos de 2 minutos y sus datos quedan disponibles de inmediato en el inventario.
- **SC-006**: En el 100% de los casos, usar una refacción en una orden deja el stock disponible correcto, sin valores negativos.
- **SC-007**: El 100% de los cambios de stock quedan explicados por un movimiento con tipo, cantidad y motivo.
- **SC-008**: El personal identifica las refacciones con stock bajo en menos de 10 segundos al abrir la pantalla de inventario.
- **SC-009**: El 100% de las operaciones de historial, mantenimiento e inventario validan el rol del usuario, sin depender de ocultar controles en la interfaz.

## Supuestos

- El historial del vehículo se deriva de las órdenes terminadas (RN-10); no se crea un registro de historial separado que pueda desincronizarse.
- La vigencia de un mantenimiento se cumple al alcanzar el kilometraje objetivo o la fecha objetivo, lo que ocurra primero; el estado "próximo" se calcula con una antelación configurable por mantenimiento en días y kilómetros (valores por defecto 30 días / 500 km), nunca con un umbral global.
- El stock negativo está prohibido (RN-8); no se contempla una política de tolerancia.
- Los movimientos de inventario son de tres tipos: entrada, salida y ajuste; el ajuste requiere motivo y es exclusivo del administrador.
- "Stock bajo" significa stock actual menor o igual al stock mínimo definido en la refacción; un stock mínimo de 0 no genera alerta.
- Las refacciones que se usan en una orden deben provenir del catálogo de refacciones (RN-6); la lista de refacciones por orden existente desde el Sprint 2 se amplía para ligarse al catálogo.
- Término canónico: «refacción». El «repuesto» del Sprint 2 (pantalla y endpoint de refacciones de la orden) designa el mismo concepto y su nombre se unifica en UI, documentación y pruebas; los endpoints heredados pueden conservarse por compatibilidad.
- Los mantenimientos se programan por vehículo y tipo de servicio, con intervalos configurables por mantenimiento (RN-12); no se asumen periodos universales como 6 meses o 5,000 km.
- Existe un único registro de mantenimiento por vehículo y tipo de servicio: al marcarlo como «servicio realizado» el mismo registro se renueva (último servicio y nuevo objetivo desde el intervalo configurable) en lugar de acumular registros cumplidos.
- El kilometraje sigue la misma regla de no-regresión ya aplicada en el Sprint 2, con corrección explícita reservada al administrador.
- Este sprint se apoya en las órdenes de servicio, clientes y vehículos entregados en los sprints 1 y 2.
- Están fuera de alcance: pagos, Mercado Pago, tickets, panel general (dashboard) y notificaciones externas (correo, WhatsApp). El aviso al cliente sobre mantenimientos próximos lo realiza el personal de recepción de forma manual.
