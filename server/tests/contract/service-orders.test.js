// Pruebas de contrato de /api/service-orders: formas de respuesta, codigos y roles
// definidos en specs/002-citas-ordenes-servicio/contracts/service-orders.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Orden Contrato ${suffix}`, telefono: `70${suffix}` });
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
      placas: `CT${suffix}`,
      kilometrajeActual: 1000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('contrato GET /api/service-orders', () => {
  test('ADMIN y RECEPTIONIST reciben 200 con el formato paginado (FR-003)', async () => {
    for (const token of [adminToken, receptionistToken]) {
      const response = await api.get('/api/service-orders').set(bearer(token));
      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        elementos: expect.any(Array),
        pagina: 1,
        paginas: expect.any(Number),
        total: expect.any(Number),
      });
      expect(response.body.total).toBeGreaterThanOrEqual(4); // seeds del Sprint 2
      if (response.body.elementos.length > 0) {
        expect(response.body.elementos[0]).toEqual(
          expect.objectContaining({
            id: expect.any(Number),
            cliente: expect.any(String),
            vehiculo: expect.any(String),
            placas: expect.any(String),
            estado: expect.any(String),
            motivoVisita: expect.any(String),
            fechaIngreso: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
            kilometrajeEntrada: expect.any(Number),
          }),
        );
      }
    }
  });

  test('el filtro por estado devuelve solo ese estado', async () => {
    const response = await api
      .get('/api/service-orders?estado=RECIBIDO')
      .set(bearer(adminToken));
    expect(response.status).toBe(200);
    expect(response.body.elementos.length).toBeGreaterThan(0);
    for (const order of response.body.elementos) {
      expect(order.estado).toBe('RECIBIDO');
    }
  });

  test('sin token se responde 401', async () => {
    const response = await api.get('/api/service-orders');
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});

describe('contrato POST /api/service-orders', () => {
  test('crea una orden en RECIBIDO y devuelve 201 con la forma del detalle', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Revisión de frenos',
        fechaIngreso: '2026-10-13',
        kilometraje: 1500,
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        clienteId: clientId,
        cliente: `Orden Contrato ${suffix}`,
        vehiculoId: vehicleId,
        placas: `CT${suffix}`,
        estado: 'RECIBIDO',
        motivoVisita: 'Revisión de frenos',
        fechaIngreso: '2026-10-13',
        kilometrajeEntrada: 1500,
        mecanicoId: null,
        citaId: null,
        diagnostico: null,
        diagnosticoBorrador: false,
        recomendaciones: null,
        fechaEntrega: null,
        servicios: [],
        repuestos: [],
        historial: expect.any(Array),
      }),
    );
    expect(response.body.historial[0]).toEqual(
      expect.objectContaining({ de: null, a: 'RECIBIDO' }),
    );
  });

  test('devuelve 400 si falta el motivo de visita', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fechaIngreso: '2026-10-13',
        kilometraje: 1600,
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
    expect(response.body.error.mensaje).toContain('El motivo de visita es obligatorio');
  });

  test('devuelve 404 si el vehículo no existe (RN-02)', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: 99999999,
        motivoVisita: 'Diagnóstico',
        fechaIngreso: '2026-10-13',
        kilometraje: 2000,
      });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_ENCONTRADO');
  });

  test('MECHANIC no puede crear órdenes (403, FR-020)', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(mechanicToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Intento mecánico',
        fechaIngreso: '2026-10-13',
        kilometraje: 1700,
      });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});

describe('contrato GET /api/service-orders/:id', () => {
  test('devuelve 200 con el detalle completo de la orden', async () => {
    const created = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Detalle de contrato',
        fechaIngreso: '2026-10-14',
        kilometraje: 1800,
      });
    expect(created.status).toBe(201);

    const response = await api
      .get(`/api/service-orders/${created.body.id}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: created.body.id,
        telefono: expect.any(String),
        servicios: expect.any(Array),
        repuestos: expect.any(Array),
        historial: expect.any(Array),
        notaCorreccionKilometraje: '',
      }),
    );
  });

  test('devuelve 404 con la forma de error para un id inexistente', async () => {
    const response = await api
      .get('/api/service-orders/99999999')
      .set(bearer(adminToken));
    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});
