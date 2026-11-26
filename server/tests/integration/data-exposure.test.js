// Integración (Sprint 7, US10, FR-028, CA-24): ninguna respuesta de usuarios,
// refacciones, órdenes, pagos y tickets incluye el hash de contraseña ni el
// token, y los precios reservados al rol no salen.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';

let ctx;
let ordenId;
let partId;
let pagoId;
let ticketId;

function sinSecretos(cuerpo, tokens) {
  const texto = JSON.stringify(cuerpo);
  expect(texto).not.toMatch(/password|passwordHash|password_hash/i);
  expect(texto).not.toMatch(/\$2[aby]\$/);
  for (const token of Object.values(tokens)) expect(texto).not.toContain(token);
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Exposición S7');
  partId = await ctx.crearRefaccion({ precioVenta: 210, precioCompra: 120 });
  ordenId = await ctx.ordenTerminada({ precio: 300, refaccion: partId });
  const total = await ctx.total(ordenId);
  const pago = await ctx.pagar(ordenId, total.total);
  pagoId = pago.body.id;
  ticketId = (await ctx.generarTicket(ordenId)).body.id;
});

test('test_las_respuestas_no_traen_hash_ni_token_en_ningun_rol', async () => {
  const consultas = [
    ['admin', '/api/users'],
    ['admin', '/api/auth/me'],
    ['recepcion', '/api/users/mechanics'],
    ['admin', '/api/parts'],
    ['admin', `/api/parts/${partId}`],
    ['recepcion', '/api/parts'],
    ['mecanico', '/api/parts'],
    ['admin', `/api/service-orders/${ordenId}`],
    ['recepcion', '/api/service-orders'],
    ['recepcion', `/api/payments/orden/${ordenId}`],
    ['recepcion', `/api/tickets/${ticketId}`],
    ['admin', '/api/audit-log'],
    ['admin', '/api/terms/acceptances'],
  ];
  for (const [rol, ruta] of consultas) {
    const response = await api.get(ruta).set(bearer(ctx.tokens[rol]));
    expect(response.status).toBe(200);
    sinSecretos(response.body, ctx.tokens);
  }
  expect(pagoId).toEqual(expect.any(Number));
});

test('test_el_precio_de_compra_solo_lo_ve_admin_y_el_mecanico_no_ve_precios_de_refaccion', async () => {
  const admin = await api.get(`/api/parts/${partId}`).set(bearer(ctx.tokens.admin));
  expect(admin.body).toHaveProperty('precioCompra', 120);

  const recepcion = await api.get(`/api/parts/${partId}`).set(bearer(ctx.tokens.recepcion));
  expect(recepcion.body).not.toHaveProperty('precioCompra');
  expect(recepcion.body).toHaveProperty('precioVenta');

  const mecanico = await api.get(`/api/parts/${partId}`).set(bearer(ctx.tokens.mecanico));
  expect(mecanico.body).not.toHaveProperty('precioCompra');
  expect(mecanico.body).not.toHaveProperty('precioVenta');
});

test('test_el_mecanico_no_recibe_pagos_tickets_ni_bitacora', async () => {
  for (const ruta of [`/api/payments/orden/${ordenId}`, `/api/tickets/${ticketId}`, '/api/audit-log', '/api/settings']) {
    const response = await api.get(ruta).set(bearer(ctx.tokens.mecanico));
    expect(response.status).toBe(403);
  }
});

test('test_un_error_interno_no_devuelve_trazas', async () => {
  const response = await api.get('/api/service-orders/abc').set(bearer(ctx.tokens.admin));
  expect(JSON.stringify(response.body)).not.toMatch(/at \w+ \(|node_modules|\.js:\d+/);
});
