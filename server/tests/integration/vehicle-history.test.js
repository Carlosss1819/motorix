// Pruebas de integración del historial del vehículo (US1): exclusión de
// órdenes no terminadas (FR-003), sin duplicados (SC-002), orden por fecha
// descendente, detalle completo por entrada (FR-002) y estado vacío.
// Fuente de verdad: specs/003-historial-inventario/spec.md (HU1, HU2).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;

// Avanza la orden por la secuencia de estados hasta el indicado. Usa ADMIN,
// que puede transicionar cualquier orden sin necesidad de asignación (R-03).
async function llevarAEstado(orderId, estado) {
  const secuencia = {
    DIAGNOSTICO: ['DIAGNOSTICO'],
    EN_REPARACION: ['DIAGNOSTICO', 'EN_REPARACION'],
    TERMINADO: ['DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO'],
    ENTREGADO: ['DIAGNOSTICO', 'EN_REPARACION', 'TERMINADO', 'ENTREGADO'],
  }[estado];
  for (const paso of secuencia) {
    const response = await api
      .post(`/api/service-orders/${orderId}/estado`)
      .set(bearer(adminToken))
      .send({ estado: paso });
    expect(response.status).toBe(200);
  }
}

async function crearOrden(kilometraje, motivo) {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: motivo,
      fechaIngreso: '2026-10-10',
      kilometraje,
    });
  expect(response.status).toBe(201);
  return response.body.id;
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
    .send({ nombre: `HistInt ${suffix}`, telefono: `75${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Honda',
      modelo: 'Civic',
      anio: 2022,
      placas: `HI${suffix}`,
      kilometrajeActual: 500,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('historial del vehículo (HU1, FR-001 a FR-003)', () => {
  test('un vehículo sin órdenes terminadas muestra el historial vacío, no un error', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.elementos).toEqual([]);
    expect(response.body.total).toBe(0);
  });

  test('solo aparecen órdenes terminadas o entregadas; la orden en curso no se duplica (FR-003)', async () => {
    const enCurso = await crearOrden(1000, 'Orden en curso');
    const terminada = await crearOrden(2000, 'Orden terminada');
    await llevarAEstado(terminada, 'TERMINADO');
    const entregada = await crearOrden(3000, 'Orden entregada');
    await llevarAEstado(entregada, 'ENTREGADO');

    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    const ids = response.body.elementos.map((entry) => entry.ordenId);
    expect(ids).toContain(terminada);
    expect(ids).toContain(entregada);
    expect(ids).not.toContain(enCurso);
    // SC-002: cada orden aparece una sola vez.
    expect(new Set(ids).size).toBe(ids.length);
  });

  test('cada entrada incluye el detalle completo del servicio (FR-002, FR-005)', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    const entrada = response.body.elementos[0];
    expect(entrada).toHaveProperty('ordenId');
    expect(entrada).toHaveProperty('fechaServicio', '2026-10-10');
    expect(entrada).toHaveProperty('kilometraje');
    expect(typeof entrada.kilometraje).toBe('number');
    expect(entrada).toHaveProperty('estadoOrden');
    expect(entrada).toHaveProperty('observaciones');
    expect(entrada).toHaveProperty('diagnostico');
    expect(entrada).toHaveProperty('recomendaciones');
    expect(Array.isArray(entrada.servicios)).toBe(true);
    expect(Array.isArray(entrada.refacciones)).toBe(true);
  });

  test('las órdenes se listan de más reciente a más antiguo', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}/history`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    const kilometrajes = response.body.elementos.map((entry) => entry.kilometraje);
    const ordenado = [...kilometrajes].sort((a, b) => b - a);
    expect(kilometrajes).toEqual(ordenado);
  });

  test('la paginación respeta porPagina y devuelve el total (patrón R-10)', async () => {
    const response = await api
      .get(`/api/vehicles/${vehicleId}/history?pagina=1&porPagina=1`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.elementos).toHaveLength(1);
    expect(response.body.pagina).toBe(1);
    expect(response.body.total).toBeGreaterThanOrEqual(2);
  });
});
