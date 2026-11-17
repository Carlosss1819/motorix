// Contrato de /api/notifications (Sprint 6, contracts/notifications.md):
// sesión obligatoria, forma de la respuesta y ninguna clave de dinero (FR-012).
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { fijarReloj, liberarReloj, CLAVES_DE_DINERO } from '../helpers/notifications-fixtures.js';

let tokens;

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  tokens = {
    admin: await loginAs('admin', 'Admin2026!'),
    recepcion: await loginAs('recepcion', 'Recepcion2026!'),
    mecanico: await loginAs('mecanico', 'Mecanico2026!'),
  };
});

afterAll(() => liberarReloj());

describe('sin sesión', () => {
  test.each([
    ['get', '/api/notifications'],
    ['get', '/api/notifications/count'],
    ['post', '/api/notifications/read'],
  ])('%s %s responde 401', async (metodo, ruta) => {
    const r = await api[metodo](ruta).send({});
    expect(r.status).toBe(401);
    expect(r.body.error.codigo).toBe('SESION_REQUERIDA');
  });
});

describe.each(['admin', 'recepcion', 'mecanico'])('con sesión de %s', (rol) => {
  test('GET /api/notifications responde la forma del contrato', async () => {
    const r = await api.get('/api/notifications').set(bearer(tokens[rol]));
    expect(r.status).toBe(200);
    expect(Object.keys(r.body).sort()).toEqual(['grupos', 'noLeidos', 'totalAvisos']);
    expect(Number.isInteger(r.body.noLeidos)).toBe(true);
    expect(Number.isInteger(r.body.totalAvisos)).toBe(true);
    for (const grupo of r.body.grupos) {
      expect(Object.keys(grupo).sort()).toEqual(['avisos', 'cantidad', 'noLeidos', 'tipo', 'titulo']);
      for (const aviso of grupo.avisos) {
        expect(Object.keys(aviso).sort()).toEqual([
          'clave',
          'descripcion',
          'destino',
          'fechaReferencia',
          'leido',
          'tipo',
          'titulo',
        ]);
        expect(['ORDEN', 'CITAS', 'VEHICULO', 'REFACCION']).toContain(aviso.destino.pantalla);
      }
    }
    expect(JSON.stringify(r.body)).not.toMatch(CLAVES_DE_DINERO);
  });

  test('GET /api/notifications/count responde solo noLeidos', async () => {
    // La igualdad con el listado se prueba en notifications-by-role con un
    // usuario propio (aquí otras suites crean datos en paralelo).
    const conteo = await api.get('/api/notifications/count').set(bearer(tokens[rol]));
    expect(conteo.status).toBe(200);
    expect(Object.keys(conteo.body)).toEqual(['noLeidos']);
    expect(Number.isInteger(conteo.body.noLeidos)).toBe(true);
  });
});

describe('POST /api/notifications/read', () => {
  test('sin clave responde 400 VALIDACION', async () => {
    const r = await api.post('/api/notifications/read').set(bearer(tokens.admin)).send({});
    expect(r.status).toBe(400);
    expect(r.body.error.codigo).toBe('VALIDACION');
  });

  test('una clave de más de 120 caracteres responde 400 VALIDACION', async () => {
    const r = await api
      .post('/api/notifications/read')
      .set(bearer(tokens.admin))
      .send({ clave: 'X'.repeat(121) });
    expect(r.status).toBe(400);
    expect(r.body.error.codigo).toBe('VALIDACION');
  });

  test('una clave que no existe responde 204 sin cuerpo (FR-030)', async () => {
    const r = await api
      .post('/api/notifications/read')
      .set(bearer(tokens.mecanico))
      .send({ clave: 'STOCK_BAJO:999999999' });
    expect(r.status).toBe(204);
  });
});
