// Pruebas de contrato del historial del vehículo (US1): GET
// /api/vehicles/:id/history — 200 paginado, 401 sin token, 403 por rol y 404
// de vehículo. Fuente de verdad:
// specs/003-historial-inventario/contracts/history.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
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
    .send({ nombre: `Historial ${suffix}`, telefono: `74${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Mazda',
      modelo: '3',
      anio: 2021,
      placas: `HD${suffix}`,
      kilometrajeActual: 1000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('contrato GET /api/vehicles/:id/history', () => {
  test('responde 200 paginado con la forma del contrato', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('elementos');
    expect(response.body).toHaveProperty('pagina', 1);
    expect(response.body).toHaveProperty('paginas');
    expect(response.body).toHaveProperty('total');
    expect(Array.isArray(response.body.elementos)).toBe(true);
  });

  test('responde 401 sin token', async () => {
    const response = await api.get(`/api/vehicles/${vehicleId}/history`);
    expect(response.status).toBe(401);
  });

  test('los tres roles autenticados pueden consultar el historial (FR-004)', async () => {
    for (const token of [adminToken, receptionistToken, mechanicToken]) {
      const response = await api
        .get(`/api/vehicles/${vehicleId}/history`)
        .set(bearer(token));
      expect(response.status).toBe(200);
    }
  });

  test('responde 404 cuando el vehículo no existe', async () => {
    const response = await api
      .get('/api/vehicles/999999/history')
      .set(bearer(adminToken));
    expect(response.status).toBe(404);
  });
});
