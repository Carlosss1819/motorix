// Acceso a datos de los tickets (tabla tickets) y del contexto de la orden
// con el que se reconstruye el comprobante (FR-007, FR-012).
// Fuente de verdad de los campos: specs/004-pagos-tickets-dashboard/data-model.md
import { query } from '../config/db.js';

const SELECT_TICKET = `
  SELECT t.*, u.username AS issued_by_username
  FROM tickets t
  JOIN users u ON u.id = t.issued_by`;

function mapTicket(row) {
  if (!row) return null;
  return {
    id: row.id,
    serviceOrderId: row.service_order_id,
    paymentId: row.payment_id,
    folio: row.folio,
    issuedBy: row.issued_by,
    issuedByUsername: row.issued_by_username,
    issuedAt: row.issued_at,
  };
}

// Ticket de una orden (único por `UNIQUE KEY uq_tickets_service_order`).
export async function findByServiceOrder(serviceOrderId) {
  const rows = await query(
    `${SELECT_TICKET} WHERE t.service_order_id = ? LIMIT 1`,
    [serviceOrderId],
  );
  return mapTicket(rows[0]);
}

export async function findById(id) {
  const rows = await query(`${SELECT_TICKET} WHERE t.id = ? LIMIT 1`, [id]);
  return mapTicket(rows[0]);
}

export async function findByFolio(folio) {
  const rows = await query(`${SELECT_TICKET} WHERE t.folio = ? LIMIT 1`, [
    folio,
  ]);
  return mapTicket(rows[0]);
}

// Siguiente folio consecutivo del año en curso (D3): `T000001-2026`. Se
// calcula sobre el máximo existente del año, así que sobrevive a borrados y
// respeta los folios fijos de las semillas.
export async function nextFolio(year = new Date().getFullYear()) {
  const rows = await query(
    `SELECT MAX(CAST(SUBSTRING(folio, 2, 6) AS UNSIGNED)) AS ultimo
     FROM tickets
     WHERE folio LIKE ?`,
    [`T%-${year}`],
  );
  const ultimo = Number(rows[0]?.ultimo ?? 0) || 0;
  return `T${String(ultimo + 1).padStart(6, '0')}-${year}`;
}

export async function create({
  serviceOrderId,
  paymentId,
  folio,
  issuedBy,
}) {
  const result = await query(
    `INSERT INTO tickets (service_order_id, payment_id, folio, issued_by)
     VALUES (?, ?, ?, ?)`,
    [serviceOrderId, paymentId, folio, issuedBy],
  );
  return findById(result.insertId);
}

// Contexto de la orden para el comprobante: cliente y vehículo con sus campos
// separados (marca, modelo, año, placas) más el kilometraje de entrada, que
// `findServiceOrderById` trae solo como etiqueta concatenada.
export async function findOrderContext(serviceOrderId) {
  const rows = await query(
    `SELECT so.id,
            so.client_id,
            c.name AS client_name,
            c.phone AS client_phone,
            v.id AS vehicle_id,
            v.brand,
            v.model,
            v.year,
            v.plates,
            so.entry_mileage
     FROM service_orders so
     JOIN clients c ON c.id = so.client_id
     JOIN vehicles v ON v.id = so.vehicle_id
     WHERE so.id = ?
     LIMIT 1`,
    [serviceOrderId],
  );
  return rows[0] ?? null;
}
