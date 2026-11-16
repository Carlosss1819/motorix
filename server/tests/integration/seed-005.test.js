// Prueba de integración de los datos de ejemplo del Sprint 5 (FR-029, R-05):
// el seed 005 es idempotente, trae la refacción con venta menor que compra,
// la orden cobrada con refacciones congeladas y su ticket versión 2, la orden
// con un pago anulado, un pago nuevo y dos tickets, y una orden cobrable sin
// pago. Sus tickets conservan la copia aunque cambie el catálogo (SC-002).
import { readFileSync } from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';
import { config } from '../../config/env.js';

const SEED_005 = path.resolve(
  import.meta.dirname,
  '..',
  '..',
  '..',
  'database',
  'seeds',
  '005_ejemplos_precios_congelados.sql',
);

// Filas del seed 005, contadas por sus claves propias y no por un rango de
// ids: después de sembrar el 9001, el AUTO_INCREMENT de MySQL salta y las
// filas que crean otras suites también reciben ids desde 9004.
const CONSULTAS = {
  parts: "SELECT COUNT(*) AS n FROM parts WHERE code LIKE 'DEM-%'",
  service_orders: 'SELECT COUNT(*) AS n FROM service_orders WHERE id IN (9001, 9002, 9003)',
  order_services:
    'SELECT COUNT(*) AS n FROM order_services WHERE service_order_id IN (9001, 9002, 9003)',
  order_labor: 'SELECT COUNT(*) AS n FROM order_labor WHERE service_order_id IN (9001, 9002, 9003)',
  order_parts: 'SELECT COUNT(*) AS n FROM order_parts WHERE service_order_id IN (9001, 9002, 9003)',
  payments: 'SELECT COUNT(*) AS n FROM payments WHERE service_order_id IN (9001, 9002, 9003)',
  tickets: "SELECT COUNT(*) AS n FROM tickets WHERE folio LIKE 'D00900_-2026'",
  order_status_history:
    'SELECT COUNT(*) AS n FROM order_status_history WHERE service_order_id IN (9001, 9002, 9003)',
};

const ESPERADAS = {
  parts: 3,
  service_orders: 3,
  order_services: 3,
  order_labor: 3,
  order_parts: 4,
  payments: 3,
  tickets: 3,
  order_status_history: 6,
};

let ctx;

async function cargarSeed() {
  const db = await mysql.createConnection({ ...config.db, multipleStatements: true });
  try {
    await db.query(readFileSync(SEED_005, 'utf8'));
  } finally {
    await db.end();
  }
}

async function conteos() {
  const resultado = {};
  for (const [tabla, consulta] of Object.entries(CONSULTAS)) {
    const [fila] = await sql(consulta);
    resultado[tabla] = Number(fila.n);
  }
  return resultado;
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Seed 005');
});

test('cargar_dos_veces_el_seed_005_no_duplica_registros', async () => {
  await cargarSeed();
  const primera = await conteos();
  await cargarSeed();
  const segunda = await conteos();
  expect(primera).toEqual(ESPERADAS);
  expect(segunda).toEqual(ESPERADAS);
});

test('existe_la_refaccion_con_venta_menor_que_compra_D_07', async () => {
  const [parte] = await sql('SELECT purchase_price, sale_price FROM parts WHERE id = 9001');
  expect(Number(parte.sale_price)).toBeLessThan(Number(parte.purchase_price));
});

test('la_orden_9001_esta_cobrada_con_refacciones_congeladas_y_ticket_version_2', async () => {
  const [orden] = await sql('SELECT status FROM service_orders WHERE id = 9001');
  expect(orden.status).toBe('TERMINADO');
  const lineas = await sql('SELECT unit_price FROM order_parts WHERE service_order_id = 9001');
  expect(lineas.length).toBeGreaterThan(0);
  for (const linea of lineas) expect(linea.unit_price).not.toBeNull();

  const total = await ctx.total(9001);
  const [pago] = await sql(
    "SELECT amount FROM payments WHERE service_order_id = 9001 AND status = 'PAGADO'",
  );
  expect(Number(pago.amount)).toBe(total.total);

  const ticket = await api.get('/api/tickets/9001').set(bearer(ctx.tokens.recepcion));
  expect(ticket.status).toBe(200);
  expect(ticket.body.formatoVersion).toBe(2);
  expect(ticket.body.formatoAnterior).toBe(false);
  expect(ticket.body.vigente).toBe(true);
  expect(ticket.body.total).toBe(total.total);
  const refacciones = ticket.body.servicios.flatMap((s) => s.refacciones);
  expect(refacciones.reduce((suma, r) => suma + r.subtotal, 0)).toBe(
    ticket.body.subtotalRefacciones,
  );
});

test('la_orden_9002_tiene_un_pago_anulado_un_pago_nuevo_y_dos_tickets_FR_033', async () => {
  const pagos = await sql(
    'SELECT status FROM payments WHERE service_order_id = 9002 ORDER BY id',
  );
  expect(pagos.map((p) => p.status)).toEqual(['ANULADO', 'PAGADO']);

  const porOrden = await api.get('/api/tickets/orden/9002').set(bearer(ctx.tokens.recepcion));
  expect(porOrden.body.existe).toBe(true);
  expect(porOrden.body.tickets).toHaveLength(2);
  expect(porOrden.body.ticket.id).toBe(9003);
  const anulado = porOrden.body.tickets.find((t) => t.id === 9002);
  expect(anulado).toMatchObject({ pagoAnulado: true, vigente: false });
});

test('la_orden_9003_queda_lista_para_cobrar_con_precio_congelado', async () => {
  const [orden] = await sql('SELECT status FROM service_orders WHERE id = 9003');
  expect(orden.status).toBe('TERMINADO');
  const pagos = await sql('SELECT id FROM payments WHERE service_order_id = 9003');
  expect(pagos).toHaveLength(0);
  const total = await ctx.total(9003);
  expect(total.total).toBeGreaterThan(0);
});

test('SC_002_los_tickets_del_seed_005_conservan_su_copia_tras_cambiar_el_catalogo', async () => {
  const antes = await sql('SELECT id, content FROM tickets WHERE id BETWEEN 9001 AND 9003 ORDER BY id');
  const precios = await sql('SELECT id, sale_price FROM parts WHERE id BETWEEN 9001 AND 9003');
  await sql('UPDATE parts SET sale_price = sale_price + 100 WHERE id BETWEEN 9001 AND 9003');
  try {
    const despues = await sql(
      'SELECT id, content FROM tickets WHERE id BETWEEN 9001 AND 9003 ORDER BY id',
    );
    expect(despues).toEqual(antes);
    const leido = await api.get('/api/tickets/9001').set(bearer(ctx.tokens.recepcion));
    expect(leido.body.total).toBe(antes[0].content.total);
  } finally {
    for (const parte of precios) {
      await sql('UPDATE parts SET sale_price = ? WHERE id = ?', [parte.sale_price, parte.id]);
    }
  }
});
