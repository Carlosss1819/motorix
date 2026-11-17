-- Migración 007 (Sprint 6): notificaciones internas.
-- Aditiva: solo crea dos tablas nuevas; no modifica tablas existentes.
-- Los avisos NO se guardan (se calculan al consultar, RN-10); aquí solo se
-- guarda la lectura de cada aviso por usuario y el registro de «cliente
-- avisado» por hecho (specs/006-notificaciones-internas/data-model.md).

-- Lectura de un aviso por usuario. La clave es tipo + objeto + estado
-- (por ejemplo MANT_VENCIDO:7:2026-12-01|-), así que un aviso que empeora es
-- una clave nueva y vuelve a mostrarse como no leído (FR-015).
CREATE TABLE IF NOT EXISTS notification_reads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  notice_key VARCHAR(120) NOT NULL,
  read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_notification_reads_user_key (user_id, notice_key),
  CONSTRAINT fk_notification_reads_user
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Aviso a un cliente: una sola vez por hecho (orden, cita o mantenimiento
-- con su objetivo vigente), sin nota, con quién y cuándo (FR-020, FR-021).
CREATE TABLE IF NOT EXISTS client_notices (
  id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  reason ENUM('VEHICULO_LISTO','CITA_MANANA','MANT_PROXIMO','MANT_VENCIDO') NOT NULL,
  fact_key VARCHAR(120) NOT NULL,
  notified_by INT NOT NULL,
  notified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_client_notices_fact (fact_key),
  KEY idx_client_notices_client (client_id),
  CONSTRAINT fk_client_notices_client
    FOREIGN KEY (client_id) REFERENCES clients (id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_client_notices_user
    FOREIGN KEY (notified_by) REFERENCES users (id)
    ON DELETE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
