// Acceso a datos de la tabla clients (driver mysql2, sin ORM).
import { query } from '../config/db.js';

function mapClient(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    email: row.email,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Escapa comodines para que la busqueda sea literal (no regex ni inyección SQL).
function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

export async function listClients(search) {
  if (search) {
    const pattern = `%${escapeLike(search)}%`;
    const rows = await query(
      `SELECT * FROM clients
       WHERE name LIKE ? OR phone LIKE ? OR IFNULL(email, '') LIKE ?
       ORDER BY name`,
      [pattern, pattern, pattern],
    );
    return rows.map(mapClient);
  }
  const rows = await query('SELECT * FROM clients ORDER BY name');
  return rows.map(mapClient);
}

export async function findById(id) {
  const rows = await query('SELECT * FROM clients WHERE id = ? LIMIT 1', [id]);
  return mapClient(rows[0]);
}

// Aviso de teléfono repetido (R-05): busca el teléfono en OTRO cliente.
export async function findByPhone(phone, excludeId = null) {
  if (excludeId) {
    const rows = await query('SELECT * FROM clients WHERE phone = ? AND id <> ? LIMIT 1', [
      phone,
      excludeId,
    ]);
    return mapClient(rows[0]);
  }
  const rows = await query('SELECT * FROM clients WHERE phone = ? LIMIT 1', [phone]);
  return mapClient(rows[0]);
}

export async function createClient({ name, phone, email, status = 'ACTIVO' }) {
  const result = await query(
    'INSERT INTO clients (name, phone, email, status) VALUES (?, ?, ?, ?)',
    [name, phone, email ?? null, status],
  );
  return findById(result.insertId);
}

export async function updateClient(id, { name, phone, email }) {
  await query('UPDATE clients SET name = ?, phone = ?, email = ? WHERE id = ?', [
    name,
    phone,
    email ?? null,
    id,
  ]);
  return findById(id);
}
