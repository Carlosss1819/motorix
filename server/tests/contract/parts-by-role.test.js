// Pruebas de contrato de los precios del catálogo por rol (Sprint 5, US5,
// FR-024, FR-025, FR-036, SC-004): `precioCompra` solo para ADMIN,
// `precioVenta` para ADMIN y RECEPTIONIST y ningún precio para MECHANIC. La
// clave se OMITE; no se manda null (R-10).
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/parts.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';

let ctx;
let partId;
let codigo;

const CAMPOS_SIN_IMPORTES = [
  'activa',
  'categoria',
  'codigo',
  'id',
  'marca',
  'nombre',
  'stockActual',
  'stockBajo',
  'stockMinimo',
];

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Precios por rol');
  partId = await ctx.crearRefaccion({ precioVenta: 320, precioCompra: 180 });
  const detalle = await api.get(`/api/parts/${partId}`).set(bearer(ctx.tokens.admin));
  codigo = detalle.body.codigo;
});

async function detallePor(token) {
  const r = await api.get(`/api/parts/${partId}`).set(bearer(token));
  expect(r.status).toBe(200);
  return r.body;
}

async function listadoPor(token) {
  const r = await api
    .get('/api/parts')
    .query({ buscar: codigo })
    .set(bearer(token));
  expect(r.status).toBe(200);
  expect(r.body.elementos).toHaveLength(1);
  return r.body.elementos[0];
}

describe.each([
  ['detalle', detallePor],
  ['listado', listadoPor],
])('GET /api/parts (%s)', (_vista, leer) => {
  test('ADMIN_recibe_precioCompra_y_precioVenta', async () => {
    const parte = await leer(ctx.tokens.admin);
    expect(parte.precioCompra).toBe(180);
    expect(parte.precioVenta).toBe(320);
  });

  test('RECEPTIONIST_recibe_solo_precioVenta', async () => {
    const parte = await leer(ctx.tokens.recepcion);
    expect(parte).not.toHaveProperty('precioCompra');
    expect(parte.precioVenta).toBe(320);
  });

  test('MECHANIC_no_recibe_ninguna_clave_de_precio_pero_si_los_demas_campos', async () => {
    const parte = await leer(ctx.tokens.mecanico);
    expect(parte).not.toHaveProperty('precioCompra');
    expect(parte).not.toHaveProperty('precioVenta');
    expect(Object.keys(parte).sort()).toEqual(CAMPOS_SIN_IMPORTES);
    expect(parte).toMatchObject({
      id: partId,
      codigo,
      categoria: 'Pruebas',
      marca: 'Motorix',
      stockActual: 50,
      stockMinimo: 1,
      stockBajo: false,
      activa: true,
    });
  });
});

test('FR_036_buscar_sigue_siendo_por_nombre_o_codigo_y_no_expone_precios', async () => {
  const porCodigo = await api
    .get('/api/parts')
    .query({ buscar: codigo })
    .set(bearer(ctx.tokens.mecanico));
  expect(porCodigo.body.elementos.map((p) => p.id)).toEqual([partId]);

  // Buscar un importe no encuentra la refacción: no se busca por precio.
  const porPrecio = await api
    .get('/api/parts')
    .query({ buscar: '320' })
    .set(bearer(ctx.tokens.mecanico));
  expect(porPrecio.body.elementos.map((p) => p.id)).not.toContain(partId);
  // Sprint 6 (H-S6-04): se revisan las CLAVES de precio, no cualquier texto;
  // el nombre de una refacción de otra suite («Refacción con precio …») y su
  // código con «320» hacían fallar la prueba de forma intermitente.
  expect(JSON.stringify(porPrecio.body)).not.toMatch(/"precio\w*"\s*:/i);
  for (const elemento of porPrecio.body.elementos) {
    expect(Object.keys(elemento).filter((k) => /precio/i.test(k))).toEqual([]);
  }
});
