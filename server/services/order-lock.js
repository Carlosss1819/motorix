// Candado por orden (Sprint 5, R-07). Toda operación que cambia el cobro o el
// contenido cobrable de UNA orden (registrar, confirmar, cancelar y anular un
// pago; agregar y quitar servicios y refacciones; cambiar el estado; generar
// un ticket) corre dentro de esta transacción, así que sobre la misma orden
// se ejecutan una tras otra. El candado es la primera lectura de la
// transacción, y después se bloquean las refacciones (nunca al revés).
// Las transacciones son cortas: nunca se llama a la red dentro (por eso la
// preferencia de Mercado Pago se crea antes de tomar el candado).
import { getConnection } from '../config/db.js';
import { lockServiceOrderForUpdate } from '../models/service_order.js';
import { notFound } from '../utils/errors.js';

// `fn(connection, locked)` recibe la conexión y `{ id, status }` de la orden.
// Si `fn` lanza un error, la transacción se revierte. Si `fn` devuelve
// `{ commitAndThrow: error }`, se hace commit y DESPUÉS se lanza el error
// (D-04: el pago desfasado queda cancelado y se responde 409).
export async function withOrderLock(orderId, fn) {
  const connection = await getConnection();
  let result;
  try {
    await connection.beginTransaction();
    const locked = await lockServiceOrderForUpdate(connection, orderId);
    if (!locked) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');
    result = await fn(connection, locked);
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
  if (result && result.commitAndThrow) throw result.commitAndThrow;
  return result;
}
