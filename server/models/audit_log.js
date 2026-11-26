// Acceso a datos de la bitácora de acciones sensibles (Sprint 7, US10).
// Solo inserta y lista: no hay funciones de edición ni de borrado (FR-024).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/audit-log.md.
import { query } from '../config/db.js';

const pad = (number) => String(number).padStart(2, '0');

function formatDateTime(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

export async function insertAuditEntry({ userId, action, entityType, entityId, detail }) {
  await query(
    `INSERT INTO audit_log (user_id, action, entity_type, entity_id, detail)
     VALUES (?, ?, ?, ?, ?)`,
    [userId ?? null, action, entityType ?? null, entityId ?? null, detail ?? null],
  );
}

// Filtros opcionales: rango de fechas (inclusive, AAAA-MM-DD), usuario y
// acción. Todos los valores viajan como parámetros (FR-029).
export async function listAuditEntries({ desde, hasta, usuarioId, accion, page, perPage }) {
  const conditions = [];
  const params = [];
  if (desde) {
    conditions.push('a.created_at >= ?');
    params.push(`${desde} 00:00:00`);
  }
  if (hasta) {
    conditions.push('a.created_at < DATE_ADD(?, INTERVAL 1 DAY)');
    params.push(hasta);
  }
  if (usuarioId) {
    conditions.push('a.user_id = ?');
    params.push(usuarioId);
  }
  if (accion) {
    conditions.push('a.action = ?');
    params.push(accion);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const totalRows = await query(`SELECT COUNT(*) AS total FROM audit_log a ${where}`, params);
  const offset = (page - 1) * perPage;
  const rows = await query(
    `SELECT a.id, a.created_at, a.user_id, u.username, a.action, a.entity_type, a.entity_id, a.detail
     FROM audit_log a
     LEFT JOIN users u ON u.id = a.user_id
     ${where}
     ORDER BY a.created_at DESC, a.id DESC
     LIMIT ${Number(perPage)} OFFSET ${Number(offset)}`,
    params,
  );

  return {
    total: Number(totalRows[0]?.total ?? 0),
    rows: rows.map((row) => ({
      id: Number(row.id),
      fecha: formatDateTime(row.created_at),
      usuarioId: row.user_id,
      usuario: row.username ?? null,
      accion: row.action,
      entidad: row.entity_type,
      entidadId: row.entity_id,
      detalle: row.detail,
    })),
  };
}
