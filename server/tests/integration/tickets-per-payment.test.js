// Pruebas de integración del ticket por pago (Sprint 5, US4): copia con
// versión 2 (FR-019), historial íntegro ante cambios de precio (SC-002), un
// ticket nuevo por cada pago PAGADO (FR-033), «pago anulado» en el ticket
// viejo (FR-022), idempotencia (SC-013) y la entrega condicionada (SC-015).
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/tickets.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Tickets por pago');
});

async function copia(ticketId) {
  const [fila] = await sql('SELECT content, format_version FROM tickets WHERE id = ?', [ticketId]);
  return { content: fila.content, version: fila.format_version };
}

async function entregar(ordenId) {
  return api
    .post(`/api/service-orders/${ordenId}/estado`)
    .set(bearer(ctx.tokens.recepcion))
    .send({ estado: 'ENTREGADO' });
}

test('ciclo_completo_cobro_anulacion_nuevo_cobro_y_dos_tickets', async () => {
  const partId = await ctx.crearRefaccion({ precioVenta: 320 });
  const ordenId = await ctx.ordenTerminada({ precio: 750, refaccion: partId, cantidad: 2 });

  // Cobrar → ticket con copia versión 2 (FR-019).
  const pago1 = await ctx.pagar(ordenId, 1390);
  expect(pago1.status).toBe(201);
  const t1 = await ctx.generarTicket(ordenId);
  expect(t1.status).toBe(201);
  expect(t1.body.formatoVersion).toBe(2);
  expect(t1.body.formatoAnterior).toBe(false);
  expect(t1.body.vigente).toBe(true);
  expect(t1.body.pagoAnulado).toBe(false);
  const guardada = await copia(t1.body.id);
  expect(guardada.version).toBe(2);
  expect(guardada.content.total).toBe(1390);
  // Lo calculado al consultar no se guarda en la copia.
  expect(guardada.content).not.toHaveProperty('vigente');
  expect(guardada.content).not.toHaveProperty('pagoAnulado');

  // SC-002: un cambio de precio en el catálogo no cambia la copia.
  await ctx.cambiarPrecioVenta(partId, 999);
  const releido = await api.get(`/api/tickets/${t1.body.id}`).set(bearer(ctx.tokens.recepcion));
  expect(releido.body.total).toBe(1390);
  expect(releido.body.servicios[0].refacciones[0].precioUnitario).toBe(320);
  expect((await copia(t1.body.id)).content).toEqual(guardada.content);

  // SC-013: repetir la generación devuelve el mismo ticket.
  const repetido = await ctx.generarTicket(ordenId);
  expect(repetido.status).toBe(200);
  expect(repetido.body.id).toBe(t1.body.id);
  expect(repetido.body.folio).toBe(t1.body.folio);

  // El administrador anula el pago → se permite agregar un servicio (FR-022).
  expect((await ctx.anular(pago1.body.id)).status).toBe(200);

  // SC-015: sin pago vigente la orden no se entrega.
  const sinPago = await entregar(ordenId);
  expect(sinPago.status).toBe(409);
  expect(sinPago.body.error.codigo).toBe('PAGO_PENDIENTE');

  expect((await ctx.agregarServicio(ordenId, 110)).status).toBe(201);

  // Pago nuevo y ticket NUEVO con otro folio (FR-033).
  const pago2 = await ctx.pagar(ordenId, 1500);
  expect(pago2.status).toBe(201);
  const t2 = await ctx.generarTicket(ordenId);
  expect(t2.status).toBe(201);
  expect(t2.body.id).not.toBe(t1.body.id);
  expect(t2.body.folio).not.toBe(t1.body.folio);
  expect(t2.body.total).toBe(1500);
  expect(t2.body.pagoId).toBe(pago2.body.id);
  expect((await ctx.generarTicket(ordenId)).body.id).toBe(t2.body.id);

  // Consulta por orden: el vigente y los dos tickets.
  const porOrden = await api
    .get(`/api/tickets/orden/${ordenId}`)
    .set(bearer(ctx.tokens.recepcion));
  expect(porOrden.status).toBe(200);
  expect(porOrden.body.existe).toBe(true);
  expect(porOrden.body.ticket.id).toBe(t2.body.id);
  expect(porOrden.body.tickets).toHaveLength(2);
  expect(porOrden.body.tickets.map((t) => t.id)).toEqual([t2.body.id, t1.body.id]);

  // FR-022: el ticket viejo muestra «pago anulado» y conserva su contenido.
  const viejo = await api.get(`/api/tickets/${t1.body.id}`).set(bearer(ctx.tokens.recepcion));
  expect(viejo.body.pagoAnulado).toBe(true);
  expect(viejo.body.vigente).toBe(false);
  expect(viejo.body.estadoPago).toBe('ANULADO');
  expect(viejo.body.total).toBe(1390);

  // SC-015: con el pago PAGADO nuevo, la entrega se permite.
  const entrega = await entregar(ordenId);
  expect(entrega.status).toBe(200);
  expect(entrega.body.estado).toBe('ENTREGADO');
});

test('sin_pago_vigente_POST_tickets_da_409_TICKET_REQUIERE_PAGO_y_no_devuelve_el_ticket_anulado', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 300 });
  const pago = await ctx.pagar(ordenId, 300);
  const t1 = await ctx.generarTicket(ordenId);
  expect(t1.status).toBe(201);
  await ctx.anular(pago.body.id);

  const r = await ctx.generarTicket(ordenId);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('TICKET_REQUIERE_PAGO');

  const porOrden = await api
    .get(`/api/tickets/orden/${ordenId}`)
    .set(bearer(ctx.tokens.recepcion));
  expect(porOrden.body.existe).toBe(false);
  expect(porOrden.body.ticket).toBeNull();
  expect(porOrden.body.tickets).toHaveLength(1);
  expect(porOrden.body.tickets[0]).toMatchObject({ id: t1.body.id, pagoAnulado: true, vigente: false });
});

test('SC_002_los_tickets_sembrados_T000001_y_T000002_conservan_su_copia_tras_cambiar_el_catalogo', async () => {
  const antes = await sql(
    "SELECT id, content FROM tickets WHERE folio IN ('T000001-2026', 'T000002-2026') ORDER BY id",
  );
  expect(antes).toHaveLength(2);
  // La refacción 3 (pastillas) es la del ticket T000002-2026.
  const [parte] = await sql('SELECT sale_price FROM parts WHERE id = 3');
  await sql('UPDATE parts SET sale_price = 777.77 WHERE id = 3');
  try {
    const despues = await sql(
      "SELECT id, content FROM tickets WHERE folio IN ('T000001-2026', 'T000002-2026') ORDER BY id",
    );
    expect(despues).toEqual(antes);
    const leido = await api.get(`/api/tickets/${antes[1].id}`).set(bearer(ctx.tokens.recepcion));
    expect(leido.body.total).toBe(Number(antes[1].content.total));
  } finally {
    await sql('UPDATE parts SET sale_price = ? WHERE id = 3', [parte.sale_price]);
  }
});
