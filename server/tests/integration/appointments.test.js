// Pruebas de integracion de citas (US2) contra la base de pruebas: alta con
// pertenencia cliente-vehiculo (RN-01, RN-02), cancelacion con motivo opcional
// (FR-006), recepcion con precarga que no crea orden (FR-007), deteccion
// perezosa de NO_PRESENTADA (R-06) y edicion de la cita (PUT).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let receivedAppointmentId;

async function crearCita(extra = {}) {
  const response = await api
    .post('/api/appointments')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      fecha: '2027-04-10',
      hora: '11:00',
      motivo: 'Cambio de aceite',
      ...extra,
    });
  expect(response.status).toBe(201);
  return response.body;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Cita Integracion ${suffix}`, telefono: `71${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2020,
      placas: `IN${suffix}`,
      kilometrajeActual: 1000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('alta y listado de la cita (FR-005, FR-006)', () => {
  test('crea la cita en PROGRAMADA y el filtro por fecha la devuelve completa', async () => {
    const creada = await crearCita();
    expect(creada.estado).toBe('PROGRAMADA');
    expect(creada.ordenId).toBeNull();

    const listado = await api
      .get('/api/appointments?fecha=2027-04-10&porPagina=50')
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);
    expect(listado.body.elementos.every((a) => a.fecha === '2027-04-10')).toBe(true);

    const propia = listado.body.elementos.find((a) => a.id === creada.id);
    expect(propia).toEqual(
      expect.objectContaining({
        estado: 'PROGRAMADA',
        motivo: 'Cambio de aceite',
        ordenId: null,
      }),
    );
  });

  test('el filtro buscar por nombre del cliente encuentra sus citas', async () => {
    const listado = await api
      .get(`/api/appointments?buscar=${encodeURIComponent(`Cita Integracion ${suffix}`)}`)
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);
    expect(listado.body.total).toBeGreaterThan(0);
    for (const cita of listado.body.elementos) {
      expect(cita.cliente).toBe(`Cita Integracion ${suffix}`);
    }
  });

  test('RN-02: rechaza un vehículo que no pertenece al cliente elegido', async () => {
    const otroCliente = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Otro Dueño Cita ${suffix}`, telefono: `72${suffix}` });
    expect(otroCliente.status).toBe(201);

    const response = await api
      .post('/api/appointments')
      .set(bearer(receptionistToken))
      .send({
        clienteId: otroCliente.body.id,
        vehiculoId: vehicleId,
        fecha: '2027-04-11',
        hora: '12:00',
        motivo: 'Cita cruzada',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VEHICULO_NO_PERTENECE');
  });
});

describe('cancelación de la cita (FR-006)', () => {
  test('cancelar con motivo guarda el texto y el estado CANCELADA', async () => {
    const cita = await crearCita({ fecha: '2027-04-12', hora: '12:00', motivo: 'Alineación' });

    const response = await api
      .post(`/api/appointments/${cita.id}/cancelar`)
      .set(bearer(receptionistToken))
      .send({ motivo: 'El cliente no pudo asistir' });

    expect(response.status).toBe(200);
    expect(response.body.estado).toBe('CANCELADA');
    expect(response.body.motivoCancelacion).toBe('El cliente no pudo asistir');
  });

  test('cancelar sin motivo deja el campo de cancelación vacío', async () => {
    const cita = await crearCita({ fecha: '2027-04-12', hora: '13:00', motivo: 'Rotación' });

    const response = await api
      .post(`/api/appointments/${cita.id}/cancelar`)
      .set(bearer(receptionistToken))
      .send({});

    expect(response.status).toBe(200);
    expect(response.body.estado).toBe('CANCELADA');
    expect(response.body.motivoCancelacion).toBe('');
  });

  test('una cita que ya no está PROGRAMADA no se puede cancelar (409)', async () => {
    const cita = await crearCita({ fecha: '2027-04-12', hora: '14:00', motivo: 'Diagnóstico' });
    const recibida = await api
      .post(`/api/appointments/${cita.id}/recibir`)
      .set(bearer(receptionistToken))
      .send({});
    expect(recibida.status).toBe(200);

    const response = await api
      .post(`/api/appointments/${cita.id}/cancelar`)
      .set(bearer(receptionistToken))
      .send({ motivo: 'Tarde para cancelar' });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_NO_PROGRAMADA');
  });
});

describe('recepción de la cita (FR-007)', () => {
  test('recibir cambia a RECIBIDA y devuelve la precarga sin crear ninguna orden', async () => {
    const cita = await crearCita({
      fecha: '2027-04-13',
      hora: '09:30',
      motivo: 'Diagnóstico de falla eléctrica',
    });
    receivedAppointmentId = cita.id;

    const response = await api
      .post(`/api/appointments/${cita.id}/recibir`)
      .set(bearer(receptionistToken))
      .send({});

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      cita: { id: cita.id, estado: 'RECIBIDA' },
      precargaOrden: {
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivo: 'Diagnóstico de falla eléctrica',
        citaId: cita.id,
      },
    });

    // FR-007: recibir no crea órdenes; el detalle sigue sin orden derivada.
    const detalle = await api
      .get(`/api/appointments/${cita.id}`)
      .set(bearer(adminToken));
    expect(detalle.status).toBe(200);
    expect(detalle.body.orden).toBeNull();
  });

  test('la precarga permite crear la orden derivada, que queda enlazada a la cita', async () => {
    const orden = await api
      .post('/api/service-orders')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Orden creada desde la cita',
        fechaIngreso: '2026-12-01',
        kilometraje: 1200,
        citaId: receivedAppointmentId,
      });

    expect(orden.status).toBe(201);
    expect(orden.body.citaId).toBe(receivedAppointmentId);

    const detalle = await api
      .get(`/api/appointments/${receivedAppointmentId}`)
      .set(bearer(adminToken));
    expect(detalle.status).toBe(200);
    expect(detalle.body.orden).toEqual(
      expect.objectContaining({
        id: orden.body.id,
        estado: 'RECIBIDO',
        fechaIngreso: '2026-12-01',
      }),
    );
  });

  test('una cita RECIBIDA no puede derivar en dos órdenes (409)', async () => {
    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Segunda orden de la misma cita',
        fechaIngreso: '2026-12-02',
        kilometraje: 1300,
        citaId: receivedAppointmentId,
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_YA_UTILIZADA');
  });

  test('una cita PROGRAMADA no puede derivar en una orden (409)', async () => {
    const cita = await crearCita({ fecha: '2027-04-14', hora: '10:00', motivo: 'Pendiente de recibir' });

    const response = await api
      .post('/api/service-orders')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        motivoVisita: 'Orden antes de recibir la cita',
        fechaIngreso: '2026-12-03',
        kilometraje: 1400,
        citaId: cita.id,
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_NO_RECIBIDA');
  });

  test('una cita cancelada no se puede recibir (409)', async () => {
    const cita = await crearCita({ fecha: '2027-04-14', hora: '11:00', motivo: 'Para cancelar' });
    const cancelada = await api
      .post(`/api/appointments/${cita.id}/cancelar`)
      .set(bearer(receptionistToken))
      .send({ motivo: 'Se canceló' });
    expect(cancelada.status).toBe(200);

    const response = await api
      .post(`/api/appointments/${cita.id}/recibir`)
      .set(bearer(receptionistToken))
      .send({});

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_NO_PROGRAMADA');
  });
});

describe('detección perezosa de NO_PRESENTADA (FR-006, R-06)', () => {
  test('una cita PROGRAMADA vencida pasa a NO_PRESENTADA al listar', async () => {
    const vencida = await api
      .post('/api/appointments')
      .set(bearer(receptionistToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2020-01-01',
        hora: '08:00',
        motivo: 'Cita olvidada',
      });
    expect(vencida.status).toBe(201);
    expect(vencida.body.estado).toBe('PROGRAMADA'); // el alta no marca vencidas

    const listado = await api
      .get('/api/appointments?fecha=2020-01-01&porPagina=50')
      .set(bearer(adminToken));
    expect(listado.status).toBe(200);

    const marcada = listado.body.elementos.find((a) => a.id === vencida.body.id);
    expect(marcada).toBeDefined();
    expect(marcada.estado).toBe('NO_PRESENTADA');
  });
});

describe('edición de la cita (PUT /:id)', () => {
  test('edita fecha, hora y motivo conservando el estado PROGRAMADA', async () => {
    const cita = await crearCita({ fecha: '2027-04-15', hora: '10:00', motivo: 'Rotación de llantas' });

    const response = await api
      .put(`/api/appointments/${cita.id}`)
      .set(bearer(receptionistToken))
      // El cuerpo del PUT es el mismo esquema que el POST sin confirmar; el
      // servicio conserva cliente y vehículo aunque se envíen.
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-04-16',
        hora: '15:00',
        motivo: 'Alineación y balanceo',
      });

    expect(response.status).toBe(200);
    expect(response.body.fecha).toBe('2027-04-16');
    expect(response.body.hora).toBe('15:00');
    expect(response.body.motivo).toBe('Alineación y balanceo');
    expect(response.body.estado).toBe('PROGRAMADA');
    expect(response.body.motivoCancelacion).toBe('');
  });

  test('vuelve a aplicar la validación de conflicto de horario (409)', async () => {
    const enConflicto = await crearCita({ fecha: '2027-04-17', hora: '09:00', motivo: 'Turno de la mañana' });
    const editable = await crearCita({ fecha: '2027-04-17', hora: '17:00', motivo: 'Turno de la tarde' });

    const response = await api
      .put(`/api/appointments/${editable.id}`)
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-04-17',
        hora: '09:00',
        motivo: 'Intento de traslape',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_CONFLICTO_HORARIO');
    expect(response.body.error.pendienteConfirmacion).toBeUndefined();
    expect(enConflicto.estado).toBe('PROGRAMADA');
  });

  test('no permite editar una cita que ya no está PROGRAMADA (409)', async () => {
    const cita = await crearCita({ fecha: '2027-04-18', hora: '09:00', motivo: 'Se cancela' });
    const cancelada = await api
      .post(`/api/appointments/${cita.id}/cancelar`)
      .set(bearer(receptionistToken))
      .send({ motivo: 'Sin interés' });
    expect(cancelada.status).toBe(200);

    const response = await api
      .put(`/api/appointments/${cita.id}`)
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-04-19',
        hora: '10:00',
        motivo: 'Intento de edición',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CITA_NO_PROGRAMADA');
  });

  test('devuelve 404 para una cita inexistente', async () => {
    const response = await api
      .put('/api/appointments/99999999')
      .set(bearer(adminToken))
      .send({
        clienteId: clientId,
        vehiculoId: vehicleId,
        fecha: '2027-04-20',
        hora: '10:00',
        motivo: 'No existe',
      });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('CITA_NO_ENCONTRADA');
  });
});
