// Pruebas de contrato de /api/terms y de terminosPendientes en /api/auth
// (Sprint 7, US9). Fuente: specs/007-reportes-configuracion/contracts/terms.md.
import { api, loginAs, loginSinAceptar, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

let adminToken;
let recepcionToken;
let nuevo;

beforeAll(async () => {
  await prepareTestDatabase();
  const suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  recepcionToken = await loginAs('recepcion', 'Recepcion2026!');
  const usuario = `term_${suffix}`;
  const creado = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({ username: usuario, email: `${usuario}@motorix.local`, rol: 'RECEPTIONIST', contrasena: 'Terminos2026!' });
  expect(creado.status).toBe(201);
  nuevo = { id: creado.body.id, usuario, login: await loginSinAceptar(usuario, 'Terminos2026!') };
});

describe('terminosPendientes en el inicio de sesión', () => {
  test('test_un_usuario_nuevo_tiene_la_aceptacion_pendiente', async () => {
    expect(nuevo.login.terminosPendientes).toBe(true);
    const me = await api.get('/api/auth/me').set(bearer(nuevo.login.token));
    expect(me.status).toBe(200);
    expect(me.body.terminosPendientes).toBe(true);
  });

  test('test_un_usuario_que_ya_acepto_no_tiene_pendiente', async () => {
    const login = await loginSinAceptar('admin', 'Admin2026!');
    expect(login.terminosPendientes).toBe(false);
  });
});

describe('GET /api/terms/current', () => {
  test('test_devuelve_la_version_vigente_con_ambos_textos', async () => {
    const response = await api.get('/api/terms/current').set(bearer(nuevo.login.token));
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      version: '1.0',
      publicadoEn: expect.stringMatching(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/),
      terminos: expect.stringContaining('TÉRMINOS Y CONDICIONES'),
      avisoPrivacidad: expect.stringContaining('AVISO DE PRIVACIDAD'),
    });
  });
});

describe('POST /api/terms/accept', () => {
  test('test_una_version_que_no_es_la_vigente_responde_409', async () => {
    const response = await api
      .post('/api/terms/accept')
      .set(bearer(nuevo.login.token))
      .send({ version: '0.1' });
    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('VERSION_NO_VIGENTE');
  });

  test('test_sin_version_responde_400', async () => {
    const response = await api.post('/api/terms/accept').set(bearer(nuevo.login.token)).send({});
    expect(response.status).toBe(400);
  });

  test('test_aceptar_es_idempotente_y_se_registra_una_vez', async () => {
    const primera = await api.post('/api/terms/accept').set(bearer(nuevo.login.token)).send({ version: '1.0' });
    const segunda = await api.post('/api/terms/accept').set(bearer(nuevo.login.token)).send({ version: '1.0' });
    expect(primera.status).toBe(200);
    expect(segunda.status).toBe(200);
    expect(segunda.body.aceptadoEn).toBe(primera.body.aceptadoEn);
    const filas = await sql('SELECT COUNT(*) AS n FROM terms_acceptances WHERE user_id = ?', [nuevo.id]);
    expect(filas[0].n).toBe(1);
    const bitacora = await sql(
      "SELECT COUNT(*) AS n FROM audit_log WHERE action = 'TERMINOS_ACEPTADOS' AND user_id = ?",
      [nuevo.id],
    );
    expect(bitacora[0].n).toBe(1);
  });
});

describe('GET /api/terms/acceptances', () => {
  test('test_admin_lista_las_aceptaciones_paginadas', async () => {
    const response = await api.get('/api/terms/acceptances?porPagina=5').set(bearer(adminToken));
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ pagina: 1, total: expect.any(Number) });
    expect(response.body.elementos.length).toBeLessThanOrEqual(5);
    expect(response.body.elementos[0]).toEqual({
      usuarioId: expect.any(Number),
      username: expect.any(String),
      version: expect.any(String),
      aceptadoEn: expect.any(String),
    });
  });

  test('test_recepcion_recibe_403', async () => {
    const response = await api.get('/api/terms/acceptances').set(bearer(recepcionToken));
    expect(response.status).toBe(403);
  });
});
