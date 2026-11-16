# Investigación (Fase 0): Precios de refacciones y cobro completo

**Funcionalidad**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Fecha**: 2026-11-14

Cada decisión indica qué se eligió, por qué y qué alternativas se descartaron. Los hechos del código se verificaron leyéndolo el 2026-11-14 (rama `005-precios-refacciones-cobro`); las consultas a la base fueron solo de lectura.

## Hechos verificados del código y de las bases

| # | Hecho | Evidencia |
|---|---|---|
| H1 | El total se calcula al cobrar con `parts.sale_price` vigente; `order_parts` no guarda precio. | `server/models/payment.js:123-160` (`findChargeContent`); `server/utils/order-total.js` (`calcularTotal`) |
| H2 | El ticket se reconstruye en cada consulta y hay un solo ticket por orden (`UNIQUE KEY uq_tickets_service_order`). Tras anular y volver a cobrar, `generateTicket` devuelve el ticket viejo, ligado al pago anulado. | `database/migrations/004_pagos_tickets_dashboard.sql:39-62`; `server/services/ticket.service.js` (`generateTicket`, `buildTicket`) |
| H3 | `registerPayment` revisa los pagos y luego inserta, sin transacción ni candado. No hay prueba de solicitudes simultáneas. **CA-8 hoy no está garantizado.** | `server/services/payment.service.js:96-165`; búsqueda de `FOR UPDATE` y `beginTransaction`: solo inventario y mantenimientos |
| H4 | `confirmPayment` solo valida la transición de estado; no compara el importe. No hay webhook. La preferencia de Mercado Pago se crea sin expiración. | `server/services/payment.service.js:212-230`; `server/services/payment_gateway/mercadopago.js` |
| H5 | El rol se lee de la base en cada petición (`authenticate`). Cambiar el rol NO cierra las sesiones; desactivar la cuenta sí. | `server/middlewares/auth.js`; `server/services/user.service.js:67-85` |
| H6 | El mecánico ya no recibe totales ni subtotales, y no tiene acceso a pagos, tickets ni panel. Sí recibe `precioCompra` y `precioVenta` del catálogo, y `manoDeObra.precio`. | `server/services/part.service.js:34-48`; `server/services/service_order.service.js:78-111`; rutas de `payments`, `tickets` y `dashboard` |
| H7 | El precio de la mano de obra solo rechaza negativos (servidor y Flutter); `order_labor.price` es `DECIMAL(10,2) NULL` sin `CHECK`. | `server/validators/service-order.validator.js:102-105`; `client/lib/screens/service_order_detail_screen.dart:283-294` |
| H8 | Las refacciones ya se rechazan en toda orden `TERMINADO` (`ORDEN_CERRADA`). | `server/services/service_order.service.js:390-396` |
| H9 | La cantidad de `order_parts` es `INT`. | `database/migrations/002_citas_ordenes_servicio.sql:136` |
| H10 | El catálogo solo busca por nombre o código y ordena por nombre; no hay filtros ni ordenamientos por precio. | `server/models/parts.js:38` y `64` |
| H11 | En `motorix_v2` y `motorix_v2_test` no hay `payment_id` repetidos en `tickets` ni órdenes con más de un pago `PAGADO`. | Consulta de solo lectura del 2026-11-14 |
| H12 | En `motorix_v2` la orden 5 es «Debug cobro», creada a mano el 2026-10-14. Los ids fijos del seed 004 chocaron con ella: `INSERT IGNORE` saltó la orden y su mano de obra (id 4), pero sí le colgó los pagos 2 y 4 y el ticket 2 del seed. En `motorix_v2_test` la orden 5 es la del seed (`TERMINADO`, 750.00). | Consulta de solo lectura; `database/seeds/004_ejemplos_pagos_tickets.sql` |
| H13 | Las migraciones se aplican archivo por archivo (`aplicar-migraciones.ps1` con el cliente `mysql`; `tests/helpers/db.js` con `multipleStatements`) y se registran en `schema_migrations` solo si el archivo termina bien. No hay un script de respaldo. | `database/scripts/aplicar-migraciones.ps1`; `server/tests/helpers/db.js` |

## R-01 · Ticket por pago y la regla de migraciones aditivas

- **Decisión**: la migración `005` cambia la unicidad de `tickets` en **una sola sentencia `ALTER TABLE`**, con el orden que pidió el responsable:
  1. agrega el índice normal `idx_tickets_service_order (service_order_id)`, que necesita la llave foránea `fk_tickets_order`;
  2. quita `uq_tickets_service_order`;
  3. agrega `UNIQUE KEY uq_tickets_payment (payment_id)`.

  Antes de la migración se corre una consulta de verificación de `payment_id` repetidos (ver [quickstart.md](./quickstart.md#2-verificación-previa)). Además, como las tres partes van en una sola sentencia, MySQL las aplica todas o ninguna: si hubiera duplicados, el `UNIQUE` falla y la tabla queda como estaba.
- **Por qué**: la constitución (principio III) exige scripts nuevos numerados y prohíbe editar los anteriores; no prohíbe reemplazar una restricción. La migración no borra ni modifica datos: no se pierde ninguna fila ni valor.
- **Gobernanza**: es la **primera migración que quita una restricción**; queda registrada en el Registro de complejidad del plan. CLAUDE.md (regla 4) y el insumo dicen «aditivas». Por decisión del responsable (2026-11-14), FR-031 incluye una tarea para aclarar la regla 4: «aditiva» significa no editar migraciones anteriores y no borrar tablas, columnas ni datos; se permite reemplazar una restricción si se conservan los datos y se documenta en el plan. Esa aclaración la aprueba el responsable; no se edita ahora.
- **Alternativas descartadas**: (a) tabla nueva de tickets por pago, con `tickets` congelada: totalmente aditiva, pero deja dos tablas de tickets y un folio que hay que coordinar entre ambas; (b) detener el sprint hasta una enmienda: el responsable eligió la opción (1) con condiciones.

## R-02 · Migración en dos archivos y recuperación

- **Decisión**: separar el esquema de los datos.
  - `005_precios_congelados_tickets_por_pago.sql`: **solo DDL**, en tres sentencias `ALTER TABLE` independientes y atómicas cada una:
    - `order_parts`: agrega `unit_price`;
    - `tickets`: agrega columnas e índices (R-01);
    - `payments`: agrega `cancellation_reason`.
  - `006_datos_precio_congelado_copia_tickets.sql`: **solo datos**, dentro de `START TRANSACTION … COMMIT`, y repetible: cada sentencia actúa solo donde la columna nueva sigue `NULL`.
- **Por qué**: en MySQL cada sentencia DDL hace un commit implícito, así que una transacción no puede envolver los `ALTER`. Con dos archivos, una falla en los datos se revierte completa (`ROLLBACK`) y basta con volver a correr el `006`; el registro en `schema_migrations` solo ocurre si el archivo termina.
- **Recuperación**:
  1. **Respaldo obligatorio** con `mysqldump` antes de aplicar (comando en el quickstart; no se agrega un script nuevo).
  2. Si el `005` falla a la mitad, se revisa con `information_schema` qué `ALTER` ya entró (consultas en el quickstart) y se restaura el respaldo. No se intenta reparar a mano en la base de demostración.
  3. Si el `006` falla, la transacción se revierte sola y se vuelve a correr.
- **Alternativas descartadas**:
  - un solo archivo: una falla de datos dejaría el esquema aplicado y el archivo sin registrar, y al volver a correrlo fallaría el `ADD COLUMN`;
  - procedimientos almacenados con guardas: necesitan `DELIMITER`, que `tests/helpers/db.js` (mysql2) no admite;
  - `ADD COLUMN IF NOT EXISTS`: no existe en MySQL 8.

## R-03 · Precio congelado (D-03) y líneas sin precio

- **Decisión**: `order_parts.unit_price DECIMAL(10,2) NULL`. `NULL` significa «sin precio registrado» y vale 0 en el total.
  - El `006` copia `parts.sale_price` a toda línea con `part_id` y `unit_price IS NULL`. Abarca órdenes abiertas (D-03) y también `TERMINADO` y `ENTREGADO`, según el supuesto de la spec, porque es el mismo valor que el sistema usa hoy para ellas.
  - Las líneas sin `part_id` y las de refacciones sin precio de venta quedan en `NULL`.
  - Desde el sprint, `addPart` rechaza una refacción sin `sale_price` (FR-005) y guarda `unit_price` dentro de la misma transacción que ya bloquea el stock.
- **Por qué**: una columna en la misma línea es la instantánea más simple. `NULL` distingue «sin precio» de «precio 0.00».
- **Alternativas descartadas**: guardar el precio en centavos (`INT`): la restricción heredada pide conservar `DECIMAL(10,2)`; usar 0 en lugar de `NULL`: confundiría un precio real de 0.00 con la falta de precio.

## R-04 · Copia del ticket y «formato anterior» (D-09)

- **Decisión**: `tickets.content JSON NULL` y `tickets.format_version SMALLINT NULL`.
  - **Versión 1 = «formato anterior»** (generada en la migración). **Versión 2 = formato del Sprint 5** (escrita por la aplicación al emitir).
  - El JSON guarda el comprobante completo tal como hoy lo devuelve `buildTicket`: taller, cliente, vehículo, servicios con refacciones, subtotales, total, método de pago y fecha. La estructura está en [data-model.md](./data-model.md#ticket-copia-del-contenido).
  - El `006` genera la versión 1 con un único `UPDATE … JOIN` y funciones `JSON_OBJECT` / `JSON_ARRAYAGG` de MySQL 8, a partir de los mismos datos que usa hoy `buildTicket`.
  - **Regla del importe pagado (FR-020)**: `total = payments.amount`. Si la suma del desglose no coincide, la copia agrega `desgloseNoCoincide: true` y la nota «El desglose no coincide con lo cobrado».
- **«Pago anulado»**: no se guarda en la copia. Al consultar, la respuesta agrega `pagoAnulado` a partir de `payments.status`.
- **Caso real**: la orden 5 de `motorix_v2` (pagado 1390.00, calculado 1090.00) tendrá la nota. Sirve como verificación del FR-020 en la demostración.
- **Alternativas descartadas**:
  - generar la copia en la primera consulta: la spec pide hacerlo durante la migración;
  - un script de Node para migrar: rompe la regla de que el esquema y los datos iniciales vivan en `database/` como SQL;
  - guardar «pago anulado» en la copia: el responsable pidió tomarlo del estado actual.

## R-05 · Datos de ejemplo (FR-029) y la orden 5

- **Decisión**: nuevo `seed 005_ejemplos_precios_congelados.sql`, idempotente con ids fijos e `INSERT IGNORE`. Se carga después del 004 y hace tres cosas:
  1. Completa `unit_price` y `content` (versión 1, «formato anterior») **solo de las filas sembradas por el seed 004**, por id (`order_parts.id = 4`, `tickets.id IN (1, 2)`), y solo donde siguen `NULL`. Así una base nueva (migraciones 001–006 con tablas vacías y después los seeds) también tiene copias.
  2. Agrega una refacción con precio de venta menor que el de compra (D-07), una orden `TERMINADO` cobrable con refacciones a precio congelado, y su pago y ticket en versión 2 con copia.
  3. Agrega una orden con un pago anulado y un pago nuevo, cada uno con su ticket (FR-033), para demostrar «pago anulado».
- **Por qué solo por id**: si el seed actualizara toda línea con `unit_price IS NULL`, en cada carga congelaría con el precio del día líneas que se quedaron sin precio al migrar.
- **Orden 5**: no es un problema del seed, sino de una base de desarrollo con datos manuales que ocupan ids del seed. **Riesgo**: cualquier seed con ids fijos puede colgarse de filas manuales. Recomendación para el responsable: antes de la demostración, recrear `motorix_v2` desde cero con los scripts de `database/`. Es una acción destructiva y queda a su decisión; este plan no la ejecuta.
- **Alternativas descartadas**: generar las copias en el seed para todas las filas (mezclaría datos reales con datos de ejemplo); quitar los tickets del seed 004 (no se editan seeds de sprints anteriores para cambiar su intención).

## R-06 · Cálculo en centavos enteros (D-08)

- **Decisión**: `server/utils/order-total.js` sigue siendo un módulo puro, pero opera en centavos enteros.
  - Convierte cada `DECIMAL` (mysql2 lo entrega como cadena) a centavos **sin pasar por flotante**: separa la parte entera y la decimal de la cadena.
  - `importeLinea = cantidad × precioCentavos`. Con cantidad entera (H9), el resultado es exacto; si algún día la cantidad admite decimales, se redondea al centavo hacia arriba desde 0.5.
  - Suma enteros y convierte a dos decimales solo para responder.
  - Tope del total: 9,999,999,999 centavos (99,999,999.99). Al agregar una refacción o un servicio, el servicio de la orden recalcula el total y rechaza con `409 TOTAL_EXCEDE_LIMITE` si se pasaría.
- **Por qué**: elimina el `Math.round(x + EPSILON)` de flotantes y cumple la restricción heredada de conservar `DECIMAL(10,2)` en la base.
- **Alternativas descartadas**: una librería de decimales (dependencia nueva sin necesidad, principio III); calcular en SQL (duplicaría la regla y no se podría probar como unidad).

## R-07 · Concurrencia: candado por orden

- **Decisión**: un candado de fila sobre la orden, `SELECT id, status FROM service_orders WHERE id = ? FOR UPDATE`, dentro de una transacción, en todas las operaciones que cambian el cobro o el contenido cobrable:
  - registrar, confirmar, cancelar y anular un pago;
  - agregar y quitar un servicio;
  - agregar y quitar una refacción;
  - cambiar el estado de la orden;
  - generar un ticket.

  **Orden de candados**: primero la orden y después las refacciones (`lockStockForUpdate`), para evitar bloqueos cruzados.
- **Carrera «confirmar pago contra cambiar servicio»**: las dos operaciones toman el mismo candado, así que se ejecutan una tras otra:
  - si el servicio entra primero, la confirmación recalcula el total bajo el candado, ve la diferencia y aplica D-04;
  - si la confirmación entra primero y el pago queda `PAGADO`, la alta o baja del servicio se rechaza por FR-021.
- **Mercado Pago**: la llamada HTTP para crear la preferencia **no** se hace con el candado tomado. El flujo es:
  1. validar sin candado;
  2. crear la preferencia (con expiración, R-09);
  3. abrir la transacción, tomar el candado, volver a validar (estado, pagos vigentes y total) e insertar.

  Si la segunda validación falla, se responde 409 y la preferencia sobrante expira sola.
- **Por qué**: corrige el hueco H3 (CA-8) y resuelve la carrera con un solo mecanismo ya usado en el proyecto (`FOR UPDATE` del inventario).
- **Alternativas descartadas**:
  - `GET_LOCK` con nombre por orden: candado de sesión, más fácil de dejar colgado;
  - unicidad parcial en `payments`: MySQL no admite índices únicos parciales;
  - columna calculada con `UNIQUE`: complica el esquema y no cubre la carrera con los servicios.

## R-08 · Pago pendiente con importe desfasado (D-04)

- **Decisión**: en `confirmPayment`, cuando se pide `estado: PAGADO` sobre un pago de Mercado Pago `PENDIENTE`, se toma el candado de la orden (R-07) y se recalcula el total.
  - Si no coincide, el pago pasa a `CANCELADO` con `cancellation_reason = 'IMPORTE_DESFASADO'`, se hace commit y se responde `409 IMPORTE_DESFASADO` con `importePago`, `totalActual` y `diferencia`.
  - Si se pide `RECHAZADO` o `CANCELADO`, no se compara el importe. La cancelación manual guarda `cancellation_reason = 'MANUAL'`.
  - La cancelación es solo local: el enlace sigue vivo en el proveedor hasta su expiración (R-09). Ese riesgo ya está en los Supuestos de la spec.
- **Por qué**: cumple D-04 y la aclaración de CHK001 (motivo distinguible) sin un estado nuevo.
- **Alternativas descartadas**: un estado nuevo `DESFASADO` (cambia la máquina de estados del Sprint 4 sin necesidad); reutilizar `annulment_reason` (es de la anulación de un `PAGADO` y está ligado a `annulled_by`).

## R-09 · Expiración de las preferencias de Mercado Pago

- **Verificación en la documentación oficial (2026-11-14)**:
  - Las URL de México (`mercadopago.com.mx/developers/es/reference/preferences/_checkout_preferences/post` y `…/docs/checkout-pro/checkout-customization/preferences`) respondieron **404**.
  - Las páginas oficiales de Brasil, en inglés, sí cargaron:
    - [Configure term of preference](https://mercadopago.com.br/developers/en/docs/checkout-pro/checkout-customization/preferences/term-of-preference): «In `expires`, enter `true`», `expiration_date_from` y `expiration_date_to` en ISO 8601, con el ejemplo `"expires": true, "expiration_date_from": "2017-02-01T12:00:00.000-04:00", "expiration_date_to": "2017-02-28T12:00:00.000-04:00"`.
    - [Create preference](https://www.mercadopago.com.br/developers/en/reference/online-payments/checkout-pro-preferences/create-preference/post): los tres campos aparecen en los ejemplos y en los errores `invalid_expiration_date_to` e `invalid_expiration_date_from`.
    - [Update preference](https://www.mercadopago.com.br/developers/en/reference/online-payments/checkout-pro-preferences/update-preference/put): los ejemplos envían esos campos, pero la página no dice de forma explícita que se puedan modificar.
  - **No verificado**: que la API de México se comporte igual (sus páginas dieron 404), y que exista una operación documentada para desactivar una preferencia ya creada.
- **Decisión**: **sí** poner expiración a las preferencias nuevas: `expires: true`, `expiration_date_from` = ahora y `expiration_date_to` = ahora + N horas, con N en la variable de entorno `MP_PREFERENCIA_VIGENCIA_HORAS` (valor por defecto 24, documentada en `.env.example`). La pasarela simulada ignora la expiración.
  - **No** se intentará expirar en el proveedor una preferencia al cancelar el pago, porque no está documentado de forma explícita. Los webhooks siguen fuera de alcance.
  - **Prueba de humo obligatoria** en sandbox de México antes de cerrar el sprint: crear una preferencia con expiración y comprobar que se acepta y que `GET /checkout/preferences/{id}` la devuelve con los campos.
- **Por qué**: reduce la ventana del riesgo D-04 (enlace vivo de un pago cancelado) y hace que la preferencia sobrante de R-07 caduque sola.
- **Alternativas descartadas**: no poner expiración (deja el riesgo abierto sin plazo); expirar al cancelar con `PUT` (no documentado de forma explícita).

## R-10 · Exposición de precios por rol en el servidor (D-10, FR-024 a FR-026, FR-034 a FR-036)

- **Decisión**: los servicios arman la respuesta según `req.user.role`. Los campos que un rol no debe ver **se omiten**: la clave no viaja; no se manda `null` ni se responde 403 por un campo.

  | Respuesta | ADMIN | RECEPTIONIST | MECHANIC |
  |---|---|---|---|
  | `GET /api/parts` y `/:id`: `precioCompra` | sí | no | no |
  | `GET /api/parts` y `/:id`: `precioVenta` | sí | sí | no |
  | `GET /api/service-orders/:id`: `repuestos[].precioUnitario` e `importe` (nuevos) | sí | sí | no |
  | `GET /api/service-orders/:id`: `servicios[].manoDeObra.precio` | sí | sí | sí (como hoy) |
  | `POST /:id/refacciones`: respuesta | sin precios para el mecánico | | |
  | Pagos, tickets y panel | según ruta | según ruta | 403 (como hoy) |

  - Búsquedas, filtros y ordenamientos del catálogo siguen siendo solo por nombre y código (H10); no se agregan por precio.
  - Los mensajes de error que citan importes (`MONTO_NO_COINCIDE`, `IMPORTE_DESFASADO`, `TOTAL_EXCEDE_LIMITE`) solo existen en rutas o flujos de ADMIN y RECEPTIONIST. Para el mecánico, `TOTAL_EXCEDE_LIMITE` responde sin cifras.
  - El manejador de errores registra el mensaje y la traza solo en el servidor; no registra cuerpos de petición ni de respuesta (se revisa en la implementación).
- **Por qué**: omitir el campo es lo que menos se presta a filtraciones y Flutter ya trata los precios como opcionales (`asNumOrNull`).
- **Alternativas descartadas**: devolver `null` (deja ver que el dato existe); filtrar solo en Flutter (viola el principio IV).

## R-11 · Flutter: precios por rol y marcas del ticket

- **Decisión**: las pantallas muestran un precio solo si viene en la respuesta y si el rol corresponde (doble condición). El detalle por pantalla está en [contracts/ui-flutter.md](./contracts/ui-flutter.md).
  - **«Formato anterior»**: chip con el token `warning` y la leyenda «Formato anterior» en el encabezado del ticket, con un texto de ayuda: «Generado a partir de los datos registrados al migrar».
  - **«Pago anulado»**: chip con el token `danger` y la leyenda «Pago anulado», más un aviso de que el comprobante ya no es el vigente de la orden.
  - **Nota del desglose**: aviso `warning` con «El desglose no coincide con lo cobrado».
  - **D-07**: al guardar un precio de venta menor que el de compra, aviso `warning` para el administrador.
  - Todo con tokens de `docs/design-system.md` (`warning` `#C9892B`, `danger`), radios de 8 px y transiciones suaves.
- **Por qué**: cumple el principio VIII y la regla del sistema de diseño de usar solo `warning`, `success` y `danger` para estados.

## R-12 · Cambio de rol con la sesión abierta — DESCARTADO

> **DESCARTADO (2026-11-14)**: el responsable no aprobó cerrar las sesiones al cambiar el rol. **No se implementa** y no genera tareas. Queda como **limitación conocida** en los Supuestos de la spec y como punto fuera de alcance; ver también [plan.md](./plan.md).

- **Hecho**: el servidor aplica el rol nuevo en la siguiente petición (H5), así que la seguridad del servidor no depende de Flutter. Pero Flutter conserva el rol del inicio de sesión: puede mostrar menús que ahora responden 403, o columnas vacías porque el campo ya no viene.
- **Decisión final**: **no se hace ningún cambio**. `user.service.update` sigue sin cerrar sesiones al cambiar el rol.
  - Limitación conocida: Flutter muestra la interfaz del rol anterior hasta que la persona vuelva a iniciar sesión.
  - Los precios siguen protegidos, porque el servidor decide qué campos envía según el rol actual (R-10).
- **Propuesta descartada**: que `user.service.update` cerrara las sesiones del usuario al cambiar su rol (`sessionStore.closeAllForUser`), igual que hoy al desactivarlo.
- **Otras alternativas que tampoco se implementan**: refrescar el rol en Flutter en cada pantalla (más llamadas y más código).

## R-13 · Validación de precios (FR-003, FR-032)

- **Decisión**: un solo esquema Zod reutilizable para precios (numérico, ≥ 0, máximo dos decimales, ≤ 999,999.99), que usan `part.validator.js` y `service-order.validator.js`. Como el valor llega como número de JSON, «máximo dos decimales» se valida con una tolerancia para el error de flotante: `Math.abs(valor * 100 - Math.round(valor * 100)) < 1e-6`. En Flutter se replica en `utils/validators.dart`, como apoyo.
- **Por qué**: una sola regla para refacciones y mano de obra, como pidió el responsable.

## R-14 · Ticket vigente y varios tickets por orden (FR-033)

- **Decisión**:
  - `generateTicket(ordenId)` busca el pago `PAGADO` no anulado de la orden. Si ese pago ya tiene ticket, lo devuelve (idempotencia, HU4-2); si no, emite uno nuevo con folio consecutivo y copia en versión 2.
  - `GET /api/tickets/orden/:ordenId` devuelve el ticket vigente y la lista de todos los tickets de la orden (vigente y de pagos anulados).
  - El folio sigue siendo único y consecutivo por año (`nextFolio`).
- **Por qué**: corrige H2 sin cambiar el formato del folio.
