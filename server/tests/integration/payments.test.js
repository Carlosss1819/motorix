// Pruebas de integración de los pagos (Sprint 4, US1): el pago nace ligado a
// su orden, la entrega exige un pago aprobado (FR-014) y la anulación deja la
// orden libre sin borrar el registro (FR-016, RN-9, SC-002).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let kilometraje = 70000;
let contador = 0;

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

async function consultaDirecta(sql, params = []) {
  const db = await mysql.createConnection(config.db);
  try {
    const [rows] = await db.query(sql, params);
    return rows;
  } finally {
    await db.end();
  }
}

// Orden con mano de obra en un estado dado; el total es `precio`.
async function crearOrdenCobrable({ estado = 'TERMINADO', precio = 450 } = {}) {
  contador += 1;
  kilometraje += 100;
  const orden = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: `Cobro de integración ${suffix} ${contador}`,
      fechaIngreso: '2026-10-21',
      kilometraje,
    });
  expect(orden.status).toBe(201);

  if (precio !== null) {
    const servicio = await api
      .post(`/api/service-orders/${orden.body.id}/servicios`)
      .set(bearer(adminToken))
      .send({
        descripcion: `Servicio de integración ${suffix} ${contador}`,
        duracionMinutos: 45,
        precio,
      });
    expect(servicio.status).toBe(201);
  }

  if (estado !== 'RECIBIDO') await fijarEstado(orden.body.id, estado);
  return orden.body.id;
}

async function registrarPago(ordenId, monto, metodo = 'EFECTIVO', token = receptionistToken) {
  return api
    .post('/api/payments')
    .set(bearer(token))
    .send({ ordenId, monto, metodo, fecha: '2026-10-21' });
}

async function entregarOrden(ordenId, token = receptionistToken) {
  return api
    .post(`/api/service-orders/${ordenId}/estado`)
    .set(bearer(token))
    .send({ estado: 'ENTREGADO' });
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Pagos integración ${suffix}`, telefono: `78${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Kia',
      modelo: 'Rio',
      anio: 2021,
      placas: `PI${suffix}`,
      kilometrajeActual: kilometraje,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('el pago registrado nace PAGADO y queda ligado a su orden (SC-002)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 450 });
  const response = await registrarPago(ordenId, 450);

  expect(response.status).toBe(201);
  expect(response.body.estado).toBe('PAGADO');
  expect(response.body.registradoPor).toBe('recepcion');

  // SC-002: ningún pago huérfano en el sistema (RN-13, FK obligatoria).
  const huerfanos = await consultaDirecta(
    `SELECT COUNT(*) AS total FROM payments p
     LEFT JOIN service_orders so ON so.id = p.service_order_id
     WHERE so.id IS NULL`,
  );
  expect(huerfanos[0].total).toBe(0);

  // El pago es visible en el detalle de la orden (escenario US1-3).
  const detalle = await api
    .get(`/api/payments/orden/${ordenId}`)
    .set(bearer(receptionistToken));
  expect(detalle.status).toBe(200);
  expect(detalle.body.elementos).toHaveLength(1);
  expect(detalle.body.elementos[0]).toMatchObject({ monto: 450, metodo: 'EFECTIVO' });
});

test('un segundo pago sobre la misma orden se rechaza (FR-004)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 800 });
  expect((await registrarPago(ordenId, 800)).status).toBe(201);

  const segundo = await registrarPago(ordenId, 800, 'TARJETA');
  expect(segundo.status).toBe(409);
  expect(segundo.body.error.codigo).toBe('ORDEN_YA_LIQUIDADA');
});

test('el monto debe coincidir con el total calculado con precios vigentes (FR-015)', async () => {
  // Mano de obra 450 + refacción del catálogo 320.00 × 2 = 1090.00.
  // La refacción se agrega antes de cerrar la orden (una orden TERMINADO no
  // admite cambios de contenido, FR-026).
  const ordenId = await crearOrdenCobrable({ estado: 'RECIBIDO', precio: 450 });
  const refaccion = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `PAY-${suffix}-${contador}`,
      nombre: `Refacción de pago ${suffix} ${contador}`,
      categoria: 'Frenos',
      stockInicial: 10,
      precioVenta: 320,
    });
  expect(refaccion.status).toBe(201);

  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.body.id, cantidad: 2 });
  expect(agregada.status).toBe(201);
  await fijarEstado(ordenId, 'TERMINADO');

  // El total mostrado por el formulario es el mismo que valida el registro
  // (T062): precios vigentes del catálogo y mismo módulo de cálculo.
  const total = await api
    .get(`/api/payments/orden/${ordenId}/total`)
    .set(bearer(receptionistToken));
  expect(total.status).toBe(200);
  expect(total.body.subtotalManoDeObra).toBe(450);
  expect(total.body.subtotalRefacciones).toBe(640);
  expect(total.body.total).toBe(1090);

  const malo = await registrarPago(ordenId, 450);
  expect(malo.status).toBe(409);
  expect(malo.body.error.codigo).toBe('MONTO_NO_COINCIDE');

  const bueno = await registrarPago(ordenId, 1090);
  expect(bueno.status).toBe(201);
  expect(bueno.body.monto).toBe(1090);
});

test('la orden no cobrable rechaza el pago (HU1-4)', async () => {
  const ordenId = await crearOrdenCobrable({ estado: 'RECIBIDO' });
  const response = await registrarPago(ordenId, 450);
  expect(response.status).toBe(409);
  expect(response.body.error.codigo).toBe('ORDEN_NO_COBRABLE');
  expect(response.body.error.mensaje).toContain('TERMINADO');
});

test('la entrega exige un pago aprobado y sin él responde 409 PAGO_PENDIENTE (FR-014)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 600 });

  const sinPago = await entregarOrden(ordenId);
  expect(sinPago.status).toBe(409);
  expect(sinPago.body.error.codigo).toBe('PAGO_PENDIENTE');
  expect(sinPago.body.error.mensaje).toContain('pago');

  // Con el pago registrado, la entrega procede y llena la fecha (FR-014).
  expect((await registrarPago(ordenId, 600)).status).toBe(201);
  const conPago = await entregarOrden(ordenId);
  expect(conPago.status).toBe(200);
  expect(conPago.body.estado).toBe('ENTREGADO');
  expect(conPago.body.fechaEntrega).not.toBeNull();
});

test('la anulación es de administración, exige motivo y deja la orden libre (FR-016)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 350 });
  const pago = await registrarPago(ordenId, 350);
  expect(pago.status).toBe(201);

  // Recepción no puede anular (RN-15).
  const comoRecepcion = await api
    .post(`/api/payments/${pago.body.id}/anular`)
    .set(bearer(receptionistToken))
    .send({ motivo: 'Intento no autorizado' });
  expect(comoRecepcion.status).toBe(403);

  // Sin motivo no se anula (FR-016).
  const sinMotivo = await api
    .post(`/api/payments/${pago.body.id}/anular`)
    .set(bearer(adminToken))
    .send({});
  expect(sinMotivo.status).toBe(400);

  const anulado = await api
    .post(`/api/payments/${pago.body.id}/anular`)
    .set(bearer(adminToken))
    .send({ motivo: 'Cobro capturado por error' });
  expect(anulado.status).toBe(200);
  expect(anulado.body).toMatchObject({
    estado: 'ANULADO',
    motivoAnulacion: 'Cobro capturado por error',
  });

  // El pago anulado se conserva como historial (RN-9), sin borrados.
  const historial = await api
    .get(`/api/payments/orden/${ordenId}`)
    .set(bearer(adminToken));
  expect(historial.status).toBe(200);
  expect(historial.body.elementos).toHaveLength(1);
  expect(historial.body.elementos[0].estado).toBe('ANULADO');

  // La orden queda libre: admite un nuevo cobro correcto.
  const nuevo = await registrarPago(ordenId, 350, 'TARJETA');
  expect(nuevo.status).toBe(201);
  expect(nuevo.body.estado).toBe('PAGADO');

  // El pago anulado no cuenta como liquidación en la entrega.
  expect((await entregarOrden(ordenId)).status).toBe(200);
});

test('no se puede anular un pago de una orden ya ENTREGADO (RN-9)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 500 });
  const pago = await registrarPago(ordenId, 500);
  expect((await entregarOrden(ordenId)).status).toBe(200);

  const response = await api
    .post(`/api/payments/${pago.body.id}/anular`)
    .set(bearer(adminToken))
    .send({ motivo: 'Corrección posterior a la entrega' });

  expect(response.status).toBe(409);
  expect(response.body.error.codigo).toBe('ORDEN_ENTREGADA');
});

test('un pago anulado dos veces responde 409 TRANSICION_INVALIDA (D7)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 250 });
  const pago = await registrarPago(ordenId, 250);
  expect(
    (await api
      .post(`/api/payments/${pago.body.id}/anular`)
      .set(bearer(adminToken))
      .send({ motivo: 'Primera anulación' })).status,
  ).toBe(200);

  const segunda = await api
    .post(`/api/payments/${pago.body.id}/anular`)
    .set(bearer(adminToken))
    .send({ motivo: 'Segunda anulación' });
  expect(segunda.status).toBe(409);
  expect(segunda.body.error.codigo).toBe('TRANSICION_INVALIDA');
});

test('cada método (efectivo, tarjeta, transferencia) se guarda con su valor correcto (FR-002)', async () => {
  for (const metodo of ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']) {
    const ordenId = await crearOrdenCobrable({ precio: 600 });
    const response = await registrarPago(ordenId, 600, metodo);

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      ordenId,
      metodo,
      estado: 'PAGADO',
    });

    // El valor guardado es el del enum, el que luego se lista como historial.
    const historial = await api
      .get(`/api/payments/orden/${ordenId}`)
      .set(bearer(receptionistToken));
    expect(historial.status).toBe(200);
    expect(historial.body.elementos[0].metodo).toBe(metodo);
  }
});

test('un método fuera del enum responde 400 VALIDACION sin guardar nada (FR-002)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 200 });
  const response = await api
    .post('/api/payments')
    .set(bearer(receptionistToken))
    .send({ ordenId, monto: 200, metodo: 'CHEQUE' });

  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('VALIDACION');

  const filas = await consultaDirecta(
    'SELECT COUNT(*) AS total FROM payments WHERE service_order_id = ?',
    [ordenId],
  );
  expect(filas[0].total).toBe(0);
});

test('sin método el registro responde 400 «método de pago requerido» (HU2-3)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 300 });
  const response = await api
    .post('/api/payments')
    .set(bearer(receptionistToken))
    .send({ ordenId, monto: 300 });

  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('VALIDACION');
  expect(response.body.error.mensaje).toContain('método de pago requerido');
});

test('el cobro Mercado Pago nace PENDIENTE con referencia, enlace y modo (SC-004)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 900 });
  const response = await registrarPago(ordenId, 900, 'MERCADO_PAGO');

  expect(response.status).toBe(201);
  expect(response.body).toMatchObject({
    ordenId,
    metodo: 'MERCADO_PAGO',
    estado: 'PENDIENTE',
    // Sin credenciales en el entorno de pruebas se usa la pasarela simulada (D1).
    modoPasarela: 'simulado',
  });
  expect(response.body.referenciaExterna).toBeTruthy();
  expect(response.body.enlacePago).toBeTruthy();

  // Mientras el pendiente siga abierto no se admite ningún segundo cobro
  // (FR-005): ni presencial ni otro Mercado Pago.
  const enEfectivo = await registrarPago(ordenId, 900, 'EFECTIVO');
  expect(enEfectivo.status).toBe(409);
  expect(enEfectivo.body.error.codigo).toBe('PAGO_PENDIENTE');

  const otroMercadoPago = await registrarPago(ordenId, 900, 'MERCADO_PAGO');
  expect(otroMercadoPago.status).toBe(409);
  expect(otroMercadoPago.body.error.codigo).toBe('PAGO_PENDIENTE');
});

test('confirmar a PAGADO liquida la orden y su entrega se vuelve posible (FR-014)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 750 });
  const registro = await registrarPago(ordenId, 750, 'MERCADO_PAGO');
  expect(registro.status).toBe(201);

  const confirmado = await api
    .post(`/api/payments/${registro.body.id}/confirmar`)
    .set(bearer(receptionistToken))
    .send({ estado: 'PAGADO' });
  expect(confirmado.status).toBe(200);
  expect(confirmado.body).toMatchObject({
    metodo: 'MERCADO_PAGO',
    estado: 'PAGADO',
  });

  // Liquidada: no admite otro cobro (FR-004).
  const otro = await registrarPago(ordenId, 750, 'EFECTIVO');
  expect(otro.status).toBe(409);
  expect(otro.body.error.codigo).toBe('ORDEN_YA_LIQUIDADA');

  // Y con su pago aprobado la entrega pasa (FR-014).
  expect((await entregarOrden(ordenId)).status).toBe(200);
});

test('rechazar o cancelar el pendiente libera la orden para otro intento (HU3-3, HU3-4)', async () => {
  for (const estado of ['RECHAZADO', 'CANCELADO']) {
    const ordenId = await crearOrdenCobrable({ precio: 650 });
    const registro = await registrarPago(ordenId, 650, 'MERCADO_PAGO');
    expect(registro.status).toBe(201);

    const confirmado = await api
      .post(`/api/payments/${registro.body.id}/confirmar`)
      .set(bearer(receptionistToken))
      .send({ estado });
    expect(confirmado.status).toBe(200);
    expect(confirmado.body.estado).toBe(estado);

    // La orden admite de inmediato un nuevo cobro presencial.
    const nuevo = await registrarPago(ordenId, 650, 'EFECTIVO');
    expect(nuevo.status).toBe(201);
    expect(nuevo.body.estado).toBe('PAGADO');
  }
});

test('el flujo Mercado Pago no guarda ni devuelve datos de tarjeta ni credenciales (RN-14)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 550 });
  const response = await registrarPago(ordenId, 550, 'MERCADO_PAGO');
  expect(response.status).toBe(201);

  // Ni en la respuesta...
  const cuerpo = JSON.stringify(response.body);
  expect(cuerpo).not.toMatch(/card|cvv|cvc|tarjeta|accessToken|MP_ACCESS_TOKEN/i);

  // ...ni en la fila guardada en la base de datos.
  const filas = await consultaDirecta(
    'SELECT * FROM payments WHERE service_order_id = ?',
    [ordenId],
  );
  expect(filas).toHaveLength(1);
  const columnas = Object.keys(filas[0]);
  expect(columnas.join(',')).not.toMatch(/card|cvv|cvc|password|token/i);
  expect(JSON.stringify(filas[0])).not.toMatch(/card|cvv|cvc|MP_ACCESS_TOKEN/i);

  // Si el entorno tuviera el access token real, tampoco se filtraría.
  if (process.env.MP_ACCESS_TOKEN) {
    expect(cuerpo).not.toContain(process.env.MP_ACCESS_TOKEN);
  }
});
