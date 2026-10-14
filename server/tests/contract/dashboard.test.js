// Pruebas de contrato de GET /api/dashboard (Sprint 4, US5): resumen del
// panel solo para administración, con fecha de referencia y contadores de
// órdenes reales (FR-010, SC-006).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;

beforeAll(async () => {
  await prepareTestDatabase();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');
});

test('responde 200 para admin con fecha y el bloque de órdenes (SC-005)', async () => {
  const response = await api.get('/api/dashboard').set(bearer(adminToken));

  expect(response.status).toBe(200);
  expect(response.body.fecha).toMatch(/^\d{4}-\d{2}-\d{2}$/);

  const ordenes = response.body.ordenes;
  expect(ordenes.total).toEqual(expect.any(Number));
  expect(ordenes.abiertas).toEqual(expect.any(Number));
  expect(ordenes.entregadas).toEqual(expect.any(Number));

  // porEstado trae exactamente los seis estados de ORDER_STATUSES.
  expect(ordenes.porEstado).toEqual({
    RECIBIDO: expect.any(Number),
    DIAGNOSTICO: expect.any(Number),
    EN_REPARACION: expect.any(Number),
    ESPERANDO_REFACCION: expect.any(Number),
    TERMINADO: expect.any(Number),
    ENTREGADO: expect.any(Number),
  });

  // Los bloques son consistentes entre sí (sin dobles conteos, CA-6).
  const suma = Object.values(ordenes.porEstado).reduce(
    (total, valor) => total + valor,
    0,
  );
  expect(suma).toBe(ordenes.total);
  expect(ordenes.entregadas).toBe(ordenes.porEstado.ENTREGADO);
  expect(ordenes.abiertas).toBe(ordenes.total - ordenes.entregadas);

  // Alcance (Principio I): no hay bloque de ingresos.
  expect(response.body).not.toHaveProperty('ingresos');
});

test('acepta la fecha de referencia y la devuelve (FR-011)', async () => {
  const response = await api
    .get('/api/dashboard?fecha=2026-10-20')
    .set(bearer(adminToken));

  expect(response.status).toBe(200);
  expect(response.body.fecha).toBe('2026-10-20');
});

test('responde 400 VALIDACION con una fecha fuera de AAAA-MM-DD', async () => {
  const response = await api
    .get('/api/dashboard?fecha=20/10/2026')
    .set(bearer(adminToken));

  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('VALIDACION');
});

test('responde 401 sin token', async () => {
  const response = await api.get('/api/dashboard');

  expect(response.status).toBe(401);
});

test('responde 403 PANEL_SOLO_ADMIN a recepción y mecánico (SC-006, RN-15)', async () => {
  for (const token of [receptionistToken, mechanicToken]) {
    const response = await api.get('/api/dashboard').set(bearer(token));

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('PANEL_SOLO_ADMIN');
  }
});
