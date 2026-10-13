// Acceso a datos del catálogo de refacciones (tabla parts, Sprint 3).
// Término canónico: «refacción» (clarificación 3). El bloqueo de fila
// (SELECT ... FOR UPDATE) es la base de la garantía de stock nunca negativo
// (RN-8, R-08): toda operación que modifica stock valida dentro de la
// transacción que lo invoca.
import { query } from '../config/db.js';

function mapPart(row) {
  if (!row) return null;
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    category: row.category,
    brand: row.brand ?? null,
    stockCurrent: row.stock_current,
    stockMin: row.stock_min,
    purchasePrice: row.purchase_price === null ? null : Number(row.purchase_price),
    salePrice: row.sale_price === null ? null : Number(row.sale_price),
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function escapeLike(term) {
  return term.replace(/[\\%_]/g, (char) => `\\${char}`);
}

// Listado con filtros de FR-018/FR-021: buscar (nombre o código), stock bajo
// (stock_actual <= stock_minimo && stock_minimo > 0, R-10) y estado activo.
export async function listParts({ search, lowStock, active, page, perPage } = {}) {
  const conditions = [];
  const values = [];

  if (search) {
    const pattern = `%${escapeLike(search)}%`;
    conditions.push('(p.name LIKE ? OR p.code LIKE ?)');
    values.push(pattern, pattern);
  }
  if (lowStock) {
    conditions.push('p.stock_current <= p.stock_min AND p.stock_min > 0');
  }
  if (active !== undefined) {
    conditions.push('p.is_active = ?');
    values.push(active ? 1 : 0);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const [countRow] = await query(
    `SELECT COUNT(*) AS total FROM parts p ${where}`,
    values,
  );
  const total = countRow.total;

  const limitValues = [...values];
  let limitClause = '';
  if (page && perPage) {
    limitClause = ' LIMIT ? OFFSET ?';
    limitValues.push(perPage, (page - 1) * perPage);
  }

  const rows = await query(
    `SELECT p.* FROM parts p ${where} ORDER BY p.name, p.code${limitClause}`,
    limitValues,
  );
  return { rows: rows.map(mapPart), total };
}

export async function findById(id) {
  const rows = await query('SELECT * FROM parts WHERE id = ? LIMIT 1', [id]);
  return mapPart(rows[0]);
}

export async function findByCode(code) {
  const rows = await query('SELECT * FROM parts WHERE code = ? LIMIT 1', [code]);
  return mapPart(rows[0]);
}

// Devuelve el id insertado. Si se pasa `connection`, el INSERT corre dentro de
// la transacción del llamador (R-08) y la lectura del registro recién creado
// debe esperar al commit, por eso solo se retorna el id.
export async function createPart(
  { code, name, category, brand, stockCurrent, stockMin, purchasePrice, salePrice },
  connection,
) {
  const sql = `INSERT INTO parts (code, name, category, brand, stock_current, stock_min, purchase_price, sale_price)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`;
  const values = [code, name, category, brand ?? null, stockCurrent, stockMin, purchasePrice ?? null, salePrice ?? null];

  if (connection) {
    const [result] = await connection.execute(sql, values);
    return { id: result.insertId };
  }
  const result = await query(sql, values);
  return findById(result.insertId);
}

// Edición de catálogo (FR-022): el código es identificador y el stock solo
// cambia por movimientos, así que aquí no se tocan.
export async function updatePart(id, { name, category, brand, stockMin, purchasePrice, salePrice }) {
  await query(
    `UPDATE parts SET name = ?, category = ?, brand = ?, stock_min = ?, purchase_price = ?, sale_price = ?
     WHERE id = ?`,
    [name, category, brand ?? null, stockMin, purchasePrice ?? null, salePrice ?? null, id],
  );
  return findById(id);
}

export async function deactivatePart(id) {
  await query('UPDATE parts SET is_active = 0 WHERE id = ?', [id]);
  return findById(id);
}

// Cambio directo de stock SOLO desde una transacción que ya bloqueó la fila.
export async function setStock(connection, id, stockCurrent) {
  await connection.execute('UPDATE parts SET stock_current = ? WHERE id = ?', [stockCurrent, id]);
}

// RN-8 / R-08: bloquea la fila de la refacción dentro de la transacción y
// devuelve el stock vigente; el llamador valida que reste antes de descontar.
export async function lockStockForUpdate(connection, id) {
  const [rows] = await connection.execute(
    'SELECT stock_current FROM parts WHERE id = ? FOR UPDATE',
    [id],
  );
  return rows[0] ? rows[0].stock_current : null;
}
