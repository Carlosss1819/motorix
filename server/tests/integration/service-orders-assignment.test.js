// Pruebas de integración de la asignación de mecánico (US3 / FR-009): asignar,
// reasignar, desasignar con `mecanicoId: null` y rechazo en órdenes cerradas
// (TERMINADO/ENTREGADO). Fuente de verdad: contracts/service-orders.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let mecanicoId;
let recepcionId;
let mechanic2Id;
let clientId;
let vehicleId;

// La entrega todavía no tiene endpoint (llega en la US5), así que el estado
// ENTREGADO se fija directamente sobre la base de pruebas motorix_v2_test.
async function marcarComoEntregada(orderId) {
  const db = await mysql.createConnection(config.db);
  try {
    await db.query(
      "UPDATE service_orders SET status = 'ENTREGADO' WHERE id = ?",
      [orderId],
    );
  } finally {
    await db.end();
  }
}

async function crearOrden(kilometraje) {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Prueba de asignación',
      fechaIngreso: '2026-10-14',
      kilometraje,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

async function asignarOrden(orderId, body, token = adminToken) {
  return api
    .post(`/api/service-orders/${orderId}/asignar`)
    .set(bearer(token))
    .send(body);
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const mecanicoLogin = await api
    .post('/api/auth/login')
    .send({ identificador: 'mecanico', contrasena: 'Mecanico2026!' });
  expect(mecanicoLogin.status).toBe(200);
  mecanicoId = mecanicoLogin.body.usuario.id;

  const recepcionLogin = await api
    .post('/api/auth/login')
    .send({ identificador: 'recepcion', contrasena: 'Recepcion2026!' });
  expect(recepcionLogin.status).toBe(200);
  recepcionId = recepcionLogin.body.usuario.id;

  const mechanic2 = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({
      username: `asig_${suffix}`,
      email: `asig_${suffix}@motorix.local`,
      rol: 'MECHANIC',
      contrasena: 'Mecanico2026!',
    });
  expect(mechanic2.status).toBe(201);
  mechanic2Id = mechanic2.body.id;

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Asignación ${suffix}`, telefono: `72${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Kia',
      modelo: 'Rio',
      anio: 2023,
      placas: `AS2${suffix}`,
      kilometrajeActual: 800,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('asignación de mecánico (US3 / FR-009)', () => {
  test('asigna un mecánico y responde id, mecanicoId y usuario', async () => {
    const ordenId = await crearOrden(1000);

    const response = await asignarOrden(ordenId, { mecanicoId }, receptionistToken);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      id: ordenId,
      mecanicoId,
      mecanico: 'mecanico',
    });

    const detalle = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(adminToken));
    expect(detalle.body.mecanicoId).toBe(mecanicoId);
    expect(detalle.body.mecanico).toBe('mecanico');
  });

  test('la asignación queda registrada en el historial de la orden', async () => {
    const ordenId = await crearOrden(2000);

    await asignarOrden(ordenId, { mecanicoId });

    const detalle = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(adminToken));
    const ultimo = detalle.body.historial.at(-1);
    expect(ultimo).toEqual(
      expect.objectContaining({ de: 'RECIBIDO', a: 'RECIBIDO', usuario: 'admin' }),
    );
  });

  test('reasigna a otro mecánico activo', async () => {
    const ordenId = await crearOrden(3000);
    await asignarOrden(ordenId, { mecanicoId });

    const response = await asignarOrden(ordenId, { mecanicoId: mechanic2Id });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      id: ordenId,
      mecanicoId: mechanic2Id,
      mecanico: `asig_${suffix}`,
    });
  });

  test('desasigna con mecanicoId null y la orden queda sin mecánico', async () => {
    const ordenId = await crearOrden(4000);
    await asignarOrden(ordenId, { mecanicoId });

    const response = await asignarOrden(ordenId, { mecanicoId: null });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      id: ordenId,
      mecanicoId: null,
      mecanico: null,
    });
  });

  test('responde 409 si la orden está TERMINADO (FR-009)', async () => {
    // La orden 4 de los seeds está en estado TERMINADO.
    const response = await asignarOrden(4, { mecanicoId });

    expect(response.status).toBe(409);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: 'ORDEN_CERRADA',
    });
  });

  test('responde 409 si la orden está ENTREGADO (FR-009)', async () => {
    const ordenId = await crearOrden(5000);
    await marcarComoEntregada(ordenId);

    const response = await asignarOrden(ordenId, { mecanicoId });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('ORDEN_CERRADA');
  });

  test('responde 404 si el mecánico no existe o no tiene ese rol', async () => {
    const ordenId = await crearOrden(6000);

    const inexistente = await asignarOrden(ordenId, { mecanicoId: 99999999 });
    expect(inexistente.status).toBe(404);
    expect(inexistente.body.error.codigo).toBe('MECANICO_NO_ENCONTRADO');

    const noMecanico = await asignarOrden(ordenId, { mecanicoId: recepcionId });
    expect(noMecanico.status).toBe(404);
    expect(noMecanico.body.error.codigo).toBe('MECANICO_NO_ENCONTRADO');
  });

  test('responde 400 si el cuerpo no trae mecanicoId', async () => {
    const ordenId = await crearOrden(7000);

    const response = await asignarOrden(ordenId, {});

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('mecánico');
  });

  test('responde 404 si la orden no existe', async () => {
    const response = await asignarOrden(99999999, { mecanicoId });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });

  test('un mecánico no puede asignar (403, FR-022)', async () => {
    const ordenId = await crearOrden(8000);

    const response = await asignarOrden(ordenId, { mecanicoId }, mechanicToken);

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});
