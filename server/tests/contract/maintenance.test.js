// Pruebas de contrato de los mantenimientos preventivos (US3, Sprint 3):
// POST/PUT/GET/realizar con sus códigos de error y la matriz de permisos
// (escritura ADMIN/MECHANIC, lectura los tres roles; clarificación 4).
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
    .send({ nombre: `MantContrato ${suffix}`, telefono: `77${suffix}` });
  expect(client.status).toBe(201);

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: client.body.id,
      marca: 'Kia',
      modelo: 'Rio',
      anio: 2021,
      placas: `MC${suffix}`,
      kilometrajeActual: 10000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('contrato POST /api/maintenance', () => {
  test('crea un mantenimiento con objetivo y devuelve 201 con estado calculado', async () => {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Cambio de aceite',
        fechaObjetivo: '2026-12-31',
        kilometrajeObjetivo: 15000,
        intervaloDias: 90,
        intervaloKm: 5000,
        notas: 'Usar aceite 5W30 sintético.',
      });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('id');
    expect(response.body).toHaveProperty('vehiculoId', vehicleId);
    expect(response.body).toHaveProperty('tipoServicio', 'Cambio de aceite');
    expect(response.body).toHaveProperty('antelacionDias', 30);
    expect(response.body).toHaveProperty('antelacionKm', 500);
    expect(response.body).toHaveProperty('estado');
    expect(['NORMAL', 'PROXIMO', 'VENCIDO']).toContain(response.body.estado);
  });

  test('sin fechaObjetivo ni kilometrajeObjetivo responde 400 OBJETIVO_REQUERIDO', async () => {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({ vehiculoId: vehicleId, tipoServicio: 'Rotación de llantas' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('OBJETIVO_REQUERIDO');
  });

  test('el mismo vehículo y tipo responde 409 MANTENIMIENTO_DUPLICADO', async () => {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Cambio de aceite',
        fechaObjetivo: '2026-12-31',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('MANTENIMIENTO_DUPLICADO');
  });

  test('recepcion no puede crear mantenimientos (403, FR-008)', async () => {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(receptionistToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Revisión de frenos',
        fechaObjetivo: '2026-12-31',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('responde 404 cuando el vehículo no existe', async () => {
    const response = await api
      .post('/api/maintenance')
      .set(bearer(adminToken))
      .send({
        vehiculoId: 999999,
        tipoServicio: 'Cambio de filtro',
        fechaObjetivo: '2026-12-31',
      });

    expect(response.status).toBe(404);
  });
});

describe('contrato GET /api/maintenance', () => {
  test('los tres roles pueden listar los mantenimientos (FR-004, clarificación 4)', async () => {
    for (const token of [adminToken, receptionistToken, mechanicToken]) {
      const response = await api.get('/api/maintenance').set(bearer(token));
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('elementos');
      expect(response.body).toHaveProperty('pagina');
      expect(response.body).toHaveProperty('paginas');
      expect(response.body).toHaveProperty('total');
    }
  });

  test('cada elemento trae vehículo, placas y cliente para el aviso (FR-013)', async () => {
    const response = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body.elementos.length).toBeGreaterThan(0);
    const item = response.body.elementos[0];
    expect(item).toHaveProperty('vehiculo');
    expect(item).toHaveProperty('placas');
    expect(item).toHaveProperty('cliente');
  });

  test('el detalle responde 200 y un id inexistente responde 404', async () => {
    const list = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(adminToken));
    const id = list.body.elementos[0].id;

    const ok = await api
      .get(`/api/maintenance/${id}`)
      .set(bearer(adminToken));
    expect(ok.status).toBe(200);
    expect(ok.body).toHaveProperty('id', id);

    const missing = await api.get('/api/maintenance/999999').set(bearer(adminToken));
    expect(missing.status).toBe(404);
    expect(missing.body.error.codigo).toBe('MANTENIMIENTO_NO_ENCONTRADO');
  });
});

describe('contrato PUT /api/maintenance/:id', () => {
  test('edita los campos enviados y devuelve 200 con el estado recalculado', async () => {
    const list = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(adminToken));
    const id = list.body.elementos[0].id;

    const response = await api
      .put(`/api/maintenance/${id}`)
      .set(bearer(mechanicToken))
      .send({ notas: 'Nota editada en contrato', intervaloKm: 6000 });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('notas', 'Nota editada en contrato');
    expect(response.body).toHaveProperty('intervaloKm', 6000);
  });
});

describe('contrato POST /api/maintenance/:id/realizar', () => {
  test('responde 404 cuando el mantenimiento no existe', async () => {
    const response = await api
      .post('/api/maintenance/999999/realizar')
      .set(bearer(mechanicToken))
      .send({});

    expect(response.status).toBe(404);
  });

  test('un registro sin intervalos y sin objetivos en el body responde 400 MANTENIMIENTO_SIN_INTERVALO', async () => {
    // Registro sin intervalos (RN-12) para ejercitar la renovación imposible.
    const creado = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Revisión de suspensión',
        fechaObjetivo: '2026-12-31',
      });
    expect(creado.status).toBe(201);

    const response = await api
      .post(`/api/maintenance/${creado.body.id}/realizar`)
      .set(bearer(mechanicToken))
      .send({});

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('MANTENIMIENTO_SIN_INTERVALO');
  });

  test('recepcion no puede marcar servicio realizado (403)', async () => {
    const list = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(adminToken));
    const id = list.body.elementos[0].id;

    const response = await api
      .post(`/api/maintenance/${id}/realizar`)
      .set(bearer(receptionistToken))
      .send({});

    expect(response.status).toBe(403);
  });
});
