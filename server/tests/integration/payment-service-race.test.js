// Prueba de integración de la carrera «confirmar pago contra quitar servicio»
// (Sprint 5, R-07): las dos operaciones toman el candado de la orden, así que
// el resultado siempre es uno de dos y nunca queda un pago PAGADO con un
// importe distinto del total.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Carrera confirmar servicio');
});

test.each([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])(
  'confirmar_y_quitar_un_servicio_a_la_vez_nunca_deja_un_PAGADO_desfasado_intento_%i',
  async () => {
    const ordenId = await ctx.ordenTerminada({ precio: 500 });
    expect((await ctx.agregarServicio(ordenId, 100)).status).toBe(201);
    const pendiente = await ctx.pagar(ordenId, 600, 'MERCADO_PAGO');
    expect(pendiente.status).toBe(201);
    const servicios = await sql(
      'SELECT id FROM order_services WHERE service_order_id = ? ORDER BY id',
      [ordenId],
    );

    const [confirmacion, baja] = await Promise.all([
      ctx.confirmar(pendiente.body.id, 'PAGADO'),
      api
        .delete(`/api/service-orders/${ordenId}/servicios/${servicios[1].id}`)
        .set(bearer(ctx.tokens.admin)),
    ]);

    const servicioPrimero =
      confirmacion.status === 409 &&
      confirmacion.body.error.codigo === 'IMPORTE_DESFASADO' &&
      baja.status === 200;
    const confirmacionPrimero =
      confirmacion.status === 200 &&
      confirmacion.body.estado === 'PAGADO' &&
      baja.status === 409 &&
      baja.body.error.codigo === 'ORDEN_PAGADA';
    expect(servicioPrimero || confirmacionPrimero).toBe(true);

    // Nunca un PAGADO con importe distinto del total de la orden.
    const [pago] = await sql('SELECT status, amount FROM payments WHERE id = ?', [
      pendiente.body.id,
    ]);
    const total = await ctx.total(ordenId);
    if (pago.status === 'PAGADO') {
      expect(Number(pago.amount)).toBe(total.total);
    } else {
      expect(pago.status).toBe('CANCELADO');
    }
  },
);
