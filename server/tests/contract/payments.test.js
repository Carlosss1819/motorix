// Pruebas de contrato de /api/payments (Sprint 4, US1): registro y consulta
// de pagos de una orden con sus códigos de error.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
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
let kilometraje = 50000;
let contador = 0;

// Fija el estado directamente en la base de pruebas (patrón de
// service-order-status.test.js) para preparar órdenes cobrables.
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

async function crearOrden({ estado = 'RECIBIDO', conManoDeObra = null } = {}) {
  contador += 1;
  kilometraje += 100;
  const orden = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: `Cobro de contrato ${suffix} ${contador}`,
      fechaIngreso: '2026-10-20',
      kilometraje,
    });
  expect(orden.status).toBe(201);

  if (conManoDeObra !== null) {
    // El alta de servicios es de ADMIN/MECHANIC (FR-022); se usa admin.
    const servicio = await api
      .post(`/api/service-orders/${orden.body.id}/servicios`)
      .set(bearer(adminToken))
      .send({
        descripcion: `Servicio de contrato ${suffix} ${contador}`,
        duracionMinutos: 60,
        precio: conManoDeObra,
      });
    expect(servicio.status).toBe(201);
  }

  if (estado !== 'RECIBIDO') await fijarEstado(orden.body.id, estado);
  return orden.body.id;
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
    .send({ nombre: `Pagos contrato ${suffix}`, telefono: `77${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2022,
      placas: `PC${suffix}`,
      kilometrajeActual: kilometraje,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('GET /api/payments/orden/:ordenId', () => {
  test('responde 200 paginado con los pagos de la orden (incluye anulados)', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO', conManoDeObra: 450 });
    const registro = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 450, metodo: 'EFECTIVO', fecha: '2026-10-20' });
    expect(registro.status).toBe(201);

    const response = await api
      .get(`/api/payments/orden/${ordenId}`)
      .query({ pagina: 1, porPagina: 10 })
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ pagina: 1, paginas: 1, total: 1 });
    expect(response.body.elementos).toHaveLength(1);
    expect(response.body.elementos[0]).toMatchObject({
      ordenId,
      monto: 450,
      metodo: 'EFECTIVO',
      estado: 'PAGADO',
    });
  });

  test('responde 401 sin token', async () => {
    const response = await api.get('/api/payments/orden/1');
    expect(response.status).toBe(401);
  });

  test('responde 403 para el rol de mecánico (FR-003, RN-15)', async () => {
    const response = await api
      .get('/api/payments/orden/1')
      .set(bearer(mechanicToken));
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('responde 404 ORDEN_NO_ENCONTRADA cuando la orden no existe', async () => {
    const response = await api
      .get('/api/payments/orden/999999')
      .set(bearer(adminToken));
    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });
});

describe('POST /api/payments — registro y rechazos (FR-004, FR-015)', () => {
  test('registra el pago de una orden TERMINADO y responde 201', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO', conManoDeObra: 650 });
    const response = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 650, metodo: 'EFECTIVO', fecha: '2026-10-20' });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      ordenId,
      monto: 650,
      metodo: 'EFECTIVO',
      estado: 'PAGADO',
      referenciaExterna: null,
      enlacePago: null,
      modoPasarela: null,
      motivoAnulacion: null,
    });
  });

  test('responde 409 ORDEN_NO_COBRABLE si la orden no está TERMINADO', async () => {
    const ordenId = await crearOrden();
    const response = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 100, metodo: 'EFECTIVO' });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('ORDEN_NO_COBRABLE');
  });

  test('responde 409 ORDEN_YA_LIQUIDADA si la orden ya tiene un pago PAGADO', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO', conManoDeObra: 300 });
    const primero = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 300, metodo: 'EFECTIVO' });
    expect(primero.status).toBe(201);

    const segundo = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 300, metodo: 'TARJETA' });

    expect(segundo.status).toBe(409);
    expect(segundo.body.error.codigo).toBe('ORDEN_YA_LIQUIDADA');
  });

  test('responde 409 MONTO_NO_COINCIDE si el monto difiere del total calculado', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO', conManoDeObra: 450 });
    const response = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 100, metodo: 'EFECTIVO' });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('MONTO_NO_COINCIDE');
  });

  test('responde 400 VALIDACION con un método fuera del enum (FR-002)', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO' });
    const response = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 100, metodo: 'CHEQUE' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain('método');
  });

  test('responde 401 sin token y 403 para el mecánico (FR-003)', async () => {
    const sinToken = await api.post('/api/payments').send({ ordenId: 1, monto: 1, metodo: 'EFECTIVO' });
    expect(sinToken.status).toBe(401);

    const response = await api
      .post('/api/payments')
      .set(bearer(mechanicToken))
      .send({ ordenId: 1, monto: 1, metodo: 'EFECTIVO' });
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('responde 404 ORDEN_NO_ENCONTRADA con una orden inexistente', async () => {
    const response = await api
      .post('/api/payments')
      .set(bearer(adminToken))
      .send({ ordenId: 999999, monto: 100, metodo: 'EFECTIVO' });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });
});
