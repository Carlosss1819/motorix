// Pruebas de contrato de los precios del catálogo (Sprint 5, US1): validación
// de dos decimales y tope (FR-003), advertencia cuando el precio de venta es
// menor que el de compra (FR-004, D-07), categoría obligatoria y marca
// opcional (FR-001) y escritura solo para ADMIN (FR-002).
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let contador = 0;

function nuevaRefaccion(extra = {}) {
  contador += 1;
  return {
    codigo: `PRC-${suffix}-${contador}`.slice(0, 30),
    nombre: `Refacción de precios ${suffix} ${contador}`,
    categoria: 'Frenos',
    ...extra,
  };
}

async function alta(body, token = adminToken) {
  return api.post('/api/parts').set(bearer(token)).send(body);
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');
});

describe('validación de precios del catálogo (FR-003)', () => {
  test.each([
    ['precioVenta', 10.555, 'El precio de venta'],
    ['precioCompra', 1000000, 'El precio de compra'],
    ['precioVenta', -1, 'El precio de venta'],
    ['precioCompra', 'abc', 'El precio de compra'],
  ])('rechaza_%s_%p_con_400_VALIDACION_nombrando_el_campo', async (campo, valor, nombre) => {
    const response = await alta(nuevaRefaccion({ [campo]: valor }));
    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain(nombre);
  });

  test('acepta_999999_99_como_precio_maximo', async () => {
    const response = await alta(
      nuevaRefaccion({ precioCompra: 999999.99, precioVenta: 999999.99 }),
    );
    expect(response.status).toBe(201);
    expect(response.body.precioVenta).toBe(999999.99);
    expect(response.body.advertencias).toBeUndefined();
  });

  test('la_edicion_valida_igual_que_el_alta', async () => {
    const creada = await alta(nuevaRefaccion({ precioVenta: 100 }));
    expect(creada.status).toBe(201);
    const response = await api
      .put(`/api/parts/${creada.body.id}`)
      .set(bearer(adminToken))
      .send({ precioVenta: 12.345 });
    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
  });
});

describe('advertencia de precio de venta menor que el de compra (FR-004, D-07)', () => {
  test('el_alta_se_guarda_con_la_advertencia', async () => {
    const response = await alta(nuevaRefaccion({ precioCompra: 200, precioVenta: 150 }));
    expect(response.status).toBe(201);
    expect(response.body.precioVenta).toBe(150);
    expect(response.body.advertencias).toEqual([
      {
        codigo: 'PRECIO_VENTA_MENOR_A_COMPRA',
        mensaje: 'El precio de venta es menor que el precio de compra',
      },
    ]);
  });

  test('la_edicion_se_guarda_con_la_advertencia', async () => {
    const creada = await alta(nuevaRefaccion({ precioCompra: 100, precioVenta: 180 }));
    expect(creada.body.advertencias).toBeUndefined();
    const response = await api
      .put(`/api/parts/${creada.body.id}`)
      .set(bearer(adminToken))
      .send({ precioVenta: 90 });
    expect(response.status).toBe(200);
    expect(response.body.precioVenta).toBe(90);
    expect(response.body.advertencias[0].codigo).toBe('PRECIO_VENTA_MENOR_A_COMPRA');
  });
});

describe('categoría y marca (FR-001)', () => {
  test('la_categoria_es_obligatoria', async () => {
    const { categoria, ...sinCategoria } = nuevaRefaccion();
    expect(categoria).toBeDefined();
    const response = await alta(sinCategoria);
    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('La categoría es obligatoria');
  });

  test('la_marca_es_opcional', async () => {
    const response = await alta(nuevaRefaccion());
    expect(response.status).toBe(201);
    expect(response.body.marca).toBeNull();
  });
});

describe('permisos de escritura (FR-002)', () => {
  test.each([
    ['recepción', () => receptionistToken],
    ['mecánico', () => mechanicToken],
  ])('%s_recibe_403_al_crear_o_editar', async (_rol, token) => {
    const creada = await alta(nuevaRefaccion({ precioVenta: 50 }));
    expect(creada.status).toBe(201);

    const altaAjena = await alta(nuevaRefaccion({ precioVenta: 50 }), token());
    expect(altaAjena.status).toBe(403);

    const edicion = await api
      .put(`/api/parts/${creada.body.id}`)
      .set(bearer(token()))
      .send({ precioVenta: 60 });
    expect(edicion.status).toBe(403);
  });
});
