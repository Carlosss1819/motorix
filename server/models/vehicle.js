// Acceso a datos de la tabla vehicles (driver mysql2, sin ORM).
import { query } from '../config/db.js';

function mapVehicle(row) {
  if (!row) return null;
  return {
    id: row.id,
    clientId: row.client_id,
    ownerName: row.owner_name ?? undefined,
    brand: row.brand,
    model: row.model,
    year: row.year,
    plates: row.plates,
    vin: row.vin,
    currentMileage: row.current_mileage,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

export async function listVehicles({ search, clientId } = {}) {
  const joins = 'FROM vehicles v LEFT JOIN clients c ON c.id = v.client_id';
  const conditions = [];
  const values = [];

  if (search) {
    const pattern = `%${escapeLike(search)}%`;
    conditions.push(
      '(v.plates LIKE ? OR v.brand LIKE ? OR v.model LIKE ? OR c.name LIKE ?)',
    );
    values.push(pattern, pattern, pattern, pattern);
  }
  if (clientId) {
    conditions.push('v.client_id = ?');
    values.push(clientId);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const rows = await query(
    `SELECT v.*, c.name AS owner_name ${joins} ${where} ORDER BY v.id`,
    values,
  );
  return rows.map(mapVehicle);
}

export async function findById(id) {
  const rows = await query(
    `SELECT v.*, c.name AS owner_name
     FROM vehicles v LEFT JOIN clients c ON c.id = v.client_id
     WHERE v.id = ? LIMIT 1`,
    [id],
  );
  return mapVehicle(rows[0]);
}

export async function findByPlates(plates, excludeId = null) {
  if (excludeId) {
    const rows = await query('SELECT * FROM vehicles WHERE plates = ? AND id <> ? LIMIT 1', [
      plates,
      excludeId,
    ]);
    return rows[0] ? mapVehicle(rows[0]) : null;
  }
  const rows = await query('SELECT * FROM vehicles WHERE plates = ? LIMIT 1', [plates]);
  return rows[0] ? mapVehicle(rows[0]) : null;
}

export async function findByVin(vin, excludeId = null) {
  if (!vin) return null;
  if (excludeId) {
    const rows = await query('SELECT * FROM vehicles WHERE vin = ? AND id <> ? LIMIT 1', [
      vin,
      excludeId,
    ]);
    return rows[0] ? mapVehicle(rows[0]) : null;
  }
  const rows = await query('SELECT * FROM vehicles WHERE vin = ? LIMIT 1', [vin]);
  return rows[0] ? mapVehicle(rows[0]) : null;
}

export async function createVehicle({
  clientId,
  brand,
  model,
  year,
  plates,
  vin,
  currentMileage,
}) {
  const result = await query(
    `INSERT INTO vehicles (client_id, brand, model, year, plates, vin, current_mileage)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [clientId, brand, model, year, plates, vin || null, currentMileage],
  );
  return findById(result.insertId);
}

export async function updateVehicle(id, { brand, model, year, plates, vin, currentMileage }) {
  await query(
    `UPDATE vehicles SET brand = ?, model = ?, year = ?, plates = ?, vin = ?, current_mileage = ?
     WHERE id = ?`,
    [brand, model, year, plates, vin || null, currentMileage, id],
  );
  return findById(id);
}

// Actualiza el kilometraje del vehículo solo si el valor nuevo es mayor
// (regla R-08: el historial y el mantenimiento usan el kilometraje vigente).
export async function refreshCurrentMileage(id, mileage) {
  await query(
    'UPDATE vehicles SET current_mileage = ? WHERE id = ? AND current_mileage < ?',
    [mileage, id, mileage],
  );
}

// Vehiculos de un cliente (usado en el detalle de cliente, FR-014).
export async function listByClient(clientId) {
  const rows = await query(
    `SELECT v.*, c.name AS owner_name
     FROM vehicles v LEFT JOIN clients c ON c.id = v.client_id
     WHERE v.client_id = ?
     ORDER BY v.id`,
    [clientId],
  );
  return rows.map(mapVehicle);
}
