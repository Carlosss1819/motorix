// Pruebas de integracion de vehiculos (US5): alta con propietario obligatorio (RN-1),
// asociacion cliente-vehiculo y busqueda por placas/modelo.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;
let clientId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');

  const cliente = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Dueño Flujo ${suffix}`, telefono: `64${suffix}` });
  expect(cliente.status).toBe(201);
  clientId = cliente.body.id;
});

describe('flujo de registro de vehiculos (US5)', () => {
  let vehicleId;

  test('el vehiculo creado queda asociado a su propietario (FR-014)', async () => {
    const created = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2019,
        placas: `FL${suffix}`,
        vin: suffix,
        kilometrajeActual: 78000,
      });

    expect(created.status).toBe(201);
    expect(created.body.clienteId).toBe(clientId);
    expect(created.body.dueno).toContain('Dueño Flujo');
    vehicleId = created.body.id;

    // El detalle del cliente lista el vehiculo (US3 x US5 integrados).
    const detail = await api
      .get(`/api/clients/${clientId}`)
      .set(bearer(adminToken));
    expect(detail.status).toBe(200);
    expect(detail.body.vehiculos).toHaveLength(1);
    expect(detail.body.vehiculos[0].id).toBe(vehicleId);
    expect(detail.body.vehiculos[0].kilometrajeActual).toBe(78000);
  });

  test('la busqueda por placas encuentra el vehiculo', async () => {
    const listing = await api
      .get(`/api/vehicles?buscar=${suffix}`)
      .set(bearer(adminToken));

    expect(listing.status).toBe(200);
    expect(listing.body.some((v) => v.id === vehicleId)).toBe(true);
  });

  test('RN-1: rechaza el alta de vehiculo sin propietario', async () => {
    const response = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({
        marca: 'Mazda',
        modelo: '3',
        anio: 2022,
        placas: `SP${suffix}`,
        vin: null,
        kilometrajeActual: 0,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('Seleccione el propietario');
  });
});

describe('actualizacion de kilometraje (US4/US5)', () => {
  test('el kilometraje se actualiza y se refleja en el listado', async () => {
    const listing = await api
      .get(`/api/vehicles?clienteId=${clientId}`)
      .set(bearer(adminToken));
    const vehicle = listing.body[0];

    const actualizado = await api
      .put(`/api/vehicles/${vehicle.id}`)
      .set(bearer(adminToken))
      .send({
        marca: vehicle.marca,
        modelo: vehicle.modelo,
        anio: vehicle.anio,
        placas: vehicle.placas,
        vin: vehicle.vin,
        kilometrajeActual: 79500,
      });

    expect(actualizado.status).toBe(200);
    expect(actualizado.body.kilometrajeActual).toBe(79500);

    // El propietario NO se cambia en este sprint.
    expect(actualizado.body.clienteId).toBe(clientId);
  });
});
