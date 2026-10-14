// Pruebas de integración del panel de control (Sprint 4, US5 y US6): los
// contadores del bloque `ordenes` coinciden con los registros individuales
// sin duplicar información aunque la orden tenga pagos y tickets (SC-005,
// CA-6, FR-010) y los bloques operativos (`citas`, `mantenimientos` y
// `alertasInventario`) reutilizan sus fuentes existentes sin copias (FR-011,
// HU6). Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md.
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

// Refacciones en alerta con la regla del inventario (stock_actual <=
// stock_min y stock_min > 0, FR-021, R-10) y su top 10 por faltante
// ascendente: espejo de la consulta del panel para comparar dentro de la
// ventana estable (la base acumula datos de otras suites y corridas).
async function snapshotStockBajo() {
  const conteo = await consultaDirecta(
    'SELECT COUNT(*) AS total FROM parts WHERE stock_current <= stock_min AND stock_min > 0',
  );
  const filas = await consultaDirecta(
    `SELECT id, code, name, stock_current, stock_min
     FROM parts
     WHERE stock_current <= stock_min AND stock_min > 0
     ORDER BY (stock_min - stock_current) ASC, code ASC
     LIMIT 10`,
  );
  return {
    total: Number(conteo[0].total),
    filas: filas.map((fila) => ({
      id: fila.id,
      codigo: fila.code,
      nombre: fila.name,
      stockActual: Number(fila.stock_current),
      stockMinimo: Number(fila.stock_min),
    })),
  };
}

// Fecha futura única por corrida: evita que las citas acumuladas de corridas
// anteriores contaminen `citas.hoy` ni `citas.proximas`.
function fechaLejana() {
  const inicio = Date.UTC(2031, 0, 1);
  const dias = Math.floor(Math.random() * 3000);
  return new Date(inicio + dias * 86400000).toISOString().substring(0, 10);
}

// Suma días a una fecha ISO (misma aritmética UTC que el backend).
function sumarDias(fecha, dias) {
  const date = new Date(`${fecha}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + dias);
  return date.toISOString().substring(0, 10);
}

// Cita propia en el día y la hora indicados, en estado PROGRAMADA.
async function crearCita(fecha, hora) {
  contador += 1;
  const cita = await api
    .post('/api/appointments')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      fecha,
      hora,
      motivo: `Cita de panel ${suffix} ${contador}`,
    });
  expect(cita.status).toBe(201);
  return cita.body.id;
}

// Lee el panel, el listado individual y los conteos de la base dentro de una
// ventana estable: los archivos de prueba corren en paralelo, así que si
// otra suite escribe órdenes o refacciones durante la lectura se reintenta
// (SC-005, HU6).
async function panelYConteos() {
  for (let intento = 0; intento < 25; intento += 1) {
    const antes = {
      ordenes: await contarEstados(),
      bajo: await snapshotStockBajo(),
    };

    const panel = await api.get('/api/dashboard').set(bearer(adminToken));
    expect(panel.status).toBe(200);

    const listado = await api
      .get('/api/service-orders?pagina=1&porPagina=1')
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);

    const despues = {
      ordenes: await contarEstados(),
      bajo: await snapshotStockBajo(),
    };
    if (JSON.stringify(antes) === JSON.stringify(despues)) {
      return {
        panel: panel.body,
        totalListado: listado.body.total,
        conteos: antes.ordenes,
        stockBajo: antes.bajo,
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

test('cuenta las citas de hoy y lista las próximas en orden ascendente (HU6)', async () => {
  const fechaRef = fechaLejana();

  // Línea de base: una colisión con una corrida anterior (muy improbable) no
  // debe alterar el conteo del día.
  const lineaBase = await consultaDirecta(
    `SELECT COUNT(*) AS total FROM appointments
     WHERE appointment_date = ? AND status IN ('PROGRAMADA', 'RECIBIDA')`,
    [fechaRef],
  );

  // Día de referencia: PROGRAMADA y RECIBIDA cuentan; CANCELADA no.
  await crearCita(fechaRef, '09:00');
  const recibida = await crearCita(fechaRef, '10:00');
  const recibir = await api
    .post(`/api/appointments/${recibida}/recibir`)
    .set(bearer(adminToken))
    .send({});
  expect(recibir.status).toBe(200);
  const cancelada = await crearCita(fechaRef, '11:00');
  const cancelar = await api
    .post(`/api/appointments/${cancelada}/cancelar`)
    .set(bearer(adminToken))
    .send({ motivo: 'Cancelada para el panel' });
  expect(cancelar.status).toBe(200);

  // Cinco próximas activas; una cancelada y una fuera del límite no cuentan.
  const esperadas = [];
  for (const salto of [1, 3, 5, 7, 9]) {
    esperadas.push(await crearCita(sumarDias(fechaRef, salto), '09:00'));
  }
  const canceladaFutura = await crearCita(sumarDias(fechaRef, 2), '09:00');
  const cancelarFutura = await api
    .post(`/api/appointments/${canceladaFutura}/cancelar`)
    .set(bearer(adminToken))
    .send({ motivo: 'Fuera del panel' });
  expect(cancelarFutura.status).toBe(200);
  const fueraDeLimite = await crearCita(sumarDias(fechaRef, 11), '09:00');

  const response = await api
    .get(`/api/dashboard?fecha=${fechaRef}`)
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  const { citas } = response.body;

  expect(citas.hoy).toBe(Number(lineaBase[0].total) + 2);

  expect(citas.proximas).toHaveLength(5);
  const ids = citas.proximas.map((cita) => cita.id);
  expect([...ids].sort((a, b) => a - b)).toEqual(
    [...esperadas].sort((a, b) => a - b),
  );

  // Orden ascendente por fecha y todas posteriores a la referencia.
  const fechas = citas.proximas.map((cita) => cita.fecha);
  expect(fechas).toEqual([...fechas].sort());
  expect(fechas).toEqual(
    [1, 3, 5, 7, 9].map((salto) => sumarDias(fechaRef, salto)),
  );
  expect(ids).not.toContain(canceladaFutura);
  expect(ids).not.toContain(fueraDeLimite);

  // Cada línea trae los campos exactos del contrato.
  for (const cita of citas.proximas) {
    expect(cita).toEqual({
      id: expect.any(Number),
      fecha: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      hora: expect.stringMatching(/^\d{2}:\d{2}$/),
      cliente: `Dashboard integración ${suffix}`,
      estado: 'PROGRAMADA',
    });
  }
});

test('reutiliza el cálculo de mantenimientos con su objetivo (HU6)', async () => {
  // Registros propios: uno vencido por fecha y otro dentro de la antelación.
  contador += 1;
  const tipoVencido = `Rotación de llantas ${suffix} ${contador}`;
  const vencido = await api
    .post('/api/maintenance')
    .set(bearer(adminToken))
    .send({
      vehiculoId: vehicleId,
      tipoServicio: tipoVencido,
      fechaObjetivo: '2031-07-01',
    });
  expect(vencido.status).toBe(201);

  contador += 1;
  const tipoProximo = `Cambio de aceite ${suffix} ${contador}`;
  const proximo = await api
    .post('/api/maintenance')
    .set(bearer(adminToken))
    .send({
      vehiculoId: vehicleId,
      tipoServicio: tipoProximo,
      fechaObjetivo: '2031-07-20',
    });
  expect(proximo.status).toBe(201);

  const response = await api
    .get('/api/dashboard?fecha=2031-07-09')
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  const { mantenimientos } = response.body;

  // Ambos bloques responden siempre como arreglo.
  expect(Array.isArray(mantenimientos.proximos)).toBe(true);
  expect(Array.isArray(mantenimientos.vencidos)).toBe(true);

  // El estado y el objetivo salen de calcMaintenanceState, no de copias.
  const halladoVencido = mantenimientos.vencidos.find(
    (registro) => registro.id === vencido.body.id,
  );
  expect(halladoVencido).toEqual({
    id: vencido.body.id,
    vehiculo: expect.stringContaining('Nissan Versa 2021'),
    tipo: tipoVencido,
    estado: 'VENCIDO',
    objetivo: '2031-07-01',
  });

  const halladoProximo = mantenimientos.proximos.find(
    (registro) => registro.id === proximo.body.id,
  );
  expect(halladoProximo).toEqual({
    id: proximo.body.id,
    vehiculo: expect.stringContaining('Nissan Versa 2021'),
    tipo: tipoProximo,
    estado: 'PROXIMO',
    objetivo: '2031-07-20',
  });
});

test('lista las alertas de stock bajo por el faltante, hasta 10 filas (HU6)', async () => {
  const { panel, stockBajo } = await panelYConteos();
  const { alertasInventario } = panel;

  // El contador coincide con la base usando la misma regla, dentro de la
  // ventana estable (la base acumula refacciones de otras corridas).
  expect(alertasInventario.stockBajo).toBe(stockBajo.total);
  expect(alertasInventario.stockBajo).toBeGreaterThanOrEqual(0);

  // La lista es el top 10 de la base: misma regla y faltante ascendente.
  expect(alertasInventario.refacciones).toEqual(stockBajo.filas);
  expect(alertasInventario.refacciones.length).toBeLessThanOrEqual(10);

  const faltantes = alertasInventario.refacciones.map(
    (refaccion) => refaccion.stockMinimo - refaccion.stockActual,
  );
  expect(faltantes).toEqual([...faltantes].sort((a, b) => a - b));

  // Toda fila respeta la regla `stockBajo` (R-10) y trae sus campos.
  for (const refaccion of alertasInventario.refacciones) {
    expect(refaccion.id).toEqual(expect.any(Number));
    expect(refaccion.codigo).toEqual(expect.any(String));
    expect(refaccion.nombre).toEqual(expect.any(String));
    expect(refaccion.stockMinimo).toBeGreaterThan(0);
    expect(refaccion.stockActual).toBeLessThanOrEqual(refaccion.stockMinimo);
  }
});

test('los bloques sin datos devuelven arreglos vacíos y contadores en 0 (HU6-4)', async () => {
  // Fecha lejana sin citas: el bloque de citas responde `[]` y 0, sin errores.
  const response = await api
    .get('/api/dashboard?fecha=2100-01-05')
    .set(bearer(adminToken));
  expect(response.status).toBe(200);

  const { fecha, citas, mantenimientos, alertasInventario, ordenes } =
    response.body;
  expect(fecha).toBe('2100-01-05');
  expect(citas).toEqual({ hoy: 0, proximas: [] });

  // Los demás bloques siempre responden como arreglo o contador, sin null.
  expect(Array.isArray(mantenimientos.proximos)).toBe(true);
  expect(Array.isArray(mantenimientos.vencidos)).toBe(true);
  expect(typeof alertasInventario.stockBajo).toBe('number');
  expect(Array.isArray(alertasInventario.refacciones)).toBe(true);
  expect(alertasInventario.refacciones.length).toBeLessThanOrEqual(10);
  expect(ordenes.total).toEqual(expect.any(Number));
});
