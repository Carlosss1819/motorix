// Servicios frecuentes y productividad (Sprint 7, Entrega B, US5, FR-033, FR-034).
// Periodo: órdenes que pasaron a TERMINADO en el rango (order_status_history).
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';
import { ventanaLibre, marcarTerminada, addDays } from '../helpers/report-fixtures.js';

let ctx;
let rango;
let mecanicoUsername;
const descripcionLibre = `Lavado de inyectores ${Date.now()}`;

async function servicio(ordenId, { precio, tipoServicioId, descripcion }) {
  const body = { descripcion, duracionMinutos: 30 };
  if (precio !== undefined) body.precio = precio;
  if (tipoServicioId) body.tipoServicioId = tipoServicioId;
  const r = await api.post(`/api/service-orders/${ordenId}/servicios`).set(bearer(ctx.tokens.admin)).send(body);
  if (r.status !== 201) throw new Error(`Servicio: ${JSON.stringify(r.body)}`);
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Reporte servicios');
  rango = await ventanaLibre(20, 5);
  [{ username: mecanicoUsername }] = await sql('SELECT username FROM users WHERE id = ?', [ctx.mecanicoId]);

  // Orden 1 (mecánico): dos cambios de aceite (tipo 70001) y una línea libre.
  const o1 = await ctx.crearOrden({ asignarMecanico: true });
  await servicio(o1, { precio: 350.1, tipoServicioId: 70001, descripcion: 'Aceite sintético' });
  await servicio(o1, { precio: 349.9, tipoServicioId: 70001, descripcion: 'Aceite y filtro' });
  await servicio(o1, { precio: 120.05, descripcion: descripcionLibre });
  await marcarTerminada(o1, `${rango.desde} 09:00:00`);

  // Orden 2 (mecánico): afinación (70002) sin precio y la misma línea libre.
  const o2 = await ctx.crearOrden({ asignarMecanico: true });
  await servicio(o2, { tipoServicioId: 70002, descripcion: 'Afinación mayor' });
  await servicio(o2, { precio: 100, descripcion: descripcionLibre });
  await marcarTerminada(o2, `${rango.hasta} 23:59:59`);

  // Orden 3 (sin mecánico): un cambio de aceite.
  const o3 = await ctx.crearOrden();
  await servicio(o3, { precio: 300, tipoServicioId: 70001, descripcion: 'Aceite' });
  await marcarTerminada(o3, `${addDays(rango.desde, 2)} 12:00:00`);

  // Orden 4: terminada fuera del rango; no cuenta.
  const o4 = await ctx.crearOrden({ asignarMecanico: true });
  await servicio(o4, { precio: 5000, tipoServicioId: 70001, descripcion: 'Aceite' });
  await marcarTerminada(o4, `${addDays(rango.hasta, 1)} 00:00:00`);
});

function consultar(reporte) {
  return api
    .get(`/api/reports/${reporte}?desde=${rango.desde}&hasta=${rango.hasta}`)
    .set(bearer(ctx.tokens.admin));
}

test('test_agrupa_por_tipo_de_servicio_y_las_lineas_sin_tipo_por_descripcion', async () => {
  const response = await consultar('servicios');
  expect(response.status).toBe(200);
  expect(response.body.elementos).toEqual([
    { tipoServicioId: 70001, tipoServicio: 'Cambio de aceite', descripcion: null, veces: 3, manoDeObra: 1000 },
    { tipoServicioId: null, tipoServicio: null, descripcion: descripcionLibre, veces: 2, manoDeObra: 220.05 },
    { tipoServicioId: 70002, tipoServicio: 'Afinación', descripcion: null, veces: 1, manoDeObra: 0 },
  ]);
});

test('test_la_productividad_cuenta_ordenes_terminadas_y_mano_de_obra_por_mecanico', async () => {
  const response = await consultar('productividad');
  expect(response.status).toBe(200);
  expect(response.body.elementos).toEqual([
    { mecanicoId: ctx.mecanicoId, mecanico: mecanicoUsername, ordenesTerminadas: 2, manoDeObra: 920.05 },
    { mecanicoId: null, mecanico: 'Sin mecánico asignado', ordenesTerminadas: 1, manoDeObra: 300 },
  ]);
});

test('test_la_respuesta_no_trae_importes_de_otros_periodos', async () => {
  const response = await api
    .get(`/api/reports/servicios?desde=${addDays(rango.hasta, 1)}&hasta=${addDays(rango.hasta, 1)}`)
    .set(bearer(ctx.tokens.admin));
  expect(response.body.elementos).toEqual([
    { tipoServicioId: 70001, tipoServicio: 'Cambio de aceite', descripcion: null, veces: 1, manoDeObra: 5000 },
  ]);
});
