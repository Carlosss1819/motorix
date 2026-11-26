// Pruebas de contrato de /api/settings (Sprint 7, US1/US2).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/settings.md.
// Solo cambia el teléfono del taller y lo restaura: ninguna otra suite lo
// revisa, así que no interfiere con las que corren en paralelo. Los márgenes
// se guardan con sus mismos valores (30 y 500) por la misma razón.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

let adminToken;
let recepcionToken;
let mecanicoToken;
let telefonoOriginal;

beforeAll(async () => {
  await prepareTestDatabase();
  adminToken = await loginAs('admin', 'Admin2026!');
  recepcionToken = await loginAs('recepcion', 'Recepcion2026!');
  mecanicoToken = await loginAs('mecanico', 'Mecanico2026!');
  const actual = await api.get('/api/settings').set(bearer(adminToken));
  telefonoOriginal = actual.body.taller.telefono;
});

afterAll(async () => {
  await api
    .put('/api/settings')
    .set(bearer(adminToken))
    .send({ telefonoTaller: telefonoOriginal });
});

describe('GET /api/settings', () => {
  test('test_admin_recibe_taller_y_margenes', async () => {
    const response = await api.get('/api/settings').set(bearer(adminToken));
    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      taller: {
        nombre: expect.any(String),
        direccion: expect.any(String),
        telefono: expect.any(String),
      },
      mantenimiento: {
        antelacionDias: expect.any(Number),
        antelacionKm: expect.any(Number),
      },
    });
  });

  test.each([
    ['recepción', () => recepcionToken],
    ['mecánico', () => mecanicoToken],
  ])('test_%s_recibe_403', async (_rol, token) => {
    const response = await api.get('/api/settings').set(bearer(token()));
    expect(response.status).toBe(403);
    const put = await api.put('/api/settings').set(bearer(token())).send({ telefonoTaller: '1' });
    expect(put.status).toBe(403);
  });

  test('test_sin_sesion_recibe_401', async () => {
    const response = await api.get('/api/settings');
    expect(response.status).toBe(401);
  });
});

describe('PUT /api/settings', () => {
  test('test_guarda_el_telefono_y_lo_registra_en_la_bitacora', async () => {
    const nuevo = `55-${Date.now()}`.slice(0, 30);
    const response = await api
      .put('/api/settings')
      .set(bearer(adminToken))
      .send({ telefonoTaller: nuevo });
    expect(response.status).toBe(200);
    expect(response.body.taller.telefono).toBe(nuevo);

    const [fila] = await sql("SELECT setting_value FROM settings WHERE setting_key = 'shop.phone'");
    expect(fila.setting_value).toBe(nuevo);

    const bitacora = await sql(
      "SELECT action, detail FROM audit_log WHERE action = 'CONFIG_ACTUALIZADA' AND detail LIKE '%shop.phone%' ORDER BY id DESC LIMIT 1",
    );
    expect(bitacora).toHaveLength(1);
  });

  test('test_guarda_los_margenes_con_limites_validos', async () => {
    const response = await api
      .put('/api/settings')
      .set(bearer(adminToken))
      .send({ antelacionDias: 30, antelacionKm: 500 });
    expect(response.status).toBe(200);
    expect(response.body.mantenimiento).toEqual({ antelacionDias: 30, antelacionKm: 500 });
  });

  test.each([
    [{ nombreTaller: '' }, 'nombre'],
    [{ nombreTaller: 'x'.repeat(121) }, '120'],
    [{ direccionTaller: 'x'.repeat(201) }, '200'],
    [{ telefonoTaller: 'x'.repeat(31) }, '30'],
    [{ antelacionDias: 0 }, 'días'],
    [{ antelacionDias: 366 }, '365'],
    [{ antelacionDias: 1.5 }, 'entero'],
    [{ antelacionKm: 50001 }, '50000'],
    [{ antelacionKm: -1 }, 'kilómetros'],
    [{}, 'al menos un dato'],
    [{ otro: 'x' }, 'campos'],
  ])('test_rechaza_%j_con_400', async (body, fragmento) => {
    const response = await api.put('/api/settings').set(bearer(adminToken)).send(body);
    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain(fragmento);
  });
});
