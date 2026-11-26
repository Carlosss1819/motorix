-- Migración 008 (Sprint 7, Entrega A): configuración del taller, catálogo de
-- tipos de servicio, términos y aviso de privacidad, y bitácora.
-- Script INMUTABLE: no editar tras aplicarse; los cambios van en nuevos scripts numerados.
-- Fuente de verdad: specs/007-reportes-configuracion/data-model.md.
--
-- Aditiva y SOLO DDL: crea cinco tablas nuevas y agrega UNA columna nullable a
-- order_services. No borra ni modifica filas, columnas ni restricciones
-- existentes; las líneas de servicio existentes quedan con service_type_id NULL.
-- Los datos (configuración inicial, tipos y la versión 1.0 de los términos)
-- van en el seed 007.

-- Configuración clave-valor (FR-001 a FR-005). Sin fila, el backend usa el
-- valor de respaldo de server/utils/settings-defaults.js (FR-003).
CREATE TABLE IF NOT EXISTS settings (
  setting_key VARCHAR(60) NOT NULL PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  updated_by INT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_settings_user
    FOREIGN KEY (updated_by) REFERENCES users (id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catálogo de tipos de servicio con intervalo (FR-007 a FR-009). El nombre es
-- único sin distinguir mayúsculas por la colación unicode_ci. Nunca se borra:
-- desactivar lo oculta de las listas (FR-008).
CREATE TABLE IF NOT EXISTS service_types (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  interval_days INT NULL,
  interval_km INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_service_types_name (name),
  CONSTRAINT chk_service_types_interval_days CHECK (interval_days IS NULL OR (interval_days BETWEEN 1 AND 3650)),
  CONSTRAINT chk_service_types_interval_km CHECK (interval_km IS NULL OR (interval_km BETWEEN 1 AND 500000)),
  CONSTRAINT chk_service_types_some_interval CHECK (interval_days IS NOT NULL OR interval_km IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Enlace opcional de la línea de servicio con su tipo (FR-010).
ALTER TABLE order_services
  ADD COLUMN service_type_id INT NULL AFTER description,
  ADD KEY idx_order_services_type (service_type_id),
  ADD CONSTRAINT fk_order_services_type
    FOREIGN KEY (service_type_id) REFERENCES service_types (id)
    ON DELETE RESTRICT;

-- Versiones de términos y aviso de privacidad (FR-014 a FR-016). La vigente es
-- la más reciente con is_current = 1; se publican con seeds, no desde la app.
CREATE TABLE IF NOT EXISTS terms_versions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  version VARCHAR(20) NOT NULL,
  published_at DATETIME NOT NULL,
  terms_text TEXT NOT NULL,
  privacy_text TEXT NOT NULL,
  is_current TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_terms_versions_version (version),
  KEY idx_terms_versions_current (is_current, published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Aceptación: una sola por usuario y versión (FR-018).
CREATE TABLE IF NOT EXISTS terms_acceptances (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  terms_version_id INT NOT NULL,
  accepted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_terms_acceptances_user_version (user_id, terms_version_id),
  KEY idx_terms_acceptances_version (terms_version_id, accepted_at),
  CONSTRAINT fk_terms_acceptances_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_terms_acceptances_version
    FOREIGN KEY (terms_version_id) REFERENCES terms_versions (id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bitácora de acciones sensibles (FR-022 a FR-025). Nunca guarda contraseñas,
-- hashes, tokens ni datos de tarjeta (FR-023). No hay rutas para editarla ni
-- borrarla, ni borrado automático (FR-024).
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id INT NULL,
  action VARCHAR(40) NOT NULL,
  entity_type VARCHAR(40) NULL,
  entity_id INT NULL,
  detail VARCHAR(255) NULL,
  KEY idx_audit_log_created (created_at),
  KEY idx_audit_log_user (user_id, created_at),
  KEY idx_audit_log_action (action, created_at),
  CONSTRAINT fk_audit_log_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
