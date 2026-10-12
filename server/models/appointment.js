// Acceso a datos de la tabla appointments (driver mysql2, sin ORM).
// En el Sprint 2 la US2 completa las funciones de citas; aquí se crea con lo
// mínimo que necesita la validación del alta de órdenes (T032 la amplía).
import { query } from '../config/db.js';

function mapAppointment(row) {
  if (!row) return null;
  return {
    id: row.id,
    clientId: row.client_id,
    vehicleId: row.vehicle_id,
    appointmentDate: row.appointment_date,
    appointmentTime: row.appointment_time,
    reason: row.reason,
    status: row.status,
    cancelReason: row.cancel_reason,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function findAppointmentById(id) {
  const rows = await query('SELECT * FROM appointments WHERE id = ? LIMIT 1', [id]);
  return mapAppointment(rows[0]);
}
