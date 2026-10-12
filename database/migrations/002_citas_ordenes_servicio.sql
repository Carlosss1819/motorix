-- Migración 002: Sprint 2 — citas y órdenes de servicio.
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad de los campos: specs/002-citas-ordenes-servicio/data-model.md

-- ---------------------------------------------------------------------------
-- Citas de recepción (FR-005, FR-006)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  reason VARCHAR(255) NOT NULL,
  status ENUM('PROGRAMADA','RECIBIDA','CANCELADA','NO_PRESENTADA') NOT NULL DEFAULT 'PROGRAMADA',
  cancel_reason VARCHAR(255) NULL,
  created_by INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_appointments_date_time (appointment_date, appointment_time),
  KEY idx_appointments_status (status),
  CONSTRAINT fk_appointments_client
    FOREIGN KEY (client_id) REFERENCES clients (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_appointments_vehicle
    FOREIGN KEY (vehicle_id) REFERENCES vehicles (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_appointments_user
    FOREIGN KEY (created_by) REFERENCES users (id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Órdenes de servicio (FR-001 a FR-004, FR-014 a FR-018)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  appointment_id INT NULL,
  status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NOT NULL DEFAULT 'RECIBIDO',
  visit_reason VARCHAR(255) NOT NULL,
  entry_date DATE NOT NULL,
  entry_mileage INT NOT NULL,
  mechanic_id INT NULL,
  diagnosis TEXT NULL,
  diagnosis_draft TINYINT(1) NOT NULL DEFAULT 0,
  recommendations TEXT NULL,
  delivery_date DATETIME NULL,
  mileage_correction_note VARCHAR(255) NULL,
  created_by INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_service_orders_appointment (appointment_id),
  KEY idx_service_orders_status (status),
  KEY idx_service_orders_mechanic_status (mechanic_id, status),
  KEY idx_service_orders_vehicle (vehicle_id),
  CONSTRAINT fk_service_orders_client
    FOREIGN KEY (client_id) REFERENCES clients (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_service_orders_vehicle
    FOREIGN KEY (vehicle_id) REFERENCES vehicles (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_service_orders_appointment
    FOREIGN KEY (appointment_id) REFERENCES appointments (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_service_orders_mechanic
    FOREIGN KEY (mechanic_id) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_service_orders_creator
    FOREIGN KEY (created_by) REFERENCES users (id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Historial de cambios de estado (FR-015)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_status_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  from_status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NULL,
  to_status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NOT NULL,
  changed_by INT NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  note VARCHAR(255) NULL,
  KEY idx_order_status_history_order (service_order_id, changed_at),
  CONSTRAINT fk_order_status_history_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE CASCADE,
  CONSTRAINT fk_order_status_history_user
    FOREIGN KEY (changed_by) REFERENCES users (id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Servicios aplicados a la orden (FR-012)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  description VARCHAR(150) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order_services_order (service_order_id),
  CONSTRAINT fk_order_services_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Mano de obra de la orden (FR-012); ligada al servicio que la originó
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_labor (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  service_id INT NOT NULL,
  description VARCHAR(150) NOT NULL,
  duration_minutes INT NOT NULL,
  price DECIMAL(10,2) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order_labor_service (service_id),
  CONSTRAINT fk_order_labor_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE CASCADE,
  CONSTRAINT fk_order_labor_service
    FOREIGN KEY (service_id) REFERENCES order_services (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Repuestos utilizados en la orden (FR-012); el stock se valida en el Sprint 3
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_parts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  description VARCHAR(120) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_order_parts_order (service_order_id),
  CONSTRAINT fk_order_parts_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
