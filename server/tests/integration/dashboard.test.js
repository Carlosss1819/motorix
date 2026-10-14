// Pruebas de integración del panel de control (Sprint 4, US5): los
// contadores del bloque `ordenes` coinciden con los registros individuales
// sin duplicar información aunque la orden tenga pagos y tickets (SC-005,
// CA-6, FR-010).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { config } from '../../config/env.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let kilometraje = 60000;
let contador = 0;

async function consultaDirecta(sql, params = []) {
  const db = await mysql.createConnection(config.db);
  try {
    const [rows] = await db.query(sql, params);
    return rows;
  } finally {
    await db.end();
  }
}

async function fijarEstado(orderId, estado) {
  await consultaDirecta('UPDATE service_orders SET status = ? WHERE id = ?', [
    estado,
    orderId,
  ]);
}

// Orden propia de la prueba, en el estado indicado.
async function crearOrden(estado = 'RECIBIDO', precio = null) {
  contador += 1;
  kilometraje += 100;
  const orden = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: `Dashboard de integración ${suffix} ${contador}`,
      fechaIngreso: '2026-10-23',
      kilometraje,
    });
  expect(orden.status).toBe(201);

  if (precio !== null) {
    const servicio = await api
      .post(`/api/service-orders/${orden.body.id}/servicios`)
      .set(bearer(adminToken))
      .send({
        descripcion: `Servicio de dashboard ${suffix} ${contador}`,
        duracionMinutos: 30,
        precio,
      });
    expect(servicio.status).toBe(201);
  }

  if (estado !== 'RECIBIDO') await fijarEstado(orden.body.id, estado);
  return orden.body.id;
}

// Conteo individual por estado, directo desde la base.
async function contarEstados() {
  const filas = await consultaDirecta(
    'SELECT status, COUNT(*) AS total FROM service_orders GROUP BY status ORDER BY status',
  );
  return Object.fromEntries(
    filas.map((fila) => [fila.status, Number(fila.total)]),
  );
}

// Lee el panel, el listado individual y los conteos de la base dentro de una
// ventana estable: los archivos de prueba corren en paralelo, así que si
// otra suite escribe órdenes durante la lectura se reintenta (SC-005).
async function panelYConteos() {
  for (let intento = 0; intento < 25; intento += 1) {
    const antes = await contarEstados();

    const panel = await api.get('/api/dashboard').set(bearer(adminToken));
    expect(panel.status).toBe(200);

    const listado = await api
      .get('/api/service-orders?pagina=1&porPagina=1')
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);

    const despues = await contarEstados();
    if (JSON.stringify(antes) === JSON.stringify(despues)) {
      return {
        panel: panel.body,
        totalListado: listado.body.total,
        conteos: antes,
      };
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error('No se obtuvo una ventana estable para comparar los conteos');
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Dashboard integración ${suffix}`, telefono: `77${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2021,
      placas: `DS${suffix}`,
      kilometrajeActual: kilometraje,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('los conteos del panel coinciden con la base y el listado, sin duplicados (SC-005, CA-6)', async () => {
  // Dos órdenes abiertas y una entregada que además tiene pago y ticket:
  // los JOIN con pagos y tickets no deben duplicar su conteo.
  const abierta1 = await crearOrden('RECIBIDO');
  const abierta2 = await crearOrden('DIAGNOSTICO');
  const entregada = await crearOrden('TERMINADO', 400);

  const pago = await api
    .post('/api/payments')
    .set(bearer(receptionistToken))
    .send({ ordenId: entregada, monto: 400, metodo: 'EFECTIVO' });
  expect(pago.status).toBe(201);

  const ticket = await api
    .post('/api/tickets')
    .set(bearer(receptionistToken))
    .send({ ordenId: entregada });
  expect(ticket.status).toBe(201);

  const entrega = await api
    .post(`/api/service-orders/${entregada}/estado`)
    .set(bearer(receptionistToken))
    .send({ estado: 'ENTREGADO' });
  expect(entrega.status).toBe(200);

  const { panel, totalListado, conteos } = await panelYConteos();
  const porEstado = panel.ordenes.porEstado;

  // Cada estado del panel es exactamente su conteo individual de la base.
  const estados = [
    'RECIBIDO',
    'DIAGNOSTICO',
    'EN_REPARACION',
    'ESPERANDO_REFACCION',
    'TERMINADO',
    'ENTREGADO',
  ];
  for (const estado of estados) {
    expect(porEstado[estado]).toBe(conteos[estado] ?? 0);
  }

  // El total coincide con la base y con el listado individual (una sola
  // fuente de verdad, sin tablas derivadas).
  const totalBase = Object.values(conteos).reduce(
    (total, valor) => total + valor,
    0,
  );
  expect(panel.ordenes.total).toBe(totalBase);
  expect(panel.ordenes.total).toBe(totalListado);

  // Abiertas = todo lo no entregado; entregadas = ENTREGADO.
  expect(panel.ordenes.entregadas).toBe(conteos.ENTREGADO ?? 0);
  expect(panel.ordenes.abiertas).toBe(totalBase - panel.ordenes.entregadas);

  // Mis órdenes quedaron en los estados esperados (control del montaje).
  const mias = await consultaDirecta(
    'SELECT status FROM service_orders WHERE id IN (?, ?, ?) ORDER BY id',
    [abierta1, abierta2, entregada],
  );
  expect(mias.map((fila) => fila.status)).toEqual([
    'RECIBIDO',
    'DIAGNOSTICO',
    'ENTREGADO',
  ]);
});
