// Integración (Sprint 7, US8, FR-012/FR-013, CA-14): el ticket nuevo incluye
// el próximo servicio por cada tipo con intervalo de la orden.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, fijarEstado } from '../helpers/fixtures.js';
import { addDays } from '../../utils/maintenance-status.js';

let ctx;

async function ticketCon(lineas) {
  const ordenId = await ctx.crearOrden();
  let total = 0;
  for (const [i, linea] of lineas.entries()) {
    total += 100;
    const r = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(ctx.tokens.admin))
      .send({ descripcion: `Línea ${i} ${ctx.suffix}`, duracionMinutos: 30, precio: 100, ...linea });
    expect(r.status).toBe(201);
  }
  await fijarEstado(ordenId, 'TERMINADO');
  expect((await ctx.pagar(ordenId, total)).status).toBe(201);
  const ticket = await ctx.generarTicket(ordenId);
  expect(ticket.status).toBe(201);
  // `vehiculo.kilometraje` del ticket es el kilometraje de entrada de la orden.
  return { ticket: ticket.body };
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Próximo servicio S7');
});

test('test_un_elemento_por_tipo_distinto_con_fecha_y_kilometraje', async () => {
  const { ticket } = await ticketCon([
    { tipoServicioId: 70001 },
    { tipoServicioId: 70001 },
    { tipoServicioId: 70004 },
    {},
  ]);
  const base = ticket.fecha;
  const km = ticket.vehiculo.kilometraje;
  expect(ticket.formatoVersion).toBe(2);
  expect(ticket.proximosServicios).toEqual([
    { tipoServicio: 'Cambio de aceite', fecha: addDays(base, 180), kilometraje: km + 5000 },
    { tipoServicio: 'Revisión de frenos', fecha: addDays(base, 365), kilometraje: null },
  ]);

  const releido = await api.get(`/api/tickets/${ticket.id}`).set(bearer(ctx.tokens.recepcion));
  expect(releido.body.proximosServicios).toEqual(ticket.proximosServicios);
});

test('test_sin_lineas_con_tipo_la_lista_queda_vacia', async () => {
  const { ticket } = await ticketCon([{}]);
  expect(ticket.proximosServicios).toEqual([]);
});
