-- Datos de ejemplo del Sprint 5 (precios congelados y tickets por pago).
-- Script IDEMPOTENTE: puede ejecutarse varias veces sin duplicar registros.
-- Fuente de verdad: specs/005-precios-refacciones-cobro/research.md (R-05) y data-model.md.

-- ===========================================================================
-- PARTE A: completa el precio congelado y la copia del ticket SOLO de las filas
-- del seed 004 (por id), porque en una base nueva el 006 corre antes que los
-- seeds y esas filas nacen con las columnas nuevas en NULL. Misma lógica que el
-- 006; solo actúa donde la columna sigue en NULL.
-- ===========================================================================

UPDATE order_parts op
JOIN parts p ON p.id = op.part_id
SET op.unit_price = p.sale_price
WHERE op.unit_price IS NULL AND op.id = 4;

UPDATE tickets t
JOIN payments pa ON pa.id = t.payment_id
JOIN service_orders so ON so.id = t.service_order_id
JOIN clients c ON c.id = so.client_id
JOIN vehicles v ON v.id = so.vehicle_id
JOIN users u ON u.id = t.issued_by
LEFT JOIN (
  SELECT service_order_id, SUM(COALESCE(price, 0)) AS subtotal
  FROM order_labor
  GROUP BY service_order_id
) mo ON mo.service_order_id = t.service_order_id
LEFT JOIN (
  SELECT service_order_id,
         SUM(IF(part_id IS NULL OR unit_price IS NULL, 0, unit_price * quantity)) AS subtotal
  FROM order_parts
  GROUP BY service_order_id
) rf ON rf.service_order_id = t.service_order_id
SET t.content = JSON_OBJECT(
      'folio', t.folio,
      'ordenId', t.service_order_id,
      'pagoId', t.payment_id,
      'emitidoPor', u.username,
      'emitidoEn', DATE_FORMAT(t.issued_at, '%Y-%m-%d %H:%i:%s'),
      'taller', JSON_OBJECT(
        'nombre', 'Motorix',
        'direccion', 'Av. Ejemplo 123, Col. Centro',
        'telefono', '55-0000-0000'),
      'cliente', JSON_OBJECT('id', c.id, 'nombre', c.name, 'telefono', c.phone),
      'vehiculo', JSON_OBJECT(
        'id', v.id, 'marca', v.brand, 'modelo', v.model, 'anio', v.year,
        'placas', v.plates, 'kilometraje', so.entry_mileage),
      'servicios', COALESCE(
        (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                  'descripcion', l.description,
                  'manoDeObra', COALESCE(l.price, 0),
                  'avisoManoDeObra', IF(l.price IS NULL, 'sin precio registrado', NULL),
                  'refacciones', IF(
                    l.id = (SELECT MIN(l2.id) FROM order_labor l2
                            WHERE l2.service_order_id = t.service_order_id),
                    COALESCE(
                      (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                                'codigo', cat.code,
                                'nombre', COALESCE(cat.name, lp.description),
                                'cantidad', lp.quantity,
                                'precioUnitario', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price),
                                'subtotal', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 0, lp.unit_price * lp.quantity),
                                'aviso', IF(lp.part_id IS NULL OR lp.unit_price IS NULL, 'sin precio registrado', NULL)))
                       FROM order_parts lp
                       LEFT JOIN parts cat ON cat.id = lp.part_id
                       WHERE lp.service_order_id = t.service_order_id),
                      JSON_ARRAY()),
                    JSON_ARRAY())))
         FROM order_labor l
         WHERE l.service_order_id = t.service_order_id),
        JSON_ARRAY()),
      'subtotalManoDeObra', COALESCE(mo.subtotal, 0),
      'subtotalRefacciones', COALESCE(rf.subtotal, 0),
      'total', pa.amount,
      'metodoPago', pa.method,
      'fecha', DATE_FORMAT(t.issued_at, '%Y-%m-%d'),
      'formatoVersion', 1,
      'desgloseNoCoincide', IF(
        COALESCE(mo.subtotal, 0) + COALESCE(rf.subtotal, 0) <> pa.amount,
        CAST('true' AS JSON), CAST('false' AS JSON)),
      'nota', IF(
        COALESCE(mo.subtotal, 0) + COALESCE(rf.subtotal, 0) <> pa.amount,
        'El desglose no coincide con lo cobrado', NULL)
    ),
    t.format_version = 1
WHERE t.content IS NULL AND t.id IN (1, 2);

-- ===========================================================================
-- PARTE B: ejemplos del Sprint 5 (FR-029). Ids fijos en un rango alto (desde
-- 9001) e INSERT IGNORE, para no chocar con datos capturados a mano (riesgo
-- H12). Folios de ejemplo con prefijo «D» (demostración), fuera de la
-- numeración consecutiva `T000000-AAAA` que asigna la aplicación.
-- Usuarios del seed 001: admin = 1, recepcion = 2, mecanico = 3.
-- Cliente 2 (María López) y vehículo 3 (Toyota Corolla 2022, GHI9012).
--
--   Orden 9001: cobrada, con refacciones a precio congelado y ticket v2.
--     mano de obra 350.00 + batería 1 x 1450.00 + aceite 4 x 145.50 = 2382.00
--   Orden 9002: pago anulado + pago nuevo, cada uno con su ticket (FR-033).
--     mano de obra 600.00 + aceite 2 x 145.50 = 891.00
--   Orden 9003: TERMINADO lista para cobrar (sin pago).
--     mano de obra 400.00 + tapete 1 x 199.50 = 599.50
-- Las líneas de refacción del seed no descuentan stock ni dejan movimientos,
-- igual que las del seed 004.
-- ===========================================================================

-- Refacciones: la 9001 tiene precio de venta MENOR que el de compra (D-07).
INSERT IGNORE INTO parts (id, code, name, category, brand, stock_current, stock_min, purchase_price, sale_price, is_active) VALUES
  (9001, 'DEM-TAP01', 'Tapete de hule (liquidación)',    'Accesorios', 'Motorix', 10, 2,  250.00,  199.50, 1),
  (9002, 'DEM-BAT01', 'Batería 12V 45Ah',                'Eléctrico',  'LTH',      8, 2, 1100.00, 1450.00, 1),
  (9003, 'DEM-ACE02', 'Aceite semisintético 10W40 (1L)', 'Motor',      'Castrol', 30, 6,   95.00,  145.50, 1);

INSERT IGNORE INTO service_orders
  (id, client_id, vehicle_id, appointment_id, status, visit_reason, entry_date, entry_mileage, mechanic_id, diagnosis, diagnosis_draft, recommendations, created_by)
VALUES
  (9001, 2, 3, NULL, 'TERMINADO', 'Cambio de batería y aceite', '2026-11-10', 15700, 3, 'Batería sin carga y aceite vencido.', 0, 'Revisar el alternador en el próximo servicio.', 2),
  (9002, 2, 3, NULL, 'TERMINADO', 'Afinación menor',            '2026-11-11', 15800, 3, 'Afinación de rutina.', 0, NULL, 2),
  (9003, 2, 3, NULL, 'TERMINADO', 'Revisión de frenos',         '2026-11-12', 15900, 3, 'Frenos en buen estado; se cambia el tapete.', 0, NULL, 2);

INSERT IGNORE INTO order_status_history (id, service_order_id, from_status, to_status, changed_by, note) VALUES
  (9001, 9001, NULL, 'RECIBIDO', 2, 'Alta de la orden'),
  (9002, 9001, 'RECIBIDO', 'TERMINADO', 3, 'Trabajo finalizado'),
  (9003, 9002, NULL, 'RECIBIDO', 2, 'Alta de la orden'),
  (9004, 9002, 'RECIBIDO', 'TERMINADO', 3, 'Trabajo finalizado'),
  (9005, 9003, NULL, 'RECIBIDO', 2, 'Alta de la orden'),
  (9006, 9003, 'RECIBIDO', 'TERMINADO', 3, 'Trabajo finalizado');

INSERT IGNORE INTO order_services (id, service_order_id, description) VALUES
  (9001, 9001, 'Cambio de batería y aceite'),
  (9002, 9002, 'Afinación menor'),
  (9003, 9003, 'Revisión de frenos');

INSERT IGNORE INTO order_labor (id, service_order_id, service_id, description, duration_minutes, price) VALUES
  (9001, 9001, 9001, 'Mano de obra cambio de batería y aceite', 60, 350.00),
  (9002, 9002, 9002, 'Mano de obra afinación menor',            90, 600.00),
  (9003, 9003, 9003, 'Mano de obra revisión de frenos',         45, 400.00);

-- Líneas con el precio de venta congelado al agregarlas (FR-006).
INSERT IGNORE INTO order_parts (id, service_order_id, description, quantity, part_id, unit_price) VALUES
  (9001, 9001, 'Batería 12V 45Ah',                1, 9002, 1450.00),
  (9002, 9001, 'Aceite semisintético 10W40 (1L)', 4, 9003,  145.50),
  (9003, 9002, 'Aceite semisintético 10W40 (1L)', 2, 9003,  145.50),
  (9004, 9003, 'Tapete de hule (liquidación)',    1, 9001,  199.50);

INSERT IGNORE INTO payments
  (id, service_order_id, amount, method, status, external_reference, payment_link, gateway_mode, annulment_reason, annulled_by, created_by, created_at, annulled_at)
VALUES
  (9001, 9001, 2382.00, 'EFECTIVO', 'PAGADO',  NULL, NULL, NULL, NULL, NULL, 2, '2026-11-10 10:00:00', NULL),
  (9002, 9002,  891.00, 'TARJETA',  'ANULADO', NULL, NULL, NULL, 'Cobro registrado con la tarjeta equivocada.', 1, 2, '2026-11-11 09:00:00', '2026-11-11 09:30:00'),
  (9003, 9002,  891.00, 'EFECTIVO', 'PAGADO',  NULL, NULL, NULL, NULL, NULL, 2, '2026-11-11 09:45:00', NULL);

-- Tickets con su copia en versión 2 (FR-019), con la estructura de
-- data-model.md. El 9002 es del pago anulado: se muestra con «Pago anulado».
INSERT IGNORE INTO tickets (id, service_order_id, payment_id, folio, issued_by, issued_at, content, format_version) VALUES
  (9001, 9001, 9001, 'D009001-2026', 2, '2026-11-10 10:05:00',
    JSON_OBJECT(
      'folio', 'D009001-2026', 'ordenId', 9001, 'pagoId', 9001,
      'emitidoPor', 'recepcion', 'emitidoEn', '2026-11-10 10:05:00',
      'taller', JSON_OBJECT('nombre', 'Motorix', 'direccion', 'Av. Ejemplo 123, Col. Centro', 'telefono', '55-0000-0000'),
      'cliente', JSON_OBJECT('id', 2, 'nombre', 'María López', 'telefono', '5551002002'),
      'vehiculo', JSON_OBJECT('id', 3, 'marca', 'Toyota', 'modelo', 'Corolla', 'anio', 2022, 'placas', 'GHI9012', 'kilometraje', 15700),
      'servicios', JSON_ARRAY(JSON_OBJECT(
        'descripcion', 'Mano de obra cambio de batería y aceite', 'manoDeObra', 350.00, 'avisoManoDeObra', NULL,
        'refacciones', JSON_ARRAY(
          JSON_OBJECT('codigo', 'DEM-BAT01', 'nombre', 'Batería 12V 45Ah', 'cantidad', 1, 'precioUnitario', 1450.00, 'subtotal', 1450.00, 'aviso', NULL),
          JSON_OBJECT('codigo', 'DEM-ACE02', 'nombre', 'Aceite semisintético 10W40 (1L)', 'cantidad', 4, 'precioUnitario', 145.50, 'subtotal', 582.00, 'aviso', NULL)))),
      'subtotalManoDeObra', 350.00, 'subtotalRefacciones', 2032.00, 'total', 2382.00,
      'metodoPago', 'EFECTIVO', 'fecha', '2026-11-10',
      'formatoVersion', 2, 'desgloseNoCoincide', CAST('false' AS JSON), 'nota', NULL),
    2),
  (9002, 9002, 9002, 'D009002-2026', 2, '2026-11-11 09:05:00',
    JSON_OBJECT(
      'folio', 'D009002-2026', 'ordenId', 9002, 'pagoId', 9002,
      'emitidoPor', 'recepcion', 'emitidoEn', '2026-11-11 09:05:00',
      'taller', JSON_OBJECT('nombre', 'Motorix', 'direccion', 'Av. Ejemplo 123, Col. Centro', 'telefono', '55-0000-0000'),
      'cliente', JSON_OBJECT('id', 2, 'nombre', 'María López', 'telefono', '5551002002'),
      'vehiculo', JSON_OBJECT('id', 3, 'marca', 'Toyota', 'modelo', 'Corolla', 'anio', 2022, 'placas', 'GHI9012', 'kilometraje', 15800),
      'servicios', JSON_ARRAY(JSON_OBJECT(
        'descripcion', 'Mano de obra afinación menor', 'manoDeObra', 600.00, 'avisoManoDeObra', NULL,
        'refacciones', JSON_ARRAY(
          JSON_OBJECT('codigo', 'DEM-ACE02', 'nombre', 'Aceite semisintético 10W40 (1L)', 'cantidad', 2, 'precioUnitario', 145.50, 'subtotal', 291.00, 'aviso', NULL)))),
      'subtotalManoDeObra', 600.00, 'subtotalRefacciones', 291.00, 'total', 891.00,
      'metodoPago', 'TARJETA', 'fecha', '2026-11-11',
      'formatoVersion', 2, 'desgloseNoCoincide', CAST('false' AS JSON), 'nota', NULL),
    2),
  (9003, 9002, 9003, 'D009003-2026', 2, '2026-11-11 09:50:00',
    JSON_OBJECT(
      'folio', 'D009003-2026', 'ordenId', 9002, 'pagoId', 9003,
      'emitidoPor', 'recepcion', 'emitidoEn', '2026-11-11 09:50:00',
      'taller', JSON_OBJECT('nombre', 'Motorix', 'direccion', 'Av. Ejemplo 123, Col. Centro', 'telefono', '55-0000-0000'),
      'cliente', JSON_OBJECT('id', 2, 'nombre', 'María López', 'telefono', '5551002002'),
      'vehiculo', JSON_OBJECT('id', 3, 'marca', 'Toyota', 'modelo', 'Corolla', 'anio', 2022, 'placas', 'GHI9012', 'kilometraje', 15800),
      'servicios', JSON_ARRAY(JSON_OBJECT(
        'descripcion', 'Mano de obra afinación menor', 'manoDeObra', 600.00, 'avisoManoDeObra', NULL,
        'refacciones', JSON_ARRAY(
          JSON_OBJECT('codigo', 'DEM-ACE02', 'nombre', 'Aceite semisintético 10W40 (1L)', 'cantidad', 2, 'precioUnitario', 145.50, 'subtotal', 291.00, 'aviso', NULL)))),
      'subtotalManoDeObra', 600.00, 'subtotalRefacciones', 291.00, 'total', 891.00,
      'metodoPago', 'EFECTIVO', 'fecha', '2026-11-11',
      'formatoVersion', 2, 'desgloseNoCoincide', CAST('false' AS JSON), 'nota', NULL),
    2);
