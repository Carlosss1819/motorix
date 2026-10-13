// Pruebas de integración del kilometraje del servicio (US2, Sprint 3): el
// kilometraje hereda al historial (FR-005), la regresión se rechaza sin
// corrección y se acepta solo con corrección de ADMIN (FR-006, R-08 heredada
// del Sprint 2) y `vehicles.current_mileage` nunca baja (FR-007).
// Fuente de verdad: specs/003-historial-inventario/spec.md (HU2).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;

async function crearOrden(kilometraje, extra = {}) {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(extra.token ?? receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: extra.motivo ?? 'Prueba de kilometraje',
      fechaIngreso: '2026-10-11',
      kilometraje,
      ...(extra.correccion ? { correccionKilometraje: extra.correccion } : {}),
    });
  return response;
}

// Avanza la orden a TERMINADO para que entre al historial.
async function terminarOrden(orderId) {
  for (const estado of ['DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO']) {
    const response = await api
      .post(`/api/service-orders/${orderId}/estado`)
      .set(bearer(adminToken))
      .send({ estado });
    expect(response.status).toBe(200);
  }
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
    .send({ nombre: `KmHist ${suffix}`, telefono: `76${suffix}` });
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
      placas: `KH${suffix}`,
      kilometrajeActual: 30000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('kilometraje del servicio en el historial (HU2, FR-005)', () => {
  test('cada entrada del historial muestra el kilometraje registrado en su orden', async () => {
    const primera = await crearOrden(31000, { motivo: 'Primera visita' });
    expect(primera.status).toBe(201);
    await terminarOrden(primera.body.id);

    const segunda = await crearOrden(32500, { motivo: 'Segunda visita' });
    expect(segunda.status).toBe(201);
    await terminarOrden(segunda.body.id);

    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    const kilometrajes = response.body.elementos.map((e) => e.kilometraje);
    expect(kilometrajes).toContain(31000);
    expect(kilometrajes).toContain(32500);
  });
});

describe('regresión de kilometraje (HU2, FR-006, R-08)', () => {
  test('rechaza una orden con kilometraje menor sin corrección (400)', async () => {
    const response = await crearOrden(32000, { motivo: 'Regresión sin corrección' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('KILOMETRAJE_MENOR');
  });

  test('recepción no puede corregir el kilometraje aunque envíe la nota (403)', async () => {
    const response = await crearOrden(32000, {
      motivo: 'Corrección sin permiso',
      correccion: 'Odómetro reemplazado',
    });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('CORRECCION_NO_AUTORIZADA');
  });

  test('la corrección de ADMIN acepta el kilometraje menor (201)', async () => {
    const response = await crearOrden(32000, {
      motivo: 'Corrección de administrador',
      correccion: 'Odómetro reemplazado por falla',
      token: adminToken,
    });

    expect(response.status).toBe(201);
  });
});

describe('kilometraje actual del vehículo (HU2, FR-007)', () => {
  test('current_mileage queda en el valor más alto, nunca baja con la corrección', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    // La última orden válida registró 32,500 km; la corrección de 32,000 km no
    // debe bajar el kilometraje del vehículo.
    expect(response.body.kilometrajeActual).toBe(32500);
  });
});
