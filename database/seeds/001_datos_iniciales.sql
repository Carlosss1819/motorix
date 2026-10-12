-- Datos de ejemplo iniciales del MVP (Sprint 1). Script IDEMPOTENTE: puede
-- ejecutarse varias veces sin duplicar datos (usa INSERT IGNORE + ids fijos).
-- Las contraseñas se guardan SOLO como hash bcrypt (nunca en texto plano).
-- Cuentas locales (solo desarrollo): admin/Admin2026!, recepcion/Recepcion2026!,
-- mecanico/Mecanico2026!

INSERT IGNORE INTO users (username, email, password_hash, role, status) VALUES
  ('admin', 'admin@motorix.local', '$2b$10$xFql0seH015D/GMTSLf8tuqT.E3l03IkgQbipPX7jlbomIE736F/G', 'ADMIN', 'ACTIVE'),
  ('recepcion', 'recepcion@motorix.local', '$2b$10$PmGyBA8wfPqUtExjFVuB4eu4v7tjXFumQvbmbSygdjf6jLuihbLY.', 'RECEPTIONIST', 'ACTIVE'),
  ('mecanico', 'mecanico@motorix.local', '$2b$10$Ln24AP/mi4GVPOdfz.RGgepcV4peDkswR8h.4jfqvSU4qs8fcs6lq', 'MECHANIC', 'ACTIVE');

INSERT IGNORE INTO clients (id, name, phone, email, status) VALUES
  (1, 'Juan Pérez', '5551002001', 'juan@correo.com', 'ACTIVO'),
  (2, 'María López', '5551002002', 'maria@correo.com', 'ACTIVO'),
  (3, 'Carlos García', '5551002003', NULL, 'ACTIVO'),
  (4, 'Ana Martínez', '5551002004', 'ana@correo.com', 'ACTIVO');

INSERT IGNORE INTO vehicles (id, client_id, brand, model, year, plates, vin, current_mileage) VALUES
  (1, 1, 'Nissan', 'Versa', 2020, 'ABC1234', '3N1AB7AP1KY123456', 45000),
  (2, 1, 'Mazda', '3', 2018, 'DEF5678', 'JM1BM1L10J1122334', 82000),
  (3, 2, 'Toyota', 'Corolla', 2022, 'GHI9012', '5YFBU4EE4NP123456', 15000),
  (4, 3, 'Chevrolet', 'Aveo', 2015, 'JKL3456', NULL, 120000);
