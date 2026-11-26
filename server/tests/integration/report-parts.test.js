// Margen de refacciones y rotación (Sprint 7, Entrega B, US6, FR-035, FR-036).
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';
import { ventanaLibre, marcarTerminada, insertarSalida, addDays } from '../helpers/report-fixtures.js';

let ctx;
let rango;
let partA;
let partB;
let partC;
let partD;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Reporte refacciones');
  rango = await ventanaLibre(30, 3);

  // A: con precio de compra; B: sin precio de compra.
  partA = await ctx.crearRefaccion({ precioVenta: 100.1, precioCompra: 60.25, stock: 50 });
  partB = await ctx.crearRefaccion({ precioVenta: 50, stock: 50 });

  const o1 = await ctx.crearOrden();
  expect((await ctx.agregarRefaccion(o1, partA, 3)).status).toBe(201);
  expect((await ctx.agregarRefaccion(o1, partB, 2)).status).toBe(201);
  await marcarTerminada(o1, `${rango.desde} 10:00:00`);

  // Segunda orden con el precio de venta ya cambiado: la línea congela 110.
  expect((await ctx.cambiarPrecioVenta(partA, 110)).status).toBe(200);
  const o2 = await ctx.crearOrden();
  expect((await ctx.agregarRefaccion(o2, partA, 1)).status).toBe(201);
  await marcarTerminada(o2, `${rango.hasta} 18:00:00`);

  // Orden terminada fuera del rango: no cuenta.
  const o3 = await ctx.crearOrden();
  expect((await ctx.agregarRefaccion(o3, partA, 7)).status).toBe(201);
  await marcarTerminada(o3, `${addDays(rango.desde, -1)} 23:59:59`);

  // Rotación: C con existencia 10 y D sin existencia.
  partC = await ctx.crearRefaccion({ precioVenta: 10, stock: 10 });
  partD = await ctx.crearRefaccion({ precioVenta: 10, stock: 1 });
  await sql('UPDATE parts SET stock_current = 0 WHERE id = ?', [partD]);
  await insertarSalida(partC, 3, `${rango.desde} 08:00:00`);
  await insertarSalida(partC, 2, `${rango.hasta} 23:59:59`);
  await insertarSalida(partC, 5, `${addDays(rango.hasta, 1)} 00:00:00`);
  await insertarSalida(partD, 4, `${rango.desde} 12:00:00`);
});

function consultar(reporte) {
  return api
    .get(`/api/reports/${reporte}?desde=${rango.desde}&hasta=${rango.hasta}`)
    .set(bearer(ctx.tokens.admin));
}

test('test_margen_por_refaccion_con_precio_congelado_y_costo_de_compra', async () => {
  const response = await consultar('refacciones');
  expect(response.status).toBe(200);
  const [a, b] = response.body.elementos;
  expect(response.body.elementos).toHaveLength(2);
  expect(a).toMatchObject({
    refaccionId: partA,
    cantidad: 4,
    costo: 241,
    venta: 410.3,
    margen: 169.3,
    aviso: null,
  });
  expect(Object.keys(a).sort()).toEqual(
    ['aviso', 'cantidad', 'codigo', 'costo', 'margen', 'nombre', 'refaccionId', 'venta'],
  );
  expect(b).toMatchObject({
    refaccionId: partB,
    cantidad: 2,
    costo: null,
    venta: 100,
    margen: null,
    aviso: 'sin costo registrado',
  });
});

test('test_las_lineas_sin_costo_registrado_no_entran_en_los_totales', async () => {
  const response = await consultar('refacciones');
  expect(response.body.totales).toEqual({ costo: 241, venta: 410.3, margen: 169.3 });
});

test('test_rotacion_es_salidas_entre_existencia_y_sin_existencia_si_es_cero', async () => {
  const response = await consultar('rotacion');
  expect(response.status).toBe(200);
  expect(response.body.elementos).toEqual([
    expect.objectContaining({ refaccionId: partC, salidas: 5, existencia: 10, rotacion: 0.5, aviso: null }),
    expect.objectContaining({ refaccionId: partD, salidas: 4, existencia: 0, rotacion: null, aviso: 'sin existencia' }),
  ]);
});
