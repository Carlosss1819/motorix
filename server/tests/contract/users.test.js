// Pruebas de contrato de /api/users: solo ADMIN (RN-5, RN-15) y formas de
// respuesta de contracts/users.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
});

describe('autorizacion de /api/users (RN-5)', () => {
  test('RECEPTIONIST recibe 403 al listar usuarios', async () => {
    const response = await api.get('/api/users').set(bearer(receptionistToken));
    expect(response.status).toBe(403);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: 'ROL_NO_AUTORIZADO',
    });
  });

  test('sin token se responde 401 con la forma de error', async () => {
    const response = await api.get('/api/users');
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});

describe('contrato GET /api/users', () => {
  test('ADMIN lista usuarios con la forma exacta (sin password)', async () => {
    const response = await api.get('/api/users').set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThanOrEqual(3);
    expect(response.body[0]).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        username: expect.any(String),
        email: expect.any(String),
        rol: expect.stringMatching(/^(ADMIN|RECEPTIONIST|MECHANIC)$/),
        estado: expect.stringMatching(/^(ACTIVO|INACTIVO)$/),
      }),
    );
    expect(JSON.stringify(response.body)).not.toContain('password');
  });
});

describe('contrato POST /api/users', () => {
  test('crea un usuario y devuelve 201 con estado ACTIVO', async () => {
    const response = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `usr_${suffix}`,
        email: `usr_${suffix}@motorix.local`,
        rol: 'RECEPTIONIST',
        contrasena: 'NuevaClave2026',
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      username: `usr_${suffix}`,
      email: `usr_${suffix}@motorix.local`,
      rol: 'RECEPTIONIST',
      estado: 'ACTIVO',
    });
  });

  test('devuelve 409 si el nombre de usuario ya existe', async () => {
    const response = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: 'admin',
        email: `otro_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'NuevaClave2026',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('USERNAME_EN_USO');
  });

  test('devuelve 409 si el correo ya existe', async () => {
    const response = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `otrousr_${suffix}`,
        email: 'admin@motorix.local',
        rol: 'MECHANIC',
        contrasena: 'NuevaClave2026',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('EMAIL_EN_USO');
  });

  test('devuelve 400 si el rol no es válido', async () => {
    const response = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `rolmal_${suffix}`,
        email: `rolmal_${suffix}@motorix.local`,
        rol: 'BOSS',
        contrasena: 'NuevaClave2026',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('Rol no válido');
  });

  test('devuelve 400 si la contraseña no cumple la política', async () => {
    const response = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `clavemal_${suffix}`,
        email: `clavemal_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'debil',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('8 caracteres');
  });
});

describe('contrato PATCH /api/users/:id', () => {
  test('cambia rol y estado devolviendo 200 con la forma exacta', async () => {
    const created = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `patch_${suffix}`,
        email: `patch_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'NuevaClave2026',
      });

    const response = await api
      .patch(`/api/users/${created.body.id}`)
      .set(bearer(adminToken))
      .send({ rol: 'RECEPTIONIST', estado: 'INACTIVO' });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      id: created.body.id,
      username: `patch_${suffix}`,
      email: `patch_${suffix}@motorix.local`,
      rol: 'RECEPTIONIST',
      estado: 'INACTIVO',
    });
  });

  test('devuelve 400 si no se envia rol ni estado', async () => {
    const response = await api
      .patch('/api/users/1')
      .set(bearer(adminToken))
      .send({});

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('Indique el rol o el estado');
  });

  test('devuelve 404 si el usuario no existe', async () => {
    const response = await api
      .patch('/api/users/99999999')
      .set(bearer(adminToken))
      .send({ estado: 'INACTIVO' });

    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});
