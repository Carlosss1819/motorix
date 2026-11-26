// Rendimiento de los reportes (Sprint 7, Entrega B, SC-008, T072): con un
// año de datos de ejemplo (1,500 órdenes terminadas en 366 días, 3,000 líneas
// de servicio con mano de obra, 3,000 líneas de refacción, 1,500 pagos y
// 3,000 salidas de inventario), cada uno de los cinco reportes del año
// completo responde en menos de 3 s, en JSON y en CSV. El tiempo se mide solo
// alrededor de cada petición (la mediana de 3, después de una de
// calentamiento). Los datos llevan claves propias de esta suite, viven en
// una ventana libre del pasado y se borran al final.
import { performance } from 'node:perf_hooks';
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';
import { ventanaLibre } from '../helpers/report-fixtures.js';

const ORDENES = 1500;
const LIMITE_MS = 3000;

let ctx;
let rango;
let motivo;
let ordenIds = [];
let partIds = [];

function valoresEnLote(filas) {
  return filas.map((fila) => `(${fila.map(() => '?').join(', ')})`).join(', ');
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Reporte rendimiento');
  rango = await ventanaLibre(100, 366);
  motivo = `Rendimiento reportes ${ctx.suffix}`;

  // 10 refacciones (sin stock mínimo para no afectar el stock bajo).
  const refacciones = Array.from({ length: 10 }, (_, i) => [
    `RPF-${ctx.suffix}-${i}`.slice(0, 30),
    `Refacción rendimiento ${i}`,
    'Pruebas',
    100,
    0,
    i % 3 === 0 ? null : '45.50',
    '80.00',
  ]);
  await sql(
    `INSERT INTO parts (code, name, category, stock_current, stock_min, purchase_price, sale_price)
     VALUES ${valoresEnLote(refacciones)}`,
    refacciones.flat(),
  );
  partIds = (await sql('SELECT id FROM parts WHERE code LIKE ? ORDER BY id', [`RPF-${ctx.suffix}-%`])).map((r) => r.id);

  // Órdenes en lotes de 500.
  for (let inicio = 0; inicio < ORDENES; inicio += 500) {
    const filas = Array.from({ length: 500 }, (_, i) => [
      ctx.clienteId,
      ctx.vehiculoId,
      'ENTREGADO',
      motivo,
      rango.desde,
      1000 + inicio + i,
      (inicio + i) % 4 === 0 ? null : ctx.mecanicoId,
      1,
    ]);
    await sql(
      `INSERT INTO service_orders (client_id, vehicle_id, status, visit_reason, entry_date, entry_mileage, mechanic_id, created_by)
       VALUES ${valoresEnLote(filas)}`,
      filas.flat(),
    );
  }
  ordenIds = (await sql('SELECT id FROM service_orders WHERE visit_reason = ? ORDER BY id', [motivo])).map((r) => r.id);
  const lista = ordenIds.join(',');
  const fechaDe = `DATE_ADD(CONCAT(?, ' 10:00:00'), INTERVAL MOD(o.id, 366) DAY)`;

  await sql(
    `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, changed_at, note)
     SELECT o.id, 'EN_REPARACION', 'TERMINADO', 1, ${fechaDe}, 'Rendimiento'
     FROM service_orders o WHERE o.id IN (${lista})`,
    [rango.desde],
  );
  // Dos líneas de servicio por orden: una tipificada y una libre.
  await sql(
    `INSERT INTO order_services (service_order_id, description, service_type_id)
     SELECT o.id, 'Servicio tipificado', 70001 + MOD(o.id, 5) FROM service_orders o WHERE o.id IN (${lista})
     UNION ALL
     SELECT o.id, CONCAT('Servicio libre ', MOD(o.id, 40)), NULL FROM service_orders o WHERE o.id IN (${lista})`,
  );
  await sql(
    `INSERT INTO order_labor (service_order_id, service_id, description, duration_minutes, price)
     SELECT s.service_order_id, s.id, 'Mano de obra', 30, 150.25
     FROM order_services s WHERE s.service_order_id IN (${lista})`,
  );
  const partes = partIds.join(',');
  await sql(
    `INSERT INTO order_parts (service_order_id, part_id, description, quantity, unit_price)
     SELECT o.id, p.id, p.name, 1 + MOD(o.id, 3), p.sale_price
     FROM service_orders o
     JOIN parts p ON p.id IN (${partes}) AND MOD(p.id, 5) IN (MOD(o.id, 5), MOD(o.id + 1, 5))
     WHERE o.id IN (${lista})`,
  );
  await sql(
    `INSERT INTO payments (service_order_id, amount, method, status, created_by, created_at)
     SELECT o.id, 1234.56, ELT(1 + MOD(o.id, 4), 'EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO'),
            IF(MOD(o.id, 10) = 0, 'ANULADO', 'PAGADO'), 1, ${fechaDe}
     FROM service_orders o WHERE o.id IN (${lista})`,
    [rango.desde],
  );
  await sql(
    `INSERT INTO inventory_movements (part_id, movement_type, quantity, reason, stock_after, created_by, created_at)
     SELECT op.part_id, 'SALIDA', op.quantity, 'Rendimiento', 0, 1,
            DATE_ADD(CONCAT(?, ' 10:00:00'), INTERVAL MOD(op.service_order_id, 366) DAY)
     FROM order_parts op WHERE op.service_order_id IN (${lista})`,
    [rango.desde],
  );
}, 120000);

afterAll(async () => {
  if (ordenIds.length) {
    const lista = ordenIds.join(',');
    await sql(`DELETE FROM payments WHERE service_order_id IN (${lista})`);
    await sql(`DELETE FROM order_parts WHERE service_order_id IN (${lista})`);
    await sql(`DELETE FROM order_labor WHERE service_order_id IN (${lista})`);
    await sql(`DELETE FROM order_services WHERE service_order_id IN (${lista})`);
    await sql(`DELETE FROM order_status_history WHERE service_order_id IN (${lista})`);
    await sql(`DELETE FROM service_orders WHERE id IN (${lista})`);
  }
  if (partIds.length) {
    const partes = partIds.join(',');
    await sql(`DELETE FROM inventory_movements WHERE part_id IN (${partes})`);
    await sql(`DELETE FROM parts WHERE id IN (${partes})`);
  }
});

async function medir(ruta) {
  const pedir = () => api.get(ruta).set(bearer(ctx.tokens.admin));
  const calentamiento = await pedir();
  expect(calentamiento.status).toBe(200);
  const tiempos = [];
  for (let i = 0; i < 3; i += 1) {
    const t0 = performance.now();
    const r = await pedir();
    tiempos.push(performance.now() - t0);
    expect(r.status).toBe(200);
  }
  tiempos.sort((a, b) => a - b);
  return { ms: tiempos[1], body: calentamiento.body };
}

test('test_los_datos_de_ejemplo_cubren_un_anio', async () => {
  expect(ordenIds).toHaveLength(ORDENES);
  const { body } = await medir(`/api/reports/ingresos?desde=${rango.desde}&hasta=${rango.hasta}`);
  // 1 de cada 10 pagos está anulado y no suma.
  expect(body.pagos).toBe(ORDENES - ORDENES / 10);
  expect(body.total).toBe(Math.round((ORDENES - ORDENES / 10) * 123456) / 100);
  expect(body.porDia.length).toBeGreaterThan(300);
});

test.each(['ingresos', 'servicios', 'productividad', 'refacciones', 'rotacion'])(
  'test_el_reporte_de_%s_de_un_anio_responde_en_menos_de_3_s_en_json_y_csv',
  async (reporte) => {
    const base = `/api/reports/${reporte}?desde=${rango.desde}&hasta=${rango.hasta}`;
    const json = await medir(base);
    const csv = await medir(`${base}&formato=csv`);
    // Evidencia de SC-008 en la salida de Jest.
    console.info(`SC-008 ${reporte}: JSON ${json.ms.toFixed(0)} ms, CSV ${csv.ms.toFixed(0)} ms`);
    expect(json.ms).toBeLessThan(LIMITE_MS);
    expect(csv.ms).toBeLessThan(LIMITE_MS);
  },
  30000,
);
