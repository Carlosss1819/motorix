// Acceso a datos de «Clientes por avisar» (Sprint 6, US7). Los candidatos se
// calculan de las tablas de origen; solo `client_notices` guarda los avisos
// hechos (una fila por hecho, índice único en fact_key). Sin importes.
import { query } from '../config/db.js';
import { ACTIVE_APPOINTMENT_STATUSES, ORDER_STATUSES } from '../utils/status-constants.js';
import { toIsoDate } from '../utils/dates.js';
import { conflict } from '../utils/errors.js';

const VEHICLE_LABEL = "CONCAT(v.brand, ' ', v.model, ' ', v.year)";

const asDate = (value) => (value ? toIsoDate(value instanceof Date ? value : new Date(value)) : null);

// Órdenes TERMINADO sin entregar, con la fecha en que pasaron a TERMINADO.
export async function listReadyOrders() {
  const rows = await query(
    `SELECT o.id, o.client_id, c.name AS client_name, c.phone AS client_phone,
            o.vehicle_id, ${VEHICLE_LABEL} AS vehicle_label, v.plates,
            COALESCE(h.finished_at, o.updated_at) AS finished_at
     FROM service_orders o
     JOIN clients c ON c.id = o.client_id
     JOIN vehicles v ON v.id = o.vehicle_id
     LEFT JOIN (
       SELECT service_order_id, MAX(changed_at) AS finished_at
       FROM order_status_history
       WHERE to_status = ?
       GROUP BY service_order_id
     ) h ON h.service_order_id = o.id
     WHERE o.status = ?`,
    [ORDER_STATUSES.TERMINADO, ORDER_STATUSES.TERMINADO],
  );
  return rows.map((row) => ({
    id: row.id,
    clientId: row.client_id,
    clientName: row.client_name,
    clientPhone: row.client_phone,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label,
    plates: row.plates,
    date: asDate(row.finished_at),
  }));
}

// Citas activas de una fecha (la de mañana), con el teléfono del cliente.
export async function listActiveAppointmentsWithPhoneOn(date) {
  const rows = await query(
    `SELECT a.id, a.client_id, c.name AS client_name, c.phone AS client_phone,
            a.vehicle_id, ${VEHICLE_LABEL} AS vehicle_label, v.plates
     FROM appointments a
     JOIN clients c ON c.id = a.client_id
     JOIN vehicles v ON v.id = a.vehicle_id
     WHERE a.appointment_date = ? AND a.status IN (?, ?)`,
    [date, ...ACTIVE_APPOINTMENT_STATUSES],
  );
  return rows.map((row) => ({
    id: row.id,
    clientId: row.client_id,
    clientName: row.client_name,
    clientPhone: row.client_phone,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label,
    plates: row.plates,
    date,
  }));
}

// Mantenimientos con los datos del vehículo y del cliente (el estado lo
// calcula el servicio con `calcMaintenanceState`, igual que la lista).
export async function listMaintenanceWithClient() {
  const rows = await query(
    `SELECT m.id, m.target_date, m.target_mileage, m.advance_days, m.advance_km,
            m.service_type, v.id AS vehicle_id, v.current_mileage, v.plates,
            ${VEHICLE_LABEL} AS vehicle_label,
            c.id AS client_id, c.name AS client_name, c.phone AS client_phone
     FROM maintenance m
     JOIN vehicles v ON v.id = m.vehicle_id
     JOIN clients c ON c.id = v.client_id`,
  );
  return rows.map((row) => ({
    id: row.id,
    targetDate: asDate(row.target_date),
    targetMileage: row.target_mileage ?? null,
    advanceDays: row.advance_days,
    advanceKm: row.advance_km,
    serviceType: row.service_type,
    vehicleId: row.vehicle_id,
    vehicleCurrentMileage: row.current_mileage,
    plates: row.plates,
    vehicleLabel: row.vehicle_label,
    clientId: row.client_id,
    clientName: row.client_name,
    clientPhone: row.client_phone,
  }));
}

export async function listNoticedFactKeys() {
  const rows = await query('SELECT fact_key FROM client_notices');
  return new Set(rows.map((row) => row.fact_key));
}

export async function findNoticeByFactKey(factKey) {
  const rows = await query(
    `SELECT n.id, n.client_id, n.reason, n.fact_key, n.notified_by, n.notified_at, u.username
     FROM client_notices n
     JOIN users u ON u.id = n.notified_by
     WHERE n.fact_key = ?
     LIMIT 1`,
    [factKey],
  );
  return rows[0] ?? null;
}

const isDuplicate = (error) => error?.code === 'ER_DUP_ENTRY' || error?.errno === 1062;

// Inserta el aviso; una marcación repetida o concurrente choca con el índice
// único y se convierte en 409 YA_AVISADO (R-07).
export async function insertNotice({ clientId, reason, factKey, notifiedBy }) {
  try {
    await query(
      'INSERT INTO client_notices (client_id, reason, fact_key, notified_by) VALUES (?, ?, ?, ?)',
      [clientId, reason, factKey, notifiedBy],
    );
  } catch (error) {
    if (isDuplicate(error)) {
      throw conflict('Este cliente ya fue avisado por este motivo', 'YA_AVISADO');
    }
    throw error;
  }
  return findNoticeByFactKey(factKey);
}
