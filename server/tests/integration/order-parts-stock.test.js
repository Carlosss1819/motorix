// Pruebas de integración del uso de refacciones en órdenes (US7, Sprint 3):
// la salida descuenta stock en la MISMA transacción que deja el movimiento
// con la orden, el retiro repone con una ENTRADA de reposición (R-09), una
// fila heredada sin `part_id` se elimina sin movimiento, una orden cerrada
// responde 409 y dos peticiones simultáneas nunca dejan stock negativo
// (FR-024 a FR-026, RN-7, RN-8).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let suffix;
let clientId;
let vehicleId;
let contador = 0;

async function crearRefaccion(stock) {
  contador += 1;
  const response = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `STK-${suffix}-${contador}`,
      nombre: `Refacción de stock ${suffix} ${contador}`,
      categoria: 'Frenos',
      stockInicial: stock,
      stockMinimo: 1,
    });
  expect(response.status).toBe(201);
  return response.body;
}

async function crearOrden() {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Control de stock en la orden',
      fechaIngreso: '2026-10-14',
      kilometraje: 800,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

async function stockDe(partId) {
  const response = await api
    .get(`/api/parts/${partId}`)
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  return response.body.stockActual;
}

async function movimientosDe(partId, query = '') {
  const response = await api
    .get(`/api/parts/${partId}/movements${query}`)
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  return response.body;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Stock ${suffix}`, telefono: `75${suffix}` });
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
      placas: `SK${suffix}`,
      kilometrajeActual: 800,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('la salida descuenta el stock y deja el movimiento SALIDA con la orden (FR-024)', async () => {
  const refaccion = await crearRefaccion(5);
  const ordenId = await crearOrden();

  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 2 });
  expect(agregada.status).toBe(201);
  expect(agregada.body.stockActual).toBe(3);
  expect(await stockDe(refaccion.id)).toBe(3);

  const movimientos = await movimientosDe(refaccion.id);
  expect(movimientos.total).toBe(2);
  expect(movimientos.elementos[0]).toMatchObject({
    tipo: 'SALIDA',
    cantidad: 2,
    ordenId,
    stockAfter: 3,
  });
  expect(movimientos.elementos[1]).toMatchObject({
    tipo: 'ENTRADA',
    motivo: 'Stock inicial',
    stockAfter: 5,
  });
});

test('el retiro repone el stock y registra la ENTRADA de reposición (FR-026, R-09)', async () => {
  const refaccion = await crearRefaccion(6);
  const ordenId = await crearOrden();
  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 4 });
  expect(agregada.status).toBe(201);
  expect(await stockDe(refaccion.id)).toBe(2);

  const retirada = await api
    .delete(
      `/api/service-orders/${ordenId}/refacciones/${agregada.body.id}`,
    )
    .set(bearer(adminToken));
  expect(retirada.status).toBe(200);
  expect(retirada.body).toEqual({
    mensaje: 'Refacción retirada de la orden.',
    stockActual: 6,
  });

  const movimientos = await movimientosDe(refaccion.id);
  expect(movimientos.total).toBe(3);
  expect(movimientos.elementos[0]).toMatchObject({
    tipo: 'ENTRADA',
    cantidad: 4,
    motivo: `Reposición por retiro de la orden #${ordenId}`,
    ordenId,
    stockAfter: 6,
  });
});

test('una fila heredada sin part_id se elimina sin movimiento de inventario', async () => {
  const ordenId = await crearOrden();
  const db = await mysql.createConnection(config.db);
  let filaHeredada;
  try {
    const [result] = await db.query(
      `INSERT INTO order_parts (service_order_id, description, quantity)
       VALUES (?, ?, ?)`,
      [ordenId, 'Repuesto registrado antes del inventario', 2],
    );
    filaHeredada = result.insertId;
  } finally {
    await db.end();
  }

  const refaccion = await crearRefaccion(4);
  const antes = await movimientosDe(refaccion.id);

  const retirada = await api
    .delete(`/api/service-orders/${ordenId}/refacciones/${filaHeredada}`)
    .set(bearer(adminToken));
  expect(retirada.status).toBe(200);
  expect(retirada.body).toEqual({
    mensaje: 'Refacción retirada de la orden.',
    // Nunca hubo descuento de inventario que reponer.
    stockActual: null,
  });
  expect(await stockDe(refaccion.id)).toBe(4);

  const despues = await movimientosDe(refaccion.id);
  expect(despues.total).toBe(antes.total);

  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(adminToken));
  expect(detalle.body.repuestos).toHaveLength(0);
});

test('una orden cerrada rechaza agregar y retirar refacciones (409)', async () => {
  const refaccion = await crearRefaccion(5);
  const ordenId = await crearOrden();
  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 1 });
  expect(agregada.status).toBe(201);

  // RECIBIDO → DIAGNOSTICO → TERMINADO con el administrador.
  const aDiagnostico = await api
    .post(`/api/service-orders/${ordenId}/estado`)
    .set(bearer(adminToken))
    .send({ estado: 'DIAGNOSTICO' });
  expect(aDiagnostico.status).toBe(200);
  const aTerminado = await api
    .post(`/api/service-orders/${ordenId}/estado`)
    .set(bearer(adminToken))
    .send({ estado: 'TERMINADO' });
  expect(aTerminado.status).toBe(200);

  const alta = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 1 });
  expect(alta.status).toBe(409);
  expect(alta.body.error.codigo).toBe('ORDEN_CERRADA');

  const retiro = await api
    .delete(
      `/api/service-orders/${ordenId}/refacciones/${agregada.body.id}`,
    )
    .set(bearer(adminToken));
  expect(retiro.status).toBe(409);
  expect(retiro.body.error.codigo).toBe('ORDEN_CERRADA');

  // El stock no se movió al intentar los cambios rechazados.
  expect(await stockDe(refaccion.id)).toBe(4);
});

test('dos altas simultáneas nunca dejan stock negativo (caso límite RN-8)', async () => {
  const refaccion = await crearRefaccion(3);
  const ordenId = await crearOrden();

  // Stock 3 y dos peticiones de 2 unidades: solo cabe UNA de las dos.
  const peticiones = [1, 2].map(() =>
    api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 2 }),
  );
  const [primera, segunda] = await Promise.all(peticiones);
  const respuestas = [primera, segunda];

  const aceptadas = respuestas.filter((r) => r.status === 201);
  const rechazadas = respuestas.filter((r) => r.status === 409);
  expect(aceptadas).toHaveLength(1);
  expect(rechazadas).toHaveLength(1);
  expect(rechazadas[0].body.error.codigo).toBe('STOCK_INSUFICIENTE');

  // RN-8: el stock nunca queda negativo y explica exactamente una salida.
  const stockFinal = await stockDe(refaccion.id);
  expect(stockFinal).toBeGreaterThanOrEqual(0);
  expect(stockFinal).toBe(1);

  const movimientos = await movimientosDe(refaccion.id, '?tipo=SALIDA');
  expect(movimientos.total).toBe(1);
  expect(movimientos.elementos[0].stockAfter).toBe(1);
});
