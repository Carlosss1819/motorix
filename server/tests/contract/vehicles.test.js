// Pruebas de contrato de /api/vehicles: propietario obligatorio (RN-1), placas y VIN
// únicos (FR-023) y formas de respuesta de contracts/vehicles.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let mechanicToken;
let suffix;
let clientId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const cliente = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Dueño Vehiculos ${suffix}`, telefono: `57${suffix}` });
  clientId = cliente.body.id;
});

const baseVehicle = () => ({
  clienteId: clientId,
  marca: 'Nissan',
  modelo: 'Versa',
  anio: 2021,
  placas: `CT${suffix}`,
  vin: suffix,
  kilometrajeActual: 42000,
});

describe('contrato POST /api/vehicles', () => {
  test('crea un vehiculo y devuelve 201 con la forma exacta', async () => {
    const response = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send(baseVehicle());

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      clienteId: clientId,
      dueno: expect.any(String),
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2021,
      placas: expect.any(String),
      vin: expect.any(String),
      kilometrajeActual: 42000,
    });
  });

  test('devuelve 400 con "Seleccione el propietario" sin clienteId (RN-1)', async () => {
    const withoutOwner = { ...baseVehicle() };
    delete withoutOwner.clienteId;
    const response = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send(withoutOwner);

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('Seleccione el propietario');
  });

  test('devuelve 404 si el propietario no existe', async () => {
    const response = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), clienteId: 99999999 });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('PROPIETARIO_INEXISTENTE');
  });

  test('devuelve 409 si las placas ya están registradas (FR-023)', async () => {
    const first = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), placas: `PC${suffix}`, vin: null, kilometrajeActual: 10 });
    expect(first.status).toBe(201);

    const repeated = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), placas: `PC${suffix}`, vin: null, kilometrajeActual: 20 });

    expect(repeated.status).toBe(409);
    expect(repeated.body.error.codigo).toBe('PLACAS_EN_USO');
  });

  test('devuelve 409 si el VIN ya está registrado (FR-023)', async () => {
    const firstVin = `V${suffix}`;
    const first = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), placas: `V1${suffix}`, vin: firstVin });
    expect(first.status).toBe(201);

    const repeated = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), placas: `V2${suffix}`, vin: firstVin });

    expect(repeated.status).toBe(409);
    expect(repeated.body.error.codigo).toBe('VIN_EN_USO');
  });

  test('devuelve 400 si el kilometraje es negativo', async () => {
    const response = await api
      .post('/api/vehicles')
      .set(bearer(adminToken))
      .send({ ...baseVehicle(), kilometrajeActual: -5 });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('El kilometraje no puede ser negativo');
  });

  test('MECHANIC recibe 403', async () => {
    const response = await api
      .post('/api/vehicles')
      .set(bearer(mechanicToken))
      .send(baseVehicle());
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('sin token se responde 401', async () => {
    const response = await api.post('/api/vehicles').send(baseVehicle());
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});

describe('contrato GET /api/vehicles y /:id', () => {
  test('lista vehiculos con la forma del contrato', async () => {
    const response = await api.get('/api/vehicles').set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    if (response.body.length > 0) {
      expect(response.body[0]).toEqual(
        expect.objectContaining({
          id: expect.any(Number),
          clienteId: expect.any(Number),
          marca: expect.any(String),
          placas: expect.any(String),
          kilometrajeActual: expect.any(Number),
        }),
      );
    }
  });

  test('filtra por clienteId', async () => {
    const response = await api
      .get(`/api/vehicles?clienteId=${clientId}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    response.body.forEach((vehicle) => {
      expect(vehicle.clienteId).toBe(clientId);
    });
  });

  test('el detalle de un vehiculo devuelve 200 con su propietario', async () => {
    const lista = await api.get('/api/vehicles').set(bearer(adminToken));
    const first = lista.body[0];

    const response = await api
      .get(`/api/vehicles/${first.id}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body.dueno).toBeTruthy();
  });

  test('un id inexistente devuelve 404 con la forma de error', async () => {
    const response = await api.get('/api/vehicles/99999999').set(bearer(adminToken));
    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});
