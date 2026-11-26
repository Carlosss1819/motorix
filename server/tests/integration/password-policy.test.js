// Integración (Sprint 7, US10, FR-026, CA-22): la política de contraseñas
// existente se aplica al crear usuarios y al cambiar la contraseña, y el hash
// nunca sale en las respuestas.
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

const POLITICA = 'al menos 8 caracteres y al menos una mayúscula, una minúscula y un número';
const INVALIDAS = [
  ['corta', 'Ab1cdef'],
  ['sin_mayuscula', 'abcdefg1'],
  ['sin_minuscula', 'ABCDEFG1'],
  ['sin_numero', 'Abcdefgh'],
];

let adminToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

test.each(INVALIDAS)('test_alta_de_usuario_rechaza_contrasena_%s', async (caso, contrasena) => {
  const response = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({ username: `pol_${caso}_${suffix}`, email: `pol_${caso}_${suffix}@motorix.local`, rol: 'MECHANIC', contrasena });
  expect(response.status).toBe(400);
  expect(response.body.error.mensaje).toContain(POLITICA);
});

test.each(INVALIDAS)('test_cambio_de_contrasena_rechaza_%s', async (_caso, nueva) => {
  const username = `polc_${_caso}_${suffix}`;
  await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({ username, email: `${username}@motorix.local`, rol: 'MECHANIC', contrasena: 'Valida2026!' });
  const token = await loginAs(username, 'Valida2026!');
  const response = await api
    .post('/api/auth/change-password')
    .set(bearer(token))
    .send({ actual: 'Valida2026!', nueva });
  expect(response.status).toBe(400);
  expect(response.body.error.mensaje).toContain(POLITICA);
});

test('test_una_contrasena_valida_se_acepta_y_el_hash_no_se_devuelve', async () => {
  const username = `polok_${suffix}`;
  const creado = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({ username, email: `${username}@motorix.local`, rol: 'MECHANIC', contrasena: 'Valida2026!' });
  expect(creado.status).toBe(201);
  expect(JSON.stringify(creado.body)).not.toMatch(/password|hash|\$2[aby]\$/i);

  const lista = await api.get('/api/users').set(bearer(adminToken));
  expect(JSON.stringify(lista.body)).not.toMatch(/password|hash|\$2[aby]\$/i);
});
