// Reporte de ingresos (Sprint 7, Entrega B, US4, FR-031, FR-032, FR-038).
// Fuente: specs/007-reportes-configuracion/contracts/reports.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';
import { ventanaLibre, insertarPago, addDays } from '../helpers/report-fixtures.js';

let ctx;
let rango;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Reporte ingresos');
  rango = await ventanaLibre(10, 3);
  const ordenA = await ctx.crearOrden();
  const ordenB = await ctx.crearOrden();
  const dia1 = rango.desde;
  const dia3 = rango.hasta;
  // Importes con centavos que en flotante no suman exacto (0.10 + 0.20).
  await insertarPago(ordenA, { monto: '0.10', metodo: 'EFECTIVO', fechaHora: `${dia1} 00:00:00` });
  await insertarPago(ordenA, { monto: '0.20', metodo: 'EFECTIVO', fechaHora: `${dia1} 13:30:00` });
  await insertarPago(ordenB, { monto: '1390.35', metodo: 'TARJETA', fechaHora: `${dia3} 23:59:59` });
  await insertarPago(ordenB, { monto: '250.00', metodo: 'TRANSFERENCIA', fechaHora: `${dia3} 10:00:00` });
  // No suman: anulado, cancelado, rechazado y fuera del rango.
  await insertarPago(ordenB, { monto: '999.99', estado: 'ANULADO', fechaHora: `${dia3} 11:00:00` });
  await insertarPago(ordenB, { monto: '888.88', estado: 'CANCELADO', fechaHora: `${dia3} 11:00:00` });
  await insertarPago(ordenB, { monto: '777.77', estado: 'RECHAZADO', fechaHora: `${dia1} 11:00:00` });
  await insertarPago(ordenB, { monto: '666.66', fechaHora: `${addDays(dia3, 1)} 00:00:00` });
});

function consultar(query, token = ctx.tokens.admin) {
  return api.get(`/api/reports/ingresos?${query}`).set(bearer(token));
}

test('test_suma_solo_pagos_pagado_por_metodo_y_por_dia_al_centavo', async () => {
  const response = await consultar(`desde=${rango.desde}&hasta=${rango.hasta}`);
  expect(response.status).toBe(200);
  expect(response.body).toEqual({
    desde: rango.desde,
    hasta: rango.hasta,
    total: 1640.65,
    pagos: 4,
    porMetodo: [
      { metodo: 'EFECTIVO', total: 0.3, pagos: 2 },
      { metodo: 'TARJETA', total: 1390.35, pagos: 1 },
      { metodo: 'TRANSFERENCIA', total: 250, pagos: 1 },
    ],
    porDia: [
      { fecha: rango.desde, total: 0.3, pagos: 2 },
      { fecha: rango.hasta, total: 1640.35, pagos: 2 },
    ],
  });
});

test('test_el_pago_del_ultimo_segundo_del_dia_cuenta_para_ese_dia', async () => {
  const response = await consultar(`desde=${rango.hasta}&hasta=${rango.hasta}`);
  expect(response.body.porMetodo.find((m) => m.metodo === 'TARJETA')).toEqual({
    metodo: 'TARJETA',
    total: 1390.35,
    pagos: 1,
  });
});

test('test_un_rango_sin_datos_devuelve_ceros_y_listas_vacias', async () => {
  const dia = '1971-01-01';
  const response = await consultar(`desde=${dia}&hasta=${dia}`);
  expect(response.status).toBe(200);
  expect(response.body).toMatchObject({ total: 0, pagos: 0, porMetodo: [], porDia: [] });
});

test.each([
  ['sin fechas', ''],
  ['inicio posterior al fin', 'desde=2026-12-01&hasta=2026-11-01'],
  ['más de un año', 'desde=2025-01-01&hasta=2026-01-02'],
  ['fecha inexistente', 'desde=2026-02-30&hasta=2026-03-02'],
])('test_%s_responde_400_rango_invalido', async (_caso, query) => {
  const response = await consultar(query);
  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('RANGO_INVALIDO');
  expect(response.body.error.mensaje).toEqual(expect.any(String));
});

test('test_formato_desconocido_responde_400', async () => {
  const response = await consultar(`desde=${rango.desde}&hasta=${rango.hasta}&formato=xlsx`);
  expect(response.status).toBe(400);
});

test.each([
  ['recepción', 'recepcion'],
  ['mecánico', 'mecanico'],
])('test_%s_recibe_403_en_los_cinco_reportes', async (_rol, clave) => {
  for (const reporte of ['ingresos', 'servicios', 'productividad', 'refacciones', 'rotacion']) {
    const response = await api
      .get(`/api/reports/${reporte}?desde=${rango.desde}&hasta=${rango.hasta}`)
      .set(bearer(ctx.tokens[clave]));
    expect(response.status).toBe(403);
  }
});

test('test_sin_sesion_responde_401', async () => {
  const response = await api.get(`/api/reports/ingresos?desde=${rango.desde}&hasta=${rango.hasta}`);
  expect(response.status).toBe(401);
});
