// Apoyo para las pruebas de reportes (Sprint 7, Entrega B).
//
// Los reportes suman todo lo que cae en un rango, y motorix_v2_test acumula
// datos de otras suites y corridas (H-B02). Para comparar cifras exactas,
// cada suite usa una VENTANA LIBRE en el pasado: toma la fecha más antigua
// registrada en pagos, historial de estados y movimientos, y se coloca
// `desplazamiento` días antes. Cada suite usa un desplazamiento distinto, así
// que dos suites que calculen la base al mismo tiempo no se pisan; una suite
// que la calcule después de otra queda todavía más atrás. Antes de insertar
// se comprueba que la ventana esté vacía.
import { sql } from './fixtures.js';

const pad = (n) => String(n).padStart(2, '0');

function isoDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function addDays(iso, days) {
  const [y, m, d] = iso.split('-').map(Number);
  return isoDate(new Date(y, m - 1, d + days));
}

async function oldestDate() {
  const [row] = await sql(
    `SELECT DATE_FORMAT(LEAST(
        COALESCE((SELECT MIN(created_at) FROM payments), NOW()),
        COALESCE((SELECT MIN(changed_at) FROM order_status_history), NOW()),
        COALESCE((SELECT MIN(created_at) FROM inventory_movements), NOW())
      ), '%Y-%m-%d') AS fecha`,
  );
  return row.fecha;
}

async function windowIsEmpty(desde, hasta) {
  const [row] = await sql(
    `SELECT
       (SELECT COUNT(*) FROM payments WHERE created_at >= ? AND created_at < DATE_ADD(?, INTERVAL 1 DAY)) +
       (SELECT COUNT(*) FROM order_status_history WHERE changed_at >= ? AND changed_at < DATE_ADD(?, INTERVAL 1 DAY)) +
       (SELECT COUNT(*) FROM inventory_movements WHERE created_at >= ? AND created_at < DATE_ADD(?, INTERVAL 1 DAY)) AS total`,
    [desde, hasta, desde, hasta, desde, hasta],
  );
  return Number(row.total) === 0;
}

// Devuelve `{ desde, hasta }` con `dias` días, libre de datos.
export async function ventanaLibre(desplazamiento, dias) {
  const base = await oldestDate();
  const hasta = addDays(base, -desplazamiento);
  const desde = addDays(hasta, -(dias - 1));
  if (!(await windowIsEmpty(desde, hasta))) {
    throw new Error(`La ventana ${desde}..${hasta} de los reportes ya tiene datos: vuelve a correr la prueba`);
  }
  return { desde, hasta };
}

export async function marcarTerminada(ordenId, fechaHora, changedBy = 1) {
  await sql(
    `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, changed_at, note)
     VALUES (?, 'EN_REPARACION', 'TERMINADO', ?, ?, 'Prueba de reportes')`,
    [ordenId, changedBy, fechaHora],
  );
  // ENTREGADO: la orden sale de las listas activas (avisos, panel) de las
  // demás suites.
  await sql("UPDATE service_orders SET status = 'ENTREGADO' WHERE id = ?", [ordenId]);
}

export async function insertarPago(ordenId, { monto, metodo = 'EFECTIVO', estado = 'PAGADO', fechaHora }) {
  const result = await sql(
    `INSERT INTO payments (service_order_id, amount, method, status, created_by, created_at)
     VALUES (?, ?, ?, ?, 1, ?)`,
    [ordenId, monto, metodo, estado, fechaHora],
  );
  return result.insertId;
}

export async function insertarSalida(partId, cantidad, fechaHora) {
  await sql(
    `INSERT INTO inventory_movements (part_id, movement_type, quantity, reason, stock_after, created_by, created_at)
     VALUES (?, 'SALIDA', ?, 'Prueba de reportes', 0, 1, ?)`,
    [partId, cantidad, fechaHora],
  );
}
