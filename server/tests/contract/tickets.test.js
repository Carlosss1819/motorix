// Pruebas de contrato de /api/tickets (Sprint 4, US4): generación idempotente
// del comprobante y consultas con sus códigos de error.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/tickets.md.
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
let kilometraje = 90000;
let contador = 0;

// Fija el estado directamente en la base de pruebas (patrón de
// payments.test.js) para preparar órdenes en TERMINADO sin transitar.
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
      motivoVisita: `Ticket de contrato ${suffix} ${contador}`,
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
        descripcion: `Servicio de ticket ${suffix} ${contador}`,
        duracionMinutos: 60,
        precio: conManoDeObra,
      });
    expect(servicio.status).toBe(201);
  }

  if (estado !== 'RECIBIDO') await fijarEstado(orden.body.id, estado);
  return orden.body.id;
}

// Orden TERMINADO con un pago aprobado: lista para generar su ticket (FR-009).
async function crearOrdenPagada(precio = 450) {
  const ordenId = await crearOrden({
    estado: 'TERMINADO',
    conManoDeObra: precio,
  });
  const pago = await api
    .post('/api/payments')
    .set(bearer(receptionistToken))
    .send({ ordenId, monto: precio, metodo: 'EFECTIVO' });
  expect(pago.status).toBe(201);
  return ordenId;
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
    .send({ nombre: `Tickets contrato ${suffix}`, telefono: `78${suffix}` });
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
      placas: `TC${suffix}`,
      kilometrajeActual: kilometraje,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('POST /api/tickets', () => {
  test('responde 201 con el comprobante completo en la primera generación', async () => {
    const ordenId = await crearOrdenPagada(500);

    const response = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      ordenId,
      folio: expect.stringMatching(/^T\d{6}-\d{4}$/),
      emitidoPor: 'recepcion',
      metodoPago: 'EFECTIVO',
      estadoPago: 'PAGADO',
      subtotalManoDeObra: 500,
      total: 500,
    });
    expect(response.body.taller).toMatchObject({ nombre: 'Motorix' });
    expect(response.body.cliente).toHaveProperty('nombre');
    expect(response.body.vehiculo).toMatchObject({ placas: `TC${suffix}` });
    expect(response.body.servicios).toHaveLength(1);
    expect(response.body.fecha).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  test('responde 200 con el mismo folio y el mismo id al reintentar (HU4-2)', async () => {
    const ordenId = await crearOrdenPagada(470);

    const primera = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });
    expect(primera.status).toBe(201);

    const segunda = await api
      .post('/api/tickets')
      .set(bearer(adminToken))
      .send({ ordenId });

    expect(segunda.status).toBe(200);
    expect(segunda.body.id).toBe(primera.body.id);
    expect(segunda.body.folio).toBe(primera.body.folio);
  });

  test('responde 400 VALIDACION con un ordenId inválido', async () => {
    const sinOrden = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({});
    expect(sinOrden.status).toBe(400);
    expect(sinOrden.body.error.codigo).toBe('VALIDACION');

    const noEntero = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId: 0 });
    expect(noEntero.status).toBe(400);
    expect(noEntero.body.error.codigo).toBe('VALIDACION');
  });

  test('responde 401 sin token y 403 para el mecánico (FR-003)', async () => {
    const sinToken = await api.post('/api/tickets').send({ ordenId: 1 });
    expect(sinToken.status).toBe(401);

    const response = await api
      .post('/api/tickets')
      .set(bearer(mechanicToken))
      .send({ ordenId: 1 });
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('responde 404 ORDEN_NO_ENCONTRADA con una orden inexistente', async () => {
    const response = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId: 999999 });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });

  test('responde 409 TICKET_REQUIERE_PAGO sin un pago aprobado (FR-009)', async () => {
    const ordenId = await crearOrden({
      estado: 'TERMINADO',
      conManoDeObra: 300,
    });

    const response = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('TICKET_REQUIERE_PAGO');
  });
});

describe('GET /api/tickets/:id', () => {
  test('responde 200 con el ticket por su id', async () => {
    const ordenId = await crearOrdenPagada(520);
    const generado = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });
    expect(generado.status).toBe(201);

    const response = await api
      .get(`/api/tickets/${generado.body.id}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      id: generado.body.id,
      folio: generado.body.folio,
      ordenId,
    });
  });

  test('responde 404 TICKET_NO_ENCONTRADO con un id inexistente', async () => {
    const response = await api
      .get('/api/tickets/999999')
      .set(bearer(receptionistToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('TICKET_NO_ENCONTRADO');
  });

  test('responde 401 sin token y 403 para el mecánico (FR-003)', async () => {
    const sinToken = await api.get('/api/tickets/1');
    expect(sinToken.status).toBe(401);

    const response = await api
      .get('/api/tickets/1')
      .set(bearer(mechanicToken));
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});

describe('GET /api/tickets/orden/:ordenId', () => {
  test('responde 200 con existe true y el ticket cuando ya existe', async () => {
    const ordenId = await crearOrdenPagada(540);
    const generado = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });
    expect(generado.status).toBe(201);

    const response = await api
      .get(`/api/tickets/orden/${ordenId}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body.existe).toBe(true);
    expect(response.body.ticket).toMatchObject({
      id: generado.body.id,
      folio: generado.body.folio,
    });
  });

  test('responde 200 con existe false y ticket null cuando no existe', async () => {
    const ordenId = await crearOrden({ estado: 'RECIBIDO' });

    const response = await api
      .get(`/api/tickets/orden/${ordenId}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ existe: false, ticket: null });
  });

  test('responde 404 ORDEN_NO_ENCONTRADA con una orden inexistente', async () => {
    const response = await api
      .get('/api/tickets/orden/999999')
      .set(bearer(receptionistToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });

  test('responde 401 sin token y 403 para el mecánico (FR-003)', async () => {
    const sinToken = await api.get('/api/tickets/orden/1');
    expect(sinToken.status).toBe(401);

    const response = await api
      .get('/api/tickets/orden/1')
      .set(bearer(mechanicToken));
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});
