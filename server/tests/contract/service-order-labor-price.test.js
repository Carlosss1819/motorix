// Pruebas de contrato del precio de la mano de obra (Sprint 5, FR-032): la
// misma regla que los precios del catálogo (numérico, ≥ 0, máximo dos
// decimales y ≤ 999,999.99). El precio sigue siendo opcional.
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/service-orders.md.
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';

let ctx;
let ordenId;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Mano de obra');
  ordenId = await ctx.crearOrden();
});

test.each([
  ['negativo', -5],
  ['no_numerico', 'abc'],
  ['con_3_decimales', 120.555],
  ['mayor_al_tope', 1000000],
])('rechaza_un_precio_%s_con_400_VALIDACION', async (_caso, precio) => {
  const response = await ctx.agregarServicio(ordenId, precio);
  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('VALIDACION');
  expect(response.body.error.mensaje).toContain('El precio de la mano de obra');
});

test('acepta_un_servicio_sin_precio', async () => {
  const response = await ctx.agregarServicio(ordenId, undefined);
  expect(response.status).toBe(201);
  expect(response.body.manoDeObra.precio).toBeNull();
});

test('acepta_999999_99', async () => {
  const response = await ctx.agregarServicio(ordenId, 999999.99);
  expect(response.status).toBe(201);
  expect(response.body.manoDeObra.precio).toBe(999999.99);
});
