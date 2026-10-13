// Acceso a datos de los movimientos de inventario (tabla inventory_movements,
// Sprint 3). Todo movimiento explica un cambio de stock con su tipo, cantidad,
// motivo, orden asociada y el stock resultante (SC-007, FR-028).
import { query } from '../config/db.js';

function mapMovement(row) {
  if (!row) return null;
  return {
    id: row.id,
    partId: row.part_id,
    movementType: row.movement_type,
    quantity: row.quantity,
    reason: row.reason ?? null,
    serviceOrderId: row.service_order_id ?? null,
    stockAfter: row.stock_after,
    createdBy: row.created_by,
    createdByUsername: row.created_by_username ?? undefined,
    createdAt: row.created_at,
  };
}

// Historial de movimientos de una refacción (FR-030), ordenado por fecha
// descendente; admite filtro por tipo.
export async function listByPart({ partId, type, page, perPage } = {}) {
  const conditions = ['im.part_id = ?'];
  const values = [partId];

  if (type) {
    conditions.push('im.movement_type = ?');
    values.push(type);
  }
  const where = `WHERE ${conditions.join(' AND ')}`;

  const [countRow] = await query(
    `SELECT COUNT(*) AS total FROM inventory_movements im ${where}`,
    values,
  );

  const limitValues = [...values];
  let limitClause = '';
  if (page && perPage) {
    limitClause = ' LIMIT ? OFFSET ?';
    limitValues.push(perPage, (page - 1) * perPage);
  }

  const rows = await query(
    `SELECT im.*, u.username AS created_by_username
     FROM inventory_movements im
     LEFT JOIN users u ON u.id = im.created_by
     ${where}
     ORDER BY im.created_at DESC, im.id DESC${limitClause}`,
    limitValues,
  );
  return { rows: rows.map(mapMovement), total: countRow.total };
}

// Registra un movimiento DESDE la transacción que modificó el stock, para
// que movimiento y stock queden siempre en el mismo commit (R-08).
export async function insertMovement(connection, {
  partId,
  movementType,
  quantity,
  reason,
  serviceOrderId,
  stockAfter,
  createdBy,
}) {
  const [result] = await connection.execute(
    `INSERT INTO inventory_movements
       (part_id, movement_type, quantity, reason, service_order_id, stock_after, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [partId, movementType, quantity, reason ?? null, serviceOrderId ?? null, stockAfter, createdBy],
  );
  return result.insertId;
}

export async function findById(id) {
  const rows = await query(
    `SELECT im.*, u.username AS created_by_username
     FROM inventory_movements im
     LEFT JOIN users u ON u.id = im.created_by
     WHERE im.id = ? LIMIT 1`,
    [id],
  );
  return mapMovement(rows[0]);
}
