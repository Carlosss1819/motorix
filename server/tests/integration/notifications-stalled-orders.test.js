// Avisos de órdenes detenidas (Sprint 6, US4, FR-006, FR-007): RECIBIDO,
// DIAGNOSTICO, EN_REPARACION y ESPERANDO_REFACCION sin cambio de estado por
// más de N × 24 horas; nunca TERMINADO ni ENTREGADO. Reloj fijo (M3).
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fechaHora,
  crearContextoAvisos,
  avisosDe,
  avisoPorClave,
} from '../helpers/notifications-fixtures.js';
import { config } from '../../config/env.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Avisos US4');
});

afterAll(() => liberarReloj());

const claveDe = (id, estado) => `ORDEN_DETENIDA:${id}:${estado}`;

test.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])(
  'una_orden_%s_sin_cambio_por_mas_de_N_dias_genera_aviso',
  async (estado) => {
    const id = await ctx.ordenConEstado({ estado, horasSinCambio: 24 * 3 + 1 });
    const { avisos } = await avisosDe(ctx.tokens.recepcion);
    const aviso = avisoPorClave(avisos, claveDe(id, estado));
    expect(aviso).toMatchObject({
      tipo: 'ORDEN_DETENIDA',
      fechaReferencia: fechaHora(-(24 * 3 + 1)).slice(0, 16).replace(' ', 'T'),
      destino: { pantalla: 'ORDEN', id },
    });
    expect(aviso.descripcion).toContain(`Orden #${id}`);
    expect(aviso.descripcion).toContain('3 días sin cambio');
  },
);

test('con_menos_de_N_dias_no_genera_aviso', async () => {
  const id = await ctx.ordenConEstado({ estado: 'DIAGNOSTICO', horasSinCambio: 24 * 3 - 1 });
  const { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(avisos, claveDe(id, 'DIAGNOSTICO'))).toBeUndefined();
});

test.each(['TERMINADO', 'ENTREGADO'])('una_orden_%s_nunca_genera_aviso', async (estado) => {
  const id = await ctx.ordenConEstado({ estado, horasSinCambio: 24 * 30 });
  const { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisos.some((a) => a.clave.startsWith(`ORDEN_DETENIDA:${id}:`))).toBe(false);
});

test('sin_historial_usa_la_fecha_de_alta', async () => {
  const id = await ctx.ordenConEstado({ estado: 'RECIBIDO', horasSinCambio: 24 * 4, sinHistorial: true });
  const { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(avisos, claveDe(id, 'RECIBIDO'))).toMatchObject({
    fechaReferencia: fechaHora(-24 * 4).slice(0, 16).replace(' ', 'T'),
  });
});

test('al_cambiar_de_estado_deja_de_estar_detenida_y_la_clave_cambia', async () => {
  const id = await ctx.ordenConEstado({ estado: 'DIAGNOSTICO', horasSinCambio: 24 * 5 });
  let { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(avisos, claveDe(id, 'DIAGNOSTICO'))).toBeDefined();

  await sql('UPDATE service_orders SET status = ? WHERE id = ?', ['EN_REPARACION', id]);
  await sql(
    `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, changed_at)
     VALUES (?, 'DIAGNOSTICO', 'EN_REPARACION', ?, ?)`,
    [id, ctx.adminId, fechaHora(-1)],
  );
  ({ avisos } = await avisosDe(ctx.tokens.admin));
  expect(avisos.some((a) => a.clave.startsWith(`ORDEN_DETENIDA:${id}:`))).toBe(false);

  // Si vuelve a pasar más de N días en el estado nuevo, es un aviso nuevo.
  await sql('UPDATE order_status_history SET changed_at = ? WHERE service_order_id = ? AND to_status = ?', [
    fechaHora(-24 * 4),
    id,
    'EN_REPARACION',
  ]);
  ({ avisos } = await avisosDe(ctx.tokens.admin));
  expect(avisoPorClave(avisos, claveDe(id, 'EN_REPARACION'))).toBeDefined();
});

test('respeta_un_N_configurado_distinto', async () => {
  const id = await ctx.ordenConEstado({ estado: 'RECIBIDO', horasSinCambio: 30 });
  const original = config.notifications.stalledOrderDays;
  try {
    config.notifications.stalledOrderDays = 1;
    let { avisos } = await avisosDe(ctx.tokens.admin);
    expect(avisoPorClave(avisos, claveDe(id, 'RECIBIDO'))).toBeDefined();
    config.notifications.stalledOrderDays = 2;
    ({ avisos } = await avisosDe(ctx.tokens.admin));
    expect(avisoPorClave(avisos, claveDe(id, 'RECIBIDO'))).toBeUndefined();
  } finally {
    config.notifications.stalledOrderDays = original;
  }
});

test('una_orden_sin_mecanico_la_ven_admin_y_recepcion', async () => {
  const id = await ctx.ordenConEstado({ estado: 'ESPERANDO_REFACCION', horasSinCambio: 24 * 6 });
  for (const token of [ctx.tokens.admin, ctx.tokens.recepcion]) {
    const { avisos } = await avisosDe(token);
    expect(avisoPorClave(avisos, claveDe(id, 'ESPERANDO_REFACCION'))).toBeDefined();
  }
});
