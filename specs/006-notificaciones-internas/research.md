# Investigación: Notificaciones internas (Sprint 6)

**Fecha**: 2026-11-16 · **Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

No quedan puntos «NEEDS CLARIFICATION» en el contexto técnico. Cada decisión se tomó leyendo el código actual.

## R-01 Cálculo al consultar

- **Decisión**: los avisos se calculan en cada `GET` con consultas SQL acotadas y lógica en el servicio. No hay tabla de avisos ni proceso programado.
- **Por qué**: CA-2 y RN-10 (no duplicar información); así el aviso desaparece en cuanto deja de cumplirse la condición.
- **Alternativas descartadas**: tabla materializada con trabajo programado (duplica datos, se desincroniza); disparadores en MySQL (lógica fuera del servicio, principio II).

## R-02 Reutilización de reglas existentes

- **Decisión**:
  - Mantenimiento: `calcMaintenanceState(row, hoy, vehicleCurrentMileage)` de `server/utils/maintenance-status.js`, sobre la misma consulta base de `models/maintenance.js` (todos los registros, sin paginar).
  - Stock: la condición `WHERE_STOCK_BAJO` de `models/dashboard.js` (`stock_current <= stock_min AND stock_min > 0`), la misma del filtro de `models/parts.js`. **Hallazgo**: ninguna de las dos excluye refacciones inactivas (`is_active`); los avisos tampoco, para que los números coincidan. La condición se exporta y se reutiliza, no se copia.
  - Citas: estados `PROGRAMADA` y `RECIBIDA` (criterio de `countAppointmentsOn` del panel), extraídos a `ACTIVE_APPOINTMENT_STATUSES` en `utils/status-constants.js` y usados por el panel y por los avisos.
- **Por qué**: CA-5 / SC-003 (los números coinciden entre pantallas).
- **Alternativas descartadas**: reescribir los criterios en el servicio nuevo (riesgo de divergencia).

## R-03 Citas vencidas

- **Hallazgo**: la agenda llama a `markExpiredAsNotPresented()` (detección perezosa: `PROGRAMADA` con fecha y hora pasadas → `NO_PRESENTADA`); el panel no.
- **Decisión**: el servicio de avisos llama a `markExpiredAsNotPresented()` antes de calcular, igual que la agenda.
- **Por qué**: una cita de hoy cuya hora ya pasó sin llegar no debe avisarse como pendiente; además la marca se persiste y el panel la refleja después.
- **Alternativa descartada**: no llamar (el aviso mostraría citas ya vencidas).

## R-04 Orden detenida

- **Decisión**: referencia = `COALESCE(MAX(h.changed_at), o.created_at)`; detenida si `TIMESTAMPDIFF(SECOND, referencia, NOW()) > N * 86400` y `o.status IN ('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION')`. Para MECHANIC se agrega `o.mechanic_id = ?`.
- **Configuración**: `config.notifications.stalledOrderDays` desde `NOTIF_ORDEN_DETENIDA_DIAS` (entero > 0; 3 por defecto), con el mismo patrón que `MP_PREFERENCIA_VIGENCIA_HORAS` del Sprint 5.
- **Alternativas descartadas**: usar `service_orders.updated_at` (cambia también al editar contenido, no solo el estado); constante fija en código (Carlos pidió que sea configurable).

## R-05 Claves de aviso y de hecho

- **Decisión**: funciones puras en `server/utils/notice-keys.js`:
  - Avisos: `MANT_PROXIMO:<id>:<objetivo>`, `MANT_VENCIDO:<id>:<objetivo>`, `STOCK_BAJO:<id>`, `STOCK_AGOTADO:<id>`, `CITA_HOY:<id>:<YYYY-MM-DD>`, `ORDEN_DETENIDA:<id>:<estado>`.
  - Hechos: `ORDEN:<id>`, `CITA:<id>`, `MANT:<id>:<objetivo>`.
  - Objetivo: `<target_date o ->|<target_mileage o ->` (ejemplo `2026-12-01|45000`, `-|45000`).
- **Por qué**: FR-015 y FR-021; el objetivo distingue ciclos de un mantenimiento que es un solo registro (`uq_maintenance_vehicle_type`) que `renewMaintenance` actualiza al registrar el servicio.
- **Largo máximo**: menos de 60 caracteres; columnas `VARCHAR(120)`.

## R-06 Lecturas

- **Decisión**: `POST /api/notifications/read` con `{ clave }`. El servicio calcula los avisos del usuario; si la clave está entre ellos, `INSERT IGNORE INTO notification_reads`; en cualquier caso responde 204.
- **Por qué**: FR-030 (no falla y no revela existencia) e idempotencia.
- **Alternativa descartada**: guardar cualquier clave sin validar (un usuario podría guardar claves de otro rol; inofensivo pero sucio y deja inferir formatos).

## R-07 Avisos a clientes y concurrencia

- **Decisión**: `client_notices.fact_key` con índice único; el `INSERT` atrapa `ER_DUP_ENTRY` y responde 409 `YA_AVISADO`. Antes de insertar se verifica que el hecho esté en la lista actual; si no, 404 `HECHO_NO_VIGENTE`.
- **Por qué**: FR-020 (una vez por hecho) y el caso de dos recepcionistas al mismo tiempo, sin candados.
- **Motivos guardados**: `VEHICULO_LISTO`, `CITA_MANANA`, `MANT_PROXIMO`, `MANT_VENCIDO` (el motivo del momento en que se avisó).

## R-08 Actualización del contador

- **Decisión**: `GET /api/notifications/count` → `{ noLeidos }`. Flutter lo llama al iniciar sesión y cuando el `AppShell` cambia de sección; el panel llama `GET /api/notifications` al abrirse (y actualiza el contador con la misma respuesta). Sin `Timer`.
- **Por qué**: aclaración 3 de Carlos.

## R-09 Rendimiento

- **Decisión**: prueba de integración que crea en `motorix_v2_test` 10 veces el volumen del seed (por ejemplo 100 mantenimientos, 50 refacciones en stock bajo, 50 órdenes detenidas, 30 citas de hoy) y mide la respuesta de `GET /api/notifications` como ADMIN: 1 consulta de calentamiento y la mediana de 3 consultas debe ser < 1000 ms. Usar la mediana evita fallas intermitentes cuando la suite completa corre en paralelo (CLAUDE.md, regla 7).
- **Por qué**: CA-13 / SC-006.

## R-10 Seed del sprint

- **Decisión**: `database/seeds/006_ejemplos_notificaciones.sql`, ids 60001 a 60099 en todas las tablas que toca. Contenido mínimo:
  - cliente «[Sprint 6] Laura Méndez» con teléfono y dos vehículos;
  - mantenimiento vencido (fecha objetivo hace 10 días) y mantenimiento próximo (fecha objetivo en 10 días, antelación 30);
  - refacciones `NOT-BAJ01` (stock bajo) y `NOT-AGO01` (agotado);
  - orden `EN_REPARACION` asignada a `mecanico`, último cambio hace 5 días (detenida) y orden `DIAGNOSTICO` sin mecánico, último cambio hace 4 días;
  - orden `TERMINADO` sin entregar (vehículo listo);
  - cita de hoy a las 23:30 (`PROGRAMADA`) y cita de mañana (`PROGRAMADA`).
- Fechas relativas con `CURDATE()`/`NOW()`; `INSERT ... ON DUPLICATE KEY UPDATE` refresca fechas sin duplicar. Usuarios por `username` (no por id).
- **Por qué**: CA-12, FR-025, principio III (la app muestra datos al arrancar).
