// Integración (Sprint 7, US1, FR-002, CA-1): los tickets nuevos usan los datos
// del taller vigentes al emitirse y los ya emitidos conservan los suyos.
// Solo cambia la dirección del taller (ninguna otra suite la revisa) y la
// restaura al final.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';

let ctx;
let direccionOriginal;

async function ticketDeOrdenPagada(precio) {
  const ordenId = await ctx.ordenTerminada({ precio });
  const pago = await ctx.pagar(ordenId, precio);
  expect(pago.status).toBe(201);
  const ticket = await ctx.generarTicket(ordenId);
  expect(ticket.status).toBe(201);
  return ticket.body;
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Ticket taller S7');
  const actual = await api.get('/api/settings').set(bearer(ctx.tokens.admin));
  direccionOriginal = actual.body.taller.direccion;
});

afterAll(async () => {
  await api
    .put('/api/settings')
    .set(bearer(ctx.tokens.admin))
    .send({ direccionTaller: direccionOriginal });
});

test('test_el_ticket_nuevo_usa_la_direccion_vigente_y_el_anterior_conserva_la_suya', async () => {
  const primero = await ticketDeOrdenPagada(300);
  const direccionAnterior = primero.taller.direccion;

  const nueva = `Calle Prueba ${ctx.suffix}`;
  const cambio = await api
    .put('/api/settings')
    .set(bearer(ctx.tokens.admin))
    .send({ direccionTaller: nueva });
  expect(cambio.status).toBe(200);

  const segundo = await ticketDeOrdenPagada(320);
  expect(segundo.taller.direccion).toBe(nueva);

  const releido = await api.get(`/api/tickets/${primero.id}`).set(bearer(ctx.tokens.recepcion));
  expect(releido.status).toBe(200);
  expect(releido.body.taller.direccion).toBe(direccionAnterior);
});
