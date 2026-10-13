-- Datos de ejemplo del Sprint 3 (inventario, mantenimientos y movimientos).
-- Script IDEMPOTENTE: puede ejecutarse varias veces sin duplicar registros
-- (ids fijos + INSERT IGNORE). Usa los usuarios, clientes y vehículos sembrados
-- en 001 y 002 (admin=1, recepcion=2, mecanico=3; vehículos 1-4).
-- FR-031 / R-13: refacciones con existencias variadas, mantenimientos en los
-- tres estados y movimientos iniciales. El historial NO se siembra: se deriva
-- de las órdenes terminadas del Sprint 2 (RN-10, R-01).

-- ---------------------------------------------------------------------------
-- Catálogo de refacciones (6): dos en stock bajo, una con stock mínimo 0
-- (sin alerta), una desactivada y existencias variadas.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO parts (id, code, name, category, brand, stock_current, stock_min, purchase_price, sale_price, is_active) VALUES
  (1, 'ACE-5W30', 'Aceite sintético 5W30 (5L)',        'Motor',    'Mobil',   24,  10, 380.00, 620.00, 1),
  (2, 'FIL-ACE01', 'Filtro de aceite universal',        'Motor',    'Mann',    3,   5,  45.00,  95.00, 1),
  (3, 'PAS-DEL01', 'Juego de pastillas delanteras',     'Frenos',   'Brembo',  12,  4,  180.00, 320.00, 1),
  (4, 'BRT-TRA01', 'Balata de freno trasera',           'Frenos',   'Brembo',  2,   2,  150.00, 280.00, 1),
  (5, 'REF-R134', 'Gas refrigerante R-134a (1L)',       'Clima',    'Dupont',  0,   0,  90.00, 160.00, 1),
  (6, 'Buj-NGK01', 'Bujía NGK estándar (unidad)',       'Motor',    'NGK',     40,  12, 35.00,  75.00, 0);

-- ---------------------------------------------------------------------------
-- Movimientos iniciales (stock_after coherente con el stock actual, SC-007).
-- El movimiento 6 es un AJUSTE con motivo; los demás son entradas de
-- reabastecimiento iniciales.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO inventory_movements (id, part_id, movement_type, quantity, reason, service_order_id, stock_after, created_by, created_at) VALUES
  (1, 1, 'ENTRADA', 24, 'Reabastecimiento inicial',      NULL, 24, 1, CURDATE() - INTERVAL 10 DAY),
  (2, 2, 'ENTRADA', 8,  'Reabastecimiento inicial',      NULL, 8,  1, CURDATE() - INTERVAL 10 DAY),
  (3, 2, 'SALIDA',  5,  'Uso en órdenes del taller',     4,    3,  3, CURDATE() - INTERVAL 3 DAY),
  (4, 3, 'ENTRADA', 12, 'Reabastecimiento inicial',      NULL, 12, 1, CURDATE() - INTERVAL 10 DAY),
  (5, 4, 'ENTRADA', 4,  'Reabastecimiento inicial',      NULL, 4,  1, CURDATE() - INTERVAL 10 DAY),
  (6, 4, 'AJUSTE',  2,  'Conteo físico: dos unidades dañadas', NULL, 2, 1, CURDATE() - INTERVAL 2 DAY),
  (7, 5, 'SALIDA',  6,  'Gas refrigerante usado en reparaciones', NULL, 0, 3, CURDATE() - INTERVAL 4 DAY),
  (8, 6, 'ENTRADA', 40, 'Reabastecimiento inicial',      NULL, 40, 1, CURDATE() - INTERVAL 10 DAY);

-- ---------------------------------------------------------------------------
-- Mantenimientos (3 por vehículo): uno VENCIDO (fecha objetivo pasada), uno
-- PRÓXIMO (objetivo cercano en km) y uno NORMAL. El estado NO se guarda: lo
-- calcula la aplicación (R-04); estos objetivos garantizan los tres estados.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO maintenance
  (id, vehicle_id, service_type, last_service_date, last_service_mileage, target_date, target_mileage, interval_days, interval_km, advance_days, advance_km, notes, created_by)
VALUES
  (1, 1, 'Cambio de aceite y filtro', CURDATE() - INTERVAL 100 DAY, 40000, CURDATE() - INTERVAL 10 DAY, 45000, 90, 5000, 30, 500, 'Usar aceite sintético 5W30 y filtro universal.', 3),
  (2, 1, 'Rotación de llantas',       CURDATE() - INTERVAL 60 DAY, 42000, CURDATE() + INTERVAL 20 DAY, 46500, 60, 4000, 15, 400, 'Revisar presión y desgaste.', 3),
  (3, 2, 'Cambio de correa',          CURDATE() - INTERVAL 200 DAY, 75000, CURDATE() + INTERVAL 150 DAY, 95000, 180, 20000, 30, 1000, 'Correa y tensor en el mismo servicio.', 3),
  (4, 3, 'Revisión de frenos',        CURDATE() - INTERVAL 30 DAY, 15000, CURDATE() + INTERVAL 60 DAY, 18000, 90, 3000, 30, 500, 'Verificar pastillas y discos.', 3),
  (5, 4, 'Mantenimiento mayor 30k',   CURDATE() - INTERVAL 5 DAY, 120400, CURDATE() + INTERVAL 85 DAY, 125400, 90, 5000, 30, 500, 'Revisión completa realizada.', 3);
