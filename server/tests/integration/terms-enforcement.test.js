// Integración (Sprint 7, US9, FR-020, CA-19): sin aceptación de la versión
// vigente, el backend rechaza toda operación salvo la lista blanca.
// No publica versiones nuevas (cambiaría la vigente para las suites en
// paralelo): la aceptación «por versión» se prueba con una aceptación de una
// versión antigua no vigente.
import { api, loginAs, loginSinAceptar, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

let adminToken;
let suffix;

async function usuarioNuevo(prefijo, rol = 'MECHANIC') {
  const username = `${prefijo}_${suffix}`;
  const creado = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({ username, email: `${username}@motorix.local`, rol, contrasena: 'Pendiente2026!' });
  expect(creado.status).toBe(201);
  return { id: creado.body.id, username };
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

test('test_sin_aceptar_las_rutas_protegidas_responden_403_terminos_pendientes', async () => {
  const usuario = await usuarioNuevo('pend', 'RECEPTIONIST');
  const { token } = await loginSinAceptar(usuario.username, 'Pendiente2026!');

  for (const ruta of ['/api/clients', '/api/service-orders', '/api/notifications', '/api/service-types']) {
    const response = await api.get(ruta).set(bearer(token));
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('TERMINOS_PENDIENTES');
  }
  const post = await api.post('/api/clients').set(bearer(token)).send({ nombre: 'X', telefono: '5500000000' });
  expect(post.status).toBe(403);
  const cambio = await api
    .post('/api/auth/change-password')
    .set(bearer(token))
    .send({ actual: 'Pendiente2026!', nueva: 'OtraClave2026!' });
  expect(cambio.status).toBe(403);
});

test('test_la_lista_blanca_funciona_y_tras_aceptar_entra', async () => {
  const usuario = await usuarioNuevo('blanca', 'RECEPTIONIST');
  const { token } = await loginSinAceptar(usuario.username, 'Pendiente2026!');

  expect((await api.get('/api/auth/me').set(bearer(token))).status).toBe(200);
  const vigente = await api.get('/api/terms/current').set(bearer(token));
  expect(vigente.status).toBe(200);
  const aceptar = await api.post('/api/terms/accept').set(bearer(token)).send({ version: vigente.body.version });
  expect(aceptar.status).toBe(200);

  const clientes = await api.get('/api/clients').set(bearer(token));
  expect(clientes.status).toBe(200);
  expect((await api.post('/api/auth/logout').set(bearer(token))).status).toBe(200);
});

test('test_cerrar_sesion_sin_aceptar_esta_permitido', async () => {
  const usuario = await usuarioNuevo('salir');
  const { token } = await loginSinAceptar(usuario.username, 'Pendiente2026!');
  const logout = await api.post('/api/auth/logout').set(bearer(token));
  expect(logout.status).toBe(200);
});

test('test_haber_aceptado_otra_version_no_cuenta_para_la_vigente', async () => {
  const usuario = await usuarioNuevo('vieja');
  await sql(
    `INSERT IGNORE INTO terms_versions (version, published_at, terms_text, privacy_text, is_current)
     VALUES ('0.9-prueba', '2026-01-01 00:00:00', 'Texto anterior', 'Aviso anterior', 0)`,
  );
  const [vieja] = await sql("SELECT id FROM terms_versions WHERE version = '0.9-prueba'");
  await sql('INSERT INTO terms_acceptances (user_id, terms_version_id) VALUES (?, ?)', [usuario.id, vieja.id]);

  const login = await loginSinAceptar(usuario.username, 'Pendiente2026!');
  expect(login.terminosPendientes).toBe(true);
  const response = await api.get('/api/service-types').set(bearer(login.token));
  expect(response.status).toBe(403);
});
