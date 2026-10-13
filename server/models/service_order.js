// Acceso a datos de las ordenes de servicio (tabla service_orders) y de su
// agregado: historial de estados, servicios, mano de obra y repuestos.
// Fuente de verdad de los campos: specs/002-citas-ordenes-servicio/data-model.md
import { query } from '../config/db.js';

const SELECT_ORDER = `
  SELECT so.*,
         c.name AS client_name,
         c.phone AS client_phone,
         CONCAT(v.brand, ' ', v.model, ' ', v.year) AS vehicle_label,
         v.plates AS vehicle_plates,
         u.username AS mechanic_username
  FROM service_orders so
  JOIN clients c ON c.id = so.client_id
  JOIN vehicles v ON v.id = so.vehicle_id
  LEFT JOIN users u ON u.id = so.mechanic_id`;

function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

function mapOrder(row) {
  if (!row) return null;
  return {
    id: row.id,
    clientId: row.client_id,
    clientName: row.client_name,
    clientPhone: row.client_phone,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label,
    plates: row.vehicle_plates,
    appointmentId: row.appointment_id,
    status: row.status,
    visitReason: row.visit_reason,
    entryDate: row.entry_date,
    entryMileage: row.entry_mileage,
    mechanicId: row.mechanic_id,
    mechanicUsername: row.mechanic_username,
    diagnosis: row.diagnosis,
    diagnosisDraft: Boolean(row.diagnosis_draft),
    recommendations: row.recommendations,
    deliveryDate: row.delivery_date,
    mileageCorrectionNote: row.mileage_correction_note,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Listado paginado con los filtros del contrato: estado, orden abierta (todo
// lo que no sea ENTREGADO), busqueda por placas o nombre del cliente y mecánico.
export async function listServiceOrders({
  search,
  status,
  openOnly,
  mechanicId,
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
    conditions.push('so.status = ?');
    values.push(status);
  }
  if (openOnly) {
    conditions.push("so.status <> 'ENTREGADO'");
  }
  if (mechanicId) {
    // FR-010 / RN-15: el mecánico solo ve las ordenes asignadas a él.
    conditions.push('so.mechanic_id = ?');
    values.push(mechanicId);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const countRows = await query(
    `SELECT COUNT(*) AS total
     FROM service_orders so
     JOIN clients c ON c.id = so.client_id
     JOIN vehicles v ON v.id = so.vehicle_id
     ${where}`,
    values,
  );

  const offset = (page - 1) * perPage;
  const rows = await query(
    `${SELECT_ORDER} ${where} ORDER BY so.id DESC LIMIT ${Number(perPage)} OFFSET ${Number(offset)}`,
    values,
  );

  return { rows: rows.map(mapOrder), total: Number(countRows[0].total) };
}

export async function findServiceOrderById(id) {
  const rows = await query(`${SELECT_ORDER} WHERE so.id = ? LIMIT 1`, [id]);
  return mapOrder(rows[0]);
}

// Orden derivada de una cita (FR-007): appointment_id es UNIQUE, así que como
// mucho existe una fila. Se usa para impedir que una cita genere dos órdenes.
export async function findOrderByAppointmentId(appointmentId) {
  const rows = await query(
    'SELECT id FROM service_orders WHERE appointment_id = ? LIMIT 1',
    [appointmentId],
  );
  return rows[0] ?? null;
}

// Kilometraje de la orden más reciente del vehículo (regla R-08). En la edición
// se excluye la orden que se está modificando, para que la comparación siga
// teniendo sentido con la orden anterior (FR-018).
export async function getLastMileageByVehicle(vehicleId, excludeOrderId = null) {
  const params = [vehicleId];
  let sql = 'SELECT entry_mileage FROM service_orders WHERE vehicle_id = ?';
  if (excludeOrderId) {
    sql += ' AND id <> ?';
    params.push(excludeOrderId);
  }
  sql += ' ORDER BY id DESC LIMIT 1';
  const rows = await query(sql, params);
  return rows[0] ? rows[0].entry_mileage : null;
}

export async function createServiceOrder({
  clientId,
  vehicleId,
  appointmentId,
  visitReason,
  entryDate,
  entryMileage,
  mechanicId,
  mileageCorrectionNote,
  createdBy,
}) {
  const result = await query(
    `INSERT INTO service_orders
       (client_id, vehicle_id, appointment_id, visit_reason, entry_date,
        entry_mileage, mechanic_id, mileage_correction_note, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      clientId,
      vehicleId,
      appointmentId ?? null,
      visitReason,
      entryDate,
      entryMileage,
      mechanicId ?? null,
      mileageCorrectionNote ?? null,
      createdBy,
    ],
  );
  return findServiceOrderById(result.insertId);
}

// Actualiza los campos permitidos de la orden; se reutiliza en diagnóstico,
// recomendaciones, asignación y transiciones de estado (historias 3 a 5).
export async function updateServiceOrder(id, fields) {
  const allowed = {
    visitReason: 'visit_reason',
    entryDate: 'entry_date',
    entryMileage: 'entry_mileage',
    mileageCorrectionNote: 'mileage_correction_note',
    mechanicId: 'mechanic_id',
    diagnosis: 'diagnosis',
    diagnosisDraft: 'diagnosis_draft',
    recommendations: 'recommendations',
    deliveryDate: 'delivery_date',
    status: 'status',
  };
  const assignments = [];
  const values = [];
  for (const [key, column] of Object.entries(allowed)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      values.push(fields[key]);
    }
  }
  if (assignments.length === 0) return findServiceOrderById(id);
  values.push(id);
  await query(`UPDATE service_orders SET ${assignments.join(', ')} WHERE id = ?`, values);
  return findServiceOrderById(id);
}

// Historial de cambios de estado (FR-015).
export async function addStatusHistory({ serviceOrderId, fromStatus, toStatus, changedBy, note }) {
  const result = await query(
    `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, note)
     VALUES (?, ?, ?, ?, ?)`,
    [serviceOrderId, fromStatus ?? null, toStatus, changedBy, note ?? null],
  );
  return result.insertId;
}

export async function listStatusHistory(serviceOrderId) {
  const rows = await query(
    `SELECT h.from_status, h.to_status, h.changed_at, u.username
     FROM order_status_history h
     JOIN users u ON u.id = h.changed_by
     WHERE h.service_order_id = ?
     ORDER BY h.id`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    fromStatus: row.from_status,
    toStatus: row.to_status,
    changedAt: row.changed_at,
    username: row.username,
  }));
}

// Servicios de la orden con su partida de mano de obra (agregado del detalle).
export async function listServicesByOrder(serviceOrderId) {
  const rows = await query(
    `SELECT s.id, s.description, l.id AS labor_id, l.duration_minutes, l.price
     FROM order_services s
     LEFT JOIN order_labor l ON l.service_id = s.id
     WHERE s.service_order_id = ?
     ORDER BY s.id`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    id: row.id,
    description: row.description,
    labor: row.labor_id
      ? { id: row.labor_id, durationMinutes: row.duration_minutes, price: row.price }
      : null,
  }));
}

// Repuestos registrados en la orden (el stock se valida en el Sprint 3).
export async function listPartsByOrder(serviceOrderId) {
  const rows = await query(
    `SELECT id, description, quantity
     FROM order_parts
     WHERE service_order_id = ?
     ORDER BY id`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    id: row.id,
    description: row.description,
    quantity: row.quantity,
  }));
}
