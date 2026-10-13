// Consulta derivada del historial del vehículo (Sprint 3, R-01): NO es una
// tabla; consolida las órdenes terminadas o entregadas del vehículo con sus
// servicios, refacciones y recomendaciones (RN-10). Usa el índice
// idx_service_orders_vehicle_status (R-02, SC-001).
import { query } from '../config/db.js';

function formatDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// Órdenes terminadas/entregadas del vehículo, lo más reciente primero
// (entry_date, id DESC), con total para paginar.
export async function listTerminatedByVehicle(vehicleId, { page, perPage } = {}) {
  const where = "WHERE so.vehicle_id = ? AND so.status IN ('TERMINADO', 'ENTREGADO')";

  const [countRow] = await query(
    `SELECT COUNT(*) AS total FROM service_orders so ${where}`,
    [vehicleId],
  );

  const limitValues = [vehicleId];
  let limitClause = '';
  if (page && perPage) {
    limitClause = ' LIMIT ? OFFSET ?';
    limitValues.push(perPage, (page - 1) * perPage);
  }

  const orders = await query(
    `SELECT so.id, so.status, so.visit_reason, so.entry_date, so.entry_mileage,
            so.diagnosis, so.recommendations
     FROM service_orders so
     ${where}
     ORDER BY so.entry_date DESC, so.id DESC${limitClause}`,
    limitValues,
  );

  const orderIds = orders.map((row) => row.id);
  const [services, parts] = await Promise.all([
    listServicesByOrders(orderIds),
    listPartsByOrders(orderIds),
  ]);

  return {
    rows: orders.map((row) => ({
      orderId: row.id,
      serviceDate: formatDate(row.entry_date),
      mileage: row.entry_mileage,
      orderStatus: row.status,
      observations: row.visit_reason,
      diagnosis: row.diagnosis ?? null,
      recommendations: row.recommendations ?? null,
      services: services.get(row.id) ?? [],
      parts: parts.get(row.id) ?? [],
    })),
    total: countRow.total,
  };
}

// Servicios de cada orden en una sola consulta (evita N+1).
async function listServicesByOrders(orderIds) {
  const map = new Map();
  if (!orderIds.length) return map;
  const placeholders = orderIds.map(() => '?').join(', ');
  const rows = await query(
    `SELECT service_order_id, description
     FROM order_services
     WHERE service_order_id IN (${placeholders})
     ORDER BY id`,
    orderIds,
  );
  for (const row of rows) {
    if (!map.has(row.service_order_id)) map.set(row.service_order_id, []);
    map.get(row.service_order_id).push(row.description);
  }
  return map;
}

// Refacciones de cada orden; las filas heredadas del Sprint 2 (sin part_id)
// devuelven partId/codigo nulos y el nombre guardado en su momento (R-06).
async function listPartsByOrders(orderIds) {
  const map = new Map();
  if (!orderIds.length) return map;
  const placeholders = orderIds.map(() => '?').join(', ');
  const rows = await query(
    `SELECT op.service_order_id, op.part_id, op.description, op.quantity, p.code
     FROM order_parts op
     LEFT JOIN parts p ON p.id = op.part_id
     WHERE op.service_order_id IN (${placeholders})
     ORDER BY op.id`,
    orderIds,
  );
  for (const row of rows) {
    if (!map.has(row.service_order_id)) map.set(row.service_order_id, []);
    map.get(row.service_order_id).push({
      partId: row.part_id ?? null,
      code: row.code ?? null,
      name: row.description,
      quantity: row.quantity,
    });
  }
  return map;
}

// El vehículo debe existir para consultar su historial (404 en otro caso).
export async function vehicleExists(vehicleId) {
  const rows = await query('SELECT id FROM vehicles WHERE id = ? LIMIT 1', [vehicleId]);
  return rows.length > 0;
}
