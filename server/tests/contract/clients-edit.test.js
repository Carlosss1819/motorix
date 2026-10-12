// Pruebas de contrato de la edicion de clientes (US4): PUT /api/clients/:id.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let mechanicToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');
});

describe('contrato PUT /api/clients/:id', () => {
  test('devuelve 200 con el cliente actualizado en la forma exacta', async () => {
    const created = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Editable ${suffix}`, telefono: `58${suffix}` });
    expect(created.status).toBe(201);

    const response = await api
      .put(`/api/clients/${created.body.id}`)
      .set(bearer(adminToken))
      .send({
        nombre: `Editable Editado ${suffix}`,
        telefono: `59${suffix}`,
        email: `editado_${suffix}@correo.com`,
      });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      id: created.body.id,
      nombre: `Editable Editado ${suffix}`,
      telefono: `59${suffix}`,
      email: `editado_${suffix}@correo.com`,
      estado: 'ACTIVO',
      fechaRegistro: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
    });
  });

  test('devuelve 400 si la edicion no trae teléfono', async () => {
    const created = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Sin Teléfono Edit ${suffix}`, telefono: `60${suffix}` });

    const response = await api
      .put(`/api/clients/${created.body.id}`)
      .set(bearer(adminToken))
      .send({ nombre: 'Solo Nombre' });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('El teléfono es obligatorio');
  });

  test('devuelve 404 si el cliente no existe', async () => {
    const response = await api
      .put('/api/clients/99999999')
      .set(bearer(adminToken))
      .send({ nombre: 'Fantasma', telefono: '5500000000' });

    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });

  test('MECHANIC recibe 403', async () => {
    const response = await api
      .put('/api/clients/1')
      .set(bearer(mechanicToken))
      .send({ nombre: 'Intento', telefono: '5500000001' });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});
