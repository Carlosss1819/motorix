-- Datos de ejemplo del Sprint 4 (pagos y tickets). Script IDEMPOTENTE: puede
-- ejecutarse varias veces sin duplicar registros (ids fijos + INSERT IGNORE).
-- Usa los usuarios, clientes, vehículos, órdenes y refacciones sembrados en
-- 001, 002 y 003 (admin=1, recepcion=2, mecanico=3).
-- FR-013 / SC-007: el taller ve pagos y tickets de ejemplo al instalar.
-- RN-13: ningún pago apunta a una orden inexistente. RN-14: sin datos de tarjeta.

-- ---------------------------------------------------------------------------
-- Órdenes adicionales de ejemplo (2): una TERMINADO pagada (para su ticket) y
-- una TERMINADO sin pago, que deja el taller listo para demostrar el cobro y
-- la entrega condicionada (FR-014). La orden 4 del Sprint 2 ya está TERMINADO
-- y se usa como primera orden cobrable.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO service_orders
  (id, client_id, vehicle_id, appointment_id, status, visit_reason, entry_date, entry_mileage, mechanic_id, diagnosis, diagnosis_draft, recommendations, created_by)
VALUES
  (5, 4, 2, NULL, 'TERMINADO', 'Cambio de pastillas delanteras', CURDATE(), 82650, 3, 'Pastillas delanteras en el límite de desgaste.', 0, 'Revisar discos a los 10,000 km.', 2),
  (6, 2, 3, NULL, 'TERMINADO', 'Ajuste de frenos traseros',     CURDATE(), 15620, 3, NULL, 0, NULL, 2);

-- Historial de estados de las órdenes nuevas (FR-015): toda orden nace en RECIBIDO.
INSERT IGNORE INTO order_status_history (id, service_order_id, from_status, to_status, changed_by, note) VALUES
  (11, 5, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (12, 5, 'RECIBIDO', 'DIAGNOSTICO', 3, NULL),
  (13, 5, 'DIAGNOSTICO', 'EN_REPARACION', 3, NULL),
  (14, 5, 'EN_REPARACION', 'TERMINADO', 3, 'Trabajo finalizado'),
  (15, 6, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (16, 6, 'RECIBIDO', 'DIAGNOSTICO', 3, NULL),
  (17, 6, 'DIAGNOSTICO', 'TERMINADO', 3, 'Trabajo finalizado');

-- Contenido de las órdenes nuevas: la 5 lleva refacción del catálogo (con
-- part_id), la 6 solo mano de obra.
INSERT IGNORE INTO order_services (id, service_order_id, description) VALUES
  (4, 5, 'Cambio de pastillas delanteras'),
  (5, 6, 'Ajuste de frenos traseros');

INSERT IGNORE INTO order_labor (id, service_order_id, service_id, description, duration_minutes, price) VALUES
  (4, 5, 4, 'Mano de obra pastillas delanteras', 60, 750.00),
  (5, 6, 5, 'Mano de obra ajuste trasero',       45, 500.00);

INSERT IGNORE INTO order_parts (id, service_order_id, description, quantity, part_id) VALUES
  (4, 5, 'Juego de pastillas delanteras', 2, 3);

-- ---------------------------------------------------------------------------
-- Pagos (4): efectivo pagado (orden 4), tarjeta pagada (orden 5), Mercado
-- Pago pendiente (orden 6, sin pago aprobado) y Mercado Pago anulado con
-- motivo (orden 5, libre de nueva liquidación). Totales calculados con los
-- precios vigentes al momento de cobrar (FR-015):
--   orden 4: mano de obra 900.00 + refacción heredada sin precio (0)  = 900.00
--   orden 5: mano de obra 750.00 + pastillas 320.00 × 2               = 1390.00
--   orden 6: solo mano de obra                                         = 500.00
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO payments
  (id, service_order_id, amount, method, status, external_reference, payment_link, gateway_mode, annulment_reason, annulled_by, created_by, created_at, annulled_at)
VALUES
  (1, 4,  900.00,  'EFECTIVO',     'PAGADO',    NULL, NULL, NULL, NULL,        NULL, 2, CURDATE() - INTERVAL 2 DAY, NULL),
  (2, 5,  1390.00, 'TARJETA',      'PAGADO',    NULL, NULL, NULL, NULL,        NULL, 2, CURDATE() - INTERVAL 1 DAY, NULL),
  (3, 6,  500.00,  'MERCADO_PAGO', 'PENDIENTE', 'MP-SEED-0003', 'https://sandbox.example.com/mp/MP-SEED-0003', 'simulado', NULL, NULL, 2, CURDATE(), NULL),
  (4, 5,  1390.00, 'MERCADO_PAGO', 'ANULADO',   'MP-SEED-0004', 'https://sandbox.example.com/mp/MP-SEED-0004', 'simulado', 'Cobro capturado por error; se registró después en efectivo.', 1, 2, CURDATE() - INTERVAL 1 DAY, CURDATE() - INTERVAL 1 DAY);

-- ---------------------------------------------------------------------------
-- Tickets (2): emitidos para las órdenes de ejemplo ya pagadas (4 y 5), con
-- folios fijos T000001-2026 y T000002-2026 (D3, FR-007). La orden 6 no tiene
-- ticket porque su pago sigue PENDIENTE (FR-009).
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO tickets (id, service_order_id, payment_id, folio, issued_by, issued_at) VALUES
  (1, 4, 1, 'T000001-2026', 2, CURDATE() - INTERVAL 2 DAY),
  (2, 5, 2, 'T000002-2026', 2, CURDATE() - INTERVAL 1 DAY);
