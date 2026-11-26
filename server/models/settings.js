// Acceso a datos de la configuración clave-valor (Sprint 7, US1/US2).
import { query } from '../config/db.js';

// Devuelve { clave: valor } con las filas guardadas.
export async function findAllSettings() {
  const rows = await query('SELECT setting_key, setting_value FROM settings');
  return Object.fromEntries(rows.map((row) => [row.setting_key, row.setting_value]));
}

// Guarda varias claves; gana el último guardado (aclaración de la spec).
export async function saveSettings(entries, userId) {
  for (const [key, value] of Object.entries(entries)) {
    await query(
      `INSERT INTO settings (setting_key, setting_value, updated_by)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value),
                               updated_by = VALUES(updated_by),
                               updated_at = CURRENT_TIMESTAMP`,
      [key, String(value), userId ?? null],
    );
  }
}
