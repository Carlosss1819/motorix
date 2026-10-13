// Pruebas de contrato del filtro de stock bajo (US8, Sprint 3): el campo
// `stockBajo` calculado en cada refacción, `?stockBajo=true` como único
// filtro válido y el caso `stock_minimo = 0` que nunca alerta (FR-020,
// FR-021, R-10, V4). Fuente de verdad:
// specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;
let contador = 0;

// Crea una refacción propia de la corrida con el stock y el mínimo indicados.
async function crearRefaccion({ stockInicial, stockMinimo }) {
  contador += 1;
  const response = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `LOW-${suffix}-${contador}`,
      nombre: `Refacción de alerta ${suffix} ${contador}`,
      categoria: 'Frenos',
      stockInicial,
      stockMinimo,
    });
  expect(response.status).toBe(201);
  return response.body;
}

// Listado de las refacciones de esta corrida con el filtro de alertas.
async function listarEnAlerta() {
  const response = await api
    .get('/api/parts')
    .query({
      buscar: `Refacción de alerta ${suffix}`,
      stockBajo: 'true',
      porPagina: 50,
    })
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  return response.body;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

describe('GET /api/parts con el campo stockBajo calculado (FR-020)', () => {
  test('marca stockBajo cuando el stock llega al mínimo', async () => {
    const enAlerta = await crearRefaccion({ stockInicial: 2, stockMinimo: 5 });
    expect(enAlerta.stockBajo).toBe(true);

    const conHolgura = await crearRefaccion({
      stockInicial: 6,
      stockMinimo: 5,
    });
    expect(conHolgura.stockBajo).toBe(false);

    const justoEnElMinimo = await crearRefaccion({
      stockInicial: 4,
      stockMinimo: 4,
    });
    expect(justoEnElMinimo.stockBajo).toBe(true);
  });

  test('un stock mínimo de 0 nunca se marca como alerta (V4, FR-021)', async () => {
    const sinMinimo = await crearRefaccion({ stockInicial: 0, stockMinimo: 0 });
    expect(sinMinimo.stockBajo).toBe(false);

    const conStockCero = await crearRefaccion({
      stockInicial: 0,
      stockMinimo: 0,
    });
    expect(conStockCero.stockBajo).toBe(false);
  });
});

describe('GET /api/parts?stockBajo=true (R-10)', () => {
  test('devuelve solo las refacciones en alerta y todas marcadas', async () => {
    const alerta = await crearRefaccion({ stockInicial: 1, stockMinimo: 3 });
    const sinAlerta = await crearRefaccion({ stockInicial: 9, stockMinimo: 3 });

    const body = await listarEnAlerta();
    const codigos = body.elementos.map((part) => part.codigo);

    expect(codigos).toContain(alerta.codigo);
    expect(codigos).not.toContain(sinAlerta.codigo);
    expect(body.elementos.length).toBeGreaterThan(0);
    for (const part of body.elementos) {
      expect(part.stockBajo).toBe(true);
    }
  });

  test('la combinación con la búsqueda sigue devolendo solo alertas', async () => {
    const buscada = await crearRefaccion({ stockInicial: 2, stockMinimo: 4 });

    const response = await api
      .get('/api/parts')
      .query({ buscar: buscada.codigo, stockBajo: 'true' })
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body.elementos).toHaveLength(1);
    expect(response.body.elementos[0].codigo).toBe(buscada.codigo);
    expect(response.body.elementos[0].stockBajo).toBe(true);
  });

  test('un valor distinto de true responde 400 en español', async () => {
    const response = await api
      .get('/api/parts')
      .query({ stockBajo: 'false' })
      .set(bearer(adminToken));

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain('stock bajo');
  });
});
