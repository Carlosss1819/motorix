// Acceso a datos de los avisos internos (Sprint 6). Los avisos NO se guardan
// (RN-10): estas consultas leen las tablas de origen con las mismas reglas que
// el panel y la lista de Mantenimientos (R-02). Solo `notification_reads` es
// propia del sprint. Ninguna consulta selecciona precios (FR-012).
import { query } from '../config/db.js';
import { WHERE_STOCK_BAJO } from './dashboard.js';
import {
  ACTIVE_APPOINTMENT_STATUSES,
  APPOINTMENT_STATUSES,
} from '../utils/status-constants.js';
import { STALLED_ORDER_STATUSES } from '../utils/stalled-order.js';

const VEHICLE_LABEL = "CONCAT(v.brand, ' ', v.model, ' ', v.year)";

// HH:MM desde una columna TIME (cadena '10:30:00' o Date).
function formatTime(value) {
  if (value instanceof Date) {
    const pad = (number) => String(number).padStart(2, '0');
    return `${pad(value.getHours())}:${pad(value.getMinutes())}`;
  }
  return String(value).slice(0, 5);
}

// Detección perezosa de citas vencidas limitada al día del reloj (R-03, M2):
// las PROGRAMADA de `date` cuya hora ya pasó pasan a NO_PRESENTADA, igual que
// la agenda. Solo toca ese día: los demás días los resuelve la agenda.
export async function markExpiredAppointmentsOn(date, time) {
  const result = await query(
    `UPDATE appointments
     SET status = ?
     WHERE status = ? AND appointment_date = ? AND appointment_time < ?`,
    [APPOINTMENT_STATUSES.NO_PRESENTADA, APPOINTMENT_STATUSES.PROGRAMADA, date, time],
  );
  return result.affectedRows;
}

// Citas activas (PROGRAMADA o RECIBIDA) de una fecha, con cliente y vehículo.
export async function listActiveAppointmentsOn(date) {
  const rows = await query(
    `SELECT a.id, a.appointment_time, a.client_id, c.name AS client_name, c.phone AS client_phone,
            a.vehicle_id, ${VEHICLE_LABEL} AS vehicle_label, v.plates
     FROM appointments a
     JOIN clients c ON c.id = a.client_id
     JOIN vehicles v ON v.id = a.vehicle_id
     WHERE a.appointment_date = ? AND a.status IN (?, ?)
     ORDER BY a.appointment_time, a.id`,
    [date, ...ACTIVE_APPOINTMENT_STATUSES],
  );
  return rows.map((row) => ({
    id: row.id,
    time: formatTime(row.appointment_time),
    clientId: row.client_id,
    clientName: row.client_name,
    clientPhone: row.client_phone,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label,
    plates: row.plates,
  }));
}

// Refacciones en stock bajo con la regla del panel (sin límite, sin precios).
export async function listLowStockParts() {
  const rows = await query(
    `SELECT id, code, name, stock_current, stock_min
     FROM parts
     WHERE ${WHERE_STOCK_BAJO}
     ORDER BY code, id`,
  );
  return rows.map((row) => ({
    id: row.id,
    code: row.code,
    name: row.name,
    stockCurrent: Number(row.stock_current),
    stockMin: Number(row.stock_min),
  }));
}

// Órdenes detenidas (R-04): estado no final y último cambio de estado (o el
// alta) anterior a `cutoff` (= ahora − N × 24 h). `mechanicId` acota al
// mecánico asignado (FR-011).
export async function listStalledOrders({ cutoff, mechanicId = null }) {
  const values = [...STALLED_ORDER_STATUSES, cutoff];
  let mechanicFilter = '';
  if (mechanicId !== null) {
    mechanicFilter = 'AND o.mechanic_id = ?';
    values.push(mechanicId);
  }
  const rows = await query(
    `SELECT o.id, o.status, o.vehicle_id, o.mechanic_id,
            ${VEHICLE_LABEL} AS vehicle_label, v.plates,
            COALESCE(h.last_change, o.created_at) AS reference
     FROM service_orders o
     JOIN vehicles v ON v.id = o.vehicle_id
     LEFT JOIN (
       SELECT service_order_id, MAX(changed_at) AS last_change
       FROM order_status_history
       GROUP BY service_order_id
     ) h ON h.service_order_id = o.id
     WHERE o.status IN (${STALLED_ORDER_STATUSES.map(() => '?').join(', ')})
       AND COALESCE(h.last_change, o.created_at) < ?
       ${mechanicFilter}
     ORDER BY reference, o.id`,
    values,
  );
  return rows.map((row) => ({
    id: row.id,
    status: row.status,
    vehicleId: row.vehicle_id,
    mechanicId: row.mechanic_id,
    vehicleLabel: row.vehicle_label,
    plates: row.plates,
    reference: row.reference,
  }));
}

// Claves leídas por un usuario (una sola consulta por petición).
export async function listReadKeys(userId) {
  const rows = await query('SELECT notice_key FROM notification_reads WHERE user_id = ?', [
    userId,
  ]);
  return new Set(rows.map((row) => row.notice_key));
}

// Guarda la lectura; repetirla no duplica (índice único por usuario y clave).
export async function insertRead(userId, key) {
  await query('INSERT IGNORE INTO notification_reads (user_id, notice_key) VALUES (?, ?)', [
    userId,
    key,
  ]);
}
