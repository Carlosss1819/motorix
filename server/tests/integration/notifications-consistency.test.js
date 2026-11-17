// Coherencia de los números (Sprint 6, SC-003, FR-008, T023 y T029): el
// centro de avisos cuenta lo mismo que la lista de Mantenimientos, el panel
// y el filtro «solo stock bajo» de Refacciones, con el reloj fijo (M3).
//
// Otras suites crean datos al mismo tiempo. Para no comparar números de dos
// momentos distintos, cada comparación toma el centro, luego la otra fuente y
// otra vez el centro; solo compara cuando el centro no cambió entre ambas
// lecturas (lectura estable), con hasta 8 intentos.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  avisosDe,
} from '../helpers/notifications-fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Coherencia');
  // Al menos uno de cada tipo para que la comparación no sea 0 = 0.
  await ctx.mantenimiento({ fechaObjetivo: fecha(-3) });
  await ctx.mantenimiento({ fechaObjetivo: fecha(10) });
  await ctx.cita({ dia: 0, hora: '19:00:00' });
  await ctx.cita({ dia: 0, hora: '20:00:00', estado: 'RECIBIDA' });
  await ctx.refaccion({ existencia: 1, minimo: 4 });
  await ctx.refaccion({ existencia: 0, minimo: 2 });
});

afterAll(() => liberarReloj());

const contar = (avisos, ...tipos) => avisos.filter((a) => tipos.includes(a.tipo)).length;

async function compararEstable(delCentro, deLaOtraFuente) {
  let ultimo;
  for (let intento = 0; intento < 8; intento += 1) {
    const antes = delCentro((await avisosDe(ctx.tokens.admin)).avisos);
    const otra = await deLaOtraFuente();
    const despues = delCentro((await avisosDe(ctx.tokens.admin)).avisos);
    ultimo = { antes, otra, despues };
    if (antes === despues) {
      expect(otra).toBe(antes);
      expect(antes).toBeGreaterThan(0);
      return;
    }
  }
  throw new Error(`Sin lectura estable: ${JSON.stringify(ultimo)}`);
}

async function totalMantenimientos(estado) {
  const r = await api
    .get('/api/maintenance')
    .query({ estado, porPagina: 50 })
    .set(bearer(ctx.tokens.admin));
  expect(r.status).toBe(200);
  return r.body.total;
}

async function panel() {
  const r = await api
    .get('/api/dashboard')
    .query({ fecha: fecha(0) })
    .set(bearer(ctx.tokens.admin));
  expect(r.status).toBe(200);
  return r.body;
}

test('mantenimientos_vencidos_del_centro_igual_a_la_lista_de_mantenimientos_SC_003', async () => {
  await compararEstable(
    (avisos) => contar(avisos, 'MANT_VENCIDO'),
    () => totalMantenimientos('vencido'),
  );
});

test('mantenimientos_proximos_del_centro_igual_a_la_lista_de_mantenimientos_SC_003', async () => {
  await compararEstable(
    (avisos) => contar(avisos, 'MANT_PROXIMO'),
    () => totalMantenimientos('proximo'),
  );
});

test('citas_de_hoy_del_centro_igual_a_citas_hoy_del_panel_consultado_despues_SC_003', async () => {
  await compararEstable(
    (avisos) => contar(avisos, 'CITA_HOY'),
    async () => (await panel()).citas.hoy,
  );
});

test('avisos_de_stock_igual_al_panel_y_al_filtro_solo_stock_bajo_FR_008', async () => {
  await compararEstable(
    (avisos) => contar(avisos, 'STOCK_BAJO', 'STOCK_AGOTADO'),
    async () => (await panel()).alertasInventario.stockBajo,
  );
  await compararEstable(
    (avisos) => contar(avisos, 'STOCK_BAJO', 'STOCK_AGOTADO'),
    async () => {
      const r = await api
        .get('/api/parts')
        .query({ stockBajo: true, porPagina: 50 })
        .set(bearer(ctx.tokens.admin));
      expect(r.status).toBe(200);
      return r.body.total;
    },
  );
});
