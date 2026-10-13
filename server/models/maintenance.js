// Acceso a datos de los mantenimientos preventivos (tabla maintenance, Sprint 3).
// El estado (normal/proximo/vencido) NO se persiste: lo calcula
// utils/maintenance-status.js en cada consulta (R-04). La unicidad por
// vehículo y tipo de servicio está garantizada por uq_maintenance_vehicle_type.
import { query } from '../config/db.js';
import {
  DEFAULT_ADVANCE_DAYS,
  DEFAULT_ADVANCE_KM,
} from '../utils/maintenance-status.js';

// mysql2 devuelve las columnas DATE como objeto Date; el contrato pide
// `YYYY-MM-DD` (mismo criterio que vehicle_history.js).
function formatDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function mapMaintenance(row) {
  if (!row) return null;
  return {
    id: row.id,
    vehicleId: row.vehicle_id,
    vehicleLabel: row.vehicle_label ?? undefined,
    plates: row.plates ?? undefined,
    vehicleCurrentMileage: row.vehicle_current_mileage ?? undefined,
    clientName: row.client_name ?? undefined,
    serviceType: row.service_type,
    lastServiceDate: formatDate(row.last_service_date),
    lastServiceMileage: row.last_service_mileage ?? null,
    targetDate: formatDate(row.target_date),
    targetMileage: row.target_mileage ?? null,
    intervalDays: row.interval_days ?? null,
    intervalKm: row.interval_km ?? null,
    advanceDays: row.advance_days,
    advanceKm: row.advance_km,
    notes: row.notes ?? null,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Select base con los datos del vehículo y el cliente (FR-013, HU4).
const BASE_SELECT = `
  SELECT m.*, CONCAT(v.brand, ' ', v.model, ' ', v.year) AS vehicle_label,
         v.plates AS plates, v.current_mileage AS vehicle_current_mileage,
         c.name AS client_name
  FROM maintenance m
  JOIN vehicles v ON v.id = m.vehicle_id
  LEFT JOIN clients c ON c.id = v.client_id`;

function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

// Listado con joins de vehículo/cliente y filtros por vehículo y búsqueda
// (tipo de servicio o placas). El filtro por estado se aplica en el servicio
// sobre el estado calculado (R-04).
export async function listMaintenance({ vehicleId, search, page, perPage } = {}) {
  const conditions = [];
  const values = [];

  if (vehicleId) {
    conditions.push('m.vehicle_id = ?');
    values.push(vehicleId);
  }
  if (search) {
    const pattern = `%${escapeLike(search)}%`;
    conditions.push('(m.service_type LIKE ? OR v.plates LIKE ?)');
    values.push(pattern, pattern);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const [countRow] = await query(
    `SELECT COUNT(*) AS total
     FROM maintenance m
     JOIN vehicles v ON v.id = m.vehicle_id
     ${where}`,
    values,
  );

  const limitValues = [...values];
  let limitClause = '';
  if (page && perPage) {
    limitClause = ' LIMIT ? OFFSET ?';
    limitValues.push(perPage, (page - 1) * perPage);
  }

  const rows = await query(
    `${BASE_SELECT} ${where} ORDER BY m.vehicle_id, m.service_type${limitClause}`,
    limitValues,
  );
  return { rows: rows.map(mapMaintenance), total: countRow.total };
}

export async function findById(id) {
  const rows = await query(`${BASE_SELECT} WHERE m.id = ? LIMIT 1`, [id]);
  return mapMaintenance(rows[0]);
}

export async function findByVehicleAndType(vehicleId, serviceType) {
  const rows = await query(
    `${BASE_SELECT} WHERE m.vehicle_id = ? AND m.service_type = ? LIMIT 1`,
    [vehicleId, serviceType],
  );
  return mapMaintenance(rows[0]);
}

export async function createMaintenance({
  vehicleId,
  serviceType,
  targetDate,
  targetMileage,
  intervalDays,
  intervalKm,
  advanceDays,
  advanceKm,
  notes,
  createdBy,
}) {
  const result = await query(
    `INSERT INTO maintenance
       (vehicle_id, service_type, target_date, target_mileage, interval_days, interval_km,
        advance_days, advance_km, notes, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      vehicleId,
      serviceType,
      targetDate ?? null,
      targetMileage ?? null,
      intervalDays ?? null,
      intervalKm ?? null,
      // Contrato: al omitir las antelaciones se guardan los defectos 30/500.
      advanceDays ?? DEFAULT_ADVANCE_DAYS,
      advanceKm ?? DEFAULT_ADVANCE_KM,
      notes ?? null,
      createdBy,
    ],
  );
  return findById(result.insertId);
}

// Edición parcial: solo los campos enviados (undefined = conservar).
export async function updateMaintenance(id, fields) {
  const current = await findById(id);
  if (!current) return null;
  await query(
    `UPDATE maintenance SET service_type = ?, target_date = ?, target_mileage = ?,
       interval_days = ?, interval_km = ?, advance_days = ?, advance_km = ?, notes = ?
     WHERE id = ?`,
    [
      fields.serviceType ?? current.serviceType,
      fields.targetDate !== undefined ? fields.targetDate : current.targetDate,
      fields.targetMileage !== undefined ? fields.targetMileage : current.targetMileage,
      fields.intervalDays !== undefined ? fields.intervalDays : current.intervalDays,
      fields.intervalKm !== undefined ? fields.intervalKm : current.intervalKm,
      fields.advanceDays ?? current.advanceDays,
      fields.advanceKm ?? current.advanceKm,
      fields.notes !== undefined ? fields.notes : current.notes,
      id,
    ],
  );
  return findById(id);
}

// Renovación al marcar «servicio realizado» (FR-015, R-05): en UNA
// transacción se actualiza el último servicio, los objetivos recalculados del
// MISMO registro y el kilometraje vigente del vehículo con la regla de valor
// más alto (FR-007). El llamador gestiona begin/commit/rollback.
export async function renewMaintenance(connection, {
  maintenanceId,
  vehicleId,
  lastServiceDate,
  lastServiceMileage,
  targetDate,
  targetMileage,
}) {
  await connection.execute(
    `UPDATE maintenance SET last_service_date = ?, last_service_mileage = ?,
       target_date = ?, target_mileage = ?
     WHERE id = ?`,
    [lastServiceDate, lastServiceMileage, targetDate, targetMileage, maintenanceId],
  );
  // Regla heredada del Sprint 2 (FR-007): el kilometraje vigente solo sube.
  await connection.execute(
    'UPDATE vehicles SET current_mileage = ? WHERE id = ? AND current_mileage < ?',
    [lastServiceMileage, vehicleId, lastServiceMileage],
  );
}

// Último kilometraje registrado en las órdenes del vehículo (para la regla
// de no-regresión del «servicio realizado», FR-006 heredada del Sprint 2).
export async function getLastOrderMileageByVehicle(vehicleId) {
  const rows = await query(
    'SELECT MAX(entry_mileage) AS last_mileage FROM service_orders WHERE vehicle_id = ?',
    [vehicleId],
  );
  return rows[0]?.last_mileage ?? null;
}
