// Contenido de la orden de servicio: servicios con su mano de obra y
// repuestos. El servicio y su partida de mano de obra se crean siempre en la
// misma transacción (R-13): no puede existir uno sin la otra.
// Fuente de verdad: specs/002-citas-ordenes-servicio/data-model.md.
import { query, getConnection } from '../config/db.js';

// Crea el servicio y su mano de obra en la MISMA transacción (FR-012, R-13):
// si falla una de las dos, no se guarda ninguna.
export async function createServiceWithLabor({
  serviceOrderId,
  description,
  durationMinutes,
  price,
}) {
  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    const [serviceResult] = await connection.execute(
      'INSERT INTO order_services (service_order_id, description) VALUES (?, ?)',
      [serviceOrderId, description],
    );
    const [laborResult] = await connection.execute(
      `INSERT INTO order_labor
         (service_order_id, service_id, description, duration_minutes, price)
       VALUES (?, ?, ?, ?, ?)`,
      [
        serviceOrderId,
        serviceResult.insertId,
        description,
        durationMinutes,
        price ?? null,
      ],
    );

    await connection.commit();
    return {
      id: serviceResult.insertId,
      description,
      labor: {
        id: laborResult.insertId,
        durationMinutes,
        price: price ?? null,
      },
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// Elimina el servicio; su mano de obra cae en cascada por la FK
// (order_labor.service_id ON DELETE CASCADE).
export async function deleteServiceById(serviceOrderId, serviceId) {
  const result = await query(
    'DELETE FROM order_services WHERE id = ? AND service_order_id = ?',
    [serviceId, serviceOrderId],
  );
  return result.affectedRows > 0;
}

// Registra un repuesto en la orden. RN-06: no se consulta el inventario
// (quedó fuera de alcance para el Sprint 2; se valida en el Sprint 3).
export async function createPart({ serviceOrderId, description, quantity }) {
  const result = await query(
    `INSERT INTO order_parts (service_order_id, description, quantity)
     VALUES (?, ?, ?)`,
    [serviceOrderId, description, quantity],
  );
  return { id: result.insertId, description, quantity };
}

// Elimina un repuesto de la orden; devuelve false si no existía.
export async function deletePartById(serviceOrderId, partId) {
  const result = await query(
    'DELETE FROM order_parts WHERE id = ? AND service_order_id = ?',
    [partId, serviceOrderId],
  );
  return result.affectedRows > 0;
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
