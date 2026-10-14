# Especificación de la Funcionalidad: Pagos, Tickets y Dashboard

**Rama de la funcionalidad**: `004-pagos-tickets-dashboard`

**Fecha de creación**: 2026-10-13

**Estado**: Borrador

**Input**: Descripción del usuario: "Usa la descripcion de @docs/sprints/sprint-4-pagos-tickets-dashboard.md"

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Registrar el pago de una orden (Prioridad: P1)

Como recepcionista, quiero registrar el pago de una orden terminada para cerrar el
ciclo del servicio y que quede constancia del cobro.

**Por qué esta prioridad**: es el corazón del sprint: sin cobro no hay cierre del
servicio ni dato para el ticket ni para el dashboard. Es la historia que convierte el
taller operativo en un taller que factura.

**Prueba independiente**: se puede probar registrando el pago de una orden entregada y
verificando que el pago queda guardado, ligado a esa orden y visible en su detalle.

**Escenarios de aceptación**:

1. **Dado** una orden en estado `TERMINADO` con su total calculado, **Cuando** el
   recepcionista registra el pago con monto, método y fecha, **Entonces** el pago queda
   guardado, ligado a la orden y el estado del pago es `PAGADO`.
2. **Dado** una orden que ya tiene un pago `PAGADO` por su total, **Cuando** el
   recepcionista intenta registrar otro pago, **Entonces** el sistema rechaza la
   operación indicando que la orden ya está liquidada.
3. **Dado** un pago registrado, **Cuando** se consulta el detalle de la orden,
   **Entonces** el monto, el método, la fecha y el estado del pago son visibles junto
   al total.
4. **Dado** una orden que no está en un estado cobrable (por ejemplo `RECIBIDO`),
   **Cuando** se intenta registrar un pago, **Entonces** el sistema rechaza la
   operación con un mensaje claro.

---

### Historia de usuario 2 - Seleccionar el método de pago (Prioridad: P2)

Como recepcionista, quiero elegir cómo se pagó (efectivo, tarjeta, transferencia o
Mercado Pago) para dejar constancia fiel de la forma de cobro.

**Por qué esta prioridad**: el método de pago es un dato obligatorio del cobro y
alimenta el ticket y los indicadores; sin él, el registro de pago quedaría incompleto.

**Prueba independiente**: se puede probar registrando pagos con cada método permitido y
verificando que cada uno queda guardado con su etiqueta correcta en el ticket.

**Escenarios de aceptación**:

1. **Dado** una orden terminada, **Cuando** el recepcionista registra un pago en
   efectivo, **Entonces** el método `EFECTIVO` queda guardado y el pago pasa a
   `PAGADO`.
2. **Dado** una orden terminada, **Cuando** el recepcionista registra un pago con
   tarjeta o transferencia, **Entonces** los métodos `TARJETA` y `TRANSFERENCIA`
   quedan guardados con su etiqueta legible en el ticket.
3. **Dado** el formulario de pago, **Cuando** no se elige método, **Entonces** el
   sistema muestra un mensaje de validación y no guarda el pago.

---

### Historia de usuario 3 - Gestionar pagos con Mercado Pago (Prioridad: P3)

Como recepcionista, quiero ofrecer el pago por Mercado Pago en modo de pruebas para
que el cliente pueda pagar de forma digital sin exponer datos de su tarjeta.

**Por qué esta prioridad**: es un canal adicional, no el cobro básico; el taller ya
cobra en efectivo con la US1. Se planifica después para no arriesgar el cierre del MVP.

**Prueba independiente**: se puede probar iniciando un pago por Mercado Pago en modo
sandbox y verificando que el pago queda `PENDIENTE` hasta la confirmación y que en
ningún momento se guarda un dato de tarjeta.

**Escenarios de aceptación**:

1. **Dado** una orden terminada, **Cuando** el recepcionista elige Mercado Pago,
   **Entonces** el sistema genera el cobro digital y el pago queda en estado
   `PENDIENTE` hasta que se confirme.
2. **Dado** un pago `PENDIENTE` por Mercado Pago, **Cuando** la plataforma confirma la
   aprobación, **Entonces** el pago pasa a `PAGADO` y la orden queda liquidada.
3. **Dado** un pago por Mercado Pago, **Cuando** la plataforma informa un rechazo o
   cancelación, **Entonces** el pago queda `RECHAZADO` (o `CANCELADO`) y la orden
   permite intentar de nuevo.
4. **Dado** el flujo completo de Mercado Pago, **Cuando** se revisa qué se guardó,
   **Entonces** no existe ningún dato de tarjeta ni credencial del proveedor en el
   sistema (RN‑14).

---

### Historia de usuario 4 - Generar el ticket de servicio (Prioridad: P4)

Como recepcionista, quiero generar e imprimir el ticket de la orden para entregar un
comprobante físico o digital al cliente.

**Por qué esta prioridad**: el ticket depende de que exista un pago y su contenido; se
construye sobre la US1/US2.

**Prueba independiente**: se puede probar generando el ticket de una orden pagada y
verificando que incluye todos los datos del comprobante y que puede visualizarse e
imprimirse.

**Escenarios de aceptación**:

1. **Dado** una orden pagada, **Cuando** el recepcionista genera el ticket,
   **Entonces** el ticket queda guardado con folio único e incluye: folio, datos del
   taller, cliente, vehículo, placas, kilometraje, servicios, refacciones, mano de
   obra, subtotal, total, método de pago, estado del pago y fecha.
2. **Dado** un ticket generado, **Cuando** se vuelve a generar para la misma orden,
   **Entonces** se conserva el mismo folio (no se duplica).
3. **Dado** un ticket generado, **Cuando** el recepcionista lo abre e imprime,
   **Entonces** se visualiza con formato de comprobante y se puede imprimir.
4. **Dado** una orden sin pago, **Cuando** se intenta generar el ticket, **Entonces**
   el sistema indica que primero debe registrarse el pago.

---

### Historia de usuario 5 - Panel de control con información general (Prioridad: P5)

Como administrador, quiero consultar un panel de control con la información general del
taller para supervisar su operación en un solo lugar.

**Por qué esta prioridad**: es una vista de supervisión; no es necesaria para cobrar ni
para entregar tickets, pero cierra el ciclo de gestión del MVP.

**Prueba independiente**: se puede probar abriendo el panel y verificando que los
indicadores coinciden con los datos reales registrados en el sistema.

**Escenarios de aceptación**:

1. **Dado** un administrador autenticado, **Cuando** abre el panel de control,
   **Entonces** ve los indicadores generales del taller calculados con datos reales.
2. **Dado** un usuario que no es administrador, **Cuando** intenta abrir el panel,
   **Entonces** el sistema no le permite el acceso.
3. **Dado** el panel con datos registrados, **Cuando** se comparan los indicadores con
   los registros individuales, **Entonces** los números coinciden (sin datos
   duplicados).

---

### Historia de usuario 6 - Órdenes, citas, mantenimientos y alertas en el dashboard (Prioridad: P6)

Como administrador, quiero ver en el dashboard las órdenes, las citas, los
mantenimientos y las alertas de inventario para anticipar pendientes del taller.

**Por qué esta prioridad**: complementa la US5 con el detalle operativo; se entrega al
final porque se apoya en los datos de los sprints 2 y 3.

**Prueba independiente**: se puede probar registrando una orden, una cita, un
mantenimiento próximo y una refacción en stock bajo, y verificando que cada uno aparece
en su bloque del dashboard.

**Escenarios de aceptación**:

1. **Dado** el dashboard, **Cuando** existen órdenes y citas registradas,
   **Entonces** se muestran sus resúmenes correspondientes con datos reales.
2. **Dado** un mantenimiento próximo o vencido, **Cuando** se abre el dashboard,
   **Entonces** aparece en su bloque correspondiente.
3. **Dado** una refacción con stock bajo, **Cuando** se abre el dashboard,
   **Entonces** aparece en las alertas de inventario.
4. **Dado** el taller sin datos en un bloque, **Cuando** se abre el dashboard,
   **Entonces** ese bloque muestra un estado vacío amigable, sin errores.

---

### Casos límite

- ¿Qué pasa cuando se intenta registrar un pago sobre una orden ya pagada o en un
  estado no cobrable?
- ¿Cómo maneja el sistema un pago por Mercado Pago que nunca recibe confirmación?
- ¿Qué sucede si el cliente quiere pagar solo una parte del total?
- ¿Cómo se comporta el ticket de una orden sin servicios ni refacciones registrados?
- ¿Qué ve el administrador en el dashboard cuando el taller no tiene datos en un
  bloque (primer arranque)?
- ¿Qué ocurre si se intenta generar un ticket dos veces para la misma orden?
- ¿Cómo se evita que un usuario sin permisos registre pagos o consulte el dashboard?

## Requisitos funcionales *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE permitir registrar el pago de una orden con monto,
  método, fecha y estado, ligándolo siempre a una orden existente (RN‑13).
- **FR-002**: El sistema DEBE soportar los métodos de pago `EFECTIVO`, `TARJETA`,
  `TRANSFERENCIA` y `MERCADO_PAGO` (CA‑2).
- **FR-003**: El sistema DEBE validar en el backend que solo los roles autorizados
  (recepción y administración) registren o consulten pagos (RN‑15).
- **FR-004**: El sistema DEBE rechazar el registro de un pago cuando la orden ya
  tenga un pago aprobado por su total, o cuando su estado no permita el cobro.
- **FR-005**: El sistema DEBE gestionar los pagos por Mercado Pago en modo sandbox,
  iniciando el cobro digital y actualizando el estado del pago (`PENDIENTE`,
  `PAGADO`, `RECHAZADO`, `CANCELADO`) según la respuesta del proveedor.
- **FR-006**: El sistema NO DEBE almacenar datos de tarjeta ni credenciales del
  procesador de pagos (RN‑14); las credenciales del proveedor se manejan fuera del
  código, por variables de entorno (CA‑7).
- **FR-007**: El sistema DEBE generar un ticket por orden pagada, con folio único, que
  incluya: folio, datos del taller, cliente, vehículo, placas, kilometraje, servicios,
  refacciones, mano de obra, subtotal, total, método de pago, estado del pago y fecha
  (CA‑4).
- **FR-008**: El sistema DEBE permitir visualizar e imprimir el ticket generado
  (CA‑5).
- **FR-009**: El sistema DEBE impedir generar un ticket de una orden que no tenga un
  pago aprobado.
- **FR-010**: El sistema DEBE ofrecer un panel de control visible únicamente para el
  administrador, calculado con datos reales y sin duplicar información (CA‑6, RN‑15).
- **FR-011**: El panel DEBE mostrar como mínimo: resumen de órdenes, citas,
  mantenimientos próximos/vencidos y alertas de stock bajo del inventario.
- **FR-012**: El sistema DEBE conservar las órdenes entregadas con sus pagos y tickets
  como historial (RN‑9), sin eliminaciones ordinarias.
- **FR-013**: Los datos de ejemplo (seeds) DEBEN incluir pagos y tickets de muestra
  para que el taller muestre información al instalar, y DEBEN ser idempotentes.

### Entidades clave *(incluido porque el rasgo implica datos)*

- **Pago**: representa el cobro de una orden; incluye monto, método, estado
  (`PENDIENTE`, `PAGADO`, `RECHAZADO`, `CANCELADO`), fecha y la orden a la que
  pertenece; referencia externa cuando el cobro es por Mercado Pago.
- **Ticket**: comprobante de la orden; incluye folio único, datos del taller, cliente,
  vehículo, kilometraje, servicios, refacciones, mano de obra, subtotal, total, método
  y estado del pago, y fecha; nace de una orden pagada.
- **Orden de servicio** (existente): ahora también consulta su total y su pago para
  cerrar el ciclo.
- **Datos del dashboard** (consulta): órdenes, citas, mantenimientos y movimientos de
  inventario ya registrados en los sprints anteriores; el panel solo los resume, sin
  crear copias.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: El recepcionista puede registrar un pago completo en menos de 1 minuto,
  desde abrir la orden hasta ver el pago guardado.
- **SC-002**: El 100 % de los pagos registrados quedan ligados a una orden existente
  (verificable consultando los pagos huérfanos: deben ser cero).
- **SC-003**: El ticket generado incluye el 100 % de los campos del comprobante
  (CA‑4) en una sola vista, imprimible sin perder información.
- **SC-004**: El flujo de Mercado Pago en sandbox se completa (inicio → confirmación →
  estado `PAGADO`) en menos de 5 minutos y sin persistir ningún dato sensible.
- **SC-005**: El dashboard carga en menos de 5 segundos y sus indicadores coinciden al
  100 % con los datos registrados (sin duplicados).
- **SC-006**: Ningún usuario sin rol de administración logra abrir el panel de control
  (0 accesos no autorizados).
- **SC-007**: Tras la instalación inicial, el taller ve pagos y tickets de ejemplo en
  la aplicación sin capturar datos a mano.

## Supuestos

- **Un pago por orden**: el MVP asume que cada orden se liquida con un único pago por
  su total; los pagos parciales quedan fuera de alcance (se documenta como decisión
  abierta).
- **Ticket imprimible, sin PDF almacenado**: el ticket se visualiza e imprime desde la
  propia aplicación; no se generan ni se archivan archivos PDF en el servidor (la
  librería y el formato exacto se definen en la fase de planificación).
- **Confirmación de Mercado Pago**: el cobro digital inicia una preferencia de pago en
  modo sandbox y el estado del pago se actualiza cuando la plataforma informa el
  resultado; no se automatiza el envío de notificaciones al cliente.
- **Sin reembolsos en el MVP**: no se implementa devolución de dinero; si se necesita
  corregir un pago, queda como decisión abierta (ver marcadores de aclaración).
- **Dashboard al abrir**: los indicadores se calculan al abrir el panel (y con acción
  de actualizar); no hay actualización en tiempo real ni alertas push.
- **Folio del ticket**: consecutivo único asignado al generar el ticket.
- **Moneda**: montos en pesos mexicanos con dos decimales, consistente con los precios
  ya registrados en el sistema.

**Fuera de alcance de esta funcionalidad** (definido por el insumo del sprint):
chatbot de WhatsApp, facturación electrónica, envío automático de correos o mensajes al
cliente, reportes avanzados o analítica histórica y aplicación móvil nativa.
