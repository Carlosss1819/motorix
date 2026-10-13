// Acceso a datos de la tabla appointments (driver mysql2, sin ORM).
// Fuente de verdad de los campos: specs/002-citas-ordenes-servicio/data-model.md
// (entidad appointments). La US2 agrega el listado con filtros, el alta, la
// edicion, el conflicto de horario y la deteccion perezosa de NO_PRESENTADA.
import { query } from '../config/db.js';
import { APPOINTMENT_STATUSES } from '../utils/status-constants.js';

// La orden derivada vive en service_orders.appointment_id (UNIQUE, FR-007), por
// eso el LEFT JOIN: una cita sin orden devuelve order_id NULL.
const SELECT_APPOINTMENT = `
  SELECT a.*,
         c.name AS client_name,
         CONCAT(v.brand, ' ', v.model, ' ', v.year) AS vehicle_label,
         v.plates AS vehicle_plates,
         so.id AS order_id,
         so.status AS order_status,
         so.entry_date AS order_entry_date
  FROM appointments a
  JOIN clients c ON c.id = a.client_id
  JOIN vehicles v ON v.id = a.vehicle_id
  LEFT JOIN service_orders so ON so.appointment_id = a.id`;

function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

function mapAppointment(row) {
  if (!row) return null;
  return {
    id: row.id,
    clientId: row.client_id,
    clientName: row.client_name,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label,
    plates: row.vehicle_plates,
    appointmentDate: row.appointment_date,
    appointmentTime: row.appointment_time,
    reason: row.reason,
    status: row.status,
    cancelReason: row.cancel_reason,
    orderId: row.order_id ?? null,
    orderStatus: row.order_status ?? null,
    orderEntryDate: row.order_entry_date ?? null,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Listado paginado con los filtros del contrato: dia exacto (fecha), rango
// (desde/hasta), estado y busqueda por placas o nombre del cliente.
export async function listAppointments({
  search,
  status,
  date,
  from,
  to,
  page = 1,
  perPage = 10,
} = {}) {
  const conditions = [];
  const values = [];

  if (search) {
    const pattern = `%${escapeLike(search)}%`;
    conditions.push('(v.plates LIKE ? OR c.name LIKE ?)');
    values.push(pattern, pattern);
  }
  if (status) {
    conditions.push('a.status = ?');
    values.push(status);
  }
  if (date) {
    conditions.push('a.appointment_date = ?');
    values.push(date);
  }
  if (from) {
    conditions.push('a.appointment_date >= ?');
    values.push(from);
  }
  if (to) {
    conditions.push('a.appointment_date <= ?');
    values.push(to);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const countRows = await query(
    `SELECT COUNT(*) AS total
     FROM appointments a
     JOIN clients c ON c.id = a.client_id
     JOIN vehicles v ON v.id = a.vehicle_id
     ${where}`,
    values,
  );

  const offset = (page - 1) * perPage;
  const rows = await query(
    `${SELECT_APPOINTMENT} ${where}
     ORDER BY a.appointment_date ASC, a.appointment_time ASC, a.id ASC
     LIMIT ${Number(perPage)} OFFSET ${Number(offset)}`,
    values,
  );

  return { rows: rows.map(mapAppointment), total: Number(countRows[0].total) };
}

export async function findAppointmentById(id) {
  const rows = await query(`${SELECT_APPOINTMENT} WHERE a.id = ? LIMIT 1`, [id]);
  return mapAppointment(rows[0]);
}

export async function createAppointment({
  clientId,
  vehicleId,
  appointmentDate,
  appointmentTime,
  reason,
  createdBy,
}) {
  // El estado nace en PROGRAMADA por el DEFAULT de la columna (data-model.md).
  const result = await query(
    `INSERT INTO appointments
       (client_id, vehicle_id, appointment_date, appointment_time, reason, created_by)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [clientId, vehicleId, appointmentDate, appointmentTime, reason, createdBy],
  );
  return findAppointmentById(result.insertId);
}

// Edicion de la cita: solo cambian fecha, hora y motivo; el estado y el motivo
// de cancelacion se conservan (contrato, seccion PUT).
export async function updateAppointment(id, fields) {
  const allowed = {
    appointmentDate: 'appointment_date',
    appointmentTime: 'appointment_time',
    reason: 'reason',
  };
  const assignments = [];
  const values = [];
  for (const [key, column] of Object.entries(allowed)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      values.push(fields[key]);
    }
  }
  if (assignments.length === 0) return findAppointmentById(id);
  values.push(id);
  await query(`UPDATE appointments SET ${assignments.join(', ')} WHERE id = ?`, values);
  return findAppointmentById(id);
}

// Cambio de estado (cancelar o recibir). El motivo de cancelacion solo se toca
// cuando se envia (cancelacion con motivo opcional).
export async function updateAppointmentStatus(id, { status, cancelReason }) {
  const assignments = ['status = ?'];
  const values = [status];
  if (cancelReason !== undefined) {
    assignments.push('cancel_reason = ?');
    values.push(cancelReason);
  }
  values.push(id);
  await query(`UPDATE appointments SET ${assignments.join(', ')} WHERE id = ?`, values);
  return findAppointmentById(id);
}

// Conflicto de horario (FR-008, R-05): misma fecha, hora y vehiculo con otra
// cita en PROGRAMADA o RECIBIDA. `excludeId` permite ignorar la propia cita al
// editar.
export async function findScheduleConflict({
  vehicleId,
  appointmentDate,
  appointmentTime,
  excludeId = null,
} = {}) {
  const params = [
    vehicleId,
    appointmentDate,
    appointmentTime,
    APPOINTMENT_STATUSES.PROGRAMADA,
    APPOINTMENT_STATUSES.RECIBIDA,
  ];
  let sql = `${SELECT_APPOINTMENT}
    WHERE a.vehicle_id = ?
      AND a.appointment_date = ?
      AND a.appointment_time = ?
      AND a.status IN (?, ?)`;
  if (excludeId) {
    sql += ' AND a.id <> ?';
    params.push(excludeId);
  }
  sql += ' LIMIT 1';
  const rows = await query(sql, params);
  return mapAppointment(rows[0]);
}

// Deteccion perezosa (FR-006, R-06): toda cita PROGRAMADA cuya fecha y hora ya
// pasaron pasa a NO_PRESENTADA antes de responder el listado o el detalle.
export async function markExpiredAsNotPresented() {
  const result = await query(
    `UPDATE appointments
     SET status = ?
     WHERE status = ?
       AND (appointment_date < CURDATE()
            OR (appointment_date = CURDATE() AND appointment_time < CURTIME()))`,
    [APPOINTMENT_STATUSES.NO_PRESENTADA, APPOINTMENT_STATUSES.PROGRAMADA],
  );
  return result.affectedRows;
}
