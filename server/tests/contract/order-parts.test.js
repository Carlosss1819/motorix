// Pruebas de contrato de las refacciones usadas en una orden (US7, Sprint 3):
// alta y retiro sobre `/api/service-orders/:id/refacciones` y sus alias
// heredados `/repuestos` con exactamente la misma respuesta (R-07), con los
// errores del catálogo: 404 REFACCION_NO_ENCONTRADA, 409 REFACCION_INACTIVA,
// 409 STOCK_INSUFICIENTE y 403 de un mecánico en orden ajena (FR-023 a
// FR-027, RN-6, RN-8).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;
let contadorRefacciones = 0;

// Crea una refacción propia de la corrida con el stock indicado: cada prueba
// trabaja con su inventario para no depender de otras suites.
async function crearRefaccion({ stock = 6, activa = true } = {}) {
  contadorRefacciones += 1;
  const codigo = `ORD-${suffix}-${contadorRefacciones}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo,
      nombre: `Refacción de orden ${suffix} ${contadorRefacciones}`,
      categoria: 'Frenos',
      stockInicial: stock,
      stockMinimo: 1,
    });
  expect(creada.status).toBe(201);

  if (!activa) {
    const desactivada = await api
      .post(`/api/parts/${creada.body.id}/desactivar`)
      .set(bearer(adminToken));
    expect(desactivada.status).toBe(200);
  }
  return creada.body;
}

async function crearOrden(kilometraje) {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Refacciones de la orden',
      fechaIngreso: '2026-10-14',
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
    .send({ nombre: `Refacciones ${suffix}`, telefono: `74${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2021,
      placas: `RF${suffix}`,
      kilometrajeActual: 700,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('POST /api/service-orders/:id/refacciones (FR-023 a FR-025)', () => {
  test('agrega una refacción del catálogo y descuenta su stock (201)', async () => {
    const ordenId = await crearOrden(1000);
    const refaccion = await crearRefaccion({ stock: 6 });

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 2 });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      id: expect.any(Number),
      partId: refaccion.id,
      codigo: refaccion.codigo,
      nombre: refaccion.nombre,
      cantidad: 2,
      stockActual: 4,
    });
  });

  test('sin partId o con cantidad 0 responde 400 en español', async () => {
    const ordenId = await crearOrden(2000);
    const refaccion = await crearRefaccion({ stock: 3 });

    const sinPart = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ cantidad: 1 });
    expect(sinPart.status).toBe(400);
    expect(sinPart.body.error.codigo).toBe('VALIDACION');
    expect(sinPart.body.error.mensaje).toContain('refacción');

    const cantidadInvalida = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 0 });
    expect(cantidadInvalida.status).toBe(400);
    expect(cantidadInvalida.body.error.mensaje).toContain('cantidad');
  });

  test('una refacción que no existe responde 404 REFACCION_NO_ENCONTRADA', async () => {
    const ordenId = await crearOrden(3000);

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: 99999999, cantidad: 1 });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REFACCION_NO_ENCONTRADA');
  });

  test('una refacción desactivada responde 409 REFACCION_INACTIVA (FR-019)', async () => {
    const ordenId = await crearOrden(4000);
    const refaccion = await crearRefaccion({ stock: 5, activa: false });

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 1 });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('REFACCION_INACTIVA');
  });

  test('sin stock suficiente responde 409 STOCK_INSUFICIENTE (RN-8)', async () => {
    const ordenId = await crearOrden(5000);
    const refaccion = await crearRefaccion({ stock: 2 });

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 3 });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('STOCK_INSUFICIENTE');
    expect(response.body.error.mensaje).toContain('2');
  });

  test('el alias heredado /repuestos responde exactamente igual (R-07)', async () => {
    const ordenId = await crearOrden(6000);
    const refaccion = await crearRefaccion({ stock: 4 });

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
      stockActual: 3,
    });
  });

  test('recepción también puede agregar refacciones (FR-027)', async () => {
    const ordenId = await crearOrden(7000);
    const refaccion = await crearRefaccion({ stock: 3 });

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(receptionistToken))
      .send({ partId: refaccion.id, cantidad: 1 });

    expect(response.status).toBe(201);
    expect(response.body.stockActual).toBe(2);
  });

  test('un mecánico en una orden ajena recibe 403 (FR-010, RN-15)', async () => {
    // La orden queda sin asignar, así que es ajena para el mecánico.
    const ordenId = await crearOrden(8000);
    const refaccion = await crearRefaccion({ stock: 3 });

    const response = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(mechanicToken))
      .send({ partId: refaccion.id, cantidad: 1 });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ORDEN_AJENA');
  });
});

describe('DELETE /api/service-orders/:id/refacciones/:refaccionId (FR-026)', () => {
  test('retira la fila y repone el stock (200)', async () => {
    const ordenId = await crearOrden(9000);
    const refaccion = await crearRefaccion({ stock: 6 });
    const agregada = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 2 });
    expect(agregada.status).toBe(201);

    const response = await api
      .delete(
        `/api/service-orders/${ordenId}/refacciones/${agregada.body.id}`,
      )
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      mensaje: 'Refacción retirada de la orden.',
      stockActual: 6,
    });
  });

  test('el alias heredado /repuestos/:repuestoId responde igual (R-07)', async () => {
    const ordenId = await crearOrden(10000);
    const refaccion = await crearRefaccion({ stock: 5 });
    const agregada = await api
      .post(`/api/service-orders/${ordenId}/repuestos`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 1 });
    expect(agregada.status).toBe(201);

    const response = await api
      .delete(
        `/api/service-orders/${ordenId}/repuestos/${agregada.body.id}`,
      )
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      mensaje: 'Refacción retirada de la orden.',
      stockActual: 5,
    });
  });

  test('una fila que no está en la orden responde 404', async () => {
    const ordenId = await crearOrden(11000);

    const response = await api
      .delete(`/api/service-orders/${ordenId}/refacciones/99999999`)
      .set(bearer(adminToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REPUESTO_NO_ENCONTRADO');
  });

  test('un mecánico en una orden ajena recibe 403 al retirar (FR-027)', async () => {
    const ordenId = await crearOrden(12000);
    const refaccion = await crearRefaccion({ stock: 4 });
    const agregada = await api
      .post(`/api/service-orders/${ordenId}/refacciones`)
      .set(bearer(adminToken))
      .send({ partId: refaccion.id, cantidad: 1 });
    expect(agregada.status).toBe(201);

    const response = await api
      .delete(
        `/api/service-orders/${ordenId}/refacciones/${agregada.body.id}`,
      )
      .set(bearer(mechanicToken));

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ORDEN_AJENA');
  });
});
