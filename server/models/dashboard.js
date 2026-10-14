// Acceso a datos del panel de control (Sprint 4, US5): contadores directos
// sobre `service_orders`, sin tablas derivadas ni copias (CA-6, FR-010).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md
import { query } from '../config/db.js';

// Conteo de órdenes agrupado por estado: una fila por estado con su total.
// Devuelve `[{ status, total }]`; los estados sin filas no aparecen.
export async function countOrdersByStatus() {
  const rows = await query(
    `SELECT status, COUNT(*) AS total
     FROM service_orders
     GROUP BY status
     ORDER BY status`,
  );
  return rows.map((row) => ({
    status: row.status,
    // COUNT(*) es entero en mysql2; Number por consistencia con DECIMAL.
    total: Number(row.total),
  }));
}
