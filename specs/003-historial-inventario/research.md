# Investigación (Fase 0)

**Funcionalidad**: Historial, mantenimiento e inventario (`003-historial-inventario`)
**Fecha**: 2026-10-13 | **Plan**: [plan.md](plan.md)

Decisiones técnicas previas al diseño. Los números de requisito (FR/HU/SC) y de reglas de
negocio (RN) son los del [spec.md](spec.md) y de `docs/project-context.md` §13.

---

## R‑01: Historial como vista derivada de las órdenes (FR‑001 a FR‑004, RN‑10)

- **Decisión**: sin tabla de historial. `GET /api/vehicles/:id/history` consulta
  `service_orders` con `status IN ('TERMINADO','ENTREGADO')` del vehículo, uniendo
  `order_services`, `order_parts`, `order_labor` y `diagnosis`/`recommendations` de la
  misma orden; se pagina con el patrón R‑10 (`pagina` por defecto 1, `porPagina`
  por defecto 10, máximo 50) y se ordena por `entry_date`/`id` descendente (lo más
  reciente primero, manteniendo el orden cronológico dentro de la página). Cada entrada
  expone: fecha del servicio (`entry_date`), kilometraje (`entry_mileage`), orden
  relacionada, diagnóstico, servicios realizados, refacciones utilizadas, observaciones
  (`visit_reason`) y recomendaciones.
- **Rationale**: RN‑10 y el supuesto "no se crea un registro de historial separado que
  pueda desincronizarse"; SC‑001 pide 10+ servicios en menos de 5 segundos, volumen que
  una consulta indexada resuelve sin tablas de resumen. `visit_reason` es el campo
  heredado que mejor representa "las observaciones" de FR‑002 (por qué vino el cliente).
- **Alternativas consideradas**: tabla `vehicle_history` poblada al cerrar la orden
  (descartada: duplica datos, viola RN‑10 y exige un proceso de sincronización);
  endpoint agregado único para todos los vehículos (descartado: se pide el historial
  *de un vehículo*).

## R‑02: Índices y rendimiento del historial (SC‑001)

- **Decisión**: la migración `003` agrega `idx_service_orders_vehicle_status`
  (`vehicle_id`, `status`) sobre `service_orders` si no existe un índice equivalente;
  las uniones sobre `order_*` ya usan sus `KEY idx_*_order` creados en el Sprint 2.
- **Rationale**: el filtro por vehículo + estado es la clave de acceso del historial;
  con él, SC‑001 se cumple por construcción (índice → filas del vehículo, no barrido de
  la tabla).
- **Alternativas consideradas**: consultar sin índice y confiar en el volumen del MVP
  (descartado: deja SC‑001 sin garantía a medida que crece el historial).

## R‑03: Kilometraje del servicio y no‑regresión (FR‑005 a FR‑007)

- **Decisión**: el kilometraje del historial es `service_orders.entry_mileage`, el
  registrado al abrir la orden (ya validado en el Sprint 2 con la regla de no‑regresión
  y `mileage_correction_note` para la corrección del administrador). El kilometraje del
  vehículo se mantiene con el helper existente `models/vehicle.js`
  (`UPDATE vehicles SET current_mileage = ? WHERE id = ? AND current_mileage < ?`),
  que ya garantiza FR‑007 (siempre el valor más alto). Este sprint no toca la regla de
  apertura: solo la reutiliza y la comprueba con pruebas nuevas.
- **Rationale**: FR‑005 a FR‑007 declaran comportamiento "heredado del Sprint 2"
  (así lo dice FR‑006); reimplementarlo sería duplicar lógica y arriesgar regresiones.
- **Alternativas consideradas**: registrar kilometraje aparte al cerrar la orden
  (descartado: crearía dos fuentes de verdad y FR‑005 fija el de apertura).

## R‑04: Motor de estados del mantenimiento (FR‑008 a FR‑012, RN‑11, RN‑12)

- **Decisión**: módulo puro `server/utils/maintenance-status.js` (mismo patrón que
  `order-transitions.js` del Sprint 2) que recibe un mantenimiento + fecha actual +
  kilometraje actual del vehículo y devuelve `normal | proximo | vencido`. Los estados
  **no se persisten**: se calculan en cada consulta, en dos reglas:
  1. **vencido** si `hoy >= fecha_objetivo` o `kilometraje_actual >= kilometraje_objetivo`
     (lo que ocurra primero, FR‑012);
  2. **próximo** si `fecha_objetivo − hoy <= antelacion_dias` o
     `kilometraje_objetivo − kilometraje_actual <= antelacion_km` (FR‑011, con
     antelación propia por registro, por defecto 30 días / 500 km según la
     clarificación del 2026‑10‑13);
  3. en otro caso, **normal**. Si el mantenimiento solo tiene fecha objetivo, la rama de
     kilómetros no participa, y viceversa.
- **Rationale**: calcular al consultar evita estados desactualizados (un vehículo que
  avanza de km o un calendario que pasa sin que nadie "toque" el registro); el módulo
  puro se prueba sin base de datos. `docs/project-context.md` §13 RN‑11/RN‑12 piden
  "por fecha y/o kilometraje" e "intervalos configurables por mantenimiento".
- **Alternativas consideradas**: columna `status` persistida con job que la refresque
  (descartada: requiere proceso programado y se desincroniza — la app puede estar
  apagada días); calcular en el SQL con `CASE` (descartada: lógica duplicada entre
  consultas y sin pruebas unitarias limpias).

## R‑05: Renovación del mantenimiento al realizarse el servicio (FR‑015)

- **Decisión**: `POST /api/maintenance/:id/realizar` (MECHANIC/ADMIN) recibe
  `fechaServicio` y `kilometrajeServicio` opcionales (por defecto: hoy y el
  `current_mileage` del vehículo) y, **en una sola transacción**: actualiza
  `last_service_date`/`last_service_mileage`, recalcula
  `target_date = fechaServicio + interval_days` y
  `target_mileage = kilometrajeServicio + interval_km` (cada objetivo solo si el
  intervalo correspondiente está configurado) y actualiza
  `vehicles.current_mileage` con el helper de no‑regresión si el kilometraje supera al
  vigente. Si no hay **ningún** intervalo configurado y el body no trae los nuevos
  objetivos, la operación se rechaza con `400 MANTENIMIENTO_SIN_INTERVALO`. Unicidad
  garantizada por `UNIQUE (vehicle_id, service_type)`: nunca se crea un registro nuevo.
- **Rationale**: la clarificación del 2026‑10‑13 fija "el mismo registro se renueva…
  sin duplicados"; una transacción evita dejar el registro a medias si algo falla.
- **Alternativas consideradas**: crear un registro nuevo y archivar el anterior
  (descartada: la aclaración lo prohibe explícitamente); marcar "realizado" sin
  recalcular y exigir que el mecánico cree el siguiente (descartada: reintroduce la
  duplicación y más pasos).

## R‑06: Catálogo de refacciones frente a la lista heredada de la orden (FR‑016 a FR‑023, RN‑6)

- **Decisión**: tabla nueva `parts` (catálogo con `code` único) y `order_parts` gana la
  columna `part_id` (nullable) con FK a `parts`, agregada **por ALTER en la migración
  003** (los scripts 001/002 no se editan, Principio III). Al agregar una refacción a
  una orden, `description` se llena con el nombre del catálogo (copia de seguridad
  histórica: aunque la refacción se desactive o se edite después, la orden conserva el
  texto con el que se usó). Las filas heredadas del Sprint 2 (solo `description`)
  siguen siendo válidas para lectura.
- **Rationale**: FR‑023 exige "solo refacciones existentes y activas del catálogo" y
  FR‑019 prohíbe el borrado (desactivación con historial); la columna `description`
  evita que el historial (R‑01) dependa del estado futuro del catálogo.
- **Alternativas consideradas**: rehacer `order_parts` con `part_id NOT NULL`
  (descartada: rompería las filas existentes del Sprint 2 y su contrato);
  tabla `order_parts` nueva y borrar la vieja (descartada: mismo motivo).

## R‑07: Término canónico «refacción» y rutas heredadas (clarificación 3)

- **Decisión**: «refacción» es el término en UI, documentación y pruebas. En rutas, se
  agregan `POST/DELETE /api/service-orders/:id/refacciones[/:refaccionId]` con el mismo
  handler que las rutas heredadas `/repuestos` (que se conservan como alias
  compatibles durante todo el sprint, documentadas en el contrato como heredadas).
  Los nuevos módulos usan `/api/parts` y `/api/maintenance` (sustantivos en inglés,
  igual que `/clients`, `/vehicles`, `/appointments`).
- **Rationale**: la clarificación exige unificar el nombre pero permite conservar los
  endpoints heredados; renombrar en una sola pasada las pantallas del Sprint 2 sin
  romper sus pruebas obliga a mantener ambos caminos apuntando a una única
  implementación.
- **Alternativas consideradas**: renombrar y eliminar `/repuestos` (descartada: rompe
  el contrato y las pruebas del Sprint 2 sin necesidad); mantener solo `/repuestos`
  (descartada: perpetúa el término no canónico en el código nuevo).

## R‑08: Movimientos de inventario y concurrencia (FR‑024 a FR‑030, RN‑7, RN‑8)

- **Decisión**: tabla `inventory_movements` con
  `movement_type ENUM('ENTRADA','SALIDA','AJUSTE')`, `quantity > 0`, `reason`
  (obligatorio para `AJUSTE`), `service_order_id` nullable (para salidas y reposiciones
  por orden), `stock_after` (stock resultante, para que SC‑007 se verifique por
  consulta) y `created_by`. Toda operación que modifica stock corre en **transacción**
  con `SELECT … FOR UPDATE` sobre la fila de `parts` antes de validar
  `stock_actual − cantidad >= 0`; si no alcanza, `ROLLBACK` y `409 STOCK_INSUFICIENTE`
  (RN‑8: nunca negativo). Tipos de movimiento: entrada = reabastecimiento (solo
  ADMIN, FR‑029), salida = uso en orden (generada automáticamente), ajuste = corrección
  manual con motivo obligatorio (solo ADMIN).
- **Rationale**: `docs/project-context.md` §13 RN‑7/RN‑8 y el caso límite "dos
  mecánicos a la vez"; `FOR UPDATE` serializa la lectura‑validación‑escritura en InnoDB
  y es la única forma de que dos transacciones simultáneas no dejen stock negativo.
  `stock_after` convierte SC‑007 en una comprobación directa.
- **Alternativas consideradas**: validar sin transacción (descartada: permite la
  condición de carrera del caso límite); trigger de base de datos que impida el stock
  negativo (descartada: los triggers quedan fuera del alcance de las capas revisables
  y dificultan los mensajes de error en español desde la API).

## R‑09: Retiro de refacción de la orden y reposición (FR‑025, FR‑026)

- **Decisión**: `DELETE /api/service-orders/:id/refacciones/:refaccionId` solo funciona
  con la orden en estado abierto (mismo guard `assertOrderOpenForContent` del Sprint 2)
  y, en transacción, incrementa el stock y registra un movimiento `ENTRADA` con
  `service_order_id` y motivo "Reposición por retiro de la orden #<id>". Si la fila
  heredada no tiene `part_id` (descripción libre del Sprint 2), solo se elimina la fila:
  no hay stock que reponer porque nunca descontó inventario.
- **Rationale**: FR‑026 pide "reponiendo el stock y dejando constancia del movimiento";
  usar `ENTRADA` en vez de `AJUSTE` mantiene el motivo obligatorio reservado a los
  ajustes manuales del administrador (FR‑029).
- **Alternativas consideradas**: movimiento `AJUSTE` para la reposición (descartada:
  consumiría el tipo que FR‑029 reserva a los ajustes con motivo del administrador);
  eliminar la fila sin movimiento (descartada: rompería SC‑007).

## R‑10: Alertas de stock bajo sin columna derivada (FR‑020, FR‑021, SC‑008)

- **Decisión**: el listado de inventario calcula `stockBajo = stock_actual <=
  stock_minimo && stock_minimo > 0` en el backend y lo devuelve como campo de cada
  refacción; el frontend lo resalta con el semáforo de `docs/design-system.md`.
  El filtro `?stockBajo=true` aplica la misma condición en la consulta. Un
  `stock_minimo = 0` no genera alerta (caso límite de la spec).
- **Rationale**: columna persistida obligaría a recalcular en cada escritura de stock y
  a un proceso de reconciliación; el cálculo en lectura es trivial y consistente.
- **Alternativas consideradas**: columna `low_stock` actualizada por trigger o por el
  servicio (descartada: estado derivado duplicado, misma clase de problema que R‑04).

## R‑11: Matriz de permisos del sprint (clarificación 4, FR‑004, FR‑022, FR‑027, RN‑15)

- **Decisión**: comprobada en `routes/` con `authorize` **y** verificada en `service`
  donde hay reglas de propiedad (SC‑009):

  | Operación | ADMIN | RECEPTIONIST | MECHANIC |
  |-----------|:-----:|:------------:|:--------:|
  | Consultar historial, inventario, movimientos, mantenimientos | ✓ | ✓ | ✓ |
  | Crear/editar/realizar mantenimientos | ✓ | — | ✓ |
  | Registrar, editar, desactivar refacciones; entradas y ajustes | ✓ | — | — |
  | Agregar/retirar refacciones en una orden | ✓ | ✓ | ✓ (solo sus órdenes) |

- **Rationale**: la clarificación del 2026‑10‑13 fija "mantenimientos: mecánico y
  administrador; entradas de inventario: solo el administrador; consultas: los 3 roles";
  FR‑004 abre el historial a los tres roles y FR‑027 repite la propiedad de las órdenes
  del mecánico ya vigente en el Sprint 2.
- **Alternativas consideradas**: delegar la propiedad de la orden solo al frontend
  (descartada: SC‑009 exige validación en backend).

## R‑12: Pantallas y navegación por rol (HU1 a HU8)

- **Decisión**: se añaden al `app_shell.dart` los módulos del rol:
  **Inventario** (ADMIN), **Mantenimientos** (ADMIN, RECEPTIONIST, MECHANIC) y
  **Historial** disponible desde el detalle del vehículo y desde la orden del mecánico
  (botón "Ver historial del vehículo", FR‑004). El historial no es una sección del
  sidebar (es una vista del vehículo); la pantalla de inventario muestra el chip de
  stock bajo y su filtro; la de mantenimientos filtra por estado y destaca los
  vencidos. Cada alta y cada "servicio realizado" exige confirmación.
- **Rationale**: Principio VIII y §16 de `project-context.md` (solo módulos del rol en
  el shell); R‑14 del Sprint 2 ya estableció el patrón de módulos por rol.
- **Alternativas consideradas**: una sola pantalla con pestañas para todo (descartada:
  mezcla roles y contradice el shell por rol ya entregado).

## R‑13: Datos de ejemplo del sprint (FR‑031)

- **Decisión**: `database/seeds/003_ejemplos_historial_inventario.sql` con ids fijos e
  `INSERT IGNORE`: refacciones variadas (algunas con stock bajo y stock mínimo 0, una
  desactivada), movimientos de entrada/salida/ajuste iniciales y mantenimientos en los
  tres estados (normal, próximo, vencido) ligados a los vehículos seed de los sprints
  previos. El historial de ejemplo no se siembra: se deriva de las órdenes seed del
  Sprint 2 (R‑01).
- **Rationale**: FR‑031 exige idempotencia y contenido visible desde el primer
  arranque; mismo patrón que R‑12 del Sprint 2.
- **Alternativas consideradas**: poblar el historial con filas propias (descartada:
  viola RN‑10).

## R‑14: Errores nuevos en español

- **Decisión**: códigos de error nuevos del backend (además de los heredados):
  `CODIGO_DUPLICADO` (409, FR‑017), `REFACCION_NO_ENCONTRADA` (404),
  `REFACCION_INACTIVA` (409, FR‑023), `STOCK_INSUFICIENTE` (409, FR‑025/RN‑8),
  `MANTENIMIENTO_DUPLICADO` (409, unicidad por vehículo y tipo),
  `MANTENIMIENTO_SIN_INTERVALO` (400, R‑05), `OBJETIVO_REQUERIDO` (400, FR‑009),
  `MANTENIMIENTO_NO_ENCONTRADO` (404), `AJUSTE_SIN_MOTIVO` (400, FR‑029),
  `KILOMETRAJE_INVALIDO` (400, R‑03, heredado del Sprint 2). El frontend muestra
  `error.message` en español.
- **Rationale**: Principio VI; mismo patrón que los `CITA_*`/`ORDEN_*` del Sprint 2.
- **Alternativas consideradas**: mensajes genéricos por código HTTP (descartados: la
  guía de errores exige mensajes claros en español para el usuario final).
