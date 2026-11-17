# Especificación de la Funcionalidad: Notificaciones internas

**Rama de la funcionalidad**: `006-notificaciones-internas`

**Fecha de creación**: 2026-11-16

**Estado**: Borrador (aclarado el 2026-11-16)

**Input**: Descripción del usuario: "Sprint 6: notificaciones internas. Insumo: `docs/sprints/sprint-6-notificaciones-internas.md`. Aplica en la spec (no en el insumo) las correcciones de migraciones, base de pruebas, rango de ids de los seeds, precios del mecánico, rutas de referencia y diferencias con el código real halladas en la revisión ligera."

> **Gobernanza**: el Sprint 6 está dentro del alcance oficial posterior al MVP por la enmienda 1.1.0 de la constitución (2026-11-13, principio I: sprints 5, 6 y 7, en orden). El Sprint 5 está cerrado (commit `1959d5a`).

## Clarifications

### Session 2026-11-16

Respuestas de Carlos (responsable del sprint) a las decisiones de la sección 9 del insumo:

- Q: ¿Qué es una orden detenida y cuánto vale N? → A: Cualquier orden en estado no final sin cambio de estado por más de N días; N = 3 por defecto, valor configurable del backend. (FR-006)
- Q: ¿Qué citas cuentan como «cita del día»? → A: Solo las de hoy, pendientes o confirmadas (no canceladas). En «Clientes por avisar» se usan las citas de mañana. (FR-005, FR-019)
- Q: ¿Cuándo se actualiza el contador de la campana? → A: Al iniciar sesión, al navegar entre las pantallas principales y al abrir el panel. Sin consultas por intervalo. (FR-017)
- Q: ¿Cuál es la identidad de un aviso para la lectura? → A: Tipo + objeto + estado (por ejemplo `MANT_VENCIDO:7`). Si un aviso empeora (de Próximo a Vencido), vuelve a mostrarse como no leído. (FR-015)
- Q: ¿Cuántos días antes se avisa un mantenimiento próximo? → A: Con el mismo criterio del indicador que ya existe en Mantenimientos; no se inventan días nuevos. (FR-003)
- Q: ¿El aviso a un cliente se repite o guarda una nota? → A: Se marca una sola vez por hecho (orden, cita o mantenimiento), sin nota. Solo se marca cuando de verdad se avisó. (FR-020, FR-021)
- Q: ¿El mecánico ve avisos de mantenimiento? → A: No. Solo avisos de órdenes asignadas a él. (FR-011)

Decisiones tomadas por el agente (Carlos pidió elegir la opción más simple que cumpla los criterios de aceptación y anotarla):

- Q: ¿A qué estados reales equivalen «pendiente o confirmada»? → A: `PROGRAMADA` y `RECIBIDA`, los mismos que el panel cuenta como citas activas (así los números coinciden, CA-5). `CANCELADA` y `NO_PRESENTADA` no generan aviso. Para «cita de mañana» se usa el mismo criterio. (FR-005, FR-019)
- Q: ¿Qué es un «estado no final» de una orden? → A: **Ajustado por Carlos el 2026-11-16** (reemplaza la decisión original del agente, que incluía `TERMINADO`): cuentan `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` y `ESPERANDO_REFACCION`. Quedan fuera `TERMINADO` y `ENTREGADO`: una orden `TERMINADO` sin recoger ya aparece en «Clientes por avisar» (motivo «Vehículo listo»), así que no se duplica como orden detenida. (FR-006)
- Q: ¿Cómo se cuentan «más de N días»? → A: Han pasado más de N × 24 horas desde el último cambio de estado (o desde el alta, si no hay cambios). (FR-006)
- Q: ¿Qué «estado» entra en la clave de cada tipo? → A: Mantenimiento: Próximo o Vencido (`MANT_PROXIMO:7`, `MANT_VENCIDO:7`). Stock: Bajo o Agotado (`STOCK_BAJO:12`, `STOCK_AGOTADO:12`). Cita de hoy: la fecha de la cita (`CITA_HOY:5:2026-11-16`), para que una cita reprogramada sea un aviso nuevo. Orden detenida: el estado actual de la orden (`ORDEN_DETENIDA:9:EN_REPARACION`). Si la condición vuelve con el mismo estado (por ejemplo, la refacción se repone y vuelve a bajar), conserva la lectura. (FR-015)
- Q: ¿El aviso a un cliente por un mantenimiento se repite si pasa de Próximo a Vencido? → A: No: el hecho es el registro de mantenimiento con su objetivo vigente, no su estado. Se avisa una vez por ciclo de mantenimiento. (FR-021)
- Q: (Revisión de checklists) Si un mantenimiento es un solo registro que se actualiza al registrar el servicio, ¿cómo se distingue un ciclo del siguiente? → A: Por su objetivo vigente (fecha y kilometraje objetivo). Ese objetivo entra en la clave de lectura (`MANT_VENCIDO:7:<objetivo>`) y en el hecho de «Clientes por avisar». (FR-015, FR-021)
- Q: (Revisión de checklists) ¿Qué pasa al marcar como leído un aviso que no existe o no le corresponde al usuario? → A: Responde con éxito y no guarda nada, para no fallar ni revelar si el objeto existe. (FR-030)
- Q: (Revisión de checklists) ¿En qué orden se muestran los avisos y dónde está «Clientes por avisar»? → A: Grupos en orden fijo por urgencia, primero los no leídos, sin paginación, y «99+» en la campana (FR-007a). «Clientes por avisar» es una sección del menú lateral para ADMIN y RECEPTIONIST (FR-029).
- Q: ¿Hay «marcar todos como leídos»? → A: No en este sprint; solo uno por uno. Los avisos leídos siguen visibles en el panel, diferenciados de los no leídos, mientras la condición se cumpla. (FR-014)
- Q: ¿Qué pasa si se marca dos veces el mismo hecho como avisado? → A: Queda un solo registro; el segundo intento recibe un aviso de que ya estaba avisado (409) y la lista se refresca. (FR-020)
- Q: ¿Qué pantalla abre cada aviso? → A: Orden detenida: el detalle de la orden. Cita de hoy: la lista de Citas en la fecha de la cita (no existe una pantalla de detalle de cita). Mantenimiento: el detalle del vehículo. Stock: el detalle de la refacción. (FR-018)
- Q: ¿Cuáles son las «pantallas principales»? → A: Las secciones del menú lateral de la app. (FR-017)

## Correcciones al insumo

El insumo (`docs/sprints/sprint-6-notificaciones-internas.md`) se copió sin cambios. Estas correcciones se aplican solo en esta spec, después de una revisión ligera (solo lectura) contra el código del 2026-11-16:

| # | El insumo dice | Lo real / la corrección | Dónde aplica |
|---|---|---|---|
| C-01 | Migración `006_...sql` (secciones 5 y 10) | `006_datos_precio_congelado_copia_tickets.sql` ya existe (Sprint 5). Las migraciones de este sprint empiezan en **`007`**. | FR-024 |
| C-02 | Pruebas de integración contra `motorix_test` | La base de pruebas es **`motorix_v2_test`** (constitución, principio III). | FR-027 |
| C-03 | No fija ids para los seeds | Los seeds del Sprint 5 usan ids desde 9001 (hasta 9006 en `order_status_history`) y las suites de pruebas crean filas que, por el AUTO_INCREMENT, caen después de ellos. Los seeds del Sprint 6 usan el rango **60001 a 60099** en todas sus tablas, con claves propias identificables (por ejemplo, códigos `NOT-` y motivos que empiezan con «[Sprint 6]»). | FR-025 |
| C-04 | No menciona precios | Regla del Sprint 5 (FR-034 a FR-036 de `specs/005-...`): **MECHANIC no recibe precios ni totales en ningún aviso**. Además, ningún aviso, para ningún rol, incluye importes: los avisos no necesitan cifras de dinero. | FR-012 |
| C-05 | Referencia a `docs/sprints/propuesta-sprints-post-mvp.md` | Ese archivo **no existe**. Se usan `docs/project-context.md` §6.12 (notificaciones), §6.3, §6.6, §6.7, §6.11 y §13 (reglas RN) y la enmienda 1.1.0 de `.specify/memory/constitution.md`. | Referencias |
| C-06 | `StockAlertsProvider`, «insignia con el número de alertas en el ícono de Inventario» y «aviso en la pantalla de inicio», solo para ADMIN | **No existen** en el cliente. Lo que existe de stock es: el bloque «Alertas de inventario» del panel (solo ADMIN), el chip «Stock bajo» y el filtro «solo stock bajo» de la lista de Refacciones. CA-8 se reinterpreta: esos indicadores siguen funcionando y sus números coinciden con los avisos de stock. | FR-016 |
| C-07 | `dashboardService.js` | El archivo real es `server/services/dashboard.service.js` (con `server/models/dashboard.js`). | Referencias |
| C-08 | Estados de cita «pendiente», «confirmada» (y §6.3: pendiente, confirmada, en proceso, completada, cancelada) | Los estados reales de una cita son **`PROGRAMADA`, `RECIBIDA`, `CANCELADA` y `NO_PRESENTADA`**. El panel cuenta como citas activas `PROGRAMADA` y `RECIBIDA`. | FR-005 |
| C-09 | «Lista de Mantenimientos consultable por recepción y mecánico» | Correcto para mantenimientos. Pero **MECHANIC no tiene acceso a citas** (403 desde el Sprint 2), así que no recibe avisos de citas. | FR-010 |
| C-10 | «Contadores ... citas próximas ... en el dashboard, solo ADMIN» | Correcto: el panel es exclusivo de ADMIN (`PANEL_SOLO_ADMIN`). Los avisos no abren el panel a otros roles. | FR-010 |
| C-11 | «Orden detenida» con `order_status_history` | Correcto: el historial guarda cada cambio de estado con fecha (`changed_at`). Una orden sin cambios usa la fecha de su alta. | FR-006 |
| C-12 | «Stock bajo o agotado» | La regla de stock bajo existente es «existencia ≤ stock mínimo y stock mínimo > 0» (Sprint 3, R-10) y no excluye las refacciones inactivas (ni en el panel ni en el filtro). «Agotado» no existe como regla aparte: se define como un caso de stock bajo con existencia 0. | FR-004 |

No se encontró otra contradicción con la constitución. Los principios que aplican de forma directa son: II (solo el backend consulta MySQL), III (MySQL local, migraciones aditivas y numeradas, seeds idempotentes con datos de ejemplo), IV y V (permisos en el backend), VII (pruebas primero) y VIII (diseño según `docs/design-system.md`).

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Centro de notificaciones con contador (Prioridad: P1)

Como administrador, quiero ver en el encabezado cuántos avisos pendientes tengo para atenderlos sin recorrer cada módulo.

**Por qué esta prioridad**: es la base del sprint; las demás historias agregan tipos de aviso o acciones sobre este centro.

**Prueba independiente**: con datos de ejemplo que generan avisos, un administrador inicia sesión, ve la campana con un número y, al abrirla, ve los avisos agrupados por tipo.

**Escenarios de aceptación**:

1. **Dado** un administrador con avisos no leídos, **Cuando** inicia sesión, **Entonces** el encabezado muestra una campana con el total de avisos no leídos.
2. **Dado** el centro cerrado, **Cuando** el usuario toca la campana, **Entonces** se abre un panel con los avisos agrupados por tipo, cada grupo con su cantidad.
3. **Dado** un usuario sin avisos, **Cuando** abre el centro, **Entonces** ve un estado vacío claro y la campana no muestra número.
4. **Dado** que la consulta falla, **Cuando** el usuario abre el centro, **Entonces** ve un mensaje de error con opción de reintentar, sin bloquear el resto de la app.

---

### Historia de usuario 2 - Avisos de mantenimientos y citas para recepción (Prioridad: P2)

Como recepcionista, quiero ver los mantenimientos próximos y vencidos y las citas del día para avisar a los clientes a tiempo.

**Prueba independiente**: con un mantenimiento próximo, uno vencido y una cita de hoy, la recepcionista ve tres avisos con su tipo, y los datos coinciden con la lista de Mantenimientos y con la agenda.

**Escenarios de aceptación**:

1. **Dado** un mantenimiento cuyo indicador en la lista de Mantenimientos es «Próximo», **Cuando** la recepcionista abre el centro, **Entonces** ve un aviso «Mantenimiento próximo» con el vehículo y el servicio.
2. **Dado** un mantenimiento con indicador «Vencido», **Entonces** el aviso es «Mantenimiento vencido».
3. **Dado** una cita para hoy que cuenta como cita del día, **Entonces** aparece un aviso «Cita de hoy» con cliente, vehículo y hora.
4. **Dado** una cita cancelada o de otro día, **Entonces** no genera aviso.

---

### Historia de usuario 3 - Avisos de stock para el administrador (Prioridad: P3)

Como administrador, quiero ver las refacciones con stock bajo o agotado para reabastecer a tiempo.

**Prueba independiente**: con una refacción en stock bajo y otra en 0, el administrador ve dos avisos y la cantidad coincide con el panel y con el filtro «solo stock bajo» de Refacciones.

**Escenarios de aceptación**:

1. **Dado** una refacción con existencia menor o igual a su stock mínimo (mínimo mayor que 0), **Entonces** el administrador ve un aviso «Stock bajo» con código, nombre, existencia y mínimo.
2. **Dado** una refacción de ese grupo con existencia 0, **Entonces** el aviso dice «Agotado».
3. **Dado** una recepcionista o un mecánico, **Entonces** el servidor no les devuelve ningún aviso de stock.

---

### Historia de usuario 4 - Órdenes detenidas (Prioridad: P4)

Como administrador o recepcionista, quiero ver las órdenes detenidas para destrabarlas.

**Prueba independiente**: con una orden sin cambio de estado desde hace más del umbral, el administrador y la recepcionista ven el aviso; al cambiarle el estado, el aviso desaparece.

**Escenarios de aceptación**:

1. **Dado** una orden en `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` o `ESPERANDO_REFACCION` cuyo último cambio de estado fue hace más del umbral, **Entonces** aparece un aviso «Orden detenida» con el número de orden, el vehículo, el estado actual y los días sin cambio.
2. **Dado** que la orden cambia de estado, **Cuando** se vuelve a consultar, **Entonces** el aviso ya no aparece.
3. **Dado** una orden `TERMINADO` o `ENTREGADO` sin cambios desde hace más del umbral, **Entonces** no genera aviso de orden detenida (la `TERMINADO` sin recoger aparece en «Clientes por avisar»).

---

### Historia de usuario 5 - Avisos del mecánico (Prioridad: P5)

Como mecánico, quiero ver solo los avisos de mis órdenes asignadas para no recibir información que no me corresponde.

**Prueba independiente**: con una orden detenida asignada al mecánico A y otra al mecánico B, cada uno ve solo la suya; ninguno recibe avisos de stock, citas, mantenimientos ni importes.

**Escenarios de aceptación**:

1. **Dado** un mecánico con una orden asignada detenida, **Entonces** ve ese aviso.
2. **Dado** una orden detenida asignada a otro mecánico o sin asignar, **Entonces** no la ve.
3. **Dado** cualquier aviso que reciba el mecánico, **Entonces** no incluye precios, subtotales ni totales.

---

### Historia de usuario 6 - Marcar como leído y abrir el módulo (Prioridad: P6)

Como usuario, quiero marcar un aviso como leído y abrir el módulo relacionado desde él para dar seguimiento rápido.

**Prueba independiente**: un usuario marca un aviso como leído, el contador baja en 1, el aviso sigue visible como leído, y otro usuario sigue viéndolo como no leído.

**Escenarios de aceptación**:

1. **Dado** un aviso no leído, **Cuando** el usuario lo marca como leído, **Entonces** el contador baja en 1 y el aviso queda como leído para ese usuario.
2. **Dado** el mismo aviso, **Cuando** otro usuario abre su centro, **Entonces** lo sigue viendo como no leído.
3. **Dado** un aviso, **Cuando** el usuario lo toca, **Entonces** se abre la pantalla relacionada: orden, cita, vehículo (para mantenimientos) o refacción.
4. **Dado** un aviso leído cuya condición deja de cumplirse, **Entonces** desaparece del centro.

---

### Historia de usuario 7 - Clientes por avisar (Prioridad: P7)

Como recepcionista, quiero una lista de clientes por avisar (vehículo listo, cita de mañana, mantenimiento próximo o vencido) con su teléfono, y marcar cada uno como avisado, para contactarlos por teléfono o en persona sin olvidar ni repetir avisos.

**Prueba independiente**: con una orden terminada sin entregar, recepción ve al cliente con teléfono, vehículo y motivo; lo marca como avisado y sale de la lista, con registro de quién y cuándo.

**Escenarios de aceptación**:

1. **Dado** una orden `TERMINADO` sin entregar, **Entonces** el cliente aparece con nombre, teléfono, vehículo y motivo «Vehículo listo».
2. **Dado** una cita de mañana o un mantenimiento próximo o vencido, **Entonces** el cliente aparece con el motivo correspondiente.
3. **Dado** un renglón, **Cuando** recepción lo marca como avisado, **Entonces** sale de la lista y queda registrado quién lo marcó y cuándo.
4. **Dado** un hecho ya avisado, **Cuando** surge un hecho nuevo para el mismo cliente (otra orden, otra cita), **Entonces** el cliente aparece de nuevo por ese hecho.
5. **Dado** un mecánico, **Cuando** intenta consultar la lista o marcar un aviso, **Entonces** el servidor responde 403.

---

### Flujo demostrable al cierre del sprint

1. Con los datos de ejemplo hay un mantenimiento vencido, una cita para hoy, una refacción con stock bajo y una orden detenida.
2. El administrador inicia sesión; la campana muestra el total de avisos.
3. Abre el centro y ve los cuatro tipos agrupados.
4. Toca el aviso de stock y llega a Refacciones.
5. Marca un aviso como leído y el contador baja.
6. La recepcionista inicia sesión y solo ve mantenimientos, citas y órdenes detenidas.
7. El mecánico solo ve avisos de sus órdenes.
8. Recepción abre «Clientes por avisar», ve al cliente de la orden terminada con su teléfono y lo marca como avisado.
9. El cliente sale de la lista y queda registrado quién lo avisó y cuándo.

### Casos límite

- Un mantenimiento sin objetivo de fecha ni de kilometraje es «Normal» y no genera aviso.
- Un mantenimiento cumple por kilometraje y por fecha a la vez: genera un solo aviso con el estado más grave.
- Una refacción inactiva con stock bajo sí genera aviso, igual que hoy aparece en el panel y en el filtro «solo stock bajo» (la regla existente no filtra por activa; cambiarla queda fuera de este sprint).
- Una refacción con stock mínimo 0 no genera aviso aunque su existencia sea 0 (regla existente).
- Una orden sin historial de cambios usa la fecha de alta para medir los días sin cambio.
- Una orden detenida sin mecánico asignado: la ven ADMIN y RECEPTIONIST, ningún mecánico.
- Un cliente con varios hechos pendientes aparece una vez por cada hecho en «Clientes por avisar».
- Dos recepcionistas marcan el mismo hecho como avisado casi al mismo tiempo: queda un solo registro; la segunda recibe una respuesta que indica que ya estaba avisado.
- Un usuario marca como leído un aviso que ya dejó de existir o que no le corresponde: la operación no falla, no guarda nada y no afecta su contador (FR-030).
- Un mantenimiento avisado al cliente y luego realizado: al registrar el servicio cambia el objetivo; cuando el siguiente ciclo llegue a Próximo, el cliente vuelve a aparecer (FR-021).
- Un vehículo cuyo kilometraje se actualiza en otra orden: el aviso de mantenimiento por kilometraje se recalcula en la siguiente consulta.
- Un aviso de un objeto que ya no existe (orden, cita o refacción borrada o desactivada) deja de mostrarse.
- Un cliente sin teléfono no es posible: el teléfono es obligatorio desde el Sprint 1.
- Cambio de día con la app abierta: los avisos «de hoy» se recalculan en la siguiente actualización del contador (al navegar o abrir el panel).
- Un mantenimiento leído como Próximo pasa a Vencido: aparece como aviso nuevo no leído.
- Una cita reprogramada a hoy desde otro día: es un aviso nuevo (la clave incluye la fecha).
- Una orden que pasa a `TERMINADO` deja de ser orden detenida y pasa a «Clientes por avisar» (motivo «Vehículo listo»); nunca está en las dos listas a la vez.
- Una orden detenida que cambia de estado deja de estar detenida; si vuelve a pasar más de N días sin cambio en el nuevo estado, es un aviso nuevo.

## Requisitos *(obligatorio)*

### Requisitos funcionales

**Cálculo de avisos**

- **FR-001**: El sistema DEBE calcular los avisos al momento de consultarlos, a partir de los datos actuales de mantenimientos, citas, refacciones y órdenes. Los avisos no se copian a otra tabla; solo se guardan la lectura por usuario (FR-013) y los avisos a clientes (FR-019).
- **FR-002**: Tipos de aviso del centro: mantenimiento próximo, mantenimiento vencido, cita de hoy, stock bajo, stock agotado y orden detenida.
- **FR-003**: Los avisos de mantenimiento DEBEN usar exactamente el cálculo del indicador de la lista de Mantenimientos (Normal, Próximo, Vencido), con la antelación propia de cada registro o la antelación por defecto ya existente, y el kilometraje vigente del vehículo. Se consideran los mismos registros que muestra la lista de Mantenimientos. «Normal» no genera aviso.
- **FR-004**: Los avisos de stock DEBEN usar exactamente la regla existente de stock bajo del panel y del filtro de Refacciones (existencia ≤ stock mínimo y stock mínimo > 0). Esa regla hoy no excluye las refacciones inactivas; para que los números coincidan (FR-008), los avisos tampoco las excluyen. Si la existencia es 0, el aviso es «Agotado»; si no, «Stock bajo».
- **FR-005**: Avisos de cita de hoy: una cita genera aviso si su fecha es hoy y su estado es `PROGRAMADA` o `RECIBIDA` (pendiente o confirmada). Las citas `CANCELADA` o `NO_PRESENTADA` y las de otros días no generan aviso en el centro.
- **FR-006**: Avisos de orden detenida: una orden en estado no final (`RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` o `ESPERANDO_REFACCION`; nunca `TERMINADO` ni `ENTREGADO`) está detenida si han pasado más de N × 24 horas desde su último cambio de estado registrado o, si no hay cambios, desde su alta. N vale 3 por defecto y es un valor configurable del backend (no se captura en la interfaz).
- **FR-007**: Cada aviso DEBE incluir: tipo, título legible, descripción breve (cliente o vehículo, servicio, refacción u orden, según el tipo), fecha de referencia, si está leído para el usuario, y el destino para abrir la pantalla relacionada. Fecha de referencia por tipo: mantenimiento, la fecha objetivo (o, si solo tiene kilometraje, la fecha del cálculo); cita, la fecha y hora de la cita; stock, la fecha del cálculo; orden detenida, la fecha del último cambio de estado (o del alta).
- **FR-007a**: Los grupos del panel siguen este orden fijo: mantenimiento vencido, orden detenida, stock agotado, stock bajo, cita de hoy, mantenimiento próximo. Dentro de cada grupo, primero los no leídos y luego por fecha de referencia (la más antigua primero). El panel muestra todos los avisos, sin paginación. La campana muestra el número hasta 99 y «99+» si hay más.
- **FR-008**: Los números del centro DEBEN coincidir con los de las otras pantallas cuando la población es la misma: mantenimientos próximos y vencidos con la lista de Mantenimientos; stock bajo con el panel y el filtro «solo stock bajo»; citas de hoy con el bloque de citas de hoy del panel.

**Permisos por rol**

- **FR-009**: ADMIN recibe todos los tipos de aviso.
- **FR-010**: RECEPTIONIST recibe mantenimientos próximos y vencidos, citas de hoy y órdenes detenidas; nunca avisos de stock.
- **FR-011**: MECHANIC recibe solo avisos de orden detenida de órdenes asignadas a él; nunca avisos de stock, de citas (no tiene acceso a citas) ni de mantenimientos.
- **FR-012**: Ningún aviso, para ningún rol, incluye precios, subtotales, totales ni otros importes (corrección C-04).
- **FR-013**: El servidor filtra los avisos por rol y por asignación; ocultar elementos en la interfaz no basta (RN-15). Las consultas de avisos y de clientes por avisar requieren sesión iniciada.

**Lectura**

- **FR-014**: Un usuario puede marcar un aviso como leído, uno por uno; la lectura se guarda por usuario, con la fecha, y no afecta a otros usuarios. Los avisos leídos siguen visibles en el panel, diferenciados de los no leídos, mientras su condición se cumpla; el contador solo cuenta los no leídos.
- **FR-015**: Cada aviso tiene una clave formada por tipo + objeto + estado: `MANT_PROXIMO:<id>:<objetivo>`, `MANT_VENCIDO:<id>:<objetivo>` (el objetivo es la fecha y el kilometraje objetivo vigentes del registro: como cada mantenimiento es un solo registro que se actualiza al hacer el servicio, el objetivo distingue un ciclo del siguiente), `STOCK_BAJO:<id>`, `STOCK_AGOTADO:<id>`, `CITA_HOY:<id>:<fecha>` y `ORDEN_DETENIDA:<id>:<estado de la orden>`. La lectura se asocia a esa clave: si el aviso cambia de estado (por ejemplo, de Próximo a Vencido o de Bajo a Agotado) es un aviso nuevo y aparece como no leído; si vuelve con la misma clave, conserva la lectura.
- **FR-016**: Los indicadores de stock existentes (bloque «Alertas de inventario» del panel, chip «Stock bajo» y filtro «solo stock bajo» de Refacciones) siguen funcionando sin cambios y no se contradicen con los avisos de stock (corrección C-06).
- **FR-017**: El encabezado muestra una campana con el total de avisos no leídos del usuario y, al tocarla, un panel con los avisos agrupados por tipo. El contador se actualiza al iniciar sesión, al navegar entre las pantallas principales (las secciones del menú lateral) y al abrir el panel; no hay consultas automáticas por intervalo.
- **FR-018**: Tocar un aviso lo marca como leído (si no lo estaba) y abre la pantalla relacionada (ajuste M1 del análisis, igual que el contrato de la interfaz): el detalle de la orden (orden detenida), la lista de Citas en la fecha de la cita (cita de hoy), el detalle del vehículo (mantenimientos) o el detalle de la refacción (stock). El centro maneja estados de carga, vacío y error según `docs/design-system.md`.

**Clientes por avisar**

- **FR-019**: ADMIN y RECEPTIONIST ven la lista «Clientes por avisar», con cliente, teléfono, vehículo y motivo. Motivos: vehículo listo (orden `TERMINADO` sin entregar), cita de mañana (`PROGRAMADA` o `RECIBIDA`, mismo criterio que FR-005), mantenimiento próximo y mantenimiento vencido (mismo indicador que FR-003).
- **FR-020**: Marcar un renglón como avisado guarda el cliente, el motivo, el hecho (orden, cita o mantenimiento), quién lo marcó y cuándo, sin nota; el renglón sale de la lista. La interfaz deja claro que solo se marca cuando de verdad se avisó (confirmación antes de guardar). Un hecho se puede marcar una sola vez: un segundo intento recibe 409 con el mensaje de que ya estaba avisado.
- **FR-021**: Un hecho ya avisado no vuelve a aparecer, aunque cambie su estado (un mantenimiento avisado como Próximo no reaparece al vencer). Un hecho nuevo del mismo cliente (otra orden, otra cita, otro mantenimiento) sí aparece. El hecho de un mantenimiento es el registro **con su objetivo vigente** (fecha y kilometraje objetivo): cuando se registra el servicio y el objetivo cambia, el siguiente ciclo es un hecho nuevo.
- **FR-029**: La lista «Clientes por avisar» es una sección del menú lateral, visible solo para ADMIN y RECEPTIONIST. Se ordena por motivo (vehículo listo, cita de mañana, mantenimiento vencido, mantenimiento próximo) y, dentro de cada motivo, por fecha (la más antigua primero). Maneja estados de carga, vacío y error según `docs/design-system.md`. No tiene paginación.
- **FR-030**: Marcar como leído una clave que no está entre los avisos actuales del usuario (porque dejó de existir o porque no le corresponde a su rol) responde con éxito y no guarda nada; así no falla y no revela si el objeto existe. Una petición sin sesión responde 401.
- **FR-022**: MECHANIC no accede a la lista ni puede marcar avisos; el servidor responde 403.
- **FR-023**: El registro de cliente avisado no se edita ni se borra desde la app (no hay bitácora ni historial de avisos en este sprint).

**Datos, pruebas y documentación**

- **FR-024**: Las tablas nuevas (lectura de avisos y avisos a clientes) se crean con migraciones aditivas y numeradas desde `007` (corrección C-01).
- **FR-025**: Un seed idempotente del sprint agrega al menos un caso de cada tipo de aviso y de cada motivo de «Clientes por avisar», con ids en el rango 60001 a 60099 (corrección C-03). Si se carga dos veces, no duplica registros. Las fechas relativas («hoy», «mañana», «hace N días») se calculan al cargar el seed para que los avisos existan el día de la demostración.
- **FR-026**: Pruebas obligatorias: cálculo de cada tipo de aviso, permisos por rol, lectura por usuario, clientes por avisar (marcar, no repetir, hecho nuevo) y rendimiento de la consulta.
- **FR-027**: Las pruebas se ejecutan contra `motorix_v2_test` (corrección C-02); la línea base (64 suites y 545 pruebas en el backend, 155 en Flutter) sigue pasando.
- **FR-028**: Se actualizan `docs/project-context.md` §6.12 y `docs/design-system.md` (campana, panel y lista) en el mismo sprint.

### Reglas de negocio aplicables

`docs/project-context.md` §13:

- **RN-5**: Solo usuarios autorizados pueden consultar y modificar registros.
- **RN-8**: No permitir stock negativo (los avisos de stock parten de la regla de stock bajo existente).
- **RN-10**: No duplicar información: los avisos se derivan de los datos existentes.
- **RN-11**: Los próximos mantenimientos se basan en fecha, kilometraje o ambos.
- **RN-15**: Los permisos deben validarse en backend.

### Entidades clave *(incluido porque la funcionalidad implica datos)*

- **Aviso** (calculado, no se guarda): tipo, objeto relacionado (orden, cita, mantenimiento o refacción), estado del objeto, título, descripción, fecha de referencia, destino y si está leído para el usuario.
- **Lectura de aviso** (se guarda): usuario, clave del aviso y fecha de lectura. Una sola por usuario y clave.
- **Cliente por avisar** (calculado): cliente, teléfono, vehículo, motivo y hecho (orden, cita o mantenimiento).
- **Aviso a cliente** (se guarda): cliente, motivo, hecho (orden, cita, o mantenimiento con su objetivo vigente), usuario que avisó y fecha. Uno solo por hecho.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Con los datos de ejemplo, un administrador ve al iniciar sesión la campana con al menos un aviso de cada tipo y llega a la pantalla relacionada de cualquiera de ellos en 2 toques o menos.
- **SC-002**: El 100 % de las pruebas de permisos confirma que cada rol recibe solo sus tipos de aviso y que ningún aviso del mecánico ni de otro rol incluye importes.
- **SC-003**: Para la misma fecha y los mismos datos, el número de mantenimientos próximos, vencidos, citas de hoy y stock bajo del centro es igual al de la lista de Mantenimientos, al panel y al filtro de Refacciones en el 100 % de los casos probados.
- **SC-004**: Marcar un aviso como leído reduce el contador en exactamente 1 para ese usuario y en 0 para los demás.
- **SC-005**: Un hecho marcado como avisado no reaparece en «Clientes por avisar» en el 100 % de los casos probados, y un hecho nuevo del mismo cliente sí aparece.
- **SC-006**: Con 10 veces el volumen de los datos de ejemplo, la consulta de avisos de un administrador responde en menos de 1 segundo en el equipo de desarrollo, medida como la mediana de 3 consultas después de una de calentamiento (para que una corrida con la suite completa en paralelo no dé un resultado intermitente).
- **SC-007**: El seed del sprint cargado dos veces deja los mismos conteos, y la línea base de pruebas sigue en verde (backend y Flutter).
- **SC-008**: El flujo demostrable (9 pasos) se completa en menos de 10 minutos.

## Supuestos

- «Hoy» y «mañana» se calculan con la fecha local del servidor, igual que el panel.
- Las antelaciones de mantenimiento son las del registro o, si no tiene, las existentes por defecto (30 días y 500 km); no se inventan días nuevos.
- Las lecturas de avisos que ya no existen se pueden quedar guardadas; no afectan contadores.
- No hay notificaciones en tiempo real ni consultas por intervalo: el contador se actualiza por acciones del usuario (FR-017).
- El valor N de orden detenida es igual para los cuatro estados no finales; no hay un N distinto por estado.
- Los avisos a clientes los hace una persona (por teléfono o en persona); el sistema solo registra que se hicieron.

## Fuera de alcance

- Envío automático de avisos a clientes por WhatsApp, correo o SMS.
- Notificaciones en tiempo real (WebSocket) o del sistema operativo.
- Preferencias por usuario sobre qué avisos recibir.
- Historial o bitácora de avisos pasados; notas en el aviso a cliente.
- Reportes y configuración del taller (Sprint 7).

## Trazabilidad

| Requisito de alto nivel | Historia | Requisitos |
|---|---|---|
| §6.12 Notificaciones internas | US1, US6 | FR-001, FR-007, FR-007a, FR-014 a FR-018 |
| §6.6 Mantenimiento preventivo | US2 | FR-003, FR-008 |
| §6.3 Citas | US2 | FR-005 |
| §6.7 Inventario | US3 | FR-004, FR-016 |
| §6.4 Órdenes | US4, US5 | FR-006, FR-011 |
| §5 Roles y RN-15 | US5 | FR-009 a FR-013, FR-022 |
| Atención a clientes | US7 | FR-019 a FR-023, FR-029 |
| Seguridad (RN-5, RN-15) | US5, US6 | FR-030 |
| Constitución III y VII | — | FR-024 a FR-028 |
