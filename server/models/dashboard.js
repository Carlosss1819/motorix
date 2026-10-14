// Acceso a datos del panel de control (Sprint 4, US5/US6): lecturas directas
// sobre las tablas de origen, sin tablas derivadas ni copias (CA-6, FR-010,
// FR-011). Cada bloque reutiliza la fuente existente: órdenes, citas,
// mantenimientos (el estado lo calcula el servicio con `calcMaintenanceState`)
// y refacciones con la regla `stockBajo` del inventario (R-10).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md
import { query } from '../config/db.js';
import { APPOINTMENT_STATUSES } from '../utils/status-constants.js';

// Regla de stock bajo del inventario (FR-021, R-10): un stock mínimo de 0
// nunca genera alerta.
const WHERE_STOCK_BAJO = 'stock_current <= stock_min AND stock_min > 0';

// Formatea una fecha DATE como `AAAA-MM-DD` en la zona local (mismo criterio
// que appointment.service, para que el día mostrado coincida con el real).
function formatDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// La columna TIME puede llegar como cadena '10:30:00' o como Date; en ambos
// casos se devuelve el horario `HH:MM` del contrato.
function formatTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const pad = (number) => String(number).padStart(2, '0');
    return `${pad(value.getHours())}:${pad(value.getMinutes())}`;
  }
  return String(value).slice(0, 5);
}

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

// Citas de la fecha de referencia con estado activo (`PROGRAMADA` o
// `RECIBIDA`), según el bloque `citas.hoy` del contrato.
export async function countAppointmentsOn(fecha) {
  const rows = await query(
    `SELECT COUNT(*) AS total
     FROM appointments
     WHERE appointment_date = ?
       AND status IN (?, ?)`,
    [fecha, APPOINTMENT_STATUSES.PROGRAMADA, APPOINTMENT_STATUSES.RECIBIDA],
  );
  return Number(rows[0].total);
}

// Las citas siguientes a la referencia (máximo [limit], orden ascendente por
// fecha, hora e id). Usa los mismos estados activos que `hoy`: una cita
// cancelada o no presentada no es «próxima».
export async function listUpcomingAppointments(fecha, limit = 5) {
  const rows = await query(
    `SELECT a.id, a.appointment_date, a.appointment_time, a.status,
            c.name AS client_name
     FROM appointments a
     JOIN clients c ON c.id = a.client_id
     WHERE a.appointment_date > ?
       AND a.status IN (?, ?)
     ORDER BY a.appointment_date ASC, a.appointment_time ASC, a.id ASC
     LIMIT ?`,
    [fecha, APPOINTMENT_STATUSES.PROGRAMADA, APPOINTMENT_STATUSES.RECIBIDA, limit],
  );
  return rows.map((row) => ({
    id: row.id,
    fecha: formatDate(row.appointment_date),
    hora: formatTime(row.appointment_time),
    cliente: row.client_name,
    estado: row.status,
  }));
}

// Total de refacciones en alerta (misma regla que la lista siguiente).
export async function countLowStockParts() {
  const rows = await query(
    `SELECT COUNT(*) AS total FROM parts WHERE ${WHERE_STOCK_BAJO}`,
  );
  return Number(rows[0].total);
}

// Refacciones en alerta: máximo [limit] filas ordenadas por faltante
// ascendente (`stock_min - stock_current`); el código desempata para que el
// orden sea estable.
export async function listLowStockParts(limit = 10) {
  const rows = await query(
    `SELECT id, code, name, stock_current, stock_min
     FROM parts
     WHERE ${WHERE_STOCK_BAJO}
     ORDER BY (stock_min - stock_current) ASC, code ASC
     LIMIT ?`,
    [limit],
  );
  return rows.map((row) => ({
    id: row.id,
    codigo: row.code,
    nombre: row.name,
    stockActual: Number(row.stock_current),
    stockMinimo: Number(row.stock_min),
  }));
}
