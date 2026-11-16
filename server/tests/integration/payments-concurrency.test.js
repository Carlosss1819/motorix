// Prueba de integración de concurrencia del cobro (Sprint 5, FR-014, SC-005,
// CA-8, R-07): dos registros simultáneos para la misma orden dejan exactamente
// un pago; el otro recibe 409 ORDEN_YA_LIQUIDADA o PAGO_PENDIENTE.
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Concurrencia de pagos');
});

test.each([1, 2, 3, 4, 5])(
  'dos_cobros_simultaneos_dejan_un_solo_pago_intento_%i',
  async (intento) => {
    const ordenId = await ctx.ordenTerminada({ precio: 300 + intento });
    const monto = 300 + intento;
    // Un intento con dos efectivos y otro mezclando Mercado Pago (pendiente).
    const segundoMetodo = intento % 2 === 0 ? 'MERCADO_PAGO' : 'EFECTIVO';

    const respuestas = await Promise.all([
      ctx.pagar(ordenId, monto, 'EFECTIVO'),
      ctx.pagar(ordenId, monto, segundoMetodo),
    ]);

    const creadas = respuestas.filter((r) => r.status === 201);
    const rechazadas = respuestas.filter((r) => r.status === 409);
    expect(creadas).toHaveLength(1);
    expect(rechazadas).toHaveLength(1);
    expect(['ORDEN_YA_LIQUIDADA', 'PAGO_PENDIENTE']).toContain(
      rechazadas[0].body.error.codigo,
    );

    const [fila] = await sql(
      `SELECT COUNT(*) AS total FROM payments
       WHERE service_order_id = ? AND status IN ('PAGADO', 'PENDIENTE')`,
      [ordenId],
    );
    expect(fila.total).toBe(1);
  },
);
