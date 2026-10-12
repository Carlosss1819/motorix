// Pruebas de contrato de /api/clients: formas de respuesta, codigos y roles
// definidos en specs/001-base-clientes-vehiculos/contracts/clients.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');
});

describe('contrato GET /api/clients', () => {
  test('ADMIN y RECEPTIONIST reciben 200 con un arreglo de clientes', async () => {
    for (const token of [adminToken, receptionistToken]) {
      const response = await api.get('/api/clients').set(bearer(token));
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      if (response.body.length > 0) {
        expect(response.body[0]).toEqual(
          expect.objectContaining({
            id: expect.any(Number),
            nombre: expect.any(String),
            telefono: expect.any(String),
            estado: expect.any(String),
          }),
        );
      }
    }
  });

  test('MECHANIC recibe 403 con la forma de error (SC-002)', async () => {
    const response = await api.get('/api/clients').set(bearer(mechanicToken));
    expect(response.status).toBe(403);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: 'ROL_NO_AUTORIZADO',
    });
  });

  test('sin token se responde 401', async () => {
    const response = await api.get('/api/clients');
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});

describe('contrato POST /api/clients', () => {
  test('crea un cliente y devuelve 201 con la forma exacta', async () => {
    const response = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({
        nombre: `Cliente Contrato ${suffix}`,
        telefono: `55${suffix}`,
        email: `contrato_${suffix}@correo.com`,
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      nombre: `Cliente Contrato ${suffix}`,
      telefono: `55${suffix}`,
      email: `contrato_${suffix}@correo.com`,
      estado: 'ACTIVO',
      fechaRegistro: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
    });
  });

  test('devuelve 400 si falta el teléfono (aclaración Q3)', async () => {
    const response = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: 'Sin Teléfono' });

    expect(response.status).toBe(400);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
    expect(response.body.error.mensaje).toContain('El teléfono es obligatorio');
  });

  test('devuelve 400 si falta el nombre', async () => {
    const response = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ telefono: '5599990000' });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('El nombre es obligatorio');
  });
});

describe('contrato GET /api/clients/:id', () => {
  test('devuelve 200 con el cliente y su arreglo de vehiculos', async () => {
    const creator = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Detalle Contrato ${suffix}`, telefono: `56${suffix}` });
    expect(creator.status).toBe(201);

    const response = await api
      .get(`/api/clients/${creator.body.id}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: creator.body.id,
        nombre: `Detalle Contrato ${suffix}`,
        vehiculos: expect.any(Array),
      }),
    );
  });

  test('devuelve 404 con la forma de error para un id inexistente', async () => {
    const response = await api.get('/api/clients/99999999').set(bearer(adminToken));
    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});
