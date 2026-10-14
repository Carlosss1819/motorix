# Reporte de Implementación: Historial, Mantenimiento e Inventario

**Funcionalidad**: `003-historial-inventario` (Sprint 3 del MVP)
**Fecha de cierre**: 2026-10-13
**Documentos de referencia**: [spec.md](spec.md) · [plan.md](plan.md) · [tasks.md](tasks.md) · [quickstart.md](quickstart.md)

## Alcance implementado

El Sprint 3 entregó las ocho historias de usuario planificadas, sin ampliar el alcance
del MVP:

| Historia | Qué quedó implementado |
|----------|------------------------|
| HU1 | Historial de servicios del vehículo como subrecurso derivado de las órdenes terminadas/entregadas (`GET /api/vehicles/:id/history`), accesible a los tres roles (RN‑10, sin tablas de duplicado) |
| HU2 | Historial con kilometraje por entrada y rechazo de órdenes con kilometraje menor al previo, salvo corrección explícita con motivo (`KILOMETRAJE_MENOR`) |
| HU3 | Alta y edición de mantenimientos preventivos por vehículo y tipo, con antelación por defecto (30 días / 500 km), duplicado rechazado (`MANTENIMIENTO_DUPLICADO`) y estado calculado en backend (R‑04) |
| HU4 | Listado de mantenimientos con estados calculados NORMAL / PRÓXIMO / VENCIDO, filtros por estado y renovación al marcar «servicio realizado» (el mismo registro se actualiza, nunca se duplica) |
| HU5 | Catálogo de refacciones con código único (`CODIGO_DUPLICADO`), escritura solo `ADMIN` y stock que solo cambia por movimientos |
| HU6 | Detalle de refacción con su historial de movimientos (tipo, cantidad, motivo/fecha y stock resultante), disponible a los tres roles |
| HU7 | Uso de refacciones del catálogo en las órdenes: salida de inventario en transacción, retiro con reposición, bloqueo de orden cerrada (`ORDEN_CERRADA`) y stock nunca negativo (RN‑6 a RN‑8) |
| HU8 | Alertas de stock bajo: campo `stockBajo` calculado (`stock_actual <= stock_minimo`), filtro del listado y semáforo en la interfaz; `stock_minimo = 0` nunca genera alerta (FR‑021) |

Base de datos: la migración `003_historial_mantenimiento_inventario.sql` crea las tablas
`maintenance`, `parts` e `inventory_movements` y **agrega** la columna `part_id` (nullable)
a `order_parts`; los scripts 001 y 002 no se tocaron. Los datos de ejemplo viven en el
seed idempotente `003_ejemplos_historial_inventario.sql`.

## Decisiones tomadas durante la implementación

1. **Historial derivado, sin duplicado**: las entradas del historial se construyen en
   cada consulta desde las órdenes terminadas; no existe una tabla de historial propia
   (RN‑10), por lo que no puede desincronizarse.
2. **Estado de mantenimiento calculado en backend**: se mantiene como módulo puro
   (`server/utils/maintenance-status.js`, estilo `order-transitions.js`) para poderlo
   probar en unidad; el estado nunca se recibe ni se guarda.
3. **Stock negativo imposible**: agregar o retirar una refacción usa transacción con
   bloqueo de fila (`SELECT … FOR UPDATE`); si no alcanza, responde
   `409 STOCK_INSUFICIENTE` sin tocar el stock.
4. **Movimientos de inventario**: solo `ENTRADA` y `AJUSTE` se registran a mano y solo
   por `ADMIN`; el `AJUSTE` exige motivo (`AJUSTE_SIN_MOTIVO`). La `SALIDA` la genera
   únicamente el uso en una orden, y el retiro genera la `ENTRADA` de reposición ligada
   a la orden (`ordenId`).
5. **Compatibilidad con el Sprint 2**: las filas heredadas de `order_parts` (sin
   `part_id`) se conservan y se presentan con su descripción; la clave JSON `repuestos`
   y los alias `/repuestos` siguen funcionando (R‑07).
6. **Terminología unificada**: la UI y los comentarios visibles usan «refacción», sin
   tocar identificadores de código (`stockRepuesto`, `repuestos`, `repuestoId`) ni
   cambiar la forma de la API (T070).
7. **Selector de refacciones sin acoplar filtros**: en Flutter, `loadCatalog()` carga
   el catálogo para el selector por separado del listado del inventario, para no
   alterar sus filtros ni su paginación; los ítems con `stockActual = 0` se muestran
   deshabilitados.
8. **Pruebas estables en BD acumulativa**: los datos de prueba usan sufijos únicos
   porque la base de pruebas no se limpia entre corridas (decisión heredada de los
   sprints anteriores).

## Métricas

| Métrica | Resultado |
|---------|-----------|
| Tareas del sprint | 75 (T001–T075), todas completadas |
| Commits del sprint | 55, atómicos y con Conventional Commits en español (patrón backend `test` → `feat`; Flutter `feat` → `test`) |
| Pruebas del backend | 41 suites / 332 pruebas en verde (unit, integración y contrato contra `motorix_v2_test`) |
| Pruebas del cliente | 93 pruebas en verde (`flutter test`) |
| ESLint del backend | 0 errores |
| `flutter analyze` | Sin problemas |
| Migración 003 | Aplicada a `motorix_v2` con `-Seeds` (con aprobación del usuario); doble corrida sin duplicar datos |
| Escenarios manuales V1–V7 | Los 7 validados con los tres roles contra el backend local (`DB_NAME=motorix_v2_test`) |
| Dependencias nuevas | Ninguna (backend y frontend conservan sus librerías) |

## Resultados de la validación manual (quickstart V1–V7)

| Escenario | Resultado | Detalle |
|-----------|-----------|---------|
| V1 — Historial desde orden terminada | OK | Solo lista órdenes terminadas/entregadas en orden inverso; la orden en curso no aparece; paginación por defecto 10 y tope 50 |
| V2 — Vehículo sin servicios y kilometraje | OK | Historial vacío responde `total=0` sin error; km menor rechazado con `KILOMETRAJE_MENOR`; con `correccionKilometraje` (admin) se acepta |
| V3 — Mantenimientos | OK | Antelación por defecto 30 días / 500 km; duplicado → `409`; sin objetivo → `400 OBJETIVO_REQUERIDO`; NORMAL/PRÓXIMO/VENCIDO calculados con sus filtros; «servicio realizado» renueva el mismo registro; recepción recibe `403` al escribir |
| V4 — Catálogo y stock bajo | OK | Código duplicado → `409`; `stockBajo` marca `stock_actual <= stock_minimo`; `stock_minimo = 0` nunca marca; búsqueda por nombre y código; la refacción desactivada desaparece de las opciones y su historial sigue visible |
| V5 — Uso en órdenes y concurrencia | OK | Agregar cantidad 2 baja el stock y registra `SALIDA` ligada a la orden (`ordenId`); cantidad mayor al stock → `409 STOCK_INSUFICIENTE` sin cambio; id inexistente → `404`; desactivada → `409 REFACCION_INACTIVA`; retiro repone el stock con `ENTRADA` de reposición; orden `TERMINADO` → `409 ORDEN_CERRADA` |
| V6 — Movimientos solo admin | OK | `ENTRADA` registrada con su `stockAfter`; `AJUSTE` sin motivo → `400 AJUSTE_SIN_MOTIVO`; con motivo se crea; el historial explica cada cambio; recepción y mecánico reciben `403` |
| V7 — Datos de ejemplo y arranque limpio | OK | Segunda corrida de migraciones + seeds no duplica nada; inventario variado (44 refacciones en stock bajo, 33 desactivadas) y mantenimientos en los tres estados; el historial muestra las órdenes del Sprint 2 |

## Decisiones abiertas

- **Recordatorios proactivos de mantenimiento (HU3)**: hoy el estado se consulta a
  demanda; un envío de avisos automáticos (correo/mensaje) quedaría para un sprint
  futuro.
- **Costo de refacciones en pagos (HU7)**: `inventory_movements` ya expone
  `stockAfter` por movimiento, lo que permitirá al Sprint 4 (pagos y tickets) reflejar
  el costo de las refacciones sin recalcular nada; falta definir si el ticket muestra
  precio de compra o de venta.
- **Concurrencia real**: el stock se protege con bloqueos de fila, pero el MVP no
  carga pruebas de estrés multiusuario; se dejará documentado como supuesto operativo.
- **Semántica del alias `/repuestos`**: se conserva por compatibilidad (R‑07); si en el
  futuro se retira, deberá ser un cambio de API versionado.
