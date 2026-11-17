// Fechas en hora local (Sprint 6, H-S6-07): la fecha de registro de clientes y
// las fechas con hora de las órdenes (entrega e historial) se devuelven en la
// hora local del servidor, como las guarda MySQL, y no en UTC. Se usan valores
// fijos a las 23:30 locales: en UTC−6 eso ya es el día siguiente, que es
// justo donde fallaba `toISOString()`.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Fechas locales');
});

test('fechaRegistro_del_cliente_es_el_dia_local_de_created_at', async () => {
  await sql("UPDATE clients SET created_at = '2026-11-16 23:30:00' WHERE id = ?", [ctx.clienteId]);

  const detalle = await api.get(`/api/clients/${ctx.clienteId}`).set(bearer(ctx.tokens.admin));
  expect(detalle.status).toBe(200);
  expect(detalle.body.fechaRegistro).toBe('2026-11-16');
});

test('fechaEntrega_y_fecha_del_historial_de_la_orden_van_en_hora_local', async () => {
  const ordenId = await ctx.crearOrden();
  await sql("UPDATE service_orders SET delivery_date = '2026-11-16 23:30:00' WHERE id = ?", [ordenId]);
  // La orden es propia de esta suite: se deja solo la fila de historial de
  // la prueba para ubicarla sin depender de la nota (la API no la devuelve).
  await sql('DELETE FROM order_status_history WHERE service_order_id = ?', [ordenId]);
  await sql(
    `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, changed_at, note)
     SELECT ?, 'RECIBIDO', 'DIAGNOSTICO', id, '2026-11-16 23:30:00', 'Fechas locales' FROM users WHERE username = 'admin'`,
    [ordenId],
  );

  const detalle = await api.get(`/api/service-orders/${ordenId}`).set(bearer(ctx.tokens.admin));
  expect(detalle.status).toBe(200);
  expect(detalle.body.fechaEntrega).toBe('2026-11-16 23:30:00');
  expect(detalle.body.historial).toHaveLength(1);
  expect(detalle.body.historial[0]).toMatchObject({ de: 'RECIBIDO', a: 'DIAGNOSTICO' });
  expect(detalle.body.historial[0].fecha).toBe('2026-11-16 23:30:00');
});
