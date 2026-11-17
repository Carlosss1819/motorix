// Rendimiento del centro de avisos (Sprint 6, SC-006, R-09, T059): con 10
// veces el volumen del seed 006 (100 mantenimientos, 50 refacciones en stock
// bajo, 50 órdenes detenidas y 30 citas de hoy), la consulta de avisos de un
// administrador responde en menos de 1 s, medida como la mediana de 3
// consultas después de una de calentamiento. Los datos llevan claves propias
// de esta suite y se borran al final. La carga de datos no cuenta: el tiempo
// se mide solo alrededor de cada petición.
import { performance } from 'node:perf_hooks';
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  fechaHora,
  crearContextoAvisos,
} from '../helpers/notifications-fixtures.js';

let ctx;
const creados = { maintenance: [], parts: [], orders: [], appointments: [] };

function valoresEnLote(filas) {
  return filas.map((fila) => `(${fila.map(() => '?').join(', ')})`).join(', ');
}

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Rendimiento');
  const s = ctx.suffix;

  // 100 mantenimientos: la mitad vencidos y la mitad próximos.
  const mantenimientos = Array.from({ length: 100 }, (_, i) => [
    ctx.vehiculoId,
    `Perf ${s} ${i}`.slice(0, 120),
    i % 2 === 0 ? fecha(-5) : fecha(10),
    30,
    500,
    ctx.adminId,
  ]);
  const m = await sql(
    `INSERT INTO maintenance (vehicle_id, service_type, target_date, advance_days, advance_km, created_by)
     VALUES ${valoresEnLote(mantenimientos)}`,
    mantenimientos.flat(),
  );
  creados.maintenance = Array.from({ length: 100 }, (_, i) => m.insertId + i);

  // 50 refacciones en stock bajo (10 de ellas agotadas).
  const refacciones = Array.from({ length: 50 }, (_, i) => [
    `PRF-${s}-${i}`.slice(0, 30),
    `Refacción rendimiento ${i}`,
    'Pruebas',
    i < 10 ? 0 : 1,
    5,
  ]);
  const p = await sql(
    `INSERT INTO parts (code, name, category, stock_current, stock_min)
     VALUES ${valoresEnLote(refacciones)}`,
    refacciones.flat(),
  );
  creados.parts = Array.from({ length: 50 }, (_, i) => p.insertId + i);

  // 50 órdenes detenidas (último cambio hace 5 días).
  const ordenes = Array.from({ length: 50 }, () => [
    ctx.clienteId,
    ctx.vehiculoId,
    'DIAGNOSTICO',
    `Rendimiento ${s}`,
    fecha(-6),
    1000,
    ctx.adminId,
    fechaHora(-24 * 6),
  ]);
  const o = await sql(
    `INSERT INTO service_orders (client_id, vehicle_id, status, visit_reason, entry_date,
                                 entry_mileage, created_by, created_at)
     VALUES ${valoresEnLote(ordenes)}`,
    ordenes.flat(),
  );
  creados.orders = Array.from({ length: 50 }, (_, i) => o.insertId + i);
  const historial = creados.orders.map((id) => [id, 'DIAGNOSTICO', ctx.adminId, fechaHora(-24 * 5)]);
  await sql(
    `INSERT INTO order_status_history (service_order_id, to_status, changed_by, changed_at)
     VALUES ${valoresEnLote(historial)}`,
    historial.flat(),
  );

  // 30 citas de hoy con hora futura respecto al reloj fijo (12:00).
  const citas = Array.from({ length: 30 }, (_, i) => [
    ctx.clienteId,
    ctx.vehiculoId,
    fecha(0),
    `${String(13 + Math.floor(i / 4)).padStart(2, '0')}:${String((i % 4) * 15).padStart(2, '0')}:00`,
    `Rendimiento ${s} ${i}`,
    'PROGRAMADA',
    ctx.adminId,
  ]);
  const a = await sql(
    `INSERT INTO appointments (client_id, vehicle_id, appointment_date, appointment_time,
                               reason, status, created_by)
     VALUES ${valoresEnLote(citas)}`,
    citas.flat(),
  );
  creados.appointments = Array.from({ length: 30 }, (_, i) => a.insertId + i);
}, 30000);

afterAll(async () => {
  liberarReloj();
  if (creados.orders.length) {
    await sql('DELETE FROM order_status_history WHERE service_order_id IN (?)', [creados.orders]);
    await sql('DELETE FROM service_orders WHERE id IN (?)', [creados.orders]);
  }
  if (creados.appointments.length) {
    await sql('DELETE FROM appointments WHERE id IN (?)', [creados.appointments]);
  }
  if (creados.maintenance.length) {
    await sql('DELETE FROM maintenance WHERE id IN (?)', [creados.maintenance]);
  }
  if (creados.parts.length) await sql('DELETE FROM parts WHERE id IN (?)', [creados.parts]);
}, 30000);

async function medir() {
  const inicio = performance.now();
  const r = await api.get('/api/notifications').set(bearer(ctx.tokens.admin));
  const ms = performance.now() - inicio;
  expect(r.status).toBe(200);
  return { ms, cuerpo: r.body };
}

test('la_mediana_de_3_consultas_de_avisos_del_admin_es_menor_que_1_segundo_SC_006', async () => {
  const calentamiento = await medir();
  // Los datos de la suite sí están en el centro (la medición no es en vacío).
  const claves = new Set(calentamiento.cuerpo.grupos.flatMap((g) => g.avisos.map((x) => x.clave)));
  expect(creados.parts.every((id) => claves.has(`STOCK_BAJO:${id}`) || claves.has(`STOCK_AGOTADO:${id}`))).toBe(true);
  expect(creados.orders.every((id) => claves.has(`ORDEN_DETENIDA:${id}:DIAGNOSTICO`))).toBe(true);
  expect(creados.appointments.every((id) => claves.has(`CITA_HOY:${id}:${fecha(0)}`))).toBe(true);

  const tiempos = [];
  for (let i = 0; i < 3; i += 1) tiempos.push((await medir()).ms);
  tiempos.sort((x, y) => x - y);
  const mediana = tiempos[1];
  expect(mediana).toBeLessThan(1000);
}, 30000);
