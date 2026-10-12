// Pruebas de integracion de ordenes de servicio (US1): creacion y detalle contra
// la base de pruebas, coherencia cliente-vehiculo (RN-01, RN-02) y regla de
// kilometraje no regresivo con correccion exclusiva de ADMIN (FR-018, R-08).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let firstOrderId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Orden Integracion ${suffix}`, telefono: `80${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Kia',
      modelo: 'Rio',
      anio: 2020,
      placas: `IT${suffix}`,
      kilometrajeActual: 1000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('creación y detalle de la orden (US1)', () => {
  test('crea la orden en RECIBIDO con su fila inicial de historial (FR-014, FR-015)', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Ruido al frenar',
        fechaIngreso: '2026-10-20',
        kilometraje: 5000,
      });

    expect(response.status).toBe(201);
    expect(response.body.estado).toBe('RECIBIDO');
    expect(response.body.motivoVisita).toBe('Ruido al frenar');
    expect(response.body.fechaIngreso).toBe('2026-10-20');
    expect(response.body.kilometrajeEntrada).toBe(5000);
    expect(response.body.servicios).toEqual([]);
    expect(response.body.repuestos).toEqual([]);
    expect(response.body.historial[0]).toEqual(
      expect.objectContaining({ de: null, a: 'RECIBIDO' }),
    );
    firstOrderId = response.body.id;
  });

  test('el detalle devuelve los datos del cliente y del vehículo (HU1)', async () => {
    const response = await api
      .get(`/api/service-orders/${firstOrderId}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body.cliente).toBe(`Orden Integracion ${suffix}`);
    expect(response.body.telefono).toBe(`80${suffix}`);
    expect(response.body.placas).toBe(`IT${suffix}`);
    expect(response.body.notaCorreccionKilometraje).toBe('');
    expect(response.body.diagnostico).toBeNull();
  });

  test('RN-02: rechaza un vehículo que no pertenece al cliente elegido', async () => {
    const otroCliente = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Otro Dueño ${suffix}`, telefono: `81${suffix}` });
    expect(otroCliente.status).toBe(201);

    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: otroCliente.body.id,
        vehiculoId: vehicleId,
        motivoVisita: 'Intento de orden cruzada',
        fechaIngreso: '2026-10-20',
        kilometraje: 5100,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_PERTENECE');
  });

  test('RN-01: un cliente sin vehículos no genera una orden huérfana', async () => {
    const sinVehiculos = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Sin Vehiculos ${suffix}`, telefono: `82${suffix}` });
    expect(sinVehiculos.status).toBe(201);

    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: sinVehiculos.body.id,
        vehiculoId: vehicleId,
        motivoVisita: 'Orden huérfana',
        fechaIngreso: '2026-10-20',
        kilometraje: 5200,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_PERTENECE');
  });
});

describe('regla de kilometraje (FR-018, R-08)', () => {
  test('rechaza con 400 un kilometraje menor que el de la última orden', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Kilometraje regresivo',
        fechaIngreso: '2026-10-21',
        kilometraje: 4000,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('KILOMETRAJE_MENOR');
    expect(response.body.error.mensaje).toContain('kilometraje de entrada');
  });

  test('RECEPTIONIST no puede corregir el kilometraje (403)', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Corrección indebida',
        fechaIngreso: '2026-10-21',
        kilometraje: 4100,
        correccionKilometraje: 'Odómetro reemplazado',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('CORRECCION_NO_AUTORIZADA');
  });

  test('ADMIN sí puede corregir y el motivo queda guardado en la orden', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Corrección autorizada',
        fechaIngreso: '2026-10-21',
        kilometraje: 4200,
        correccionKilometraje: 'Odómetro reemplazado por falla',
      });

    expect(response.status).toBe(201);
    expect(response.body.notaCorreccionKilometraje).toBe('Odómetro reemplazado por falla');
    expect(response.body.kilometrajeEntrada).toBe(4200);
  });
});

describe('edición de la orden (PUT /:id)', () => {
  test('actualiza motivo, fecha y kilometraje sin cambiar cliente ni vehículo', async () => {
    const response = await api
      .put(`/api/service-orders/${firstOrderId}`)
      .set(bearer(receptionistToken))
      .send({
        motivoVisita: 'Ruido al frenar y vibración',
        fechaIngreso: '2026-10-22',
        kilometraje: 5400,
      });

    expect(response.status).toBe(200);
    expect(response.body.motivoVisita).toBe('Ruido al frenar y vibración');
    expect(response.body.fechaIngreso).toBe('2026-10-22');
    expect(response.body.kilometrajeEntrada).toBe(5400);
    expect(response.body.clienteId).toBe(clientId);
    expect(response.body.vehiculoId).toBe(vehicleId);
  });

  test('aplica la misma regla de kilometraje que el alta (400 sin corrección)', async () => {
    const response = await api
      .put(`/api/service-orders/${firstOrderId}`)
      .set(bearer(adminToken))
      .send({
        motivoVisita: 'Ruido al frenar y vibración',
        fechaIngreso: '2026-10-22',
        kilometraje: 100,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('KILOMETRAJE_MENOR');
  });

  test('no permite editar una orden terminada (409)', async () => {
    const listado = await api
      .get('/api/service-orders?estado=TERMINADO')
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);
    expect(listado.body.elementos.length).toBeGreaterThan(0);

    const response = await api
      .put(`/api/service-orders/${listado.body.elementos[0].id}`)
      .set(bearer(adminToken))
      .send({
        motivoVisita: 'Intento de edición tardía',
        fechaIngreso: '2026-10-22',
        kilometraje: 999999,
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('ORDEN_CERRADA');
  });
});
