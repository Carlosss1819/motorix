// Pruebas de integración de la inmovilización por pago (Sprint 5, FR-021 a
// FR-023, SC-009): una orden TERMINADO con un pago PAGADO no admite altas ni
// bajas de servicios hasta que el pago se anule.
// Fuente de verdad: specs/005-precios-refacciones-cobro/data-model.md
// («Reglas de inmovilización»).
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, fijarEstado, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Orden pagada');
});

async function primerServicio(ordenId) {
  const [fila] = await sql(
    'SELECT id FROM order_services WHERE service_order_id = ? ORDER BY id LIMIT 1',
    [ordenId],
  );
  return fila.id;
}

async function quitarServicio(ordenId, servicioId) {
  return api
    .delete(`/api/service-orders/${ordenId}/servicios/${servicioId}`)
    .set(bearer(ctx.tokens.admin));
}

test('TERMINADO_con_PAGADO_rechaza_agregar_y_quitar_servicios_con_ORDEN_PAGADA', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 400 });
  expect((await ctx.pagar(ordenId, 400)).status).toBe(201);

  const alta = await ctx.agregarServicio(ordenId, 50);
  expect(alta.status).toBe(409);
  expect(alta.body.error).toEqual({
    codigo: 'ORDEN_PAGADA',
    mensaje: 'La orden ya está pagada: no admite cambios en sus servicios',
  });

  const baja = await quitarServicio(ordenId, await primerServicio(ordenId));
  expect(baja.status).toBe(409);
  expect(baja.body.error.codigo).toBe('ORDEN_PAGADA');
});

test.each([
  ['PENDIENTE', 'MERCADO_PAGO', null],
  ['RECHAZADO', 'MERCADO_PAGO', 'RECHAZADO'],
  ['CANCELADO', 'MERCADO_PAGO', 'CANCELADO'],
])('con_un_pago_%s_se_permite_cambiar_servicios', async (_estado, metodo, confirmarCon) => {
  const ordenId = await ctx.ordenTerminada({ precio: 250 });
  const pago = await ctx.pagar(ordenId, 250, metodo);
  expect(pago.status).toBe(201);
  if (confirmarCon) expect((await ctx.confirmar(pago.body.id, confirmarCon)).status).toBe(200);

  expect((await ctx.agregarServicio(ordenId, 10)).status).toBe(201);
});

test('con_el_PAGADO_anulado_se_permite_cambiar_servicios_FR_022', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 260 });
  const pago = await ctx.pagar(ordenId, 260);
  expect((await ctx.anular(pago.body.id)).status).toBe(200);

  expect((await ctx.agregarServicio(ordenId, 15)).status).toBe(201);
  expect((await quitarServicio(ordenId, await primerServicio(ordenId))).status).toBe(200);
});

test('sin_pago_se_permite_cambiar_servicios', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 270 });
  expect((await ctx.agregarServicio(ordenId, 20)).status).toBe(201);
});

test('FR_023_las_refacciones_en_TERMINADO_siguen_con_ORDEN_CERRADA', async () => {
  const partId = await ctx.crearRefaccion({ precioVenta: 10 });
  const ordenId = await ctx.ordenTerminada({ precio: 280 });
  const r = await ctx.agregarRefaccion(ordenId, partId, 1);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('ORDEN_CERRADA');
});

test('FR_023_ENTREGADO_sigue_con_ORDEN_ENTREGADA', async () => {
  const partId = await ctx.crearRefaccion({ precioVenta: 10 });
  const ordenId = await ctx.ordenTerminada({ precio: 290 });
  await fijarEstado(ordenId, 'ENTREGADO');

  const servicio = await ctx.agregarServicio(ordenId, 5);
  expect(servicio.status).toBe(409);
  expect(servicio.body.error.codigo).toBe('ORDEN_ENTREGADA');

  const refaccion = await ctx.agregarRefaccion(ordenId, partId, 1);
  expect(refaccion.status).toBe(409);
  expect(refaccion.body.error.codigo).toBe('ORDEN_ENTREGADA');
});
