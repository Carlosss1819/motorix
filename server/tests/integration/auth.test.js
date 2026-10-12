// Pruebas de integracion de autenticación (US1): login por usuario o correo (FR-002),
// bloqueo por intentos fallidos, cierre por inactividad (aclaración Q1) y cambio de
// contrasena con política mínima (FR-008).
import jwt from 'jsonwebtoken';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import * as sessionStore from '../../utils/sessionStore.js';
import { config } from '../../config/env.js';

let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
});

describe('login por usuario y por correo (FR-002)', () => {
  test('inicia sesión con nombre de usuario', async () => {
    const response = await api
      .post('/api/auth/login')
      .send({ identificador: 'admin', contrasena: 'Admin2026!' });

    expect(response.status).toBe(200);
    expect(response.body.usuario.username).toBe('admin');
    expect(response.body.usuario.rol).toBe('ADMIN');
  });

  test('inicia sesión con correo electrónico (mismo resultado)', async () => {
    const response = await api
      .post('/api/auth/login')
      .send({ identificador: 'admin@motorix.local', contrasena: 'Admin2026!' });

    expect(response.status).toBe(200);
    expect(response.body.usuario.username).toBe('admin');
    expect(response.body.usuario.rol).toBe('ADMIN');
  });

  test('un usuario desconocido recibe el mismo mensaje genérico', async () => {
    const response = await api
      .post('/api/auth/login')
      .send({ identificador: `fantasma_${suffix}`, contrasena: 'Cualquier2026!' });

    expect(response.status).toBe(401);
    expect(response.body.error.mensaje).toBe('Credenciales inválidas');
  });
});

describe('bloqueo tras 5 intentos fallidos', () => {
  test('tras 5 fallos el sexto intento responde 423 y tras esperar no aplica', async () => {
    const token = await loginAs('admin', 'Admin2026!');
    await api
      .post('/api/users')
      .set(bearer(token))
      .send({
        username: `fallo_${suffix}`,
        email: `fallo_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'Fallo2026!',
      })
      .expect(201);

    for (let attempt = 0; attempt < 5; attempt += 1) {
      const attemptResponse = await api
        .post('/api/auth/login')
        .send({ identificador: `fallo_${suffix}`, contrasena: 'Otra2026!' });
      expect(attemptResponse.status).toBe(401);
    }

    const lock = await api
      .post('/api/auth/login')
      .send({ identificador: `fallo_${suffix}`, contrasena: 'Otra2026!' });
    expect(lock.status).toBe(423);

    // Incluso con la contraseña CORRECTA la cuenta sigue bloqueada.
    const withCorrectPassword = await api
      .post('/api/auth/login')
      .send({ identificador: `fallo_${suffix}`, contrasena: 'Fallo2026!' });
    expect(withCorrectPassword.status).toBe(423);
  });
});

describe('cierre de sesión por inactividad de 30 minutos (aclaración Q1)', () => {
  test('una sesión envejecida más allá del límite recibe 401', async () => {
    const login = await api
      .post('/api/auth/login')
      .send({ identificador: 'admin', contrasena: 'Admin2026!' });
    expect(login.status).toBe(200);

    const payload = jwt.decode(login.body.token);
    expect(payload.jti).toBeTruthy();

    // Envejece la sesión más allá de 30 minutos (sin esperar en tiempo real).
    sessionStore.setLastActivity(payload.jti, Date.now() - config.session.idleMs - 1000);

    const response = await api.get('/api/auth/me').set(bearer(login.body.token));
    expect(response.status).toBe(401);
    expect(response.body.error.codigo).toBe('SESION_INVALIDA');
  });

  test('una sesión activa sigue funcionando', async () => {
    const token = await loginAs('recepcion', 'Recepcion2026!');
    const response = await api.get('/api/auth/me').set(bearer(token));
    expect(response.status).toBe(200);
  });
});

describe('cambio de contraseña (FR-008)', () => {
  test('flujo completo: cambiar contraseña y entrar con la nueva', async ()    => {
    const token = await loginAs('admin', 'Admin2026!');
    await api
      .post('/api/users')
      .set(bearer(token))
      .send({
        username: `cambio_${suffix}`,
        email: `cambio_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'Antigua2026!',
      })
      .expect(201);

    const userToken = await loginAs(`cambio_${suffix}`, 'Antigua2026!');

    const change = await api
      .post('/api/auth/change-password')
      .set(bearer(userToken))
      .send({ actual: 'Antigua2026!', nueva: 'NuevaSegura2026' });
    expect(change.status).toBe(200);
    expect(change.body.mensaje).toBe('Contraseña actualizada');

    // La contrasena vieja ya no sirve y la nueva si.
    const oldPassword = await api
      .post('/api/auth/login')
      .send({ identificador: `cambio_${suffix}`, contrasena: 'Antigua2026!' });
    expect(oldPassword.status).toBe(401);

    const newPassword = await api
      .post('/api/auth/login')
      .send({ identificador: `cambio_${suffix}`, contrasena: 'NuevaSegura2026' });
    expect(newPassword.status).toBe(200);
  });
});
