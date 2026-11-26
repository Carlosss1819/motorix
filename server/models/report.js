// Consultas de agregación de los reportes (Sprint 7, Entrega B, R-08).
// Solo lectura y siempre con parámetros (FR-029). Los importes salen como
// cadena DECIMAL de MySQL (suma exacta) y el servicio los pasa a centavos
// enteros con utils/money.js (FR-032).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/reports.md.
//
// Periodo de cada reporte (aclaración de la spec):
//   * ingresos: fecha de registro (`created_at`) de los pagos en `PAGADO`;
//   * servicios, productividad y margen: órdenes con un paso a `TERMINADO`
//     en `order_status_history` dentro del rango;
//   * rotación: movimientos `SALIDA` del rango.
// El rango es [desde 00:00:00, hasta + 1 día) en hora local del servidor.
import { query } from '../config/db.js';

// Órdenes que pasaron a TERMINADO en el rango (una fila por orden).
const CTE_TERMINADAS = `t AS (
  SELECT DISTINCT h.service_order_id AS id
  FROM order_status_history h
  WHERE h.to_status = 'TERMINADO'
    AND h.changed_at >= CONCAT(?, ' 00:00:00')
    AND h.changed_at < DATE_ADD(?, INTERVAL 1 DAY)
)`;

export async function incomeByMethod({ desde, hasta }) {
  return query(
    `SELECT p.method AS metodo, COUNT(*) AS pagos, SUM(p.amount) AS total
     FROM payments p
     WHERE p.status = 'PAGADO'
       AND p.created_at >= CONCAT(?, ' 00:00:00')
       AND p.created_at < DATE_ADD(?, INTERVAL 1 DAY)
     GROUP BY p.method
     ORDER BY p.method`,
    [desde, hasta],
  );
}

export async function incomeByDay({ desde, hasta }) {
  return query(
    `SELECT DATE_FORMAT(p.created_at, '%Y-%m-%d') AS fecha, COUNT(*) AS pagos, SUM(p.amount) AS total
     FROM payments p
     WHERE p.status = 'PAGADO'
       AND p.created_at >= CONCAT(?, ' 00:00:00')
       AND p.created_at < DATE_ADD(?, INTERVAL 1 DAY)
     GROUP BY fecha
     ORDER BY fecha`,
    [desde, hasta],
  );
}

// Servicios de las órdenes terminadas: por tipo de servicio y, si la línea no
// tiene tipo, por descripción. `limit` lo fija el servicio (máximo 50).
export async function frequentServices({ desde, hasta }, limit) {
  return query(
    `WITH ${CTE_TERMINADAS},
     l AS (
       SELECT ol.service_id, SUM(ol.price) AS mano
       FROM order_labor ol
       JOIN t ON t.id = ol.service_order_id
       GROUP BY ol.service_id
     )
     SELECT s.service_type_id AS tipo_id,
            st.name AS tipo,
            CASE WHEN s.service_type_id IS NULL THEN s.description END AS descripcion,
            COUNT(*) AS veces,
            COALESCE(SUM(l.mano), 0) AS mano_total
     FROM order_services s
     JOIN t ON t.id = s.service_order_id
     LEFT JOIN service_types st ON st.id = s.service_type_id
     LEFT JOIN l ON l.service_id = s.id
     GROUP BY tipo_id, tipo, descripcion
     ORDER BY veces DESC, mano_total DESC, COALESCE(tipo, descripcion)
     LIMIT ${Number(limit)}`,
    [desde, hasta],
  );
}

// Órdenes terminadas y mano de obra por mecánico asignado.
export async function productivity({ desde, hasta }, limit) {
  return query(
    `WITH ${CTE_TERMINADAS},
     l AS (
       SELECT ol.service_order_id, SUM(ol.price) AS mano
       FROM order_labor ol
       JOIN t ON t.id = ol.service_order_id
       GROUP BY ol.service_order_id
     )
     SELECT o.mechanic_id AS mecanico_id, u.username AS mecanico,
            COUNT(*) AS ordenes, COALESCE(SUM(l.mano), 0) AS mano_total
     FROM t
     JOIN service_orders o ON o.id = t.id
     LEFT JOIN users u ON u.id = o.mechanic_id
     LEFT JOIN l ON l.service_order_id = o.id
     GROUP BY o.mechanic_id, u.username
     ORDER BY ordenes DESC, mano_total DESC, u.username
     LIMIT ${Number(limit)}`,
    [desde, hasta],
  );
}

// Refacciones del catálogo usadas en las órdenes terminadas: cantidad, venta
// (precio congelado de cada línea × cantidad) y precio de compra vigente.
// Las líneas heredadas sin `part_id` (Sprint 2) no tienen refacción del
// catálogo y no entran. Sin límite: el servicio calcula los totales con
// todas las filas y luego recorta la lista.
export async function partsMargin({ desde, hasta }) {
  return query(
    `WITH ${CTE_TERMINADAS}
     SELECT p.id, p.code, p.name, p.purchase_price,
            SUM(op.quantity) AS cantidad,
            SUM(op.quantity * COALESCE(op.unit_price, 0)) AS venta
     FROM order_parts op
     JOIN t ON t.id = op.service_order_id
     JOIN parts p ON p.id = op.part_id
     GROUP BY p.id, p.code, p.name, p.purchase_price
     ORDER BY venta DESC, p.name`,
    [desde, hasta],
  );
}

// Unidades que salieron por refacción en el rango y existencia actual.
export async function partsRotation({ desde, hasta }, limit) {
  return query(
    `SELECT p.id, p.code, p.name, p.stock_current, SUM(im.quantity) AS salidas
     FROM inventory_movements im
     JOIN parts p ON p.id = im.part_id
     WHERE im.movement_type = 'SALIDA'
       AND im.created_at >= CONCAT(?, ' 00:00:00')
       AND im.created_at < DATE_ADD(?, INTERVAL 1 DAY)
     GROUP BY p.id, p.code, p.name, p.stock_current
     ORDER BY salidas DESC, p.name
     LIMIT ${Number(limit)}`,
    [desde, hasta],
  );
}
