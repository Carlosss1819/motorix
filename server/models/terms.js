// Acceso a datos de términos y aviso de privacidad (Sprint 7, US9).
// La versión vigente es la más reciente con is_current = 1 (data-model.md).
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

const CURRENT_VERSION = `SELECT id, version, published_at, terms_text, privacy_text
  FROM terms_versions
  WHERE is_current = 1
  ORDER BY published_at DESC, id DESC
  LIMIT 1`;

// Una sola consulta por petición (FR-020): versión vigente y si el usuario la
// aceptó. Devuelve null si no hay versión publicada.
export async function findPendingStatus(userId) {
  const rows = await query(
    `SELECT tv.id, tv.version,
            EXISTS(SELECT 1 FROM terms_acceptances ta
                   WHERE ta.user_id = ? AND ta.terms_version_id = tv.id) AS accepted
     FROM (${CURRENT_VERSION}) tv`,
    [userId],
  );
  if (!rows[0]) return null;
  return { versionId: rows[0].id, version: rows[0].version, accepted: Boolean(rows[0].accepted) };
}

export async function findCurrentVersion(userId) {
  const rows = await query(
    `SELECT tv.id, tv.version, tv.published_at, tv.terms_text, tv.privacy_text, ta.accepted_at
     FROM (${CURRENT_VERSION}) tv
     LEFT JOIN terms_acceptances ta ON ta.terms_version_id = tv.id AND ta.user_id = ?`,
    [userId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    version: row.version,
    publicadoEn: formatDateTime(row.published_at),
    terminos: row.terms_text,
    avisoPrivacidad: row.privacy_text,
    aceptado: Boolean(row.accepted_at),
    aceptadoEn: formatDateTime(row.accepted_at),
  };
}

// INSERT IGNORE: aceptar dos veces es idempotente (UNIQUE usuario+versión).
// Devuelve true si la aceptación es nueva.
export async function insertAcceptance(userId, versionId) {
  const result = await query(
    'INSERT IGNORE INTO terms_acceptances (user_id, terms_version_id) VALUES (?, ?)',
    [userId, versionId],
  );
  return result.affectedRows > 0;
}

export async function listAcceptances({ version, page, perPage }) {
  const params = [];
  let where = '';
  if (version) {
    where = 'WHERE tv.version = ?';
    params.push(version);
  }
  const totalRows = await query(
    `SELECT COUNT(*) AS total
     FROM terms_acceptances ta JOIN terms_versions tv ON tv.id = ta.terms_version_id ${where}`,
    params,
  );
  const offset = (page - 1) * perPage;
  const rows = await query(
    `SELECT ta.user_id, u.username, tv.version, ta.accepted_at
     FROM terms_acceptances ta
     JOIN terms_versions tv ON tv.id = ta.terms_version_id
     JOIN users u ON u.id = ta.user_id
     ${where}
     ORDER BY ta.accepted_at DESC, ta.id DESC
     LIMIT ${Number(perPage)} OFFSET ${Number(offset)}`,
    params,
  );
  return {
    total: Number(totalRows[0]?.total ?? 0),
    rows: rows.map((row) => ({
      usuarioId: row.user_id,
      username: row.username,
      version: row.version,
      aceptadoEn: formatDateTime(row.accepted_at),
    })),
  };
}
