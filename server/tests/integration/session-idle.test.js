// Integración (Sprint 7, US10, FR-027, CA-23): una sesión con más de 30
// minutos sin actividad responde 401 SESION_INVALIDA en el backend.
import jwt from 'jsonwebtoken';
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { setLastActivity } from '../../utils/sessionStore.js';
import { config } from '../../config/env.js';

beforeAll(async () => {
  await prepareTestDatabase();
});

test('test_el_limite_de_inactividad_es_de_30_minutos', () => {
  expect(config.session.idleMs).toBe(30 * 60 * 1000);
});

test('test_una_sesion_inactiva_mas_de_30_minutos_se_rechaza', async () => {
  const token = await loginAs('recepcion', 'Recepcion2026!');
  expect((await api.get('/api/auth/me').set(bearer(token))).status).toBe(200);

  const { jti } = jwt.decode(token);
  setLastActivity(jti, Date.now() - (30 * 60 * 1000 + 1000));

  const response = await api.get('/api/clients').set(bearer(token));
  expect(response.status).toBe(401);
  expect(response.body.error.codigo).toBe('SESION_INVALIDA');
});

test('test_una_sesion_con_actividad_reciente_sigue_vigente', async () => {
  const token = await loginAs('recepcion', 'Recepcion2026!');
  const { jti } = jwt.decode(token);
  setLastActivity(jti, Date.now() - 29 * 60 * 1000);
  expect((await api.get('/api/clients').set(bearer(token))).status).toBe(200);
});
