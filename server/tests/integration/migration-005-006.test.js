// Prueba de integración de las migraciones 005 (esquema) y 006 (datos) del
// Sprint 5: precio congelado de las líneas (SC-011), copia de los tickets en
// versión 1 (SC-012) y nota cuando el desglose no coincide con lo cobrado
// (FR-020).
//
// Aislamiento (para no repetir los timeouts de H-B01): la prueba NO ejecuta
// el 006 completo sobre la base compartida mientras corren otras suites.
// Ejecuta el texto del 006 con sus dos WHERE acotados a las filas que crea la
// propia prueba (por sus ids). El acotamiento se hace sobre el texto real del
// archivo, así que una edición del 006 que cambie esos WHERE hace fallar la
// prueba en lugar de dejarla probando otra cosa.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

const MIGRACION_006 = path.resolve(
  import.meta.dirname,
  '..',
  '..',
  '..',
  'database',
  'migrations',
  '006_datos_precio_congelado_copia_tickets.sql',
);

const ANCLA_LINEAS = 'WHERE op.unit_price IS NULL';
const ANCLA_TICKETS = 'WHERE t.content IS NULL';

let db;
let suffix;
const ids = {};

async function q(sql, params = []) {
  const [rows] = await db.query(sql, params);
  return rows;
}

// Texto del 006 con sus WHERE acotados a las filas de esta prueba.
function migracionAcotada() {
  const texto = readFileSync(MIGRACION_006, 'utf8');
  expect(texto).toContain(ANCLA_LINEAS);
  expect(texto).toContain(ANCLA_TICKETS);
  const lineas = [ids.lineaConPrecio, ids.lineaSinPrecio, ids.lineaSinParte].join(', ');
  const tickets = [ids.ticketCuadra, ids.ticketDescuadrado].join(', ');
  return texto
    .replace(ANCLA_LINEAS, `${ANCLA_LINEAS} AND op.id IN (${lineas})`)
    .replace(ANCLA_TICKETS, `${ANCLA_TICKETS} AND t.id IN (${tickets})`);
}

async function crearOrden(clienteId, vehiculoId, km) {
  const r = await q(
    `INSERT INTO service_orders
       (client_id, vehicle_id, status, visit_reason, entry_date, entry_mileage, created_by)
     VALUES (?, ?, 'TERMINADO', ?, CURDATE(), ?, 1)`,
    [clienteId, vehiculoId, `Migración 006 ${suffix}`, km],
  );
  return r.insertId;
}

async function crearManoDeObra(ordenId, precio) {
  const servicio = await q(
    'INSERT INTO order_services (service_order_id, description) VALUES (?, ?)',
    [ordenId, 'Servicio migración'],
  );
  await q(
    `INSERT INTO order_labor (service_order_id, service_id, description, duration_minutes, price)
     VALUES (?, ?, 'Mano de obra migración', 30, ?)`,
    [ordenId, servicio.insertId, precio],
  );
}

async function crearPagoYTicket(ordenId, monto, folio) {
  const pago = await q(
    `INSERT INTO payments (service_order_id, amount, method, status, created_by)
     VALUES (?, ?, 'EFECTIVO', 'PAGADO', 2)`,
    [ordenId, monto],
  );
  const ticket = await q(
    `INSERT INTO tickets (service_order_id, payment_id, folio, issued_by)
     VALUES (?, ?, ?, 2)`,
    [ordenId, pago.insertId, folio],
  );
  return ticket.insertId;
}

async function contenido(ticketId) {
  const [fila] = await q('SELECT content, format_version FROM tickets WHERE id = ?', [ticketId]);
  const copia = typeof fila.content === 'string' ? JSON.parse(fila.content) : fila.content;
  return { copia, version: fila.format_version };
}

beforeAll(async () => {
  await prepareTestDatabase();
  db = await mysql.createConnection({ ...config.db, multipleStatements: true });
  suffix = uniqueSuffix();
  const corto = suffix.slice(-8);

  const cliente = await q('INSERT INTO clients (name, phone) VALUES (?, ?)', [
    `Cliente migración ${suffix}`,
    `91${corto}`,
  ]);
  const vehiculo = await q(
    `INSERT INTO vehicles (client_id, brand, model, year, plates, current_mileage)
     VALUES (?, 'Nissan', 'March', 2018, ?, 1000)`,
    [cliente.insertId, `MG${corto}`],
  );

  const conPrecio = await q(
    `INSERT INTO parts (code, name, category, stock_current, stock_min, sale_price)
     VALUES (?, ?, 'Pruebas', 10, 0, 320.00)`,
    [`MGP-${suffix}`.slice(0, 30), `Refacción con precio ${suffix}`],
  );
  const sinPrecio = await q(
    `INSERT INTO parts (code, name, category, stock_current, stock_min, sale_price)
     VALUES (?, ?, 'Pruebas', 10, 0, NULL)`,
    [`MGS-${suffix}`.slice(0, 30), `Refacción sin precio ${suffix}`],
  );
  ids.partConPrecio = conPrecio.insertId;

  // Orden 1: mano de obra 750 + 2 × 320 (precio vigente) + línea sin precio +
  // línea heredada sin part_id. Desglose = 1390.00 = lo cobrado.
  const orden1 = await crearOrden(cliente.insertId, vehiculo.insertId, 1000);
  await crearManoDeObra(orden1, 750);
  const l1 = await q(
    `INSERT INTO order_parts (service_order_id, description, quantity, part_id)
     VALUES (?, 'Pastillas', 2, ?)`,
    [orden1, conPrecio.insertId],
  );
  const l2 = await q(
    `INSERT INTO order_parts (service_order_id, description, quantity, part_id)
     VALUES (?, 'Sin precio', 1, ?)`,
    [orden1, sinPrecio.insertId],
  );
  const l3 = await q(
    `INSERT INTO order_parts (service_order_id, description, quantity, part_id)
     VALUES (?, 'Heredada sin catálogo', 1, NULL)`,
    [orden1],
  );
  ids.lineaConPrecio = l1.insertId;
  ids.lineaSinPrecio = l2.insertId;
  ids.lineaSinParte = l3.insertId;
  ids.ticketCuadra = await crearPagoYTicket(orden1, 1390.0, `M${corto}A`);

  // Orden 2: mano de obra 1090, pero el pago fue de 1390 (como la orden 5 de
  // motorix_v2): el desglose no coincide con lo cobrado (FR-020).
  const orden2 = await crearOrden(cliente.insertId, vehiculo.insertId, 1100);
  await crearManoDeObra(orden2, 1090);
  ids.ticketDescuadrado = await crearPagoYTicket(orden2, 1390.0, `M${corto}B`);

  await q(migracionAcotada());
});

afterAll(async () => {
  await db.end();
});

describe('esquema de la migración 005', () => {
  test('existen_las_columnas_nuevas', async () => {
    const columnas = await q(
      `SELECT TABLE_NAME AS tabla, COLUMN_NAME AS columna
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE()
         AND ((TABLE_NAME = 'order_parts' AND COLUMN_NAME = 'unit_price')
           OR (TABLE_NAME = 'tickets' AND COLUMN_NAME IN ('content', 'format_version'))
           OR (TABLE_NAME = 'payments' AND COLUMN_NAME = 'cancellation_reason'))`,
    );
    expect(columnas).toHaveLength(4);
  });

  test('la_unicidad_es_por_pago_y_no_por_orden', async () => {
    const indices = await q(
      `SELECT DISTINCT INDEX_NAME AS nombre, NON_UNIQUE AS noUnico
       FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tickets'`,
    );
    const nombres = indices.map((i) => i.nombre);
    expect(nombres).toContain('uq_tickets_payment');
    expect(nombres).toContain('idx_tickets_service_order');
    expect(nombres).not.toContain('uq_tickets_service_order');
    expect(indices.find((i) => i.nombre === 'uq_tickets_payment').noUnico).toBe(0);
  });
});

describe('datos de la migración 006', () => {
  test('SC_011_la_linea_con_refaccion_toma_el_precio_vigente_y_las_demas_quedan_en_null', async () => {
    const filas = await q('SELECT id, unit_price FROM order_parts WHERE id IN (?, ?, ?)', [
      ids.lineaConPrecio,
      ids.lineaSinPrecio,
      ids.lineaSinParte,
    ]);
    const porId = Object.fromEntries(filas.map((f) => [f.id, f.unit_price]));
    expect(porId[ids.lineaConPrecio]).toBe('320.00');
    expect(porId[ids.lineaSinPrecio]).toBeNull();
    expect(porId[ids.lineaSinParte]).toBeNull();
  });

  test('SC_012_la_copia_tiene_version_1_y_total_igual_al_importe_pagado', async () => {
    const { copia, version } = await contenido(ids.ticketCuadra);
    expect(version).toBe(1);
    expect(copia.formatoVersion).toBe(1);
    expect(Number(copia.total)).toBe(1390);
    expect(Number(copia.subtotalManoDeObra)).toBe(750);
    expect(Number(copia.subtotalRefacciones)).toBe(640);
    expect(copia.desgloseNoCoincide).toBe(false);
    expect(copia.nota).toBeNull();
    expect(copia.metodoPago).toBe('EFECTIVO');

    const refacciones = copia.servicios.flatMap((s) => s.refacciones);
    expect(refacciones).toHaveLength(3);
    const pastillas = refacciones.find((r) => r.cantidad === 2);
    expect(Number(pastillas.precioUnitario)).toBe(320);
    expect(Number(pastillas.subtotal)).toBe(640);
    expect(pastillas.aviso).toBeNull();
    const sinPrecio = refacciones.filter((r) => r.aviso === 'sin precio registrado');
    expect(sinPrecio).toHaveLength(2);
    expect(copia.servicios[0].avisoManoDeObra).toBeNull();
  });

  test('FR_020_un_pago_que_no_coincide_con_el_desglose_lleva_la_nota', async () => {
    const { copia, version } = await contenido(ids.ticketDescuadrado);
    expect(version).toBe(1);
    expect(Number(copia.total)).toBe(1390);
    expect(Number(copia.subtotalManoDeObra)).toBe(1090);
    expect(copia.desgloseNoCoincide).toBe(true);
    expect(copia.nota).toBe('El desglose no coincide con lo cobrado');
  });

  test('volver_a_ejecutar_el_006_no_cambia_nada', async () => {
    const antes = await q(
      'SELECT id, content FROM tickets WHERE id IN (?, ?) ORDER BY id',
      [ids.ticketCuadra, ids.ticketDescuadrado],
    );
    // Aunque cambie el precio del catálogo, el 006 solo actúa donde las
    // columnas nuevas siguen en NULL.
    await q('UPDATE parts SET sale_price = 999.00 WHERE id = ?', [ids.partConPrecio]);
    await q(migracionAcotada());

    const [linea] = await q('SELECT unit_price FROM order_parts WHERE id = ?', [ids.lineaConPrecio]);
    expect(linea.unit_price).toBe('320.00');
    const despues = await q(
      'SELECT id, content FROM tickets WHERE id IN (?, ?) ORDER BY id',
      [ids.ticketCuadra, ids.ticketDescuadrado],
    );
    expect(despues).toEqual(antes);
  });
});
