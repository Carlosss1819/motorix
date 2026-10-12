// Pruebas de contrato de /api/auth: formas de respuesta y códigos exactos
// definidos en specs/001-base-clientes-vehiculos/contracts/auth.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

beforeAll(async () => {
  await prepareTestDatabase();
});

describe('contrato POST /api/auth/login', () => {
  test('devuelve 200 con token y usuario en la forma exacta', async () => {
    const response = await api
      .post('/api/auth/login')
      .send({ identificador: 'admin', contrasena: 'Admin2026!' });

    expect(response.status).toBe(200);
    expect(typeof response.body.token).toBe('string');
    expect(response.body.token.length).toBeGreaterThan(0);
    expect(response.body.usuario).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        username: 'admin',
        email: expect.any(String),
        rol: 'ADMIN',
      }),
    );
    expect(response.body).not.toHaveProperty('contrasena');
    expect(JSON.stringify(response.body)).not.toContain('password');
  });

  test('devuelve 400 con { error: { mensaje, codigo } } si faltan datos', async () => {
    const response = await api.post('/api/auth/login').send({});

    expect(response.status).toBe(400);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
    expect(response.body.error.mensaje).toMatch(/[áéíóúñÁÉÍÓÚÑ]/);
  });

  test('devuelve 401 con mensaje genérico si la contraseña es incorrecta', async () => {
    const response = await api
      .post('/api/auth/login')
      .send({ identificador: 'admin', contrasena: 'Incorrecta2026!' });

    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: 'Credenciales inválidas',
      codigo: 'CREDENCIALES_INVALIDAS',
    });
  });

  test('bloquea la cuenta con 423 tras 5 intentos fallidos (V3)', async () => {
    const suffix = uniqueSuffix();
    const token = await loginAs('admin', 'Admin2026!');
    await api
      .post('/api/users')
      .set(bearer(token))
      .send({
        username: `bloqueo_${suffix}`,
        email: `bloqueo_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'Prueba2026!',
      })
      .expect(201);

    // Los primeros 5 intentos responden 401 con mensaje genérico...
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const attemptResponse = await api
        .post('/api/auth/login')
        .send({ identificador: `bloqueo_${suffix}`, contrasena: 'Mal2026!' });
      expect(attemptResponse.status).toBe(401);
      expect(attemptResponse.body.error.mensaje).toBe('Credenciales inválidas');
    }

    // ...y el sexto responde 423 (cuenta bloqueada).
    const lock = await api
      .post('/api/auth/login')
      .send({ identificador: `bloqueo_${suffix}`, contrasena: 'Mal2026!' });
    expect(lock.status).toBe(423);
    expect(lock.body.error.codigo).toBe('CUENTA_BLOQUEADA');
    expect(lock.body.error.mensaje).toContain('15 minutos');
  });
});

describe('contrato de sesión /me, /logout y /change-password', () => {
  test('GET /api/auth/me exige token (401 sin el)', async () => {
    const response = await api.get('/api/auth/me');
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });

  test('GET /api/auth/me devuelve 200 con los datos del usuario', async () => {
    const token = await loginAs('admin', 'Admin2026!');
    const response = await api.get('/api/auth/me').set(bearer(token));

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        username: 'admin',
        email: expect.any(String),
        rol: 'ADMIN',
      }),
    );
  });

  test('POST /api/auth/logout devuelve 200 y cierra la sesión', async () => {
    const token = await loginAs('recepcion', 'Recepcion2026!');
    const logout = await api.post('/api/auth/logout').set(bearer(token));
    expect(logout.status).toBe(200);
    expect(logout.body.mensaje).toBe('Sesión cerrada');

    const after = await api.get('/api/auth/me').set(bearer(token));
    expect(after.status).toBe(401);
  });

  test('POST /api/auth/change-password devuelve 400 si la actual es incorrecta', async () => {
    const token = await loginAs('admin', 'Admin2026!');
    const response = await api
      .post('/api/auth/change-password')
      .set(bearer(token))
      .send({ actual: 'NoEsLaClave2026', nueva: 'NuevaClave2026' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('CONTRASENA_ACTUAL_INVALIDA');
  });

  test('POST /api/auth/change-password devuelve 400 si la nueva no cumple política', async () => {
    const token = await loginAs('admin', 'Admin2026!');
    const response = await api
      .post('/api/auth/change-password')
      .set(bearer(token))
      .send({ actual: 'Admin2026!', nueva: 'corta' });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('8 caracteres');
  });
});
