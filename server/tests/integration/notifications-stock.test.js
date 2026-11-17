// Avisos de stock (Sprint 6, US3, FR-004, FR-007, FR-008, FR-016): la misma
// regla del panel y del filtro «solo stock bajo», solo para ADMIN y sin
// precios.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  avisosDe,
  avisoPorClave,
  CLAVES_DE_DINERO,
} from '../helpers/notifications-fixtures.js';

let ctx;
const ids = {};

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Avisos US3');
  ids.bajo = await ctx.refaccion({ existencia: 2, minimo: 5 });
  ids.igual = await ctx.refaccion({ existencia: 5, minimo: 5 });
  ids.agotado = await ctx.refaccion({ existencia: 0, minimo: 3 });
  ids.minimoCero = await ctx.refaccion({ existencia: 0, minimo: 0 });
  ids.suficiente = await ctx.refaccion({ existencia: 10, minimo: 3 });
  ids.inactiva = await ctx.refaccion({ existencia: 1, minimo: 4, activa: 0 });
});

afterAll(() => liberarReloj());

test('stock_bajo_y_agotado_generan_su_aviso_con_destino_a_la_refaccion', async () => {
  const { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(avisos, `STOCK_BAJO:${ids.bajo}`)).toMatchObject({
    tipo: 'STOCK_BAJO',
    fechaReferencia: fecha(0),
    destino: { pantalla: 'REFACCION', id: ids.bajo },
  });
  expect(avisoPorClave(avisos, `STOCK_BAJO:${ids.igual}`)).toBeDefined();
  expect(avisoPorClave(avisos, `STOCK_AGOTADO:${ids.agotado}`)).toMatchObject({
    tipo: 'STOCK_AGOTADO',
    fechaReferencia: fecha(0),
  });
  expect(avisoPorClave(avisos, `STOCK_BAJO:${ids.bajo}`).descripcion).toMatch(/2 .*mínimo 5/);
});

test('minimo_cero_y_existencia_suficiente_no_generan_aviso', async () => {
  const { avisos } = await avisosDe(ctx.tokens.admin);
  const claves = avisos.map((a) => a.clave);
  for (const id of [ids.minimoCero, ids.suficiente]) {
    expect(claves).not.toContain(`STOCK_BAJO:${id}`);
    expect(claves).not.toContain(`STOCK_AGOTADO:${id}`);
  }
});

test('una_refaccion_inactiva_en_stock_bajo_si_genera_aviso_como_el_panel', async () => {
  const { avisos } = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(avisos, `STOCK_BAJO:${ids.inactiva}`)).toBeDefined();
});

test('recepcion_y_mecanico_no_reciben_avisos_de_stock', async () => {
  for (const token of [ctx.tokens.recepcion, ctx.tokens.mecanico]) {
    const { avisos } = await avisosDe(token);
    expect(avisos.some((a) => a.tipo.startsWith('STOCK_'))).toBe(false);
  }
});

test('los_avisos_de_stock_no_traen_precios', async () => {
  const { avisos } = await avisosDe(ctx.tokens.admin);
  const deStock = avisos.filter((a) => a.tipo.startsWith('STOCK_'));
  expect(JSON.stringify(deStock)).not.toMatch(CLAVES_DE_DINERO);
  // Los precios de las refacciones de esta prueba (compra 80.00, venta 120.00)
  // no deben aparecer como número suelto en sus avisos. Se exige que no haya
  // otro dígito alrededor para no confundirlos con partes de códigos o ids
  // generados (por ejemplo `ALR-1794868102...` o `STOCK_BAJO:9120`).
  const nuestras = deStock.filter((a) => a.descripcion.startsWith(`N6-${ctx.suffix}`));
  expect(nuestras.length).toBeGreaterThan(0);
  expect(JSON.stringify(nuestras)).not.toMatch(/(^|[^\d])(120|80)(\.0+)?(?!\d)/);
});

test('coincide_con_el_filtro_solo_stock_bajo_de_refacciones_FR_008', async () => {
  const { avisos } = await avisosDe(ctx.tokens.admin);
  const nuestras = avisos
    .filter((a) => a.tipo.startsWith('STOCK_') && a.descripcion.startsWith(`N6-${ctx.suffix}`))
    .map((a) => a.destino.id)
    .sort();
  const lista = await api
    .get(`/api/parts?stockBajo=true&buscar=N6-${ctx.suffix}&porPagina=50`)
    .set(bearer(ctx.tokens.admin));
  expect(lista.status).toBe(200);
  expect(nuestras).toEqual(lista.body.elementos.map((p) => p.id).sort());
});

test('el_total_de_avisos_de_stock_coincide_con_el_panel_FR_008', async () => {
  // Otras suites crean refacciones en paralelo: se repite la comparación
  // hasta 3 veces para que un alta concurrente entre las dos consultas no
  // cuente como diferencia. La regla comparada es la misma (WHERE_STOCK_BAJO).
  let iguales = false;
  for (let intento = 0; intento < 3 && !iguales; intento += 1) {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    const panel = await api.get('/api/dashboard').set(bearer(ctx.tokens.admin));
    const deStock = avisos.filter((a) => a.tipo.startsWith('STOCK_')).length;
    iguales = deStock === panel.body.alertasInventario.stockBajo;
  }
  expect(iguales).toBe(true);
});
