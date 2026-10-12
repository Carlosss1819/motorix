// Acceso a datos de la tabla users (driver mysql2, sin ORM).
import { query } from '../config/db.js';

function mapUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    passwordHash: row.password_hash,
    role: row.role,
    status: row.status,
    failedLoginAttempts: row.failed_login_attempts,
    lockedUntil: row.locked_until,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function findById(id) {
  const rows = await query('SELECT * FROM users WHERE id = ? LIMIT 1', [id]);
  return mapUser(rows[0]);
}

export async function findByUsername(username) {
  const rows = await query('SELECT * FROM users WHERE username = ? LIMIT 1', [username]);
  return mapUser(rows[0]);
}

export async function findByEmail(email) {
  const rows = await query('SELECT * FROM users WHERE email = ? LIMIT 1', [email]);
  return mapUser(rows[0]);
}

// FR-002 / RN-16: si el identificador contiene "@" se busca por correo,
// en cualquier otro caso por nombre de usuario.
export async function findByIdentifier(identifier) {
  if (identifier.includes('@')) return findByEmail(identifier);
  return findByUsername(identifier);
}

export async function listUsers() {
  const rows = await query('SELECT * FROM users ORDER BY id');
  return rows.map(mapUser);
}

export async function createUser({ username, email, passwordHash, role }) {
  const result = await query(
    'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
    [username, email, passwordHash, role],
  );
  return findById(result.insertId);
}

// Actualiza campos permitidos: role, status, password_hash.
export async function updateUser(id, fields) {
  const allowed = { role: 'role', status: 'status', passwordHash: 'password_hash' };
  const assignments = [];
  const values = [];
  for (const [key, column] of Object.entries(allowed)) {
    if (fields[key] !== undefined) {
      assignments.push(`${column} = ?`);
      values.push(fields[key]);
    }
  }
  if (assignments.length === 0) return findById(id);
  values.push(id);
  await query(`UPDATE users SET ${assignments.join(', ')} WHERE id = ?`, values);
  return findById(id);
}

export async function updatePassword(id, passwordHash) {
  return updateUser(id, { passwordHash });
}

// Registra un intento fallido y, si corresponde, el bloqueo temporal.
export async function setLoginFailures(id, failedLoginAttempts, lockedUntil) {
  await query('UPDATE users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?', [
    failedLoginAttempts,
    lockedUntil,
    id,
  ]);
}

export async function clearLoginFailures(id) {
  await setLoginFailures(id, 0, null);
}
