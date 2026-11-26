// Acceso a datos de los tickets (tabla tickets) y del contexto de la orden
// con el que se arma el comprobante (FR-007; Sprint 5: FR-019, FR-033).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/data-model.md y
// specs/005-precios-refacciones-cobro/data-model.md.
//
// Unicidad (Sprint 5, migración 005): un ticket por PAGO (`uq_tickets_payment`);
// una orden puede tener varios tickets si un pago se anuló y se cobró de nuevo.
import { query } from '../config/db.js';

// Ejecuta en la conexión de una transacción (R-07) o en el pool.
async function run(connection, sql, params = []) {
  if (connection) {
    const [rows] = await connection.execute(sql, params);
    return rows;
  }
  return query(sql, params);
}

// El estado del pago se lee al consultar: «vigente» y «pago anulado» no se
// guardan en la copia (data-model.md).
const SELECT_TICKET = `
  SELECT t.*, u.username AS issued_by_username, p.status AS payment_status
  FROM tickets t
  JOIN users u ON u.id = t.issued_by
  JOIN payments p ON p.id = t.payment_id`;

function parseContent(value) {
  if (value === null || value === undefined) return null;
  return typeof value === 'string' ? JSON.parse(value) : value;
}

function mapTicket(row) {
  if (!row) return null;
  return {
    id: row.id,
    serviceOrderId: row.service_order_id,
    paymentId: row.payment_id,
    paymentStatus: row.payment_status,
    folio: row.folio,
    issuedBy: row.issued_by,
    issuedByUsername: row.issued_by_username,
    issuedAt: row.issued_at,
    // Copia del comprobante y su versión de formato (FR-019).
    content: parseContent(row.content),
    formatVersion: row.format_version ?? null,
  };
}

export async function findById(id, connection = null) {
  const rows = await run(connection, `${SELECT_TICKET} WHERE t.id = ? LIMIT 1`, [id]);
  return mapTicket(rows[0]);
}

export async function findByFolio(folio) {
  const rows = await query(`${SELECT_TICKET} WHERE t.folio = ? LIMIT 1`, [folio]);
  return mapTicket(rows[0]);
}

// Ticket de un pago (único por `uq_tickets_payment`).
export async function findByPaymentId(paymentId, connection = null) {
  const rows = await run(connection, `${SELECT_TICKET} WHERE t.payment_id = ? LIMIT 1`, [
    paymentId,
  ]);
  return mapTicket(rows[0]);
}

// Todos los tickets de una orden, del más reciente al más antiguo (FR-033).
export async function listByServiceOrder(serviceOrderId) {
  const rows = await query(
    `${SELECT_TICKET} WHERE t.service_order_id = ? ORDER BY t.issued_at DESC, t.id DESC`,
    [serviceOrderId],
  );
  return rows.map(mapTicket);
}

// Siguiente folio consecutivo del año en curso (D3): `T000001-2026`. Se
// calcula sobre el máximo existente del año, así que sobrevive a borrados y
// respeta los folios fijos de las semillas. Se lee SIEMPRE con el pool (lo
// último confirmado), para que un reintento por folio repetido vea el folio
// que otra transacción acaba de confirmar.
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

// Alta del ticket con su copia (Sprint 5, FR-019): `content` es el
// comprobante completo y `formatVersion` su versión (2 desde el Sprint 5).
export async function create(
  { serviceOrderId, paymentId, folio, issuedBy, issuedAt, content, formatVersion },
  connection = null,
) {
  const result = await run(
    connection,
    `INSERT INTO tickets
       (service_order_id, payment_id, folio, issued_by, issued_at, content, format_version)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      serviceOrderId,
      paymentId,
      folio,
      issuedBy,
      issuedAt,
      JSON.stringify(content),
      formatVersion,
    ],
  );
  return findById(result.insertId, connection);
}

// Contexto de la orden para el comprobante: cliente y vehículo con sus campos
// separados (marca, modelo, año, placas) más el kilometraje de entrada, que
// `findServiceOrderById` trae solo como etiqueta concatenada.
// Sprint 7 (US8, FR-012): tipos de servicio distintos con intervalo enlazados
// a las líneas de la orden, en el orden en que se agregaron.
export async function findOrderServiceTypes(serviceOrderId, connection = null) {
  const rows = await run(
    connection,
    `SELECT st.id, st.name, st.interval_days, st.interval_km, MIN(os.id) AS first_line
     FROM order_services os
     JOIN service_types st ON st.id = os.service_type_id
     WHERE os.service_order_id = ?
     GROUP BY st.id, st.name, st.interval_days, st.interval_km
     ORDER BY first_line`,
    [serviceOrderId],
  );
  return rows.map((row) => ({
    id: row.id,
    nombre: row.name,
    intervaloDias: row.interval_days,
    intervaloKm: row.interval_km,
  }));
}

export async function findOrderContext(serviceOrderId, connection = null) {
  const rows = await run(
    connection,
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
