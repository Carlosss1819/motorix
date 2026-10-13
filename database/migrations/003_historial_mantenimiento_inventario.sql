-- Migración 003: Sprint 3 — historial, mantenimiento e inventario.
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad de los campos: specs/003-historial-inventario/data-model.md

-- ---------------------------------------------------------------------------
-- Catálogo de refacciones (FR-016 a FR-021); término canónico «refacción»
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS parts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) NOT NULL,
  name VARCHAR(120) NOT NULL,
  category VARCHAR(80) NOT NULL,
  brand VARCHAR(80) NULL,
  stock_current INT NOT NULL DEFAULT 0,
  stock_min INT NOT NULL DEFAULT 0,
  purchase_price DECIMAL(10,2) NULL,
  sale_price DECIMAL(10,2) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_parts_code (code),
  KEY idx_parts_name (name),
  CONSTRAINT chk_parts_stock_current CHECK (stock_current >= 0),
  CONSTRAINT chk_parts_stock_min CHECK (stock_min >= 0),
  CONSTRAINT chk_parts_purchase_price CHECK (purchase_price IS NULL OR purchase_price >= 0),
  CONSTRAINT chk_parts_sale_price CHECK (sale_price IS NULL OR sale_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Mantenimientos preventivos (FR-008 a FR-015); el estado (normal/proximo/
-- vencido) NO se persiste: se calcula en cada consulta (R-04)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  vehicle_id INT NOT NULL,
  service_type VARCHAR(120) NOT NULL,
  last_service_date DATE NULL,
  last_service_mileage INT NULL,
  target_date DATE NULL,
  target_mileage INT NULL,
  interval_days INT NULL,
  interval_km INT NULL,
  advance_days INT NOT NULL DEFAULT 30,
  advance_km INT NOT NULL DEFAULT 500,
  notes VARCHAR(255) NULL,
  created_by INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_maintenance_vehicle_type (vehicle_id, service_type),
  KEY idx_maintenance_vehicle (vehicle_id),
  CONSTRAINT fk_maintenance_vehicle
    FOREIGN KEY (vehicle_id) REFERENCES vehicles (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_maintenance_user
    FOREIGN KEY (created_by) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT chk_maintenance_last_service_mileage CHECK (last_service_mileage IS NULL OR last_service_mileage >= 0),
  CONSTRAINT chk_maintenance_target_mileage CHECK (target_mileage IS NULL OR target_mileage >= 0),
  CONSTRAINT chk_maintenance_interval_days CHECK (interval_days IS NULL OR interval_days > 0),
  CONSTRAINT chk_maintenance_interval_km CHECK (interval_km IS NULL OR interval_km > 0),
  CONSTRAINT chk_maintenance_advance_days CHECK (advance_days > 0),
  CONSTRAINT chk_maintenance_advance_km CHECK (advance_km > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Movimientos de inventario (FR-028 a FR-030); stock_after explica cada
-- cambio (SC-007) y service_order_id liga la salida/reposición a la orden
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_movements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  part_id INT NOT NULL,
  movement_type ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
  quantity INT NOT NULL,
  reason VARCHAR(255) NULL,
  service_order_id INT NULL,
  stock_after INT NOT NULL,
  created_by INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_movements_part (part_id, created_at),
  KEY idx_movements_order (service_order_id),
  CONSTRAINT fk_movements_part
    FOREIGN KEY (part_id) REFERENCES parts (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_movements_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_movements_user
    FOREIGN KEY (created_by) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT chk_movements_quantity CHECK (quantity > 0),
  CONSTRAINT chk_movements_stock_after CHECK (stock_after >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Refacciones usadas en la orden: columna nueva part_id (nullable) que
-- liga la fila al catálogo; las filas heredadas del Sprint 2 quedan con
-- part_id NULL y su descripción original (R-06). La migración 002 no se edita.
-- ---------------------------------------------------------------------------
ALTER TABLE order_parts
  ADD COLUMN part_id INT NULL AFTER service_order_id;

ALTER TABLE order_parts
  ADD KEY idx_order_parts_part (part_id);

ALTER TABLE order_parts
  ADD CONSTRAINT fk_order_parts_part
    FOREIGN KEY (part_id) REFERENCES parts (id)
    ON DELETE RESTRICT;

-- ---------------------------------------------------------------------------
-- Índice del historial (R-02, SC-001): el filtro por vehículo + estado es
-- la clave de acceso de GET /api/vehicles/:id/history
-- ---------------------------------------------------------------------------
ALTER TABLE service_orders
  ADD KEY idx_service_orders_vehicle_status (vehicle_id, status);
