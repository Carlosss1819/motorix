// Pruebas de integración de los tickets (Sprint 4, US4): folio consecutivo
// por año (SC-003), generación sin duplicados (HU4-2), reconstrucción del
// comprobante desde la orden y su pago con los subtotales de order-total.js
// (NULL tratado como 0, D2) y ausencia de datos sensibles (RN-14).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/tickets.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let kilometraje = 80000;
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
      motivoVisita: `Ticket de integración ${suffix} ${contador}`,
      fechaIngreso: '2026-10-22',
      kilometraje,
    });
  expect(orden.status).toBe(201);

  if (precio !== null) {
    const servicio = await api
      .post(`/api/service-orders/${orden.body.id}/servicios`)
      .set(bearer(adminToken))
      .send({
        descripcion: `Servicio de ticket ${suffix} ${contador}`,
        duracionMinutos: 45,
        precio,
      });
    expect(servicio.status).toBe(201);
  }

  if (estado !== 'RECIBIDO') await fijarEstado(orden.body.id, estado);
  return orden.body.id;
}

async function registrarPago(ordenId, monto, metodo = 'EFECTIVO') {
  return api
    .post('/api/payments')
    .set(bearer(receptionistToken))
    .send({ ordenId, monto, metodo, fecha: '2026-10-22' });
}

// Orden con contenido rico para el comprobante: una mano de obra con precio,
// otra sin precio (NULL → 0, D2) y una refacción del catálogo.
async function crearOrdenConContenido() {
  contador += 1;
  kilometraje += 100;
  const orden = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: `Contenido de ticket ${suffix} ${contador}`,
      fechaIngreso: '2026-10-22',
      kilometraje,
    });
  expect(orden.status).toBe(201);
  const ordenId = orden.body.id;

  const descripcionA = `Diagnóstico de ticket ${suffix} ${contador}`;
  const servicioA = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(adminToken))
    .send({
      descripcion: descripcionA,
      duracionMinutos: 30,
      precio: 450,
    });
  expect(servicioA.status).toBe(201);

  const descripcionB = `Revisión sin precio ${suffix} ${contador}`;
  const servicioB = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(adminToken))
    .send({ descripcion: descripcionB, duracionMinutos: 20 });
  expect(servicioB.status).toBe(201);

  const codigo = `TKT-${suffix}-${contador}`;
  const nombre = `Refacción de ticket ${suffix} ${contador}`;
  const refaccion = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo,
      nombre,
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
  return { ordenId, descripcionA, descripcionB, codigo, nombre };
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Tickets integración ${suffix}`, telefono: `79${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2023,
      placas: `TI${suffix}`,
      kilometrajeActual: kilometraje,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('los folios siguen el formato T000000-AAAA y son consecutivos (SC-003)', async () => {
  const ordenA = await crearOrdenCobrable({ precio: 410 });
  const ordenB = await crearOrdenCobrable({ precio: 420 });
  expect((await registrarPago(ordenA, 410)).status).toBe(201);
  expect((await registrarPago(ordenB, 420)).status).toBe(201);

  const primero = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId: ordenA });
  expect(primero.status).toBe(201);

  const segundo = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId: ordenB });
  expect(segundo.status).toBe(201);

  const anio = new Date().getFullYear();
  const patron = new RegExp(`^T\\d{6}-${anio}$`);
  expect(primero.body.folio).toMatch(patron);
  expect(segundo.body.folio).toMatch(patron);

  const numero = (folio) => Number(folio.slice(1, 7));
  expect(numero(segundo.body.folio)).toBe(numero(primero.body.folio) + 1);
});

test('regenerar el ticket devuelve el mismo registro y no lo duplica (HU4-2)', async () => {
  const ordenId = await crearOrdenCobrable({ precio: 460 });
  expect((await registrarPago(ordenId, 460)).status).toBe(201);

  const primera = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId });
  expect(primera.status).toBe(201);

  const segunda = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId });
  expect(segunda.status).toBe(200);
  expect(segunda.body.id).toBe(primera.body.id);
  expect(segunda.body.folio).toBe(primera.body.folio);

  // En la base sigue habiendo exactamente un ticket para la orden.
  const filas = await consultaDirecta(
    'SELECT COUNT(*) AS total FROM tickets WHERE service_order_id = ?',
    [ordenId],
  );
  expect(filas[0].total).toBe(1);
});

test('el ticket reconstruye el detalle con los subtotales de order-total.js (D2)', async () => {
  const { ordenId, descripcionA, descripcionB, codigo, nombre } =
    await crearOrdenConContenido();

  // El total vigente del formulario y el del ticket salen del mismo cálculo.
  const total = await api
    .get(`/api/payments/orden/${ordenId}/total`)
    .set(bearer(receptionistToken));
  expect(total.status).toBe(200);
  expect(total.body.subtotalManoDeObra).toBe(450);
  expect(total.body.subtotalRefacciones).toBe(640);
  expect(total.body.total).toBe(1090);

  expect((await registrarPago(ordenId, 1090)).status).toBe(201);

  const response = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId });
  expect(response.status).toBe(201);

  const ticket = response.body;
  expect(ticket).toMatchObject({
    ordenId,
    emitidoPor: 'recepcion',
    metodoPago: 'EFECTIVO',
    estadoPago: 'PAGADO',
    subtotalManoDeObra: 450,
    subtotalRefacciones: 640,
    total: 1090,
    cliente: { nombre: `Tickets integración ${suffix}` },
    vehiculo: {
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2023,
      placas: `TI${suffix}`,
    },
  });
  expect(ticket.fecha).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  expect(ticket.emitidoEn).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/);

  // Mano de obra: precio NULL tratado como 0 (D2).
  expect(ticket.servicios).toHaveLength(2);
  expect(ticket.servicios[0]).toMatchObject({
    descripcion: descripcionA,
    manoDeObra: 450,
  });
  expect(ticket.servicios[1]).toMatchObject({
    descripcion: descripcionB,
    manoDeObra: 0,
  });

  // Las refacciones viajan anidadas con su código, cantidad y subtotales.
  expect(ticket.servicios[0].refacciones).toHaveLength(1);
  expect(ticket.servicios[0].refacciones[0]).toEqual({
    codigo,
    nombre,
    cantidad: 2,
    precioUnitario: 320,
    subtotal: 640,
  });

  // RN-14: el comprobante no arrastra datos de tarjeta ni credenciales.
  const cuerpo = JSON.stringify(ticket);
  expect(cuerpo).not.toMatch(/card|cvv|cvc|4111|accessToken|MP_ACCESS_TOKEN/i);
  if (process.env.MP_ACCESS_TOKEN) {
    expect(cuerpo).not.toContain(process.env.MP_ACCESS_TOKEN);
  }

  // La consulta por orden confirma que ya existe (para el botón «Ver ticket»).
  const porOrden = await api
    .get(`/api/tickets/orden/${ordenId}`)
    .set(bearer(receptionistToken));
  expect(porOrden.status).toBe(200);
  expect(porOrden.body.existe).toBe(true);
  expect(porOrden.body.ticket.folio).toBe(ticket.folio);
});
