-- Migración 004: Sprint 4 — pagos, tickets y dashboard.
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad de los campos: specs/004-pagos-tickets-dashboard/data-model.md
-- RN-14: ninguna columna almacena datos de tarjeta ni credenciales del proveedor.

-- ---------------------------------------------------------------------------
-- Pagos de las órdenes de servicio (FR-001, FR-002, RN-13). Un pago siempre
-- pertenece a una orden existente. La regla «un solo pago PAGADO por orden» y
-- «un solo pago PENDIENTE por orden» se valida en el servicio (FR-004), porque
-- MySQL no admite restricciones únicas parciales.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method ENUM('EFECTIVO','TARJETA','TRANSFERENCIA','MERCADO_PAGO') NOT NULL,
  status ENUM('PENDIENTE','PAGADO','RECHAZADO','CANCELADO','ANULADO') NOT NULL,
  external_reference VARCHAR(120) NULL,
  payment_link VARCHAR(512) NULL,
  gateway_mode VARCHAR(20) NULL,
  annulment_reason VARCHAR(255) NULL,
  annulled_by INT NULL,
  created_by INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  annulled_at DATETIME NULL,
  KEY idx_payments_order (service_order_id),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_payments_annulled_by
    FOREIGN KEY (annulled_by) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_payments_created_by
    FOREIGN KEY (created_by) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT chk_payments_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Tickets de servicio (FR-007, FR-009): un ticket por orden (UNIQUE) con folio
-- consecutivo por año; nace de un pago aprobado y se reconstruye desde la orden
-- y su pago al consultarlo (no guarda copia en frío de los datos, FR-012).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_order_id INT NOT NULL,
  payment_id INT NOT NULL,
  folio VARCHAR(20) NOT NULL,
  issued_by INT NOT NULL,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tickets_folio (folio),
  UNIQUE KEY uq_tickets_service_order (service_order_id),
  CONSTRAINT fk_tickets_order
    FOREIGN KEY (service_order_id) REFERENCES service_orders (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_tickets_payment
    FOREIGN KEY (payment_id) REFERENCES payments (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_tickets_issued_by
    FOREIGN KEY (issued_by) REFERENCES users (id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
