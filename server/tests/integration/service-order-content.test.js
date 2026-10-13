// Pruebas de integración del contenido de la orden (US4): el servicio y su
// mano de obra se crean juntos (R-13), el diagnóstico en borrador se marca y
// se limpia (FR-011, FR-019), el mecánico registra repuestos y
// recomendaciones en sus órdenes y no en ajenas.
// Fuente de verdad: specs/002-citas-ordenes-servicio/spec.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let mechanicToken;
let mechanicId;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let kilometraje = 20000;

// Crea una orden asignada al mecánico de las pruebas (o a otro si se indica).
async function crearOrdenAsignada(mecanicoAsignado = mechanicId) {
  kilometraje += 100;
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Contenido de la orden (integración)',
      fechaIngreso: '2026-10-15',
      kilometraje,
      mecanicoId: mecanicoAsignado,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const mecanico = await api
    .get('/api/auth/me')
    .set(bearer(mechanicToken));
  expect(mecanico.status).toBe(200);
  mechanicId = mecanico.body.id;

  // Un segundo mecánico para probar órdenes ajenas.
  const adminToken = await loginAs('admin', 'Admin2026!');
  const otro = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({
      username: `mec2_${suffix}`,
      email: `mec2_${suffix}@motorix.local`,
      rol: 'MECHANIC',
      contrasena: 'Mecanico2026!',
    });
  expect(otro.status).toBe(201);

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Integración ${suffix}`, telefono: `74${suffix}` });
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
      placas: `CI${suffix}`,
      kilometrajeActual: 500,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('el servicio y su mano de obra se crean juntos y aparecen en el detalle (R-13)', async () => {
  const ordenId = await crearOrdenAsignada();

  const primero = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(mechanicToken))
    .send({ descripcion: 'Cambio de pastillas', duracionMinutos: 60, precio: 450 });
  expect(primero.status).toBe(201);

  const segundo = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(mechanicToken))
    .send({ descripcion: 'Alineación y balanceo', duracionMinutos: 40, precio: 300 });
  expect(segundo.status).toBe(201);

  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(mechanicToken));
  expect(detalle.status).toBe(200);
  expect(detalle.body.servicios).toHaveLength(2);
  expect(detalle.body.servicios[0]).toEqual({
    id: expect.any(Number),
    descripcion: 'Cambio de pastillas',
    manoDeObra: {
      id: expect.any(Number),
      duracionMinutos: 60,
      precio: expect.anything(),
    },
  });
  expect(Number(detalle.body.servicios[0].manoDeObra.precio)).toBe(450);
});

test('el diagnóstico en borrador se marca y se limpia al guardarlo definitivo (FR-011, FR-019)', async () => {
  const ordenId = await crearOrdenAsignada();

  const borrador = await api
    .post(`/api/service-orders/${ordenId}/diagnostico`)
    .set(bearer(mechanicToken))
    .send({ texto: 'Fuga de aceite en el motor', borrador: true });
  expect(borrador.status).toBe(200);
  expect(borrador.body.diagnosticoBorrador).toBe(true);

  const detalleBorrador = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(mechanicToken));
  expect(detalleBorrador.body.diagnostico).toBe('Fuga de aceite en el motor');
  expect(detalleBorrador.body.diagnosticoBorrador).toBe(true);

  const definitivo = await api
    .post(`/api/service-orders/${ordenId}/diagnostico`)
    .set(bearer(mechanicToken))
    .send({ texto: 'Fuga de aceite en la junta de culata', borrador: false });
  expect(definitivo.status).toBe(200);
  expect(definitivo.body.diagnosticoBorrador).toBe(false);

  const detalleFinal = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(mechanicToken));
  expect(detalleFinal.body.diagnostico).toBe('Fuga de aceite en la junta de culata');
  expect(detalleFinal.body.diagnosticoBorrador).toBe(false);
});

test('el mecánico registra repuestos y recomendaciones en su orden (RN-06, FR-013)', async () => {
  const ordenId = await crearOrdenAsignada();

  const repuesto = await api
    .post(`/api/service-orders/${ordenId}/repuestos`)
    .set(bearer(mechanicToken))
    .send({ descripcion: 'Juego de bujías', cantidad: 4 });
  expect(repuesto.status).toBe(201);

  const recomendaciones = await api
    .post(`/api/service-orders/${ordenId}/recomendaciones`)
    .set(bearer(mechanicToken))
    .send({ texto: 'Cambiar el aceite a los 5,000 km' });
  expect(recomendaciones.status).toBe(200);

  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(mechanicToken));
  expect(detalle.body.repuestos).toHaveLength(1);
  expect(detalle.body.repuestos[0]).toEqual({
    id: expect.any(Number),
    descripcion: 'Juego de bujías',
    cantidad: 4,
  });
  expect(detalle.body.recomendaciones).toBe('Cambiar el aceite a los 5,000 km');
});

test('al borrar el servicio desaparece su mano de obra asociada (cascada)', async () => {
  const ordenId = await crearOrdenAsignada();
  const servicio = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(mechanicToken))
    .send({ descripcion: 'Servicio temporal', duracionMinutos: 25 });
  expect(servicio.status).toBe(201);

  const borrado = await api
    .delete(
      `/api/service-orders/${ordenId}/servicios/${servicio.body.servicio.id}`,
    )
    .set(bearer(mechanicToken));
  expect(borrado.status).toBe(200);

  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(mechanicToken));
  expect(detalle.body.servicios).toHaveLength(0);
});

test('un mecánico no puede registrar contenido en una orden ajena (403)', async () => {
  const adminToken = await loginAs('admin', 'Admin2026!');
  const users = await api
    .get('/api/users')
    .set(bearer(adminToken));
  expect(users.status).toBe(200);
  const otroMecanico = users.body.find(
    (user) => user.username === `mec2_${suffix}`,
  );
  expect(otroMecanico).toBeDefined();

  const ordenId = await crearOrdenAsignada(otroMecanico.id);

  const diagnostico = await api
    .post(`/api/service-orders/${ordenId}/diagnostico`)
    .set(bearer(mechanicToken))
    .send({ texto: 'Contenido ajeno', borrador: false });
  expect(diagnostico.status).toBe(403);
  expect(diagnostico.body.error.codigo).toBe('ORDEN_AJENA');

  const servicio = await api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(mechanicToken))
    .send({ descripcion: 'Servicio ajeno', duracionMinutos: 10 });
  expect(servicio.status).toBe(403);
  expect(servicio.body.error.codigo).toBe('ORDEN_AJENA');
});
