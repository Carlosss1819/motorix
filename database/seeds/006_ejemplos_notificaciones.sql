-- Datos de ejemplo del Sprint 6 (notificaciones internas y «Clientes por avisar»).
-- Script IDEMPOTENTE: puede ejecutarse varias veces sin duplicar registros.
-- Fuente de verdad: specs/006-notificaciones-internas/research.md (R-10), FR-025.
--
-- Reglas del seed:
--   * Ids fijos en el rango 60001 a 60099 en todas las tablas que toca
--     (corrección C-03), con claves propias: nombres y motivos que empiezan con
--     «[Sprint 6]», códigos `NOT-` y placas `NOT6-`.
--   * Fechas RELATIVAS (CURDATE()/NOW()) calculadas al cargar. Si la
--     demostración es otro día, vuelve a cargar el seed ese día.
--   * `INSERT ... ON DUPLICATE KEY UPDATE`: recargarlo refresca fechas y
--     estados de SUS filas sin duplicarlas. No borra nada: si en la demostración
--     marcas a la cliente como «avisada», ese registro se conserva.
--   * Usuarios por `username` (admin, recepcion, mecanico), no por id.
--
-- Qué genera (con la fecha del día de carga):
--   MANT_VENCIDO   mantenimiento 60001, objetivo hace 10 días (vehículo 60003)
--   MANT_PROXIMO   mantenimiento 60002, objetivo en 10 días, antelación 30 (vehículo 60002)
--   STOCK_BAJO     refacción 60001 NOT-BAJ01 (existencia 2, mínimo 5)
--   STOCK_AGOTADO  refacción 60002 NOT-AGO01 (existencia 0, mínimo 3)
--   CITA_HOY       cita 60001 hoy a las 23:30 (PROGRAMADA), para que no pase a
--                  NO_PRESENTADA durante la demostración
--   ORDEN_DETENIDA orden 60001 EN_REPARACION asignada a `mecanico`, último
--                  cambio hace 5 días; orden 60002 DIAGNOSTICO sin mecánico,
--                  último cambio hace 4 días
--   Clientes por avisar: orden 60003 TERMINADO (vehículo listo), cita 60002
--                  de mañana y los dos mantenimientos de arriba.

SET @s6_admin = (SELECT id FROM users WHERE username = 'admin' LIMIT 1);
SET @s6_recepcion = (SELECT id FROM users WHERE username = 'recepcion' LIMIT 1);
SET @s6_mecanico = (SELECT id FROM users WHERE username = 'mecanico' LIMIT 1);

-- Cliente con teléfono y tres vehículos ------------------------------------
INSERT INTO clients (id, name, phone, email, status) VALUES
  (60001, '[Sprint 6] Laura Méndez', '5550060001', 'laura.mendez@correo.com', 'ACTIVO')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  phone = VALUES(phone),
  status = VALUES(status);

INSERT INTO vehicles (id, client_id, brand, model, year, plates, vin, current_mileage) VALUES
  (60001, 60001, 'Volkswagen', 'Jetta', 2019, 'NOT6-001', NULL, 61000),
  (60002, 60001, 'Kia', 'Rio', 2021, 'NOT6-002', NULL, 28000),
  (60003, 60001, 'Chevrolet', 'Aveo', 2017, 'NOT6-003', NULL, 97000)
ON DUPLICATE KEY UPDATE
  client_id = VALUES(client_id),
  plates = VALUES(plates),
  current_mileage = GREATEST(current_mileage, VALUES(current_mileage));

-- Mantenimientos: vencido y próximo (solo por fecha) -------------------------
INSERT INTO maintenance (id, vehicle_id, service_type, target_date, target_mileage,
                         advance_days, advance_km, notes, created_by) VALUES
  (60001, 60003, '[Sprint 6] Cambio de aceite', CURDATE() - INTERVAL 10 DAY, NULL,
   30, 500, 'Ejemplo de mantenimiento vencido', @s6_admin),
  (60002, 60002, '[Sprint 6] Afinación', CURDATE() + INTERVAL 10 DAY, NULL,
   30, 500, 'Ejemplo de mantenimiento próximo', @s6_admin)
ON DUPLICATE KEY UPDATE
  vehicle_id = VALUES(vehicle_id),
  target_date = VALUES(target_date),
  target_mileage = VALUES(target_mileage),
  advance_days = VALUES(advance_days),
  advance_km = VALUES(advance_km);

-- Refacciones: stock bajo y agotada ------------------------------------------
INSERT INTO parts (id, code, name, category, brand, stock_current, stock_min,
                   purchase_price, sale_price, is_active) VALUES
  (60001, 'NOT-BAJ01', 'Bujía de iridio (ejemplo Sprint 6)', 'Encendido', 'Motorix', 2, 5, 95.00, 150.00, 1),
  (60002, 'NOT-AGO01', 'Sensor de oxígeno (ejemplo Sprint 6)', 'Sensores', 'Motorix', 0, 3, 420.00, 650.00, 1)
ON DUPLICATE KEY UPDATE
  stock_current = VALUES(stock_current),
  stock_min = VALUES(stock_min),
  is_active = VALUES(is_active);

-- Citas: hoy a las 23:30 y mañana --------------------------------------------
INSERT INTO appointments (id, client_id, vehicle_id, appointment_date, appointment_time,
                          reason, status, cancel_reason, created_by) VALUES
  (60001, 60001, 60001, CURDATE(), '23:30:00',
   '[Sprint 6] Revisión de ruido en el motor', 'PROGRAMADA', NULL, @s6_recepcion),
  (60002, 60001, 60003, CURDATE() + INTERVAL 1 DAY, '10:00:00',
   '[Sprint 6] Revisión de suspensión', 'PROGRAMADA', NULL, @s6_recepcion)
ON DUPLICATE KEY UPDATE
  appointment_date = VALUES(appointment_date),
  appointment_time = VALUES(appointment_time),
  status = VALUES(status),
  cancel_reason = NULL;

-- Órdenes: dos detenidas y una terminada sin entregar ------------------------
INSERT INTO service_orders (id, client_id, vehicle_id, appointment_id, status, visit_reason,
                            entry_date, entry_mileage, mechanic_id, diagnosis, diagnosis_draft,
                            recommendations, created_by, created_at) VALUES
  (60001, 60001, 60001, NULL, 'EN_REPARACION', '[Sprint 6] Fuga de anticongelante',
   CURDATE() - INTERVAL 6 DAY, 61000, @s6_mecanico, 'Manguera inferior del radiador rota.', 0,
   NULL, @s6_recepcion, NOW() - INTERVAL 6 DAY),
  (60002, 60001, 60002, NULL, 'DIAGNOSTICO', '[Sprint 6] Testigo de motor encendido',
   CURDATE() - INTERVAL 4 DAY, 28000, NULL, NULL, 0,
   NULL, @s6_recepcion, NOW() - INTERVAL 4 DAY),
  (60003, 60001, 60003, NULL, 'TERMINADO', '[Sprint 6] Cambio de balatas',
   CURDATE() - INTERVAL 1 DAY, 97000, @s6_mecanico, 'Balatas delanteras al 10 %.', 0,
   'Revisar discos en el próximo servicio.', @s6_recepcion, NOW() - INTERVAL 1 DAY)
ON DUPLICATE KEY UPDATE
  status = VALUES(status),
  entry_date = VALUES(entry_date),
  mechanic_id = VALUES(mechanic_id),
  delivery_date = NULL,
  created_at = VALUES(created_at);

-- Historial: el último cambio de cada orden fija su antigüedad ---------------
INSERT INTO order_status_history (id, service_order_id, from_status, to_status,
                                  changed_by, changed_at, note) VALUES
  (60001, 60001, NULL, 'RECIBIDO', @s6_recepcion, NOW() - INTERVAL 6 DAY, '[Sprint 6] Alta de la orden'),
  (60002, 60001, 'RECIBIDO', 'EN_REPARACION', @s6_mecanico, NOW() - INTERVAL 5 DAY, '[Sprint 6] Inicia reparación'),
  (60003, 60002, NULL, 'RECIBIDO', @s6_recepcion, NOW() - INTERVAL 4 DAY - INTERVAL 2 HOUR, '[Sprint 6] Alta de la orden'),
  (60004, 60002, 'RECIBIDO', 'DIAGNOSTICO', @s6_recepcion, NOW() - INTERVAL 4 DAY, '[Sprint 6] En diagnóstico'),
  (60005, 60003, NULL, 'RECIBIDO', @s6_recepcion, NOW() - INTERVAL 1 DAY, '[Sprint 6] Alta de la orden'),
  (60006, 60003, 'RECIBIDO', 'TERMINADO', @s6_mecanico, NOW() - INTERVAL 2 HOUR, '[Sprint 6] Trabajo terminado')
ON DUPLICATE KEY UPDATE
  service_order_id = VALUES(service_order_id),
  from_status = VALUES(from_status),
  to_status = VALUES(to_status),
  changed_at = VALUES(changed_at),
  note = VALUES(note);
