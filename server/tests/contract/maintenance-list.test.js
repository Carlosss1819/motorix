// Pruebas de contrato del listado de mantenimientos (US4, Sprint 3):
// `GET /api/maintenance` con `?estado=` (estado CALCULADO), `?vehiculoId=`,
// `?buscar=` por tipo o placas, paginación R-10 y la matriz de permisos
// (200 para los tres roles, 403 de escritura para recepción; FR-004,
// clarificación 4, HU4/V3).
// Fuente de verdad: specs/003-historial-inventario/contracts/maintenance.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let vehicleId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `MantLista ${suffix}`, telefono: `79${suffix}` });
  expect(client.status).toBe(201);

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: client.body.id,
      marca: 'Volkswagen',
      modelo: 'Gol',
      anio: 2019,
      placas: `ML${suffix}`,
      kilometrajeActual: 50000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;

  // Tres mantenimientos: uno vencido, uno próximo y uno normal.
  const creados = [
    { tipoServicio: 'Frenos vencidos', kilometrajeObjetivo: 40000 },
    { tipoServicio: 'Afinamiento proximo', kilometrajeObjetivo: 50300 },
    { tipoServicio: 'Llantas posteriores', fechaObjetivo: '2030-01-01' },
  ];
  for (const extra of creados) {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({ vehiculoId: vehicleId, tipoServicio: extra.tipoServicio, ...extra });
    expect(response.status).toBe(201);
  }
});

describe('GET /api/maintenance — filtros (HU4, R-04)', () => {
  test('?vehiculoId= devuelve solo los del vehículo y con vehiculo, placas y cliente', async () => {
    const response = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(3);
    for (const item of response.body.elementos) {
      expect(item.vehiculoId).toBe(vehicleId);
      expect(item.vehiculo).toContain('Volkswagen');
      expect(item.placas).toBe(`ML${suffix}`);
      expect(typeof item.cliente).toBe('string');
    }
  });

  test('?estado= filtra sobre el estado calculado, no sobre un valor guardado', async () => {
    const vencidos = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&estado=vencido`)
      .set(bearer(receptionistToken));
    expect(vencidos.status).toBe(200);
    expect(vencidos.body.total).toBe(1);
    expect(vencidos.body.elementos[0].tipoServicio).toBe('Frenos vencidos');
    expect(vencidos.body.elementos[0].estado).toBe('VENCIDO');

    const proximos = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&estado=PROXIMO`)
      .set(bearer(mechanicToken));
    expect(proximos.status).toBe(200);
    expect(proximos.body.total).toBe(1);
    expect(proximos.body.elementos[0].tipoServicio).toBe('Afinamiento proximo');

    const normales = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&estado=normal`)
      .set(bearer(adminToken));
    expect(normales.status).toBe(200);
    expect(normales.body.total).toBe(1);
    expect(normales.body.elementos[0].tipoServicio).toBe('Llantas posteriores');
  });

  test('?buscar= filtra por tipo de servicio o por placas', async () => {
    const porTipo = await api
      .get('/api/maintenance?buscar=Frenos')
      .set(bearer(receptionistToken));
    expect(porTipo.status).toBe(200);
    expect(
      porTipo.body.elementos.some((item) => item.tipoServicio === 'Frenos vencidos'),
    ).toBe(true);

    const porPlacas = await api
      .get(`/api/maintenance?buscar=ML${suffix}`)
      .set(bearer(receptionistToken));
    expect(porPlacas.status).toBe(200);
    expect(porPlacas.body.total).toBe(3);
  });

  test('la paginación R-10 recorta la página y reporta el total real', async () => {
    const response = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&porPagina=2&pagina=2`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.pagina).toBe(2);
    expect(response.body.paginas).toBe(2);
    expect(response.body.total).toBe(3);
    expect(response.body.elementos).toHaveLength(1);
  });
});

describe('permisos del listado (HU4, V3, clarificación 4)', () => {
  test('los tres roles reciben 200 en el listado', async () => {
    for (const token of [adminToken, receptionistToken, mechanicToken]) {
      const response = await api.get('/api/maintenance').set(bearer(token));
      expect(response.status).toBe(200);
    }
  });

  test('recepcion consulta pero sus escrituras responden 403', async () => {
    const lectura = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(receptionistToken));
    expect(lectura.status).toBe(200);

    const escritura = await api
      .post('/api/maintenance')
      .set(bearer(receptionistToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Revisión de recepción',
        fechaObjetivo: '2026-12-31',
      });
    expect(escritura.status).toBe(403);
    expect(escritura.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});
