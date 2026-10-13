// Pruebas de contrato del contenido de la orden (US4): diagnóstico con
// borrador (FR-011), servicios con su mano de obra (FR-012, R-13), refacciones
// del catálogo en la ruta heredada /repuestos (RN-06, US7 del Sprint 3) y
// recomendaciones (FR-013). Fuente de verdad:
// specs/002-citas-ordenes-servicio/contracts/service-orders.md y
// specs/003-historial-inventario/contracts/parts.md.
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
let contadorRefacciones = 0;

// La entrega no tiene endpoint todavía (US5), así que el estado ENTREGADO se
// fija directamente sobre la base de pruebas motorix_v2_test.
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
      motivoVisita: 'Contenido de la orden',
      fechaIngreso: '2026-10-14',
      kilometraje,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

// Crea una refacción de la corrida: desde el Sprint 3 el alta en la orden
// recibe `partId` del catálogo en lugar de una descripción libre.
async function crearRefaccion(stock = 5) {
  contadorRefacciones += 1;
  const response = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `CTT-${suffix}-${contadorRefacciones}`,
      nombre: `Repuesto de contrato ${suffix} ${contadorRefacciones}`,
      categoria: 'Frenos',
      stockInicial: stock,
      stockMinimo: 1,
    });
  expect(response.status).toBe(201);
  return response.body;
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
    .send({ nombre: `Contenido ${suffix}`, telefono: `73${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2020,
      placas: `CD${suffix}`,
      kilometrajeActual: 600,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('contrato POST /api/service-orders/:id/diagnostico', () => {
  test('guarda el diagnóstico definitivo y responde 200 (FR-011)', async () => {
    const ordenId = await crearOrden(1000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(adminToken))
      .send({ texto: 'Pastillas delanteras al límite', borrador: false });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      diagnostico: 'Pastillas delanteras al límite',
      diagnosticoBorrador: false,
    });
  });

  test('marca el diagnóstico como borrador (FR-011)', async () => {
    const ordenId = await crearOrden(2000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(adminToken))
      .send({ texto: 'Ruido extraño en el diferencial', borrador: true });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      diagnostico: 'Ruido extraño en el diferencial',
      diagnosticoBorrador: true,
    });
  });

  test('devuelve 400 si el texto del diagnóstico está vacío', async () => {
    const ordenId = await crearOrden(3000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(adminToken))
      .send({ texto: '   ' });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('diagnóstico');
  });

  test('devuelve 404 si la orden no existe', async () => {
    const response = await api
      .post('/api/service-orders/99999999/diagnostico')
      .set(bearer(adminToken))
      .send({ texto: 'Sin orden', borrador: false });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('ORDEN_NO_ENCONTRADA');
  });
});

describe('contrato POST /api/service-orders/:id/servicios', () => {
  test('crea el servicio con su mano de obra y responde 201 (FR-012)', async () => {
    const ordenId = await crearOrden(4000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Cambio de pastillas', duracionMinutos: 45, precio: 350 });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      servicio: { id: expect.any(Number), descripcion: 'Cambio de pastillas' },
      manoDeObra: { id: expect.any(Number), duracionMinutos: 45, precio: 350 },
    });
  });

  test('acepta servicios sin precio (opcional)', async () => {
    const ordenId = await crearOrden(5000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Alineación', duracionMinutos: 30 });

    expect(response.status).toBe(201);
    expect(response.body.manoDeObra.precio).toBeNull();
  });

  test('devuelve 400 si falta la duración o no es mayor a cero', async () => {
    const ordenId = await crearOrden(6000);

    const sinDuracion = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Sin duración' });
    expect(sinDuracion.status).toBe(400);

    const duracionCero = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Duración cero', duracionMinutos: 0 });
    expect(duracionCero.status).toBe(400);
    expect(duracionCero.body.error.mensaje).toContain('duración');
  });
});

describe('contrato DELETE /api/service-orders/:id/servicios/:servicioId', () => {
  test('borra el servicio y responde con el mensaje del contrato', async () => {
    const ordenId = await crearOrden(7000);
    const created = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Servicio a borrar', duracionMinutos: 20 });
    expect(created.status).toBe(201);

    const response = await api
      .delete(
        `/api/service-orders/${ordenId}/servicios/${created.body.servicio.id}`,
      )
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ mensaje: 'Servicio eliminado' });

    const detalle = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(adminToken));
    expect(detalle.body.servicios).toHaveLength(0);
  });

  test('devuelve 404 si el servicio no existe en la orden', async () => {
    const ordenId = await crearOrden(8000);

    const response = await api
      .delete(`/api/service-orders/${ordenId}/servicios/99999999`)
      .set(bearer(adminToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('SERVICIO_NO_ENCONTRADO');
  });
});

describe('contrato POST /api/service-orders/:id/repuestos', () => {
  test('registra la refacción del catálogo con su cantidad y responde 201', async () => {
    const ordenId = await crearOrden(9000);
    const refaccion = await crearRefaccion(5);

    const response = await api
      .post(`/api/service-orders/${ordenId}/repuestos`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 1 });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      partId: refaccion.id,
      codigo: refaccion.codigo,
      nombre: refaccion.nombre,
      cantidad: 1,
      stockActual: 4,
    });
  });

  test('devuelve 400 si la cantidad es menor que 1 (RN-06)', async () => {
    const ordenId = await crearOrden(10000);
    const refaccion = await crearRefaccion(3);

    const response = await api
      .post(`/api/service-orders/${ordenId}/repuestos`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 0 });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('cantidad');
  });
});

describe('contrato DELETE /api/service-orders/:id/repuestos/:repuestoId', () => {
  test('retira la refacción y devuelve su stock (R-09)', async () => {
    const ordenId = await crearOrden(11000);
    const refaccion = await crearRefaccion(5);
    const created = await api
      .post(`/api/service-orders/${ordenId}/repuestos`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 2 });
    expect(created.status).toBe(201);

    const response = await api
      .delete(`/api/service-orders/${ordenId}/repuestos/${created.body.id}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      mensaje: 'Refacción retirada de la orden.',
      stockActual: 5,
    });

    const detalle = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(adminToken));
    expect(detalle.body.repuestos).toHaveLength(0);
  });

  test('devuelve 404 si el repuesto no existe en la orden', async () => {
    const ordenId = await crearOrden(12000);

    const response = await api
      .delete(`/api/service-orders/${ordenId}/repuestos/99999999`)
      .set(bearer(adminToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REPUESTO_NO_ENCONTRADO');
  });
});

describe('contrato POST /api/service-orders/:id/recomendaciones', () => {
  test('guarda las recomendaciones y responde 200 (FR-013)', async () => {
    const ordenId = await crearOrden(13000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/recomendaciones`)
      .set(bearer(adminToken))
      .send({ texto: 'Revisar discos en 5,000 km' });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      recomendaciones: 'Revisar discos en 5,000 km',
    });
  });

  test('devuelve 400 si el texto está vacío', async () => {
    const ordenId = await crearOrden(14000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/recomendaciones`)
      .set(bearer(adminToken))
      .send({ texto: '' });

    expect(response.status).toBe(400);
  });
});

describe('permisos y orden entregada del contenido (US4)', () => {
  test('RECEPTIONIST no registra contenido en la orden (403, FR-022)', async () => {
    const ordenId = await crearOrden(15000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(receptionistToken))
      .send({ texto: 'Intento de recepción', borrador: false });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('un mecánico no puede registrar contenido en una orden ajena (403)', async () => {
    // La orden queda sin asignar, así que es ajena para el mecánico.
    const ordenId = await crearOrden(16000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(mechanicToken))
      .send({ texto: 'Intento ajeno', borrador: false });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ORDEN_AJENA');
  });

  test('la orden ENTREGADO rechaza todo cambio de contenido con 409 (FR-016)', async () => {
    const ordenId = await crearOrden(17000);
    const servicio = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Servicio previo a la entrega', duracionMinutos: 15 });
    expect(servicio.status).toBe(201);
    await marcarComoEntregada(ordenId);

    const diagnostico = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(adminToken))
      .send({ texto: 'Ya entregada', borrador: false });
    expect(diagnostico.status).toBe(409);
    expect(diagnostico.body.error.codigo).toBe('ORDEN_ENTREGADA');

    const servicios = await api
      .post(`/api/service-orders/${ordenId}/servicios`)
      .set(bearer(adminToken))
      .send({ descripcion: 'Servicio tardío', duracionMinutos: 10 });
    expect(servicios.status).toBe(409);

    const refaccion = await crearRefaccion(4);
    const repuestos = await api
      .post(`/api/service-orders/${ordenId}/repuestos`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 1 });
    expect(repuestos.status).toBe(409);
    expect(repuestos.body.error.codigo).toBe('ORDEN_ENTREGADA');

    const recomendaciones = await api
      .post(`/api/service-orders/${ordenId}/recomendaciones`)
      .set(bearer(adminToken))
      .send({ texto: 'Recomendación tardía' });
    expect(recomendaciones.status).toBe(409);

    const bajaServicio = await api
      .delete(
        `/api/service-orders/${ordenId}/servicios/${servicio.body.servicio.id}`,
      )
      .set(bearer(adminToken));
    expect(bajaServicio.status).toBe(409);
    expect(bajaServicio.body.error.codigo).toBe('ORDEN_ENTREGADA');
  });
});
