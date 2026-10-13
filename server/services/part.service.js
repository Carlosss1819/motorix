// Logica de negocio del catalogo de refacciones (US5, Sprint 3).
// Reglas aplicadas aqui: codigo unico en todo el catalogo (FR-017 -> 409
// CODIGO_DUPLICADO), stock inicial que deja su ENTRADA constancia (SC-007),
// edicion que no toca codigo ni stock_actual (FR-022), desactivacion
// idempotente sin borrado (FR-019) y stock nunca negativo (RN-8, R-08).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import {
  listParts,
  findById,
  findByCode,
  createPart,
  updatePart,
  deactivatePart,
  lockStockForUpdate,
  setStock,
} from '../models/parts.js';
import {
  insertMovement,
  listByPart,
  findById as findMovementById,
} from '../models/inventory_movement.js';
import { getConnection } from '../config/db.js';
import { badRequest, conflict, notFound } from '../utils/errors.js';

const MOTIVO_STOCK_INICIAL = 'Stock inicial';

// stock_actual <= stock_minimo y stock_minimo > 0 (FR-020, FR-021, R-10):
// un stock_minimo de 0 nunca genera alerta.
function isLowStock(part) {
  return part.stockMin > 0 && part.stockCurrent <= part.stockMin;
}

// Mapeo al formato del contrato (claves en español) con stockBajo calculado.
function toApi(part) {
  return {
    id: part.id,
    codigo: part.code,
    nombre: part.name,
    categoria: part.category,
    marca: part.brand ?? null,
    stockActual: part.stockCurrent,
    stockMinimo: part.stockMin,
    stockBajo: isLowStock(part),
    precioCompra: part.purchasePrice,
    precioVenta: part.salePrice,
    activa: part.isActive,
  };
}

function normalizarPaginacion(filters) {
  const rawPage = Number(filters.pagina);
  const page = Number.isInteger(rawPage) && rawPage > 0 ? rawPage : 1;
  const rawPerPage = Number(filters.porPagina);
  const perPage =
    Number.isInteger(rawPerPage) && rawPerPage > 0 ? Math.min(rawPerPage, 50) : 10;
  return { page, perPage };
}

export async function list(filters) {
  const { page, perPage } = normalizarPaginacion(filters);
  const { rows, total } = await listParts({
    search: filters.buscar,
    // `?stockBajo=true` (US8, R-10): solo refacciones con stock_actual
    // <= stock_minimo y stock_minimo > 0.
    lowStock: filters.stockBajo === 'true',
    active: filters.activa === undefined ? undefined : filters.activa === 'true',
    page,
    perPage,
  });
  const paginas = Math.max(1, Math.ceil(total / perPage));
  return {
    elementos: rows.map(toApi),
    pagina: page,
    paginas,
    total,
  };
}

export async function getById(id) {
  const part = await findById(id);
  if (!part) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }
  return toApi(part);
}

// mysql2 devuelve DATETIME como objeto Date; el contrato history/parts pide
// `YYYY-MM-DD HH:mm:ss` (mismo criterio que formatDate de los otros modelos).
function formatDateTime(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

// Mapeo al formato del contrato (seccion GET /api/parts/:id/movements).
function toMovementApi(movement) {
  return {
    id: movement.id,
    tipo: movement.movementType,
    cantidad: movement.quantity,
    motivo: movement.reason,
    ordenId: movement.serviceOrderId,
    stockAfter: movement.stockAfter,
    registradoPor: movement.createdByUsername ?? null,
    fecha: formatDateTime(movement.createdAt),
  };
}

// Historial auditable de una refacción (FR-030): orden descendente, filtro
// por tipo y paginación R-10. 404 si la refacción no existe.
export async function listMovements(partId, filters = {}) {
  const part = await findById(partId);
  if (!part) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }

  const { page, perPage } = normalizarPaginacion(filters);
  const { rows, total } = await listByPart({
    partId,
    type: filters.tipo,
    page,
    perPage,
  });

  return {
    elementos: rows.map(toMovementApi),
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}

// Registro manual de ENTRADA (reabastecimiento) y AJUSTE (corrección) solo
// por ADMIN (FR-029): la SALIDA la genera el uso en órdenes, nunca aquí.
// Todo en transacción con bloqueo de fila para que el stock nunca quede
// negativo (RN-8, R-08) y movimiento y stock sean el mismo commit.
export async function registerMovement(partId, data, user) {
  const part = await findById(partId);
  if (!part) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }

  const motivo = data.motivo ? data.motivo.trim() : '';
  if (data.tipo === 'AJUSTE' && !motivo) {
    throw badRequest(
      'El ajuste de inventario debe indicar el motivo del cambio',
      'AJUSTE_SIN_MOTIVO',
    );
  }

  const connection = await getConnection();
  try {
    await connection.beginTransaction();
    const stockActual = await lockStockForUpdate(connection, partId);
    if (stockActual === null) {
      await connection.rollback();
      throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
    }

    // ENTRADA y AJUSTE siempre aumentan el stock (contrato, seccion movements).
    const stockAfter = stockActual + data.cantidad;
    await setStock(connection, partId, stockAfter);
    const movementId = await insertMovement(connection, {
      partId,
      movementType: data.tipo,
      quantity: data.cantidad,
      reason: motivo || null,
      stockAfter,
      createdBy: user.id,
    });
    await connection.commit();

    const movement = await findMovementById(movementId);
    return toMovementApi(movement);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// El stock inicial se crea junto a su movimiento ENTRADA en UNA transaccion
// (SC-007): o queda constancia completa del alta, o no se crea nada.
export async function create(data, user) {
  const duplicada = await findByCode(data.codigo);
  if (duplicada) {
    throw conflict(
      'Ya existe una refacción con este código: usa uno distinto',
      'CODIGO_DUPLICADO',
    );
  }

  const stockInicial = data.stockInicial ?? 0;
  const connection = await getConnection();
  try {
    await connection.beginTransaction();
    const created = await createPart(
      {
        code: data.codigo,
        name: data.nombre,
        category: data.categoria,
        brand: data.marca,
        stockCurrent: stockInicial,
        stockMin: data.stockMinimo ?? 0,
        purchasePrice: data.precioCompra,
        salePrice: data.precioVenta,
      },
      connection,
    );

    if (stockInicial > 0) {
      await insertMovement(connection, {
        partId: created.id,
        movementType: 'ENTRADA',
        quantity: stockInicial,
        reason: MOTIVO_STOCK_INICIAL,
        stockAfter: stockInicial,
        createdBy: user.id,
      });
    }

    await connection.commit();
    const part = await findById(created.id);
    return toApi(part);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// Edicion parcial del catalogo: el codigo es identificador y el stock_actual
// solo cambia por movimientos, aqui no se tocan (FR-022).
export async function update(id, data) {
  const current = await findById(id);
  if (!current) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }

  const updated = await updatePart(id, {
    name: data.nombre ?? current.name,
    category: data.categoria ?? current.category,
    brand: data.marca !== undefined ? data.marca : current.brand,
    stockMin: data.stockMinimo ?? current.stockMin,
    purchasePrice:
      data.precioCompra !== undefined ? data.precioCompra : current.purchasePrice,
    salePrice: data.precioVenta !== undefined ? data.precioVenta : current.salePrice,
  });
  return toApi(updated);
}

// Baja sin borrado (FR-019): su historial de uso y sus movimientos se
// conservan. Repetir la desactivacion responde igual (idempotente).
export async function deactivate(id) {
  const current = await findById(id);
  if (!current) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }
  await deactivatePart(id);
  return { mensaje: 'Refacción desactivada.' };
}
