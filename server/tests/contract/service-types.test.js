// Pruebas de contrato de /api/service-types (Sprint 7, US3).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/service-types.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

let adminToken;
let recepcionToken;
let mecanicoToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  recepcionToken = await loginAs('recepcion', 'Recepcion2026!');
  mecanicoToken = await loginAs('mecanico', 'Mecanico2026!');
});

function crear(body, token = adminToken) {
  return api.post('/api/service-types').set(bearer(token)).send(body);
}

describe('lectura del catálogo', () => {
  test.each([
    ['admin', () => adminToken],
    ['recepción', () => recepcionToken],
    ['mecánico', () => mecanicoToken],
  ])('test_%s_lista_los_tipos_activos_del_seed', async (_rol, token) => {
    const response = await api.get('/api/service-types').set(bearer(token()));
    expect(response.status).toBe(200);
    expect(response.body.elementos).toEqual(
      expect.arrayContaining([
        { id: 70001, nombre: 'Cambio de aceite', intervaloDias: 180, intervaloKm: 5000, activo: true },
      ]),
    );
    expect(response.body.elementos.every((tipo) => tipo.activo)).toBe(true);
  });

  test('test_incluir_inactivos_solo_aplica_para_admin', async () => {
    const creado = await crear({ nombre: `Inactivo ${suffix}`, intervaloDias: 30 });
    await api.post(`/api/service-types/${creado.body.id}/desactivar`).set(bearer(adminToken));

    const admin = await api.get('/api/service-types?incluirInactivos=true').set(bearer(adminToken));
    expect(admin.body.elementos.map((t) => t.id)).toContain(creado.body.id);

    const recepcion = await api
      .get('/api/service-types?incluirInactivos=true')
      .set(bearer(recepcionToken));
    expect(recepcion.status).toBe(200);
    expect(recepcion.body.elementos.map((t) => t.id)).not.toContain(creado.body.id);
  });
});

describe('escritura del catálogo (solo ADMIN)', () => {
  test('test_crea_un_tipo_y_lo_registra_en_la_bitacora', async () => {
    const response = await crear({ nombre: `Alineación ${suffix}`, intervaloDias: 180, intervaloKm: 10000 });
    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      nombre: `Alineación ${suffix}`,
      intervaloDias: 180,
      intervaloKm: 10000,
      activo: true,
    });
    const bitacora = await sql(
      "SELECT 1 FROM audit_log WHERE action = 'TIPO_SERVICIO_CREADO' AND entity_id = ?",
      [response.body.id],
    );
    expect(bitacora).toHaveLength(1);
  });

  test('test_sin_ningun_intervalo_responde_400_intervalo_requerido', async () => {
    const response = await crear({ nombre: `Sin intervalo ${suffix}` });
    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('INTERVALO_REQUERIDO');
  });

  test('test_nombre_repetido_sin_distinguir_mayusculas_responde_409', async () => {
    await crear({ nombre: `Balanceo ${suffix}`, intervaloKm: 8000 });
    const response = await crear({ nombre: `BALANCEO ${suffix}`, intervaloKm: 9000 });
    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('TIPO_SERVICIO_DUPLICADO');
  });

  test.each([
    [{ nombre: '', intervaloDias: 10 }],
    [{ nombre: 'x'.repeat(121), intervaloDias: 10 }],
    [{ nombre: 'Rango', intervaloDias: 3651 }],
    [{ nombre: 'Rango', intervaloKm: 500001 }],
    [{ nombre: 'Rango', intervaloKm: 0 }],
  ])('test_valores_fuera_de_limite_%j_responden_400', async (body) => {
    const response = await crear(body);
    expect(response.status).toBe(400);
  });

  test('test_edita_y_no_permite_quitar_todos_los_intervalos', async () => {
    const creado = await crear({ nombre: `Editable ${suffix}`, intervaloDias: 90, intervaloKm: 3000 });
    const editado = await api
      .put(`/api/service-types/${creado.body.id}`)
      .set(bearer(adminToken))
      .send({ intervaloKm: null, intervaloDias: 120 });
    expect(editado.status).toBe(200);
    expect(editado.body).toMatchObject({ intervaloDias: 120, intervaloKm: null });

    const sinNada = await api
      .put(`/api/service-types/${creado.body.id}`)
      .set(bearer(adminToken))
      .send({ intervaloDias: null });
    expect(sinNada.status).toBe(400);
    expect(sinNada.body.error.codigo).toBe('INTERVALO_REQUERIDO');
  });

  test('test_activar_y_desactivar_es_idempotente_y_se_registra', async () => {
    const creado = await crear({ nombre: `Activable ${suffix}`, intervaloDias: 60 });
    const primera = await api.post(`/api/service-types/${creado.body.id}/desactivar`).set(bearer(adminToken));
    const segunda = await api.post(`/api/service-types/${creado.body.id}/desactivar`).set(bearer(adminToken));
    expect(primera.body.activo).toBe(false);
    expect(segunda.status).toBe(200);
    const activo = await api.post(`/api/service-types/${creado.body.id}/activar`).set(bearer(adminToken));
    expect(activo.body.activo).toBe(true);
    const bitacora = await sql(
      "SELECT action FROM audit_log WHERE entity_type = 'service_type' AND entity_id = ? ORDER BY id",
      [creado.body.id],
    );
    expect(bitacora.map((fila) => fila.action)).toEqual([
      'TIPO_SERVICIO_CREADO',
      'TIPO_SERVICIO_DESACTIVADO',
      'TIPO_SERVICIO_ACTIVADO',
    ]);
  });

  test('test_un_tipo_inexistente_responde_404', async () => {
    const response = await api.put('/api/service-types/999999').set(bearer(adminToken)).send({ intervaloDias: 5 });
    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('TIPO_SERVICIO_NO_ENCONTRADO');
  });

  test.each([
    ['recepción', () => recepcionToken],
    ['mecánico', () => mecanicoToken],
  ])('test_%s_no_puede_escribir_el_catalogo', async (_rol, token) => {
    const response = await crear({ nombre: `No permitido ${suffix}`, intervaloDias: 10 }, token());
    expect(response.status).toBe(403);
    const desactivar = await api.post('/api/service-types/70001/desactivar').set(bearer(token()));
    expect(desactivar.status).toBe(403);
  });

  test('test_no_existe_borrado_de_tipos', async () => {
    const response = await api.delete('/api/service-types/70001').set(bearer(adminToken));
    expect(response.status).toBe(404);
  });
});
