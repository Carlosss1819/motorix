// Prueba de integración de los datos de ejemplo del Sprint 6 (FR-025, SC-007,
// R-10, T056): el seed 006 es idempotente y, recién cargado, da al
// administrador al menos un aviso de cada tipo y a «Clientes por avisar» los
// cuatro motivos.
//
// Las filas se cuentan por sus claves propias (ids 60001 a 60099 junto con el
// prefijo «[Sprint 6]», códigos `NOT-` y placas `NOT6-`), no por un rango de
// ids: después de sembrar el 60001, el AUTO_INCREMENT de MySQL salta y las
// filas que crean otras suites también reciben ids desde 60002 o más.
//
// Ajuste M3: el seed calcula sus fechas con CURDATE()/NOW() al cargarse; la
// prueba fija el reloj del servidor a las 12:00 del día que reporta MySQL
// después de cargarlo, para que una corrida cerca de la medianoche (o después
// de las 23:30, la hora de la cita de hoy) no cambie el resultado.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import { setNowForTests } from '../../utils/clock.js';
import { config } from '../../config/env.js';

const SEED_006 = path.resolve(
  import.meta.dirname,
  '..',
  '..',
  '..',
  'database',
  'seeds',
  '006_ejemplos_notificaciones.sql',
);

const PROPIAS = 'BETWEEN 60001 AND 60099';
const CONSULTAS = {
  clients: `SELECT COUNT(*) AS n FROM clients WHERE id ${PROPIAS} AND name LIKE '[Sprint 6]%'`,
  vehicles: `SELECT COUNT(*) AS n FROM vehicles WHERE id ${PROPIAS} AND plates LIKE 'NOT6-%'`,
  maintenance: `SELECT COUNT(*) AS n FROM maintenance WHERE id ${PROPIAS} AND service_type LIKE '[Sprint 6]%'`,
  parts: `SELECT COUNT(*) AS n FROM parts WHERE id ${PROPIAS} AND code LIKE 'NOT-%'`,
  appointments: `SELECT COUNT(*) AS n FROM appointments WHERE id ${PROPIAS} AND reason LIKE '[Sprint 6]%'`,
  service_orders: `SELECT COUNT(*) AS n FROM service_orders WHERE id ${PROPIAS} AND visit_reason LIKE '[Sprint 6]%'`,
  order_status_history: `SELECT COUNT(*) AS n FROM order_status_history WHERE id ${PROPIAS} AND note LIKE '[Sprint 6]%'`,
};

const ESPERADAS = {
  clients: 1,
  vehicles: 3,
  maintenance: 2,
  parts: 2,
  appointments: 2,
  service_orders: 3,
  order_status_history: 6,
};

let tokenAdmin;

async function cargarSeed() {
  const db = await mysql.createConnection({ ...config.db, multipleStatements: true });
  try {
    await db.query(readFileSync(SEED_006, 'utf8'));
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

// Fija el reloj a las 12:00 del día de MySQL (el mismo CURDATE() del seed).
async function fijarRelojAlDiaDelSeed() {
  const [fila] = await sql("SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS hoy");
  const [anio, mes, dia] = fila.hoy.split('-').map(Number);
  setNowForTests(new Date(anio, mes - 1, dia, 12, 0, 0));
}

beforeAll(async () => {
  await prepareTestDatabase();
  tokenAdmin = await loginAs('admin', 'Admin2026!');
});

afterAll(() => setNowForTests(null));

test('cargar_dos_veces_el_seed_006_no_duplica_registros_SC_007', async () => {
  await cargarSeed();
  const primera = await conteos();
  await cargarSeed();
  const segunda = await conteos();
  expect(primera).toEqual(ESPERADAS);
  expect(segunda).toEqual(primera);
});

test('con_el_seed_006_el_admin_recibe_al_menos_un_aviso_de_cada_tipo_FR_025', async () => {
  await cargarSeed();
  await fijarRelojAlDiaDelSeed();
  const r = await api.get('/api/notifications').set(bearer(tokenAdmin));
  expect(r.status).toBe(200);
  const avisos = r.body.grupos.flatMap((g) => g.avisos);
  const delSeed = (tipo, id) => avisos.some((a) => a.tipo === tipo && a.destino.id === id);

  expect(delSeed('MANT_VENCIDO', 60003)).toBe(true); // vehículo del mantenimiento vencido
  expect(delSeed('MANT_PROXIMO', 60002)).toBe(true);
  expect(delSeed('STOCK_BAJO', 60001)).toBe(true);
  expect(delSeed('STOCK_AGOTADO', 60002)).toBe(true);
  expect(delSeed('CITA_HOY', 60001)).toBe(true);
  expect(delSeed('ORDEN_DETENIDA', 60001)).toBe(true);
  expect(delSeed('ORDEN_DETENIDA', 60002)).toBe(true);
  // La orden TERMINADO no está detenida (estado final).
  expect(delSeed('ORDEN_DETENIDA', 60003)).toBe(false);
});

test('la_orden_detenida_del_seed_le_llega_al_mecanico_asignado_FR_011', async () => {
  await cargarSeed();
  await fijarRelojAlDiaDelSeed();
  const token = await loginAs('mecanico', 'Mecanico2026!');
  const r = await api.get('/api/notifications').set(bearer(token));
  const avisos = r.body.grupos.flatMap((g) => g.avisos);
  expect(avisos.some((a) => a.clave.startsWith('ORDEN_DETENIDA:60001:'))).toBe(true);
  // La orden en diagnóstico sin mecánico no le llega.
  expect(avisos.some((a) => a.clave.startsWith('ORDEN_DETENIDA:60002:'))).toBe(false);
});

test('con_el_seed_006_clientes_por_avisar_tiene_los_cuatro_motivos_FR_025', async () => {
  await cargarSeed();
  await fijarRelojAlDiaDelSeed();
  const r = await api.get('/api/client-notices').set(bearer(tokenAdmin));
  expect(r.status).toBe(200);
  const delSeed = r.body.elementos.filter((e) => e.cliente.id === 60001);
  expect(new Set(delSeed.map((e) => e.motivo))).toEqual(
    new Set(['VEHICULO_LISTO', 'CITA_MANANA', 'MANT_PROXIMO', 'MANT_VENCIDO']),
  );
  for (const e of delSeed) expect(e.cliente.telefono).toBe('5550060001');
});
