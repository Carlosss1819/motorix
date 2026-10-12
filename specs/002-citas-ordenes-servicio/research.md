# Investigación (Fase 0)

**Funcionalidad**: Gestión de Citas y Órdenes de Servicio (`002-citas-ordenes-servicio`)
**Fecha**: 2026-10-12 | **Plan**: [plan.md](plan.md)

No quedan incógnitas marcadas como NEEDS CLARIFICATION en el Contexto Técnico: el stack
está fijado por la constitución y validado en el Sprint 1. Lo que sí requería decisión
era el comportamiento operativo (estados, permisos por transición, conflictos de cita y
kilometraje), resuelto aquí a partir de `spec.md`, `docs/project-context.md` y
`docs/reglas.md`.

---

## R‑01: Reutilización del stack y de las pruebas del Sprint 1

- **Decisión**: sin dependencias ni estructuras nuevas. Se agregan archivos a las capas
  existentes de `server/` y `client/`; las pruebas siguen con Jest + supertest contra
  `motorix_v2_test` y `flutter test`.
- **Rationale**: la constitución (Principios II y III) fija el stack; repetir el patrón
  de Sprint 1 (routes → controllers → services → models, con `validate` + `authorize`)
  reduce el riesgo y mantiene la coherencia de la API.
- **Alternativas consideradas**: ORM o librería de colas de estados (descartado: fuera
  del núcleo permitido y resoluble en pocas líneas); rehacer estructura de carpetas
  (descartado: decisión ya resuelta en el Sprint 1).

## R‑02: Máquina de estados de la orden de servicio

- **Decisión**: los estados son `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`,
  `ESPERANDO_REFACCION`, `TERMINADO` y `ENTREGADO`, con este mapa de transiciones
  válidas (todo lo demás se rechaza con mensaje claro):

  ```text
  RECIBIDO        → DIAGNOSTICO
  DIAGNOSTICO     → EN_REPARACION | ESPERANDO_REFACCION | TERMINADO
  EN_REPARACION   → ESPERANDO_REFACCION | TERMINADO
  ESPERANDO_REFACCION → DIAGNOSTICO | EN_REPARACION | TERMINADO
  TERMINADO       → ENTREGADO
  ENTREGADO       → (ninguna; orden cerrada e inmutable)
  ```

  Toda orden nace en `RECIBIDO` (cita o no) y cada transición se registra en
  `order_status_history` con usuario, fecha y estado anterior (FR‑014, FR‑015).
- **Rationale**: es exactamente la secuencia de `docs/project-context.md` §6.4 y de la
  aclaración del 2026‑10‑11; `ESPERANDO_REFACCION` se modela como desvío reversible
  (escenario 3 de la HU5), y `TERMINADO → ENTREGADO` cierra el ciclo con fecha de
  entrega. El mapa se implementa como objeto de constantes en
  `server/services/service_order.service.js`, sin librería externa.
- **Alternativas consideradas**: grafo con transiciones arbitrarias por rol
  (descartado: más difícil de probar y no exige la spec); estados libres que el
  frontend decide (descartado: la constitución exige validar en backend).

## R‑03: Quién puede realizar cada transición (FR‑022)

- **Decisión**: matriz de autorización comprobada en `service` (no solo en la ruta):

  | Transición | `MECHANIC` asignado | `RECEPTIONIST` | `ADMIN` |
  |------------|--------------------|----------------|---------|
  | Alta en `RECIBIDO` y asignación de mecánico | no | sí | sí |
  | `RECIBIDO → DIAGNOSTICO` | sí | no | sí |
  | `DIAGNOSTICO/EN_REPARACION/ESPERANDO_REFACCION ↔` y `→ TERMINADO` | sí | no | sí |
  | `→ ENTREGADO` (desde `TERMINADO`) | no | sí | sí |
  | Edición de datos de la orden (motivo, fecha, asignación) | no | sí | sí |

  Un `MECHANIC` solo opera órdenes cuyo `mechanic_id` es el suyo (FR‑010); el rol
  `MECHANIC` no accede a `/api/appointments` (403).
- **Rationale**: reproduce literalmente la aclaración del 2026‑10‑11 y FR‑020/FR‑022,
  y satisface RN‑05 y RN‑15 (permisos en backend).
- **Alternativas consideradas**: autorizar solo por rol (descartado: permitiría a un
  mecánico avanzar órdenes ajenas); validar solo ocultando botones (descartado: viola
  la constitución, Principio IV).

## R‑04: Asignación y reasignación de mecánico

- **Decisión**: manual por recepción. El mecánico es opcional al crear la orden y se
  asigna o reasigna desde el detalle (`POST /api/service-orders/:id/asignar`, aceptando
  `mecanicoId: null` para desasignar). Se rechaza con `409` si la orden está en
  `TERMINADO` o `ENTREGADO` (FR‑009, escenario 4 de la HU3). El listado del mecánico se
  filtra por `mechanic_id = usuario` y excluye las órdenes sin asignar (FR‑010).
- **Rationale**: aclaración del 2026‑10‑11 ("asignación opcional al alta y reasignable
  después"); el alta manual es suficiente para un taller pequeño.
- **Alternativas consideradas**: asignación automática por disponibilidad/carga
  (descartado por la aclaración explícita); asignación obligatoria al alta (descartado:
  la orden debe poder ingresar sin mecánico).

## R‑05: Conflicto de horario entre citas (FR‑008)

- **Decisión**: hay conflicto cuando otra cita en la misma `fecha` y `hora` comparte el
  **mismo vehículo** y su estado es `PROGRAMADA` o `RECIBIDA`. El backend responde `409`
  con `{ pendienteConfirmacion: true, aviso, confirmarReenvio: true }`; la segunda
  llamada con `confirmar: true` guarda la cita. Dos vehículos distintos en el mismo
  horario no generan conflicto.
- **Rationale**: es el patrón de aviso‑y‑confirmación ya usado en clientes (teléfono
  repetido) y coincide con el escenario 5 de la HU2 ("aviso de conflicto… no se guarda
  sin confirmación explícita") y con el caso límite "mismo vehículo". Como las citas no
  llevan mecánico (entidad de `spec.md`), no puede evaluar conflicto por mecánico.
- **Alternativas consideradas**: bloquear el `409` sin posibilidad de confirmar
  (descartado: el escenario exige confirmación, no veto); comparar contra cualquier cita
  del día (descartado: dos vehículos distintos pueden coincidir en hora).

## R‑06: Detección de citas no presentadas (FR‑006)

- **Decisión**: cálculo **perezoso y persistente**: al listar o consultar citas, toda
  cita `PROGRAMADA` con `fecha + hora` ya pasados se actualiza a `NO_PRESENTADA` en la
  misma consulta. No hay cron ni proceso en segundo plano.
- **Rationale**: sin dependencias ni timers (la app corre en la máquina local y puede
  apagarse), el estado queda guardado para que el listado sea estable y auditable.
- **Alternativas consideradas**: job programado cada minuto (descartado: proceso
  adicional y estado inconsistente si la app está cerrada); calcular el estado solo al
  mostrar sin persistir (descartado: haría imposible filtrar por `NO_PRESENTADA` y
  registrar el cambio).

## R‑07: Borrador de diagnóstico (FR‑011, FR‑019)

- **Decisión**: la orden guarda `diagnosis` (texto) y `diagnosis_draft` (booleano).
  "Guardar borrador" persiste el texto con `diagnosis_draft = true`; "Guardar y
  continuar" lo persiste con `diagnosis_draft = false`. Al salir de la pantalla sin
  guardar, el frontend descarta lo no persistido (FR‑019). Un borrador nunca cuenta
  como diagnóstico completo para transiciones y se marca como tal en el detalle.
- **Rationale**: la RN‑11 del insumo del sprint y FR‑011 piden un borrador guardado;
  hacerlo explícito en backend evita perder trabajo y permite verificarlo con pruebas.
- **Alternativas consideradas**: borrador solo en memoria del frontend (descartado:
  FR‑011 dice "guardarse como borrador", es decir, persistir); tabla aparte
  `order_drafts` (descartado: sobrediseño para un solo campo).

## R‑08: Validación del primer kilometraje (supuesto 3, pendiente de cierre)

- **Decisión**: se aplica FR‑018 literalmente. El kilometraje de entrada se compara con
  el de la **última orden del mismo vehículo**; si no hay orden previa, se acepta el
  valor indicado (≥ 0). Si es menor que la orden previa, el backend responde `400` salvo
  que la petición incluya `correccionKilometraje` (texto obligatorio), que solo
  `ADMIN` puede enviar; la corrección se guarda en
  `service_orders.mileage_correction_note`. Al guardar una orden, si el kilometraje es
  mayor que `vehicles.current_mileage`, se actualiza el del vehículo.
- **Rationale**: cierra el supuesto diferido del checklist: FR‑018 ya fija "acepta el
  primer kilometraje cuando no exista valor previo", y la constitución (Principio V)
  exige que un valor menor solo sea posible con **corrección explícita** — de ahí el
  motivo obligatorio registrado. Actualizar `vehicles.current_mileage` mantiene
  coherente el dato del Sprint 1 sin duplicar fuentes (RN‑03, RN‑04).
- **Alternativas consideradas**: exigir ≥ `vehicles.current_mileage` en la primera
  orden (descartado: contradicto por FR‑018 y puede bloquear la recepción si el dato del
  vehículo está desactualizado); bloquear siempre sin corrección (descartado: viola el
  Principio V, que admite corrección explícita); permitir la corrección a recepción sin
  motivo (descartado: sin rastro no es "explícita").

## R‑09: Panel de recepción (HU6)

- **Decisión**: sin endpoint nuevo. El panel compone en el frontend dos llamadas ya
  existentes: `GET /api/appointments?fecha=<hoy>` y
  `GET /api/service-orders?estadoAbierta=true`, con estados vacío y de carga propios
  ("sin actividades" cuando ambas vienen vacías, escenario 3).
- **Rationale**: evita duplicar lógica de consulta y estadísticos en el backend; la HU6
  es comodidad de vista, no una consulta nueva.
- **Alternativas consideradas**: endpoint agregado `/api/reception/summary`
  (descartado: duplica filtros y obliga a mantener dos caminos para el mismo dato).

## R‑10: Búsqueda, filtros y paginación (FR‑003)

- **Decisión**: parámetros de consulta en las listas — órdenes:
  `?estado=&buscar=&pagina=&porPagina=` (`buscar` sobre placas, nombre o apellido del
  cliente); citas: `?fecha=&estado=&buscar=`. Respuesta paginada
  `{ elementos, pagina, paginas, total }` con `porPagina` por defecto 10 y máximo 50.
- **Rationale**: mantiene el patrón REST del Sprint 1 y cumple "con paginación" de
  FR‑003 sin depender de librerías externas de paginación.
- **Alternativas consideradas**: listado completo sin paginar (descartado: FR‑003 lo
  exige); paginación por cursor (descartado: innecesario al volumen del MVP).

## R‑11: Trazabilidad de las reglas de negocio (acción correctiva del gate I) ⚠ conflicto abierto

- **Decisión (para implementar)**: la numeración de referencia es la de
  `docs/project-context.md` §13 (lista 1‑17). Mapeo correcto de las reglas citadas en
  `spec.md`:

  | Cita en `spec.md` | Regla real (§13) | Comentario |
  |--------------------|------------------|------------|
  | RN‑02 (orden sin cliente/válido) | **RN‑02** y **RN‑01** | correcta; RN‑01 cubre vehículo con propietario |
  | RN‑06 (secuencia de estados) | §6.4 *Estados principales* + **RN‑05** | §13 no tiene RN de estados; el número 6 corresponde a refacciones |
  | RN‑07 (cambio de estado con usuario/fecha; entregado inmutable) | **RN‑09** | el 7 corresponde a salida de inventario (Sprint 3) |
  | RN‑08 (visión de órdenes por rol) | **RN‑05** y **RN‑15** | el 8 corresponde a stock negativo (Sprint 3) |
  | RN‑11 (borrador de diagnóstico) | sin RN equivalente | referenciar FR‑011 en lugar de una RN |
  | RN‑13 (permisos de citas/órdenes) | **RN‑05** y **RN‑15** | el 13 corresponde a pagos (Sprint 4) |
  | RN‑14 (orden exige cliente y vehículo) | **RN‑01** y **RN‑02** | el 14 corresponde a datos sensibles de pago |
  | RN‑15 (historial del vehículo) | **RN‑10** (historial derivado) + **RN‑03**/**RN‑04** (kilometraje) | el 15 corresponde a permisos en backend, que sí aplica a FR‑012/FR‑020 |
  | "definidas en `docs/reglas.md`" | `docs/project-context.md` §13 | `docs/reglas.md` no numera las reglas |

- **Decisión de alcance**: este plan implementa el **comportamiento** correcto en todos
  los casos (las reglas ya están bien descritas en los FR); la corrección es textual y
  se hace en `spec.md` durante la implementación, dejando constancia en el reporte final.
- **Rationale**: Principio I — si cambia una regla o su referencia, la fuente de verdad
  debe quedar alineada para que código y planeación no se contradigan.
- **Alternativas consideradas**: renumerar `docs/project-context.md` (descartado: rompe
  la trazabilidad de los sprints ya entregados 1 y 3/4, que citan esos números).

## R‑12: Datos de ejemplo del sprint (FR‑021, SC‑006)

- **Decisión**: `database/seeds/002_ejemplos_citas_ordenes.sql` con ids fijos e
  `INSERT IGNORE`: al menos 5 citas (2 `PROGRAMADA` de hoy, 1 `CANCELADA`, 1
  `RECIBIDA`, 1 pasada para `NO_PRESENTADA`) y 4 órdenes en estados variados
  (`RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `TERMINADO`), con su historial de
  estados, servicios, mano de obra y repuestos de ejemplo, apuntando a clientes,
  vehículos y usuarios ya sembrados en el Sprint 1.
- **Rationale**: exige la constitución (seeds visibles al arrancar y no duplicables) y
  SC‑006; los ids fijos + `INSERT IGNORE` son el mismo mecanismo idempotente ya usado en
  `001_datos_iniciales.sql`.
- **Alternativas consideradas**: seeds en JavaScript (descartado: el esquema y los datos
  viven en `database/`); reinsertar clientes/vehículos propios (descartado: duplicaría
  datos del Sprint 1).

## R‑13: Cómo se registran servicios, mano de obra y repuestos (FR‑012)

- **Decisión**: registrar un servicio desde la interfaz crea en la misma transacción una
  fila en `order_services` y su partida en `order_labor` (con duración y precio
  opcional); los repuestos van directo a `order_parts` con su cantidad (≥ 1). Todo se
  agrega mientras la orden no esté `ENTREGADO`; desde `ENTREGADO` el backend rechaza
  altas y bajas con `409` (FR‑016, escenario 5 de la HU4). Se permite eliminar una fila
  ya agregada (servicio, partida o repuesto) antes de `ENTREGADO` para corregir errores
  de captura, dejando la orden cerrada de solo lectura después.
- **Rationale**: el insumo del sprint pide las tablas `order_services` y `order_labor`,
  y la HU4 pide "servicios con su nombre y duración… con su mano de obra asociada"; una
  escritura atómica evita servicios sin mano de obra. La eliminación limitada cumple el
  Principio VIII (confirmación en acciones destructivas) sin permitir alterar historial.
- **Alternativas consideradas**: una sola tabla `order_services` con columna de duración
  (descartado: el insumo del sprint pide `order_labor` y Sprint 3/4 facturarán la mano de
  obra por separado); tablas independientes sin relación (descartado: dejaría partidas de
  mano de obra huérfanas); edición libre de la orden ya entregada (descartado: RN‑09 y
  FR‑016).

## R‑14: Pantallas y navegación por rol

- **Decisión**: se añaden al sidebar solo los módulos del sprint y del rol:
  `ADMIN` y `RECEPTIONIST` ven **Citas**, **Órdenes** e **Inicio (panel de
  recepción)**; `MECHANIC` ve **Mis órdenes** e **Inicio**. Pantallas nuevas:
  listado y formulario de citas, listado de órdenes (con filtros), formulario de orden
  (precargable desde una cita recibida) y detalle de orden (asignación, estados,
  diagnóstico, servicios, repuestos y recomendaciones). Los chips de estado comparten
  color con el design system (verde completado, ámbar advertencia/`ESPERANDO_REFACCION`,
  rojo error/`CANCELADA`).
- **Rationale**: Principio VIII y `docs/project-context.md` §16 (solo módulos del
  sprint actual y del rol); las pantallas reutilizan `app_shell`, tokens y widgets
  comunes ya existentes.
- **Alternativas consideradas**: un único panel con pestañas para todo (descartado:
  impide el filtrado por rol en servidor y complica la navegación); pantallas nuevas con
  layout propio (descartado: rompe la consistencia visual).
