// Pruebas de contrato del aislamiento del rol MECHANIC (US3): solo ve y abre
// sus propias órdenes (FR-010, RN-15, SC-003). Fuente de verdad:
// specs/002-citas-ordenes-servicio/contracts/service-orders.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let mechanicToken;
let mechanic2Token;
let suffix;
let mecanicoId;
let clientId;
let vehicleId;
let ordenPropiaId;
let ordenAjenaId;
let ordenSinAsignarId;
let placasAjena;

async function crearOrden(vehiculo, kilometraje, mecanicoIdAsignado) {
  const body = {
    clienteId: clientId,
    vehiculoId: vehiculo,
    motivoVisita: 'Aislamiento del mecánico',
    fechaIngreso: '2026-10-14',
    kilometraje,
  };
  if (mecanicoIdAsignado) body.mecanicoId = mecanicoIdAsignado;
  const response = await api
    .post('/api/service-orders')
    .set(bearer(adminToken))
    .send(body);
  expect(response.status).toBe(201);
  return response.body.id;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const login = await api
    .post('/api/auth/login')
    .send({ identificador: 'mecanico', contrasena: 'Mecanico2026!' });
  expect(login.status).toBe(200);
  mecanicoId = login.body.usuario.id;

  // Segundo mecánico: sus órdenes no deben aparecer en el listado del primero.
  const mechanic2 = await api
    .post('/api/users')
    .set(bearer(adminToken))
    .send({
      username: `mec2_${suffix}`,
      email: `mec2_${suffix}@motorix.local`,
      rol: 'MECHANIC',
      contrasena: 'Mecanico2026!',
    });
  expect(mechanic2.status).toBe(201);
  mechanic2Token = await loginAs(`mec2_${suffix}`, 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Aislamiento ${suffix}`, telefono: `71${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  // Vehículo de la orden propia y vehículo ajeno: las placas del ajeno no
  // deben devolver nada en el alcance del mecánico.
  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Mazda',
      modelo: '3',
      anio: 2022,
      placas: `AS${suffix}`,
      kilometrajeActual: 500,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;

  placasAjena = `AJ${suffix}`;
  const vehicleAjeno = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Honda',
      modelo: 'Civic',
      anio: 2021,
      placas: placasAjena,
      kilometrajeActual: 500,
    });
  expect(vehicleAjeno.status).toBe(201);

  // Órdenes por vehículo con kilometraje creciente (regla R-08).
  ordenPropiaId = await crearOrden(vehicleId, 1000, mecanicoId);
  ordenAjenaId = await crearOrden(vehicleAjeno.body.id, 2000, mechanic2.body.id);
  ordenSinAsignarId = await crearOrden(vehicleAjeno.body.id, 3000);
});

describe('contrato GET /api/service-orders con token de MECHANIC (FR-010)', () => {
  test('responde 200 con el formato paginado y solo las órdenes propias', async () => {
    const response = await api
      .get('/api/service-orders')
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      elementos: expect.any(Array),
      pagina: 1,
      paginas: expect.any(Number),
      total: expect.any(Number),
    });

    const ids = response.body.elementos.map((order) => order.id);
    expect(ids).toContain(ordenPropiaId);
    expect(ids).not.toContain(ordenAjenaId);
    expect(ids).not.toContain(ordenSinAsignarId);
    for (const order of response.body.elementos) {
      expect(order.mecanicoId).toBe(mecanicoId);
    }
  });

  test('los filtros no pueden ampliar el alcance del mecánico (SC-003)', async () => {
    const response = await api
      .get(`/api/service-orders?buscar=${placasAjena}&estadoAbierta=true`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(0);
    expect(response.body.elementos).toHaveLength(0);
  });

  test('abre su propia orden con 200', async () => {
    const response = await api
      .get(`/api/service-orders/${ordenPropiaId}`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.id).toBe(ordenPropiaId);
    expect(response.body.mecanicoId).toBe(mecanicoId);
  });

  test('abrir una orden de otro mecánico responde 403 ORDEN_AJENA', async () => {
    const response = await api
      .get(`/api/service-orders/${ordenAjenaId}`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(403);
    expect(response.body.error).toEqual({
      mensaje: expect.any(String),
      codigo: 'ORDEN_AJENA',
    });
  });

  test('el aislamiento es recíproco: el otro mecánico solo ve las suyas', async () => {
    const response = await api
      .get('/api/service-orders')
      .set(bearer(mechanic2Token));

    expect(response.status).toBe(200);
    const ids = response.body.elementos.map((order) => order.id);
    expect(ids).toContain(ordenAjenaId);
    expect(ids).not.toContain(ordenPropiaId);
    expect(ids).not.toContain(ordenSinAsignarId);
    for (const order of response.body.elementos) {
      expect(order.mecanicoId).not.toBe(mecanicoId);
    }
  });

  test('una orden sin asignar tampoco se puede abrir (403)', async () => {
    const response = await api
      .get(`/api/service-orders/${ordenSinAsignarId}`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ORDEN_AJENA');
  });
});
