// Avisos por rol (Sprint 6, US5, FR-009 a FR-013, SC-002): el mecánico solo
// recibe órdenes detenidas asignadas a él; recepción no recibe stock; ningún
// aviso trae importes para ningún rol.
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  avisosDe,
  avisoPorClave,
  idDeUsuario,
  CLAVES_DE_DINERO,
} from '../helpers/notifications-fixtures.js';

let ctx;
const ids = {};
let tokenMecanicoB;

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Avisos US5');

  const usuarioB = `mecb_${ctx.suffix}`.slice(0, 40);
  const alta = await api
    .post('/api/users')
    .set(bearer(ctx.tokens.admin))
    .send({ username: usuarioB, email: `${usuarioB}@motorix.local`, rol: 'MECHANIC', contrasena: 'MecanicoB2026!' });
  if (alta.status !== 201) throw new Error(`Usuario B: ${JSON.stringify(alta.body)}`);
  tokenMecanicoB = await loginAs(usuarioB, 'MecanicoB2026!');
  ids.mecanicoA = await idDeUsuario('mecanico');
  ids.mecanicoB = alta.body.id;

  ids.ordenA = await ctx.ordenConEstado({ estado: 'EN_REPARACION', horasSinCambio: 24 * 5, mecanicoId: ids.mecanicoA });
  ids.ordenB = await ctx.ordenConEstado({ estado: 'DIAGNOSTICO', horasSinCambio: 24 * 5, mecanicoId: ids.mecanicoB });
  ids.sinMecanico = await ctx.ordenConEstado({ estado: 'RECIBIDO', horasSinCambio: 24 * 5 });
  ids.vencido = await ctx.mantenimiento({ fechaObjetivo: fecha(-3) });
  ids.refaccion = await ctx.refaccion({ existencia: 0, minimo: 2 });
  ids.bajo = await ctx.refaccion({ existencia: 1, minimo: 2 });
  ids.proximo = await ctx.mantenimiento({ fechaObjetivo: fecha(7) });
  ids.cita = await ctx.cita({ hora: '17:00:00' });
});

afterAll(() => liberarReloj());

test('cada_mecanico_ve_solo_su_orden_detenida', async () => {
  const a = await avisosDe(ctx.tokens.mecanico);
  const b = await avisosDe(tokenMecanicoB);
  expect(avisoPorClave(a.avisos, `ORDEN_DETENIDA:${ids.ordenA}:EN_REPARACION`)).toBeDefined();
  expect(avisoPorClave(a.avisos, `ORDEN_DETENIDA:${ids.ordenB}:DIAGNOSTICO`)).toBeUndefined();
  expect(avisoPorClave(b.avisos, `ORDEN_DETENIDA:${ids.ordenB}:DIAGNOSTICO`)).toBeDefined();
  expect(avisoPorClave(b.avisos, `ORDEN_DETENIDA:${ids.ordenA}:EN_REPARACION`)).toBeUndefined();
  for (const { avisos } of [a, b]) {
    expect(avisos.some((x) => x.clave.startsWith(`ORDEN_DETENIDA:${ids.sinMecanico}:`))).toBe(false);
  }
});

test('el_mecanico_solo_recibe_el_grupo_de_ordenes_detenidas', async () => {
  for (const token of [ctx.tokens.mecanico, tokenMecanicoB]) {
    const { cuerpo } = await avisosDe(token);
    expect(cuerpo.grupos.every((g) => g.tipo === 'ORDEN_DETENIDA')).toBe(true);
    const ordenes = cuerpo.grupos.flatMap((g) => g.avisos).map((a) => Number(a.clave.split(':')[1]));
    if (ordenes.length === 0) continue;
    const filas = await sql(
      `SELECT DISTINCT mechanic_id FROM service_orders WHERE id IN (${ordenes.map(() => '?').join(',')})`,
      ordenes,
    );
    expect(filas.map((f) => f.mechanic_id)).toEqual([
      token === tokenMecanicoB ? ids.mecanicoB : ids.mecanicoA,
    ]);
  }
});

test('recepcion_recibe_mantenimientos_citas_y_ordenes_pero_no_stock', async () => {
  const { avisos } = await avisosDe(ctx.tokens.recepcion);
  expect(avisos.some((a) => a.clave.startsWith(`MANT_VENCIDO:${ids.vencido}:`))).toBe(true);
  expect(avisoPorClave(avisos, `CITA_HOY:${ids.cita}:${fecha(0)}`)).toBeDefined();
  expect(avisoPorClave(avisos, `ORDEN_DETENIDA:${ids.sinMecanico}:RECIBIDO`)).toBeDefined();
  expect(avisos.some((a) => a.tipo.startsWith('STOCK_'))).toBe(false);
});

test('admin_recibe_los_seis_tipos_de_aviso', async () => {
  const { cuerpo } = await avisosDe(ctx.tokens.admin);
  const tipos = cuerpo.grupos.map((g) => g.tipo);
  for (const tipo of ['MANT_VENCIDO', 'ORDEN_DETENIDA', 'STOCK_AGOTADO', 'STOCK_BAJO', 'CITA_HOY', 'MANT_PROXIMO']) {
    expect(tipos).toContain(tipo);
  }
});

test('ningun_aviso_trae_importes_para_ningun_rol_SC_002', async () => {
  for (const token of [ctx.tokens.admin, ctx.tokens.recepcion, ctx.tokens.mecanico, tokenMecanicoB]) {
    const { cuerpo } = await avisosDe(token);
    expect(JSON.stringify(cuerpo)).not.toMatch(CLAVES_DE_DINERO);
  }
});

test('el_contador_coincide_con_el_listado', async () => {
  // Se usa el mecánico B, creado por esta suite: sus avisos no cambian por las
  // órdenes que otras suites crean en paralelo.
  const { cuerpo } = await avisosDe(tokenMecanicoB);
  const conteo = await api.get('/api/notifications/count').set(bearer(tokenMecanicoB));
  expect(conteo.body).toEqual({ noLeidos: cuerpo.noLeidos });
  expect(cuerpo.noLeidos).toBe(1);
});
