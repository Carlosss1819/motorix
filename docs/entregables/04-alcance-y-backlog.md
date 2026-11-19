# 04. Enunciado del alcance y Product Backlog

**Proyecto:** Motorix, sistema de gestión para un taller mecánico
**Elaboró:** Carlos Castro Rafael
**Fecha de corte de los datos:** 2026-11-19 (rama `006-notificaciones-internas`)

> Fuentes: `.specify/memory/constitution.md` (versión 1.1.0), `docs/project-context.md`, los insumos de `docs/sprints/` y las especificaciones y tareas de `specs/`. Las historias se copian tal como están escritas en esos archivos.

## 1. Enunciado del alcance

### 1.1 Descripción del producto

Motorix concentra en un solo sistema la información de clientes, vehículos, citas, órdenes de servicio, inventario de refacciones y pagos de un taller mecánico, para que cada visita forme parte del expediente digital del vehículo y sirva para consultar su historial y anticipar los próximos mantenimientos (`docs/project-context.md` §2).

**Usuarios:** administrador, recepcionista y mecánico.

**Objetivos medibles** (`docs/project-context.md` §3):

- Centralizar el 100 % de la información de clientes, vehículos, servicios e inventario registrada en el sistema.
- Registrar el 100 % de los servicios realizados para mantener actualizado el historial de cada vehículo.
- Generar recordatorios de mantenimiento con base en las fechas y el kilometraje registrados.

### 1.2 Qué entra en el alcance

| Bloque | Contenido | Estado |
|---|---|---|
| **MVP: Sprint 1** | Inicio de sesión, usuarios y roles, clientes y vehículos. | Terminado |
| **MVP: Sprint 2** | Citas y órdenes de servicio (diagnóstico, servicios, recomendaciones, estados). | Terminado |
| **MVP: Sprint 3** | Historial del vehículo, próximo mantenimiento e inventario de refacciones con alertas de stock bajo. | Terminado |
| **MVP: Sprint 4** | Pagos (incluye Mercado Pago en sandbox), tickets y dashboard. | Terminado |
| **Sprint 5** | Precios de refacciones, precio congelado, cobro completo y ticket por pago. | Terminado |
| **Sprint 6** | Notificaciones internas por rol y lista de clientes por avisar. | Terminado (en la rama `006-notificaciones-internas`) |
| **Sprint 7** | Reportes y configuración del taller; costeo, margen de ganancia, utilidad y reportes financieros (según las referencias de los insumos de los sprints 5 y 6). | Pendiente `[COMPLETAR: insumo docs/sprints/sprint-7-*.md con historias de usuario]` |
| **Despliegue para la demostración** | Backend, frontend web y MySQL 8 en hosting, solo para la demostración escolar. | Pendiente `[COMPLETAR: proveedor de hosting y fecha]` |
| **Aviso de privacidad** | Visible dentro de la app, por solicitud del profesor. | Pendiente `[COMPLETAR: texto del aviso de privacidad, revisado con el profesor]` |

Origen del alcance posterior al MVP: acuerdo del equipo por WhatsApp el 2026-11-11 y solicitud del profesor; registrado en la enmienda 1.1.0 de la constitución (2026-11-13). Los sprints se hacen en orden y uno a la vez.

### 1.3 Qué NO entra en el alcance

Recopilado de las secciones «Fuera de alcance» de los insumos de `docs/sprints/` y de la constitución:

**Integraciones y canales**

- Chatbot de WhatsApp (solo como integración externa futura).
- Envío automático de avisos o mensajes al cliente por cualquier canal (WhatsApp, correo, SMS): el aviso lo hace recepción y el sistema solo lo registra.
- Notificaciones en tiempo real por WebSocket o notificaciones del sistema operativo.
- Aplicación móvil nativa.

**Finanzas y facturación**

- Facturación electrónica e impuestos.
- Descuentos, promociones y pagos parciales o a plazos.
- Reembolsos dentro del sistema.
- Catálogo de proveedores y órdenes de compra.
- Reportes avanzados o analítica histórica (salvo lo que defina el Sprint 7).

**Cuentas y preferencias**

- Registro público de usuarios.
- Recuperación de contraseña por correo.
- Preferencias por usuario sobre qué avisos recibir.
- Historial o bitácora de avisos pasados.
- Modo oscuro.

**Sprints opcionales (8 a 10)**

- Quedan fuera del alcance oficial. Según el insumo del Sprint 5, ahí caen WhatsApp (dentro del rango «Sprints 6 a 9») y las fotos del vehículo y la puesta en producción (Sprint 10). `[COMPLETAR: contenido exacto de los sprints 8 y 9; la propuesta docs/sprints/propuesta-sprints-post-mvp.md citada por el insumo del Sprint 6 no está en el repositorio]`. Cada integrante puede hacerlos en su propia versión registrando antes su propia enmienda.

### 1.4 Supuestos, restricciones y riesgos

- **Supuesto:** el taller cuenta con internet y con personal que puede usar el sistema.
- **Restricción:** Mercado Pago depende de su disponibilidad y de la conexión; se usa en modo de prueba.
- **Restricción técnica:** stack MENF (MySQL, Express, Node, Flutter); base local para desarrollo y pruebas.
- **Riesgos:** resistencia del personal al cambio, registros incorrectos o incompletos, fallas de internet y dependencia de servicios externos (`docs/project-context.md` §18).

## 2. Product Backlog

**Cómo leer el backlog:**

- **Prioridad:** la que asigna la especificación de cada sprint (`P1` = más importante). En el Sprint 1 y el Sprint 2 la especificación agrupó o reordenó las historias del insumo; la columna «Insumo» muestra la correspondencia.
- **Estado:** se toma de `specs/NNN-nombre/tasks.md` (tareas marcadas `[x]` frente a `[ ]`). **Terminado** = todas las tareas de la historia están marcadas.

### Resumen por épica

| Épica | Sprint | Especificación | Historias | Tareas en `tasks.md` | Estado |
|---|---|---|---|---|---|
| E1. Base del sistema, clientes y vehículos | 1 | `specs/001-base-clientes-vehiculos` | 6 (insumo) / 5 (spec) | 80 de 86 | Terminado (6 tareas de cierre sin marcar) |
| E2. Citas y órdenes de servicio | 2 | `specs/002-citas-ordenes-servicio` | 7 (insumo) / 6 (spec) | 79 de 79 | Terminado |
| E3. Historial, mantenimiento e inventario | 3 | `specs/003-historial-inventario` | 8 | 75 de 75 | Terminado |
| E4. Pagos, tickets y dashboard | 4 | `specs/004-pagos-tickets-dashboard` | 6 | 63 de 63 | Terminado |
| E5. Precios de refacciones y cobro completo | 5 | `specs/005-precios-refacciones-cobro` | 5 | 88 de 89 | Terminado (1 tarea no ejecutada por decisión) |
| E6. Notificaciones internas | 6 | `specs/006-notificaciones-internas` | 7 | 68 de 68 | Terminado |
| E7. Reportes y configuración del taller | 7 | No existe todavía | `[COMPLETAR]` | — | Pendiente |

### E1. Sprint 1: Base del sistema, clientes y vehículos

Objetivo: permitir que un usuario autorizado inicie sesión, gestione clientes y registre vehículos asociados a un propietario.

| ID | Historia de usuario | Insumo | Prioridad | Estado |
|---|---|---|---|---|
| S1-US1 | Como usuario del taller (administrador, recepcionista o mecánico), quiero iniciar sesión con mi usuario o mi correo electrónico y mi contraseña para acceder a las funciones que corresponden a mi rol. | US1 | P1 | Terminado |
| S1-US3 | Como recepcionista, quiero registrar clientes y consultarlos para mantener actualizada la información de los propietarios que atiende el taller. | US3 | P2 | Terminado |
| S1-US5/US6 | Como recepcionista, quiero registrar un vehículo y asociarlo a su propietario para llevar el control de los automóviles que atiende el taller. | US5 y US6 | P3 | Terminado |
| S1-US4 | Como recepcionista, quiero editar los datos de un cliente para corregir o actualizar su información sin perder la relación con sus vehículos. | US4 | P4 | Terminado |
| S1-US2 | Como administrador, quiero crear usuarios, asignarles un rol y activarlos o desactivarlos para controlar quién puede usar el sistema. | US2 | P5 | Terminado |

Nota: en `tasks.md` quedan sin marcar 6 tareas de la fase final de pulido y cierre (T079, T080, T082, T083, T085 y T086: revisión visual, confirmaciones, corrida final de suites, validación del quickstart, confirmación de la decisión R-04 y reporte final). No pertenecen a una historia concreta.

### E2. Sprint 2: Citas y órdenes de servicio

Objetivo: que recepción registre citas y cree órdenes de servicio, y que el mecánico consulte sus órdenes, registre diagnóstico, servicios y recomendaciones, y actualice el estado.

| ID | Historia de usuario | Insumo | Prioridad | Estado |
|---|---|---|---|---|
| S2-H1 | Como recepcionista, quiero registrar una orden de servicio que asocie a un cliente y un vehículo, y consultarla después, para que el trabajo del taller quede documentado desde la llegada del vehículo. | US2 y US3 | P1 | Terminado |
| S2-H2 | Como recepcionista, quiero registrar, consultar, cancelar y marcar como recibida una cita, para organizar la llegada de vehículos y poder derivarla a una orden de servicio cuando el cliente llega. | US1 | P2 | Terminado |
| S2-H3 | Como mecánico, quiero ver solo las órdenes de servicio que están asignadas a mí, para saber qué trabajos atender sin ver trabajo ajeno. | US4 | P3 | Terminado |
| S2-H4 | Como mecánico, quiero registrar el diagnóstico, los servicios realizados, las recomendaciones y los repuestos utilizados en una orden asignada, para que quede constancia técnica del trabajo. | US5 y US7 | P4 | Terminado |
| S2-H5 | Como recepcionista o mecánico, quiero avanzar la orden por sus estados (recibido, diagnóstico, en reparación, esperando refacción, terminado, entregado), para que todos vean en qué punto está el trabajo. | US6 | P5 | Terminado |
| S2-H6 | Como recepcionista, quiero ver las citas del día y las órdenes abiertas en una sola vista, para planificar el trabajo del taller. | Agregada en la especificación | P6 | Terminado |

Historia del insumo integrada en otra: US7 («Como mecánico, quiero agregar observaciones y recomendaciones para dejar constancia del estado del vehículo») quedó dentro de S2-H4.

### E3. Sprint 3: Historial, mantenimiento e inventario

Objetivo: mantener el historial de servicios por vehículo, dar seguimiento a los próximos mantenimientos y controlar el inventario con alertas de stock bajo.

| ID | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| S3-US1 | Como mecánico, quiero consultar el historial de servicios de un vehículo para conocer su estado y antecedentes. | P1 | Terminado |
| S3-US2 | Como mecánico, quiero registrar el kilometraje de cada servicio para mantener actualizado el historial. | P2 | Terminado |
| S3-US3 | Como mecánico, quiero establecer el próximo mantenimiento para programar el siguiente servicio. | P3 | Terminado |
| S3-US4 | Como recepcionista, quiero consultar los mantenimientos próximos para avisar al cliente. | P4 | Terminado |
| S3-US5 | Como administrador, quiero registrar y consultar refacciones para controlar el inventario. | P5 | Terminado |
| S3-US6 | Como administrador, quiero consultar el stock disponible para saber qué hay en existencia. | P6 | Terminado |
| S3-US7 | Como mecánico, quiero agregar refacciones utilizadas a una orden para reflejar su uso. | P7 | Terminado |
| S3-US8 | Como administrador, quiero visualizar alertas de stock bajo para reabastecer a tiempo. | P8 | Terminado |

### E4. Sprint 4: Pagos, tickets y dashboard

Objetivo: registrar pagos de una orden (incluido Mercado Pago en sandbox), generar tickets de servicio y consultar un panel de control.

| ID | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| S4-US1 | Como recepcionista, quiero registrar el pago de una orden terminada para cerrar el ciclo del servicio y que quede constancia del cobro. | P1 | Terminado |
| S4-US2 | Como recepcionista, quiero elegir cómo se pagó (efectivo, tarjeta, transferencia o Mercado Pago) para dejar constancia fiel de la forma de cobro. | P2 | Terminado |
| S4-US3 | Como recepcionista, quiero ofrecer el pago por Mercado Pago en modo de pruebas para que el cliente pueda pagar de forma digital sin exponer datos de su tarjeta. | P3 | Terminado |
| S4-US4 | Como recepcionista, quiero generar e imprimir el ticket de la orden para entregar un comprobante físico o digital al cliente. | P4 | Terminado |
| S4-US5 | Como administrador, quiero consultar un panel de control con la información general del taller para supervisar su operación en un solo lugar. | P5 | Terminado |
| S4-US6 | Como administrador, quiero ver en el dashboard las órdenes, las citas, los mantenimientos y las alertas de inventario para anticipar pendientes del taller. | P6 | Terminado |

### E5. Sprint 5: Precios de refacciones y cobro completo

Objetivo: congelar el precio de venta de una refacción al agregarla a una orden, incluirlo en el total, el pago y el ticket, conservar intactos los pagos y tickets emitidos y restringir el precio de compra por rol.

| ID | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| S5-US1 | Como administrador, quiero registrar y mantener la categoría, la marca y los precios de compra y de venta de una refacción, con validaciones, para conocer el costo y el precio de cada pieza. | P1 | Terminado |
| S5-US2 | Como recepcionista, quiero que el total de la orden incluya las refacciones con el precio de venta congelado al agregarlas, para cobrar el trabajo completo sin que un cambio posterior del catálogo altere el importe. | P2 | Terminado |
| S5-US3 | Como recepcionista, quiero que el pago y el ticket reflejen el total con refacciones congeladas, para entregar un comprobante correcto al cliente. | P3 | Terminado |
| S5-US4 | Como administrador, quiero que un cambio de precio no altere órdenes abiertas ni pagos y tickets ya emitidos, para conservar la integridad del historial. | P4 | Terminado |
| S5-US5 | Como mecánico, quiero seguir usando las refacciones en una orden sin recibir sus precios (de compra, de venta ni el precio congelado de la línea), para no exponer información financiera del taller; recepción recibe el precio de venta y solo el administrador el de compra. | P5 | Terminado |

Nota: la tarea T084 (pasos de interfaz y cronometraje del criterio SC-006) quedó «No ejecutada por decisión de Carlos (2026-11-16)»; el flujo se cubrió con un recorrido por API documentado en `docs/evidencias/`.

### E6. Sprint 6: Notificaciones internas

Objetivo: que cada usuario vea en el encabezado un centro de notificaciones con los avisos de su rol, calculados con datos reales, y pueda marcarlos como leídos.

| ID | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| S6-US1 | Como administrador, quiero ver en el encabezado cuántos avisos pendientes tengo para atenderlos sin recorrer cada módulo. | P1 | Terminado |
| S6-US2 | Como recepcionista, quiero ver los mantenimientos próximos y vencidos y las citas del día para avisar a los clientes a tiempo. | P2 | Terminado |
| S6-US3 | Como administrador, quiero ver las refacciones con stock bajo o agotado para reabastecer a tiempo. | P3 | Terminado |
| S6-US4 | Como administrador o recepcionista, quiero ver las órdenes detenidas para destrabarlas. | P4 | Terminado |
| S6-US5 | Como mecánico, quiero ver solo los avisos de mis órdenes asignadas para no recibir información que no me corresponde. | P5 | Terminado |
| S6-US6 | Como usuario, quiero marcar un aviso como leído y abrir el módulo relacionado desde él para dar seguimiento rápido. | P6 | Terminado |
| S6-US7 | Como recepcionista, quiero una lista de clientes por avisar (vehículo listo, cita de mañana, mantenimiento próximo o vencido) con su teléfono, y marcar cada uno como avisado, para contactarlos por teléfono o en persona sin olvidar ni repetir avisos. | P7 | Terminado |

Nota: el Sprint 6 está terminado y registrado en el commit `c07f962` de la rama `006-notificaciones-internas`; esa rama (con los sprints 5 y 6) todavía no se ha fusionado a `main`.

### E7. Sprint 7: Reportes y configuración del taller

| ID | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| S7-US? | `[COMPLETAR: historias de usuario del Sprint 7; aún no existe docs/sprints/sprint-7-*.md ni specs/007-*]` | `[COMPLETAR]` | Pendiente |

Lo único que el repositorio dice del Sprint 7 está en los «Fuera de alcance» de los sprints anteriores: «Costeo, margen de ganancia, utilidad y reportes financieros (Sprint 7)» (insumo del Sprint 5) y «Reportes y configuración del taller (Sprint 7)» (insumo del Sprint 6).

### Elementos del alcance que no son épicas de sprint

| Elemento | Estado |
|---|---|
| Despliegue en hosting para la demostración escolar | Pendiente `[COMPLETAR: proveedor y fecha]` |
| Aviso de privacidad visible en la app | Pendiente `[COMPLETAR: texto y ubicación en la app]` |

## 3. Trazabilidad con los requisitos de alto nivel

| Requisito de alto nivel (`docs/project-context.md` §4) | Épicas |
|---|---|
| 1. Como recepcionista quiero gestionar clientes, vehículos, citas y órdenes de servicio. | E1, E2 |
| 2. Como mecánico necesito consultar el historial y seguimiento de mantenimiento de los vehículos. | E3, E6 |
| 3. Como administrador deseo controlar el inventario y stock de refacciones. | E3, E5, E6 |
| 4. Como recepcionista puedo registrar pagos mediante Mercado Pago. | E4, E5 |
| 5. Como recepcionista necesito generar tickets de servicio. | E4, E5 |
| 6. Como administrador requiero consultar la información general del taller desde un panel de control. | E4, E7 |
| 7. Como administrador puedo gestionar los usuarios y sus roles de acceso. | E1 |
