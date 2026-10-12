-- Datos de ejemplo del Sprint 2 (citas y órdenes de servicio). Script IDEMPOTENTE:
-- puede ejecutarse varias veces sin duplicar registros (ids fijos + INSERT IGNORE).
-- Usa clientes, vehículos y usuarios sembrados en 001_datos_iniciales.sql
-- (admin=1, recepcion=2, mecanico=3; clientes 1-4, vehículos 1-4).
-- FR-021 / SC-006: al menos 5 citas y 4 órdenes con estados variados.
--
-- Nota: las citas 1 y 2 ("citas de hoy") se refrescan en cada ejecución para que la
-- demostración del panel de recepción siga siendo válida con el día actual; las demás
-- citas y todas las órdenes solo se insertan si no existen (no se alteran).

-- ---------------------------------------------------------------------------
-- Citas (5): 2 de hoy PROGRAMADA, 1 RECIBIDA ligada a la orden 1, 1 NO_PRESENTADA
-- y 1 CANCELADA.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO appointments (id, client_id, vehicle_id, appointment_date, appointment_time, reason, status, cancel_reason, created_by) VALUES
  (1, 1, 1, CURDATE(), '10:00:00', 'Revisión de frenos delanteros', 'PROGRAMADA', NULL, 2),
  (2, 2, 3, CURDATE(), '12:30:00', 'Cambio de aceite y filtros', 'PROGRAMADA', NULL, 2),
  (3, 3, 4, CURDATE() - INTERVAL 1 DAY, '09:00:00', 'Diagnóstico de falla eléctrica', 'NO_PRESENTADA', NULL, 2),
  (4, 1, 1, CURDATE(), '08:00:00', 'Revisión de frenos', 'RECIBIDA', NULL, 2),
  (5, 4, 2, CURDATE() - INTERVAL 2 DAY, '16:00:00', 'Alineación y balanceo', 'CANCELADA', 'El cliente no pudo asistir', 2);

-- Refresco de la ventana de demostración (sin duplicar: solo actualiza las filas 1 y 2)
INSERT INTO appointments (id, client_id, vehicle_id, appointment_date, appointment_time, reason, status, cancel_reason, created_by) VALUES
  (1, 1, 1, CURDATE(), '10:00:00', 'Revisión de frenos delanteros', 'PROGRAMADA', NULL, 2),
  (2, 2, 3, CURDATE(), '12:30:00', 'Cambio de aceite y filtros', 'PROGRAMADA', NULL, 2)
ON DUPLICATE KEY UPDATE
  appointment_date = VALUES(appointment_date),
  appointment_time = VALUES(appointment_time),
  reason = VALUES(reason),
  status = 'PROGRAMADA',
  cancel_reason = NULL;

-- ---------------------------------------------------------------------------
-- Órdenes de servicio (4): RECIBIDO, DIAGNOSTICO, EN_REPARACION y TERMINADO.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO service_orders
  (id, client_id, vehicle_id, appointment_id, status, visit_reason, entry_date, entry_mileage, mechanic_id, diagnosis, diagnosis_draft, recommendations, created_by)
VALUES
  (1, 1, 1, 4, 'RECIBIDO',     'Revisión de frenos',              CURDATE(), 45200,  NULL, NULL, 0, NULL, 2),
  (2, 1, 2, NULL, 'DIAGNOSTICO',    'Ruido en suspensión trasera',    CURDATE(), 82100,  3,     'Bujes traseros desgastados; se requiere reemplazo de la pareja.', 0, NULL, 2),
  (3, 2, 3, NULL, 'EN_REPARACION', 'Cambio de correa de distribución', CURDATE(), 15300,  3,     'Correa con fisuras visibles.', 0, NULL, 2),
  (4, 3, 4, NULL, 'TERMINADO',    'Mantenimiento mayor',            CURDATE(), 120400, 3,     'Revisión completa de 30,000 km realizada.', 0, 'Revisar niveles de líquidos a los 5,000 km.', 2);

-- ---------------------------------------------------------------------------
-- Historial de estados (FR-015): toda orden nace en RECIBIDO.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO order_status_history (id, service_order_id, from_status, to_status, changed_by, note) VALUES
  (1,  1, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (2,  2, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (3,  2, 'RECIBIDO', 'DIAGNOSTICO', 3, NULL),
  (4,  3, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (5,  3, 'RECIBIDO', 'DIAGNOSTICO', 3, NULL),
  (6,  3, 'DIAGNOSTICO', 'EN_REPARACION', 3, NULL),
  (7,  4, NULL, 'RECIBIDO',      2, 'Alta de la orden'),
  (8,  4, 'RECIBIDO', 'DIAGNOSTICO', 3, NULL),
  (9,  4, 'DIAGNOSTICO', 'EN_REPARACION', 3, NULL),
  (10, 4, 'EN_REPARACION', 'TERMINADO', 3, 'Trabajo finalizado');

-- ---------------------------------------------------------------------------
-- Servicios, mano de obra y repuestos de ejemplo (FR-012).
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO order_services (id, service_order_id, description) VALUES
  (1, 2, 'Cambio de bujes traseros'),
  (2, 3, 'Cambio de correa de distribución'),
  (3, 4, 'Mantenimiento de 30,000 km');

INSERT IGNORE INTO order_labor (id, service_order_id, service_id, description, duration_minutes, price) VALUES
  (1, 2, 1, 'Mano de obra suspensión trasera', 60, 450.00),
  (2, 3, 2, 'Mano de obra distribución', 90, 700.00),
  (3, 4, 3, 'Mano de obra mantenimiento mayor', 120, 900.00);

INSERT IGNORE INTO order_parts (id, service_order_id, description, quantity) VALUES
  (1, 2, 'Buje trasero', 2),
  (2, 3, 'Correa de distribución', 1),
  (3, 4, 'Filtro de aceite', 1);
