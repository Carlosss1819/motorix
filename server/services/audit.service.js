// Bitácora de acciones sensibles (Sprint 7, US10, FR-022 a FR-025).
// - Lista cerrada de acciones (research R-06).
// - El detalle nunca lleva contraseñas, hashes, tokens ni datos de tarjeta
//   (FR-023): cada servicio arma un texto breve y aquí se recorta a 255.
// - Registrar NO debe tumbar la operación principal (FR-025): si la inserción
//   falla, solo se anota en el servidor.
import { insertAuditEntry, listAuditEntries } from '../models/audit_log.js';

export const AUDIT_ACTIONS = Object.freeze([
  'LOGIN_FALLIDO',
  'CUENTA_BLOQUEADA',
  'USUARIO_CREADO',
  'USUARIO_ROL_CAMBIADO',
  'USUARIO_ACTIVADO',
  'USUARIO_DESACTIVADO',
  'CONFIG_ACTUALIZADA',
  'TIPO_SERVICIO_CREADO',
  'TIPO_SERVICIO_EDITADO',
  'TIPO_SERVICIO_ACTIVADO',
  'TIPO_SERVICIO_DESACTIVADO',
  'PRECIO_REFACCION_CAMBIADO',
  'PAGO_ANULADO',
  'PAGO_CANCELADO',
  'TERMINOS_ACEPTADOS',
]);

const MAX_DETAIL = 255;

// Detalle breve y de una sola línea, recortado al tamaño de la columna.
export function sanitizeDetail(detail) {
  if (detail === undefined || detail === null) return null;
  const text = String(detail).replace(/\s+/g, ' ').trim();
  if (!text) return null;
  return text.length > MAX_DETAIL ? `${text.slice(0, MAX_DETAIL - 1)}…` : text;
}

// Inyección para pruebas: permite simular una falla de la base.
let writer = insertAuditEntry;
export function setAuditWriterForTests(fn) {
  writer = fn ?? insertAuditEntry;
}

export async function record({ userId = null, action, entityType = null, entityId = null, detail = null }) {
  try {
    await writer({
      userId,
      action,
      entityType,
      entityId,
      detail: sanitizeDetail(detail),
    });
  } catch (error) {
    // FR-025: la bitácora no bloquea la operación; el detalle queda en el servidor.
    console.error('[bitacora]', new Date().toISOString(), action, error?.message);
  }
}

export async function list(filters) {
  const page = filters.pagina ?? 1;
  const perPage = filters.porPagina ?? 20;
  const { total, rows } = await listAuditEntries({
    desde: filters.desde,
    hasta: filters.hasta,
    usuarioId: filters.usuarioId,
    accion: filters.accion,
    page,
    perPage,
  });
  return {
    elementos: rows,
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
    acciones: AUDIT_ACTIONS,
  };
}
