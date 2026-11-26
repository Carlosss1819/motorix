# Investigación (Fase 0): Reportes y configuración del taller

No quedaron marcadores `NEEDS CLARIFICATION` en el contexto técnico. Estas son las decisiones de diseño.

## R-01 — Configuración clave-valor con respaldo en código

- **Decisión**: tabla `settings` (clave, valor, quién y cuándo). Claves: `shop.name`, `shop.address`, `shop.phone`, `maintenance.advance_days`, `maintenance.advance_km`. Los valores de respaldo viven en `server/utils/settings-defaults.js` (los de la constante `TALLER` y `DEFAULT_ADVANCE_*`). Una función pura `resolveSettings(rows)` combina lo guardado con el respaldo.
- **Por qué**: pocas claves, sin esquema rígido; una instalación sin filas sigue funcionando (FR-003, CA-3).
- **Alternativas**: una tabla de una sola fila con columnas (más rígida); variables de entorno (exigen reiniciar, es lo que se quiere evitar).

## R-02 — Márgenes de "Próximo" = antelación por defecto de registros nuevos

- **Decisión**: `maintenance.service.create` usa los márgenes de `settings` cuando el cuerpo no trae `antelacionDias`/`antelacionKm`. Los registros existentes no cambian (H-S7-01). `calcMaintenanceState` y el dashboard siguen usando la antelación del registro.
- **Alternativas**: recalcular el estado con el margen global ignorando el del registro (rompe el Sprint 3 y los avisos del Sprint 6).

## R-03 — Catálogo `service_types` y enlace opcional en `order_services`

- **Decisión**: nombre único con colación `utf8mb4_unicode_ci` (no distingue mayúsculas); intervalos nullable con `CHECK` (al menos uno). `order_services.service_type_id` nullable con FK `RESTRICT`; las líneas existentes quedan en `NULL`. Solo se aceptan tipos activos al agregar una línea.
- **Propuesta del mantenimiento (FR-011)**: se calcula en el cliente con el tipo elegido y el kilometraje actual del vehículo, con la misma regla que la función pura `proposeNextService` del backend (`utils/next-service.js`), probada en unidad.

## R-04 — Próximo servicio en la copia del ticket

- **Decisión**: `buildContent` agrega `proximosServicios: [{ tipoServicio, fecha, kilometraje }]` (un elemento por tipo distinto con intervalo; `fecha = fecha de emisión + días`, `kilometraje = kilometraje de entrada + km`; null si el tipo no tiene ese intervalo). Lista vacía cuando no hay tipos. El formato sigue en 2; los tickets anteriores no traen el campo y el cliente no muestra la sección (FR-013).
- **Datos del taller**: `buildContent` lee `settings` al emitir; la copia ya guarda `taller` (H-S7-02).

## R-05 — Términos: versión vigente y aceptación validada en `authenticate`

- **Decisión**: `terms_versions` (versión, fecha, textos, `is_current`) y `terms_acceptances` (único por usuario y versión). El middleware `authenticate`, después de validar la sesión, consulta en una sola sentencia la versión vigente y si el usuario la aceptó; si no, responde `403 TERMINOS_PENDIENTES` salvo en la lista blanca: `GET /api/auth/me`, `POST /api/auth/logout`, `GET /api/terms/current`, `POST /api/terms/accept`. Sin versión vigente publicada, no hay nada pendiente.
- **Login**: la respuesta agrega `terminosPendientes` (y `GET /api/auth/me` también).
- **Publicación**: seed `007` inserta la versión `1.0` (id 70001). Una versión nueva se publica con un seed posterior que apaga `is_current` de la anterior (H-S7-04).
- **Pruebas**: `tests/helpers/api.js#loginAs` acepta la versión vigente después de iniciar sesión, y `global-setup.js` registra la aceptación de los usuarios existentes en `motorix_v2_test` (Clarifications).

## R-06 — Bitácora tolerante a fallos

- **Decisión**: `audit.service.record({ userId, action, entityType, entityId, detail })` inserta en `audit_log` y, si falla, solo registra en consola (FR-025). El detalle se arma en cada servicio con datos no sensibles y se recorta a 255. Acciones: `LOGIN_FALLIDO`, `CUENTA_BLOQUEADA`, `USUARIO_CREADO`, `USUARIO_ROL_CAMBIADO`, `USUARIO_ACTIVADO`, `USUARIO_DESACTIVADO`, `CONFIG_ACTUALIZADA`, `TIPO_SERVICIO_CREADO`, `TIPO_SERVICIO_EDITADO`, `TIPO_SERVICIO_ACTIVADO`, `TIPO_SERVICIO_DESACTIVADO`, `PRECIO_REFACCION_CAMBIADO`, `PAGO_ANULADO`, `PAGO_CANCELADO`, `TERMINOS_ACEPTADOS`.
- **Consulta**: solo ADMIN, paginada (máximo 50 por página), filtros `desde`, `hasta`, `usuarioId`, `accion`. No hay rutas de edición ni borrado.

## R-07 — `helmet`

- **Decisión**: `app.use(helmet())` con la configuración por defecto, antes de las rutas. La app web se sirve aparte y llama a `/api` por proxy (mismo origen), así que `Cross-Origin-Resource-Policy` y la CSP de las respuestas JSON no la afectan. Se conserva `app.disable('x-powered-by')`.

## R-08 — Reportes (Entrega B)

- **Decisión**: consultas de agregación con parámetros sobre `payments`, `order_services`/`order_labor`, `order_parts`, `parts`, `inventory_movements` y `order_status_history`; sumas en centavos con `utils/money.js`. Rango `desde`/`hasta` (`AAAA-MM-DD`, máximo 366 días); los atajos se calculan en el cliente con la hora de Ciudad de México. El periodo de servicios, margen y productividad lo define el paso a `TERMINADO` en `order_status_history`. CSV con `utils/csv.js` (BOM, separador coma, comillas dobles duplicadas para escapar, CRLF) cuando `formato=csv`.
- **Alternativas**: vistas o tablas resumen (duplican datos, RN-10).

## R-09 — Inactividad (CA-23)

- **Decisión**: ya existe en backend (`SESSION_IDLE_MS`) y en Flutter (`AuthProvider.inactivityTimeout` y `onUnauthorized`). Solo se agregan pruebas: una de backend (`setLastActivity`) y una de Flutter que comprueba que un `401` con sesión abierta lleva al inicio de sesión.
