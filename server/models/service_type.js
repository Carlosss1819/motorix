// Acceso a datos del catálogo de tipos de servicio (Sprint 7, US3).
// Nunca se borran filas: desactivar solo cambia is_active (FR-008).
import { query } from '../config/db.js';

function mapServiceType(row) {
  if (!row) return null;
  return {
    id: row.id,
    nombre: row.name,
    intervaloDias: row.interval_days,
    intervaloKm: row.interval_km,
    activo: Boolean(row.is_active),
  };
}

export async function listServiceTypes({ includeInactive = false } = {}) {
  const rows = await query(
    `SELECT id, name, interval_days, interval_km, is_active
     FROM service_types
     ${includeInactive ? '' : 'WHERE is_active = 1'}
     ORDER BY name, id`,
  );
  return rows.map(mapServiceType);
}

export async function findServiceTypeById(id) {
  const rows = await query(
    'SELECT id, name, interval_days, interval_km, is_active FROM service_types WHERE id = ? LIMIT 1',
    [id],
  );
  return mapServiceType(rows[0]);
}

// Búsqueda por nombre sin distinguir mayúsculas (colación unicode_ci).
export async function findServiceTypeByName(name) {
  const rows = await query(
    'SELECT id, name, interval_days, interval_km, is_active FROM service_types WHERE name = ? LIMIT 1',
    [name],
  );
  return mapServiceType(rows[0]);
}

export async function insertServiceType({ nombre, intervaloDias, intervaloKm }) {
  const result = await query(
    'INSERT INTO service_types (name, interval_days, interval_km) VALUES (?, ?, ?)',
    [nombre, intervaloDias ?? null, intervaloKm ?? null],
  );
  return findServiceTypeById(result.insertId);
}

export async function updateServiceType(id, { nombre, intervaloDias, intervaloKm }) {
  await query(
    'UPDATE service_types SET name = ?, interval_days = ?, interval_km = ? WHERE id = ?',
    [nombre, intervaloDias ?? null, intervaloKm ?? null, id],
  );
  return findServiceTypeById(id);
}

export async function setServiceTypeActive(id, active) {
  await query('UPDATE service_types SET is_active = ? WHERE id = ?', [active ? 1 : 0, id]);
  return findServiceTypeById(id);
}
