// Pruebas de contrato de /api/appointments: formas de respuesta, codigos y roles
// definidos en specs/002-citas-ordenes-servicio/contracts/appointments.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;
let otherVehicleId;

// Fechas fijas en el futuro: evitan que la deteccion perezosa (FR-006) cambie
// el estado de estas citas durante la corrida de las pruebas.
const FECHA = '2027-03-15';
const HORA = '10:30';

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Cita Contrato ${suffix}`, telefono: `95${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Mazda',
      modelo: 'CX-5',
      anio: 2022,
      placas: `CC${suffix}`,
      kilometrajeActual: 5000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;

  const otherVehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2021,
      placas: `CD${suffix}`,
      kilometrajeActual: 8000,
    });
  expect(otherVehicle.status).toBe(201);
  otherVehicleId = otherVehicle.body.id;
});

describe('contrato GET /api/appointments', () => {
  test('ADMIN y RECEPTIONIST reciben 200 con el formato paginado', async () => {
    for (const token of [adminToken, receptionistToken]) {
      const response = await api.get('/api/appointments').set(bearer(token));
      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        elementos: expect.any(Array),
        pagina: 1,
        paginas: expect.any(Number),
        total: expect.any(Number),
      });
      expect(response.body.total).toBeGreaterThanOrEqual(5); // seeds del Sprint 2
      expect(response.body.elementos[0]).toEqual(
        expect.objectContaining({
          id: expect.any(Number),
          clienteId: expect.any(Number),
          cliente: expect.any(String),
          vehiculoId: expect.any(Number),
          vehiculo: expect.any(String),
          placas: expect.any(String),
          fecha: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
          hora: expect.stringMatching(/^\d{2}:\d{2}$/),
          motivo: expect.any(String),
          estado: expect.any(String),
          motivoCancelacion: expect.any(String),
        }),
      );
      expect(response.body.elementos[0]).toHaveProperty('ordenId');
    }
  });

  test('MECHANIC recibe 403 (FR-020)', async () => {
    const response = await api.get('/api/appointments').set(bearer(mechanicToken));
    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('sin token se responde 401', async () => {
    const response = await api.get('/api/appointments');
    expect(response.status).toBe(401);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
  });
});

describe('contrato POST /api/appointments', () => {
  test('crea una cita en PROGRAMADA y devuelve 201 con la forma del listado', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: FECHA,
        hora: HORA,
        motivo: 'Revisión de frenos',
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: expect.any(Number),
        clienteId: clientId,
        cliente: `Cita Contrato ${suffix}`,
        vehiculoId: vehicleId,
        placas: `CC${suffix}`,
        fecha: FECHA,
        hora: HORA,
        motivo: 'Revisión de frenos',
        estado: 'PROGRAMADA',
        motivoCancelacion: '',
        ordenId: null,
      }),
    );
  });

  test('devuelve 400 si falta el motivo de la cita (FR-005)', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({ clienteId: clientId, vehiculoId: vehicleId, fecha: FECHA, hora: HORA });

    expect(response.status).toBe(400);
    expect(response.body.error.mensaje).toContain('El motivo de la cita es obligatorio');
  });

  test('devuelve 409 con las banderas de confirmación ante conflicto de horario (FR-008)', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: FECHA,
        hora: HORA,
        motivo: 'Otra revisión',
      });

    expect(response.status).toBe(409);
    expect(response.body.error).toEqual({
      mensaje: `Ya existe una cita para este vehículo el ${FECHA} a las ${HORA}`,
      codigo: 'CITA_CONFLICTO_HORARIO',
      pendienteConfirmacion: true,
      confirmarReenvio: true,
    });
  });

  test('el reenvío con confirmar: true guarda la cita (T025 lo indica como 200; el contrato responde 201 al crear)', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: FECHA,
        hora: HORA,
        motivo: 'Revisión confirmada',
        confirmar: true,
      });

    expect(response.status).toBe(201);
    expect(response.body.estado).toBe('PROGRAMADA');
    expect(response.body.motivo).toBe('Revisión confirmada');
  });

  test('el mismo horario de otro vehículo no genera conflicto', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: otherVehicleId,
        fecha: FECHA,
        hora: HORA,
        motivo: 'Otro vehículo en el mismo turno',
      });

    expect(response.status).toBe(201);
    expect(response.body.estado).toBe('PROGRAMADA');
  });

  test('MECHANIC no puede crear citas (403, FR-020)', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(mechanicToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-03-16',
        hora: '12:00',
        motivo: 'Intento mecánico',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('devuelve 400 si el vehículo no pertenece al cliente (RN-02)', async () => {
    const otroCliente = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Otro Dueño Cita ${suffix}`, telefono: `96${suffix}` });
    expect(otroCliente.status).toBe(201);

    const response = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({
        clienteId: otroCliente.body.id,
        vehiculoId: vehicleId,
        fecha: '2027-03-17',
        hora: '13:00',
        motivo: 'Cita cruzada',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_PERTENECE');
  });

  test('devuelve 404 si el vehículo no existe', async () => {
    const response = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: 99999999,
        fecha: '2027-03-17',
        hora: '14:00',
        motivo: 'Vehículo inexistente',
      });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_ENCONTRADO');
  });
});

describe('contrato GET /api/appointments/:id', () => {
  let citaId;

  test('devuelve 200 con la cita y la orden en null mientras no exista (FR-007)', async () => {
    const created = await api
      .post('/api/appointments')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-03-18',
        hora: '09:00',
        motivo: 'Detalle de contrato',
      });
    expect(created.status).toBe(201);
    citaId = created.body.id;

    const response = await api
      .get(`/api/appointments/${citaId}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        id: citaId,
        cliente: `Cita Contrato ${suffix}`,
        placas: `CC${suffix}`,
        fecha: '2027-03-18',
        hora: '09:00',
        estado: 'PROGRAMADA',
        orden: null,
      }),
    );
  });

  test('devuelve 404 con la forma de error para un id inexistente', async () => {
    const response = await api
      .get('/api/appointments/99999999')
      .set(bearer(adminToken));
    expect(response.status).toBe(404);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: expect.any(String),
    });
    expect(response.body.error.codigo).toBe('CITA_NO_ENCONTRADA');
  });
});
