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
    // Sprint 5 (FR-033, R-14): la consulta agrega la lista `tickets`.
    expect(response.body).toEqual({ existe: false, ticket: null, tickets: [] });
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

// ---------------------------------------------------------------------------
// Sprint 5 (US3, FR-017, FR-018, SC-008): el ticket nuevo desglosa cada
// refacción con su precio congelado, y las líneas y la mano de obra sin
// precio llevan el aviso, igual que el desglose del pago.
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/tickets.md.
// ---------------------------------------------------------------------------
describe('Sprint 5 — desglose de refacciones en el ticket', () => {
  test('el_ticket_nuevo_trae_cantidad_precio_congelado_y_subtotal_por_refaccion', async () => {
    const ordenId = await crearOrden({ conManoDeObra: 750 });
    // Mano de obra sin precio: vale 0 y lleva su aviso.
    const sinPrecio = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: `Revisión sin costo ${suffix}`, duracionMinutos: 15 });
    expect(sinPrecio.status).toBe(201);

    contador += 1;
    const refaccion = await api
      .post('/api/parts')
      .set(bearer(adminToken))
      .send({
        codigo: `TKT-${suffix}-${contador}`,
        nombre: `Pastillas de ticket ${suffix}`,
        categoria: 'Frenos',
        stockInicial: 10,
        precioVenta: 320,
      });
    const agregada = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.body.id, cantidad: 2 });
    expect(agregada.status).toBe(201);
    // Una línea heredada sin catálogo (Sprint 2): sin precio registrado.
    const db = await mysql.createConnection(config.db);
    await db.query(
      `INSERT INTO order_parts (service_order_id, description, quantity, part_id, unit_price)
       VALUES (?, 'Filtro heredado', 1, NULL, NULL)`,
      [ordenId],
    );
    await db.end();
    // El catálogo cambia antes de cobrar: el ticket usa el precio congelado.
    await api
      .put(`/api/parts/${refaccion.body.id}`)
      .set(bearer(adminToken))
      .send({ precioVenta: 999 });
    await fijarEstado(ordenId, 'TERMINADO');

    const pago = await api
      .post('/api/payments')
      .set(bearer(receptionistToken))
      .send({ ordenId, monto: 1390, metodo: 'TARJETA' });
    expect(pago.status).toBe(201);

    const response = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });
    expect(response.status).toBe(201);

    const refacciones = response.body.servicios.flatMap((s) => s.refacciones);
    expect(refacciones).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          nombre: `Pastillas de ticket ${suffix}`,
          cantidad: 2,
          precioUnitario: 320,
          subtotal: 640,
          aviso: null,
        }),
        expect.objectContaining({
          nombre: 'Filtro heredado',
          cantidad: 1,
          subtotal: 0,
          aviso: 'sin precio registrado',
        }),
      ]),
    );
    const sumaRefacciones = refacciones.reduce((suma, r) => suma + r.subtotal, 0);
    expect(response.body.subtotalRefacciones).toBe(sumaRefacciones);
    expect(response.body.subtotalManoDeObra).toBe(750);
    expect(response.body.total).toBe(
      response.body.subtotalManoDeObra + response.body.subtotalRefacciones,
    );
    expect(response.body.total).toBe(1390);

    const manoDeObra = response.body.servicios.map((s) => s.avisoManoDeObra);
    expect(manoDeObra).toEqual([null, 'sin precio registrado']);
  });
});

// ---------------------------------------------------------------------------
// Sprint 5 (US4, FR-019, FR-020, FR-033): copia con versión, «formato
// anterior», nota del desglose y la consulta por orden con varios tickets.
// ---------------------------------------------------------------------------
describe('Sprint 5 — copia con versión y tickets por orden', () => {
  test.each([1, 2])('el_ticket_sembrado_%i_trae_formatoAnterior_true', async (id) => {
    const response = await api.get(`/api/tickets/${id}`).set(bearer(receptionistToken));
    expect(response.status).toBe(200);
    expect(response.body.formatoVersion).toBe(1);
    expect(response.body.formatoAnterior).toBe(true);
    expect(response.body.folio).toBe(`T00000${id}-2026`);
  });

  test('un_ticket_con_el_desglose_desfasado_trae_desgloseNoCoincide_y_nota', async () => {
    const ordenId = await crearOrden({ estado: 'TERMINADO', conManoDeObra: 1090 });
    const db = await mysql.createConnection(config.db);
    try {
      const [pago] = await db.query(
        `INSERT INTO payments (service_order_id, amount, method, status, created_by)
         VALUES (?, 1390.00, 'TARJETA', 'PAGADO', 2)`,
        [ordenId],
      );
      const copia = {
        folio: `D${suffix}`.slice(0, 20),
        ordenId,
        pagoId: pago.insertId,
        servicios: [],
        subtotalManoDeObra: 1090,
        subtotalRefacciones: 0,
        total: 1390,
        metodoPago: 'TARJETA',
        formatoVersion: 1,
        desgloseNoCoincide: true,
        nota: 'El desglose no coincide con lo cobrado',
      };
      const [ticket] = await db.query(
        `INSERT INTO tickets (service_order_id, payment_id, folio, issued_by, content, format_version)
         VALUES (?, ?, ?, 2, ?, 1)`,
        [ordenId, pago.insertId, copia.folio, JSON.stringify(copia)],
      );

      const response = await api
        .get(`/api/tickets/${ticket.insertId}`)
        .set(bearer(receptionistToken));
      expect(response.status).toBe(200);
      expect(response.body.total).toBe(1390);
      expect(response.body.desgloseNoCoincide).toBe(true);
      expect(response.body.nota).toBe('El desglose no coincide con lo cobrado');
      expect(response.body.formatoAnterior).toBe(true);
    } finally {
      await db.end();
    }
  });

  test('GET_orden_tiene_la_forma_existe_ticket_tickets', async () => {
    const ordenId = await crearOrdenPagada(610);
    const generado = await api
      .post('/api/tickets')
      .set(bearer(receptionistToken))
      .send({ ordenId });
    expect(generado.status).toBe(201);

    const response = await api
      .get(`/api/tickets/orden/${ordenId}`)
      .set(bearer(receptionistToken));
    expect(response.status).toBe(200);
    expect(Object.keys(response.body).sort()).toEqual(['existe', 'ticket', 'tickets']);
    expect(response.body.existe).toBe(true);
    expect(response.body.ticket).toMatchObject({
      id: generado.body.id,
      vigente: true,
      pagoAnulado: false,
      formatoAnterior: false,
      formatoVersion: 2,
    });
    expect(response.body.tickets).toEqual([
      {
        id: generado.body.id,
        folio: generado.body.folio,
        pagoId: generado.body.pagoId,
        emitidoEn: generado.body.emitidoEn,
        vigente: true,
        pagoAnulado: false,
        formatoAnterior: false,
      },
    ]);
  });
});
