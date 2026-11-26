// Pruebas de contrato de /api/audit-log (Sprint 7, US10, FR-024).
// Fuente: specs/007-reportes-configuracion/contracts/audit-log.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

let adminToken;
let recepcionToken;
let mecanicoToken;
let adminId;

beforeAll(async () => {
  await prepareTestDatabase();
  adminToken = await loginAs('admin', 'Admin2026!');
  recepcionToken = await loginAs('recepcion', 'Recepcion2026!');
  mecanicoToken = await loginAs('mecanico', 'Mecanico2026!');
  [{ id: adminId }] = await sql("SELECT id FROM users WHERE username = 'admin'");
  // Una entrada propia para filtrar con certeza.
  await api.put('/api/settings').set(bearer(adminToken)).send({ antelacionKm: 500 });
});

test('test_admin_consulta_la_bitacora_paginada_de_la_mas_reciente_a_la_mas_antigua', async () => {
  const response = await api.get('/api/audit-log?porPagina=5').set(bearer(adminToken));
  expect(response.status).toBe(200);
  expect(response.body).toMatchObject({ pagina: 1, paginas: expect.any(Number), total: expect.any(Number) });
  expect(response.body.acciones).toContain('PAGO_ANULADO');
  expect(response.body.elementos.length).toBeLessThanOrEqual(5);
  const fechas = response.body.elementos.map((e) => e.fecha);
  expect([...fechas].sort().reverse()).toEqual(fechas);
  // usuario, entidad y detalle pueden ser null (por ejemplo, login fallido
  // con un usuario inexistente): se revisa la forma, no los valores.
  expect(Object.keys(response.body.elementos[0]).sort()).toEqual(
    ['accion', 'detalle', 'entidad', 'entidadId', 'fecha', 'id', 'usuario', 'usuarioId'],
  );
  expect(response.body.elementos[0]).toMatchObject({ id: expect.any(Number), accion: expect.any(String) });
});

test('test_filtra_por_accion_usuario_y_fecha', async () => {
  const hoy = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const fecha = `${hoy.getFullYear()}-${pad(hoy.getMonth() + 1)}-${pad(hoy.getDate())}`;
  const response = await api
    .get(`/api/audit-log?accion=CONFIG_ACTUALIZADA&usuarioId=${adminId}&desde=${fecha}&hasta=${fecha}`)
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  expect(response.body.total).toBeGreaterThan(0);
  for (const entrada of response.body.elementos) {
    expect(entrada.accion).toBe('CONFIG_ACTUALIZADA');
    expect(entrada.usuarioId).toBe(adminId);
    expect(entrada.fecha.startsWith(fecha)).toBe(true);
  }
});

test.each([
  ['accion=BORRAR_TODO'],
  ['desde=2026-13-45x'],
  ['desde=2026-12-01&hasta=2026-11-01'],
  ['usuarioId=abc'],
  ['porPagina=51'],
])('test_filtro_invalido_%s_responde_400', async (query) => {
  const response = await api.get(`/api/audit-log?${query}`).set(bearer(adminToken));
  expect(response.status).toBe(400);
});

test.each([
  ['recepción', () => recepcionToken],
  ['mecánico', () => mecanicoToken],
])('test_%s_recibe_403', async (_rol, token) => {
  const response = await api.get('/api/audit-log').set(bearer(token()));
  expect(response.status).toBe(403);
});

test.each([
  ['post', '/api/audit-log'],
  ['put', '/api/audit-log/1'],
  ['delete', '/api/audit-log/1'],
])('test_no_existe_%s_sobre_la_bitacora', async (metodo, ruta) => {
  const response = await api[metodo](ruta).set(bearer(adminToken)).send({});
  expect(response.status).toBe(404);
});
