// Prueba de integración del pago pendiente desfasado (Sprint 5, D-04, FR-016,
// SC-010, R-08): si al confirmar como PAGADO un cobro de Mercado Pago su
// importe ya no coincide con el total de la orden, el pago se cancela con el
// motivo IMPORTE_DESFASADO y se responde 409 con las cifras.
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/payments.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Pago desfasado');
});

async function servicios(ordenId) {
  return sql('SELECT id FROM order_services WHERE service_order_id = ? ORDER BY id', [ordenId]);
}

test('confirmar_un_pendiente_desfasado_lo_cancela_con_IMPORTE_DESFASADO_y_permite_un_pago_nuevo', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 1090 });
  await ctx.agregarServicio(ordenId, 300);
  const pendiente = await ctx.pagar(ordenId, 1390, 'MERCADO_PAGO');
  expect(pendiente.status).toBe(201);
  expect(pendiente.body.estado).toBe('PENDIENTE');

  // Se quita el servicio de 300 mientras el cobro sigue pendiente.
  const [, segundo] = await servicios(ordenId);
  const baja = await api
    .delete(`/api/service-orders/${ordenId}/servicios/${segundo.id}`)
    .set(bearer(ctx.tokens.admin));
  expect(baja.status).toBe(200);

  const confirmacion = await ctx.confirmar(pendiente.body.id, 'PAGADO');
  expect(confirmacion.status).toBe(409);
  expect(confirmacion.body.error).toEqual({
    codigo: 'IMPORTE_DESFASADO',
    mensaje:
      'El importe del pago (1390.00) ya no coincide con el total de la orden (1090.00); ' +
      'el pago se canceló. Antes de generar uno nuevo, revisa en el panel de Mercado Pago ' +
      'si el cliente ya pagó.',
    importePago: 1390,
    totalActual: 1090,
    diferencia: 300,
  });

  const lista = await api
    .get(`/api/payments/orden/${ordenId}`)
    .set(bearer(ctx.tokens.recepcion));
  const cancelado = lista.body.elementos.find((p) => p.id === pendiente.body.id);
  expect(cancelado.estado).toBe('CANCELADO');
  expect(cancelado.motivoCancelacion).toBe('IMPORTE_DESFASADO');

  // SC-010: después se registra un pago nuevo por el total correcto.
  const nuevo = await ctx.pagar(ordenId, 1090);
  expect(nuevo.status).toBe(201);
  expect(nuevo.body.estado).toBe('PAGADO');
});

test('confirmar_un_pendiente_que_coincide_lo_deja_PAGADO', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 640 });
  const pendiente = await ctx.pagar(ordenId, 640, 'MERCADO_PAGO');
  const confirmacion = await ctx.confirmar(pendiente.body.id, 'PAGADO');
  expect(confirmacion.status).toBe(200);
  expect(confirmacion.body.estado).toBe('PAGADO');
  expect(confirmacion.body.motivoCancelacion).toBeNull();
});

test('una_cancelacion_manual_guarda_el_motivo_MANUAL', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 220 });
  const pendiente = await ctx.pagar(ordenId, 220, 'MERCADO_PAGO');
  const cancelacion = await ctx.confirmar(pendiente.body.id, 'CANCELADO');
  expect(cancelacion.status).toBe(200);
  expect(cancelacion.body.estado).toBe('CANCELADO');
  expect(cancelacion.body.motivoCancelacion).toBe('MANUAL');
});

test('RECHAZADO_no_compara_el_importe', async () => {
  const ordenId = await ctx.ordenTerminada({ precio: 500 });
  await ctx.agregarServicio(ordenId, 100);
  const pendiente = await ctx.pagar(ordenId, 600, 'MERCADO_PAGO');
  const [, segundo] = await servicios(ordenId);
  await api
    .delete(`/api/service-orders/${ordenId}/servicios/${segundo.id}`)
    .set(bearer(ctx.tokens.admin));

  const rechazo = await ctx.confirmar(pendiente.body.id, 'RECHAZADO');
  expect(rechazo.status).toBe(200);
  expect(rechazo.body.estado).toBe('RECHAZADO');
  expect(rechazo.body.motivoCancelacion).toBeNull();
});
