// Contenido de la orden de servicio: servicios con su mano de obra y
// refacciones. El servicio y su partida de mano de obra se crean siempre en la
// misma transacción (R-13): no puede existir uno sin la otra.
// Fuente de verdad: specs/002-citas-ordenes-servicio/data-model.md.
import { query } from '../config/db.js';

// Crea el servicio y su mano de obra en la MISMA transacción (FR-012, R-13):
// si falla una de las dos, no se guarda ninguna. Desde el Sprint 5 recibe la
// conexión de la transacción que ya tiene el candado de la orden (R-07).
export async function createServiceWithLabor(
  connection,
  { serviceOrderId, description, durationMinutes, price, serviceTypeId = null },
) {
  // Sprint 7 (FR-010): enlace opcional con el catálogo de tipos de servicio.
  const [serviceResult] = await connection.execute(
    'INSERT INTO order_services (service_order_id, description, service_type_id) VALUES (?, ?, ?)',
    [serviceOrderId, description, serviceTypeId],
  );
  const [laborResult] = await connection.execute(
    `INSERT INTO order_labor
       (service_order_id, service_id, description, duration_minutes, price)
     VALUES (?, ?, ?, ?, ?)`,
    [serviceOrderId, serviceResult.insertId, description, durationMinutes, price ?? null],
  );
  return {
    id: serviceResult.insertId,
    description,
    serviceTypeId,
    labor: {
      id: laborResult.insertId,
      durationMinutes,
      price: price ?? null,
    },
  };
}

// Elimina el servicio; su mano de obra cae en cascada por la FK
// (order_labor.service_id ON DELETE CASCADE).
export async function deleteServiceById(connection, serviceOrderId, serviceId) {
  const [result] = await connection.execute(
    'DELETE FROM order_services WHERE id = ? AND service_order_id = ?',
    [serviceId, serviceOrderId],
  );
  return result.affectedRows > 0;
}

// Fila de refacción usada en la orden (US7): `description` guarda el nombre
// del catálogo copiado en el momento del alta (R-06) y `part_id` queda en
// NULL solo en las filas heredadas del Sprint 2. Las funciones reciben la
// conexión para correr dentro de la transacción que mueve el stock (R-08).
// Sprint 5 (FR-006): `unitPrice` es el precio de venta vigente al agregar la
// línea y queda congelado; nunca se actualiza después (FR-007, FR-011).
export async function insertOrderPart(
  connection,
  { serviceOrderId, description, quantity, partId = null, unitPrice = null },
) {
  const [result] = await connection.execute(
    `INSERT INTO order_parts (service_order_id, description, quantity, part_id, unit_price)
     VALUES (?, ?, ?, ?, ?)`,
    [serviceOrderId, description, quantity, partId, unitPrice],
  );
  return { id: result.insertId, description, quantity, partId, unitPrice };
}

// Fila de la orden con bloqueo de fila: dos retiros simultáneos de la misma
// fila serializan aquí y solo uno repone el stock (RN-8, R-08).
export async function findOrderPartRow(connection, serviceOrderId, rowId) {
  const [rows] = await connection.execute(
    `SELECT id, part_id, description, quantity
     FROM order_parts
     WHERE id = ? AND service_order_id = ?
     LIMIT 1
     FOR UPDATE`,
    [rowId, serviceOrderId],
  );
  return rows[0] ?? null;
}

// Elimina la fila dentro de la transacción; devuelve false si ya no existía.
export async function deleteOrderPart(connection, serviceOrderId, rowId) {
  const [result] = await connection.execute(
    'DELETE FROM order_parts WHERE id = ? AND service_order_id = ?',
    [rowId, serviceOrderId],
  );
  return result.affectedRows > 0;
}

// Servicios de la orden con su partida de mano de obra (agregado del detalle).
export async function listServicesByOrder(serviceOrderId) {
  const rows = await query(
    `SELECT s.id, s.description, s.service_type_id, st.name AS service_type_name,
            l.id AS labor_id, l.duration_minutes, l.price
     FROM order_services s
     LEFT JOIN order_labor l ON l.service_id = s.id
     LEFT JOIN service_types st ON st.id = s.service_type_id
     WHERE s.service_order_id = ?
     ORDER BY s.id`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    id: row.id,
    description: row.description,
    serviceTypeId: row.service_type_id ?? null,
    serviceTypeName: row.service_type_name ?? null,
    labor: row.labor_id
      ? { id: row.labor_id, durationMinutes: row.duration_minutes, price: row.price }
      : null,
  }));
}

// Refacciones registradas en la orden (el stock se controla desde el Sprint 3).
export async function listPartsByOrder(serviceOrderId) {
  const rows = await query(
    `SELECT id, description, quantity, part_id, unit_price
     FROM order_parts
     WHERE service_order_id = ?
     ORDER BY id`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    id: row.id,
    description: row.description,
    quantity: row.quantity,
    partId: row.part_id,
    // DECIMAL como cadena (o null = «sin precio registrado»), Sprint 5.
    unitPrice: row.unit_price,
  }));
}
