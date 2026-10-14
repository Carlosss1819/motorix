// Pruebas de contrato de POST /api/service-orders/:id/estado (US5): el mapa
// de transiciones R-02, la matriz de permisos por rol R-03 / FR-022, el
// historial (FR-015) y la fecha de entrega.
// Fuente de verdad: specs/002-citas-ordenes-servicio/contracts/service-orders.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;
let kilometraje = 30000;

// El endpoint de transiciones es el primero de la US5, así que los estados
// previos (TERMINADO) se fijan directamente sobre motorix_v2_test.
async function fijarEstado(orderId, estado) {
  const db = await mysql.createConnection(config.db);
  try {
    await db.query('UPDATE service_orders SET status = ? WHERE id = ?', [
      estado,
      orderId,
    ]);
  } finally {
    await db.end();
  }
}

async function crearOrden(kilometrajeExtra = 0) {
  kilometraje += 100 + kilometrajeExtra;
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Transición de estados',
      fechaIngreso: '2026-10-16',
      kilometraje,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

async function cambiarEstado(orderId, token, body) {
  return api
    .post(`/api/service-orders/${orderId}/estado`)
    .set(bearer(token))
    .send(body);
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Estados ${suffix}`, telefono: `75${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Mazda',
      modelo: 'CX-5',
      anio: 2022,
      placas: `ES${suffix}`,
      kilometrajeActual: 700,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('contrato POST /api/service-orders/:id/estado', () => {
  test('ADMIN avanza RECIBIDO → DIAGNOSTICO con 200 e historial (FR-015)', async () => {
    const ordenId = await crearOrden();

    const response = await cambiarEstado(ordenId, adminToken, {
      estado: 'DIAGNOSTICO',
    });

    expect(response.status).toBe(200);
    expect(response.body.estado).toBe('DIAGNOSTICO');
    expect(response.body.fechaEntrega).toBeNull();
    const ultimo = response.body.historial.at(-1);
    expect(ultimo).toEqual({
      de: 'RECIBIDO',
      a: 'DIAGNOSTICO',
      usuario: 'admin',
      fecha: expect.any(String),
    });
  });

  test('el mecánico asignado gestiona el bloque medio con nota', async () => {
    const ordenId = await crearOrden(100);
    const asignacion = await api
      .post(`/api/service-orders/${ordenId}/asignar`)
      .set(bearer(receptionistToken))
      .send({ mecanicoId: 3 });
    expect(asignacion.status).toBe(200);

    const diagnostico = await cambiarEstado(ordenId, mechanicToken, {
      estado: 'DIAGNOSTICO',
    });
    expect(diagnostico.status).toBe(200);

    const reparacion = await cambiarEstado(ordenId, mechanicToken, {
      estado: 'EN_REPARACION',
      nota: 'Se cambiaron bujes',
    });
    expect(reparacion.status).toBe(200);
    expect(reparacion.body.estado).toBe('EN_REPARACION');

    const historial = reparacion.body.historial;
    expect(historial.at(-2)).toMatchObject({
      de: 'RECIBIDO',
      a: 'DIAGNOSTICO',
      usuario: 'mecanico',
    });
    expect(historial.at(-1)).toMatchObject({
      de: 'DIAGNOSTICO',
      a: 'EN_REPARACION',
      usuario: 'mecanico',
    });
  });

  test('403 cuando recepción intenta el bloque medio (FR-022)', async () => {
    const ordenId = await crearOrden(200);

    const response = await cambiarEstado(ordenId, receptionistToken, {
      estado: 'DIAGNOSTICO',
    });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('403 ORDEN_AJENA cuando un mecánico no asignado intenta el cambio', async () => {
    const ordenId = await crearOrden(300);

    const response = await cambiarEstado(ordenId, mechanicToken, {
      estado: 'DIAGNOSTICO',
    });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ORDEN_AJENA');
  });

  test('409 con los estados permitidos cuando la transición es inválida (SC-004)', async () => {
    const ordenId = await crearOrden(400);

    const response = await cambiarEstado(ordenId, adminToken, {
      estado: 'ENTREGADO',
    });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('TRANSICION_INVALIDA');
    expect(response.body.error.mensaje).toContain('DIAGNOSTICO');
  });

  test('TERMINADO → ENTREGADO: solo recepción o administración, y llena fechaEntrega', async () => {
    const ordenId = await crearOrden(500);
    await fijarEstado(ordenId, 'TERMINADO');

    // Sprint 4 / FR-014: la entrega exige un pago aprobado; se registra
    // primero la mano de obra y su cobro (el total debe coincidir, FR-015).
    const servicio = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Servicio de entrega', duracionMinutos: 30, precio: 150 });
    expect(servicio.status).toBe(201);

    const pago = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 150, metodo: 'EFECTIVO' });
    expect(pago.status).toBe(201);

    const rechazoMecanico = await cambiarEstado(ordenId, mechanicToken, {
      estado: 'ENTREGADO',
    });
    expect(rechazoMecanico.status).toBe(403);
    expect(rechazoMecanico.body.error.codigo).toBe('ROL_NO_AUTORIZADO');

    const entrega = await cambiarEstado(ordenId, receptionistToken, {
      estado: 'ENTREGADO',
      nota: 'Entregada al cliente',
    });
    expect(entrega.status).toBe(200);
    expect(entrega.body.estado).toBe('ENTREGADO');
    expect(entrega.body.fechaEntrega).toEqual(expect.any(String));
    expect(entrega.body.historial.at(-1)).toMatchObject({
      de: 'TERMINADO',
      a: 'ENTREGADO',
      usuario: 'recepcion',
    });
  });

  test('FR-014: la entrega sin un pago aprobado responde 409 PAGO_PENDIENTE', async () => {
    const ordenId = await crearOrden(550);
    await fijarEstado(ordenId, 'TERMINADO');

    const response = await cambiarEstado(ordenId, receptionistToken, {
      estado: 'ENTREGADO',
    });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('PAGO_PENDIENTE');
  });

  test('409 cuando la orden ya está ENTREGADO (estado terminal)', async () => {
    const ordenId = await crearOrden(600);
    await fijarEstado(ordenId, 'ENTREGADO');

    const response = await cambiarEstado(ordenId, adminToken, {
      estado: 'TERMINADO',
    });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('TRANSICION_INVALIDA');
    expect(response.body.error.mensaje).toContain('ya no admite');
  });

  test('404 si la orden no existe', async () => {
    const response = await cambiarEstado(99999999, adminToken, {
      estado: 'DIAGNOSTICO',
    });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });

  test('400 si el estado recibido no es válido', async () => {
    const ordenId = await crearOrden(700);

    const response = await cambiarEstado(ordenId, adminToken, {
      estado: 'VOLANDO',
    });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('estado');
  });
});
