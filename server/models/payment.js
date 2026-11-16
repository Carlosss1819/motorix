// Acceso a datos de los pagos (tabla payments) y del contenido de la orden
// necesario para cobrar (mano de obra y refacciones con precio congelado).
// Fuente de verdad de los campos: specs/004-pagos-tickets-dashboard/data-model.md
import { query } from '../config/db.js';

// Ejecuta en la conexión de una transacción (Sprint 5, R-07) o en el pool.
async function run(connection, sql, params = []) {
  if (connection) {
    const [rows] = await connection.execute(sql, params);
    return rows;
  }
  return query(sql, params);
}

const SELECT_PAYMENT = `
  SELECT p.*, u.username AS created_by_username, a.username AS annulled_by_username
  FROM payments p
  JOIN users u ON u.id = p.created_by
  LEFT JOIN users a ON a.id = p.annulled_by`;

function mapPayment(row) {
  if (!row) return null;
  return {
    id: row.id,
    serviceOrderId: row.service_order_id,
    amount: row.amount,
    method: row.method,
    status: row.status,
    externalReference: row.external_reference,
    paymentLink: row.payment_link,
    gatewayMode: row.gateway_mode,
    annulmentReason: row.annulment_reason,
    // Sprint 5 (FR-016): IMPORTE_DESFASADO, MANUAL o null.
    cancellationReason: row.cancellation_reason ?? null,
    annulledBy: row.annulled_by,
    annulledByUsername: row.annulled_by_username,
    createdBy: row.created_by,
    createdByUsername: row.created_by_username,
    createdAt: row.created_at,
    annulledAt: row.annulled_at,
  };
}

export async function createPayment(
  {
    serviceOrderId,
    amount,
    method,
    status,
    externalReference = null,
    paymentLink = null,
    gatewayMode = null,
    createdBy,
  },
  connection = null,
) {
  const result = await run(
    connection,
    `INSERT INTO payments
       (service_order_id, amount, method, status, external_reference,
        payment_link, gateway_mode, created_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [serviceOrderId, amount, method, status, externalReference, paymentLink, gatewayMode, createdBy],
  );
  return findPaymentById(result.insertId, connection);
}

export async function findPaymentById(id, connection = null) {
  const rows = await run(connection, `${SELECT_PAYMENT} WHERE p.id = ? LIMIT 1`, [id]);
  return mapPayment(rows[0]);
}

// Pagos de una orden, paginados; incluye anulados, que son historial (RN-9).
export async function listPaymentsByOrder(serviceOrderId, { page = 1, perPage = 10 } = {}) {
  const countRows = await query(
    'SELECT COUNT(*) AS total FROM payments WHERE service_order_id = ?',
    [serviceOrderId],
  );
  const offset = (page - 1) * perPage;
  const rows = await query(
    `${SELECT_PAYMENT} WHERE p.service_order_id = ?
     ORDER BY p.id DESC LIMIT ${Number(perPage)} OFFSET ${Number(offset)}`,
    [serviceOrderId],
  );
  return { rows: rows.map(mapPayment), total: Number(countRows[0].total) };
}

// Conteo de pagos de una orden en un estado dado. La regla «un solo pago
// PAGADO por orden» y «un solo cobro PENDIENTE» se valida en el servicio con
// esta consulta (FR-004; MySQL no admite únicas parciales).
export async function countPaymentsByStatus(serviceOrderId, status, connection = null) {
  const rows = await run(
    connection,
    'SELECT COUNT(*) AS total FROM payments WHERE service_order_id = ? AND status = ?',
    [serviceOrderId, status],
  );
  return Number(rows[0].total);
}

// Primer pago en el estado dado (por ejemplo, el que respalda la entrega).
export async function findPaymentByStatus(serviceOrderId, status, connection = null) {
  const rows = await run(
    connection,
    `${SELECT_PAYMENT} WHERE p.service_order_id = ? AND p.status = ?
     ORDER BY p.id LIMIT 1`,
    [serviceOrderId, status],
  );
  return mapPayment(rows[0]);
}

// Actualiza el estado de un pago y, cuando aplica, los campos de anulación
// (FR-016). Devuelve el pago recargado.
// Sprint 5: `cancellationReason` guarda el motivo de una cancelación
// (FR-016) y `connection` permite actualizar dentro de la transacción con el
// candado de la orden (R-07).
export async function updatePaymentStatus(
  id,
  {
    status,
    annulmentReason = null,
    annulledBy = null,
    annulledAt = null,
    paymentLink = null,
    externalReference = null,
    cancellationReason = null,
  },
  connection = null,
) {
  const assignments = ['status = ?'];
  const values = [status];
  if (annulmentReason !== null) {
    assignments.push('annulment_reason = ?', 'annulled_by = ?', 'annulled_at = ?');
    values.push(annulmentReason, annulledBy, annulledAt);
  }
  if (paymentLink !== null) {
    assignments.push('payment_link = ?');
    values.push(paymentLink);
  }
  if (externalReference !== null) {
    assignments.push('external_reference = ?');
    values.push(externalReference);
  }
  if (cancellationReason !== null) {
    assignments.push('cancellation_reason = ?');
    values.push(cancellationReason);
  }
  values.push(id);
  await run(connection, `UPDATE payments SET ${assignments.join(', ')} WHERE id = ?`, values);
  return findPaymentById(id, connection);
}

// Contenido de la orden para cobrar (FR-015; Sprint 5, R-03): su mano de obra
// y sus refacciones con el precio CONGELADO de cada línea
// (`order_parts.unit_price`), no el del catálogo. Las filas heredadas de
// `order_parts` sin `part_id` vuelven con `partId: null` y se valoran en 0.
// Los importes viajan como la cadena DECIMAL de mysql2: `order-total.js` los
// convierte a centavos sin pasar por flotante (R-06).
// `connection` permite leerlo dentro de la transacción que tiene el candado
// de la orden (R-07).
export async function findChargeContent(serviceOrderId, connection = null) {
  const laborRows = await run(
    connection,
    `SELECT id, description, price
     FROM order_labor
     WHERE service_order_id = ?
     ORDER BY id`,
    [serviceOrderId],
  );
  const partRows = await run(
    connection,
    `SELECT op.id, op.description, op.quantity, op.part_id, op.unit_price,
            pa.code, pa.name
     FROM order_parts op
     LEFT JOIN parts pa ON pa.id = op.part_id
     WHERE op.service_order_id = ?
     ORDER BY op.id`,
    [serviceOrderId],
  );
  return {
    manoDeObra: laborRows.map((row) => ({
      id: row.id,
      descripcion: row.description,
      precio: row.price,
    })),
    refacciones: partRows.map((row) => ({
      id: row.id,
      descripcion: row.description,
      cantidad: row.quantity,
      partId: row.part_id,
      // `codigo` y `nombre` del catálogo los usa el ticket (FR-007); el
      // cálculo del total solo mira cantidad y precioUnitario.
      codigo: row.code ?? null,
      nombre: row.name ?? null,
      precioUnitario: row.unit_price,
    })),
  };
}
