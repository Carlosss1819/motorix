// Pruebas de integración del inventario de refacciones (US5, Sprint 3):
// el código es único en todo el catálogo, el stock inicial deja su
// movimiento ENTRADA constancia desde el alta (SC-007, R-08), la
// desactivación es idempotente y conserva el historial, y una refacción
// desactivada no puede agregarse a una orden (V4, FR-019, RN-6).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Inventario ${suffix}`, telefono: `77${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Kia',
      modelo: 'Rio',
      anio: 2022,
      placas: `IN${suffix}`,
      kilometrajeActual: 500,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('el código es único: un segundo alta con el mismo código no duplica (FR-017)', async () => {
  const codigo = `Uniq-${suffix}`;
  const primera = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({ codigo, nombre: 'Refacción única', categoria: 'Varios' });
  expect(primera.status).toBe(201);

  const segunda = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({ codigo, nombre: 'Duplicado con el mismo código', categoria: 'Varios' });
  expect(segunda.status).toBe(409);
  expect(segunda.body.error.codigo).toBe('CODIGO_DUPLICADO');

  const listado = await api
    .get(`/api/parts?buscar=${codigo}`)
    .set(bearer(adminToken));
  expect(listado.status).toBe(200);
  expect(listado.body.total).toBe(1);
});

test('el stock inicial genera un movimiento ENTRADA con motivo «Stock inicial» (SC-007)', async () => {
  const codigo = `Stk-${suffix}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo,
      nombre: 'Refacción con stock inicial',
      categoria: 'Frenos',
      stockInicial: 7,
      stockMinimo: 2,
    });
  expect(creada.status).toBe(201);
  expect(creada.body.stockActual).toBe(7);

  const movimientos = await api
    .get(`/api/parts/${creada.body.id}/movements`)
    .set(bearer(adminToken));
  expect(movimientos.status).toBe(200);
  expect(movimientos.body.total).toBe(1);
  expect(movimientos.body.elementos[0]).toMatchObject({
    tipo: 'ENTRADA',
    cantidad: 7,
    motivo: 'Stock inicial',
    stockAfter: 7,
  });
});

test('la desactivación es idempotente y el historial de movimientos se conserva (FR-019)', async () => {
  const codigo = `Des-${suffix}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({ codigo, nombre: 'Refacción a desactivar', categoria: 'Varios', stockInicial: 3 });
  expect(creada.status).toBe(201);

  const primera = await api
    .post(`/api/parts/${creada.body.id}/desactivar`)
    .set(bearer(adminToken));
  expect(primera.status).toBe(200);

  const segunda = await api
    .post(`/api/parts/${creada.body.id}/desactivar`)
    .set(bearer(adminToken));
  expect(segunda.status).toBe(200);

  const consulta = await api
    .get(`/api/parts/${creada.body.id}`)
    .set(bearer(adminToken));
  expect(consulta.status).toBe(200);
  expect(consulta.body.activa).toBe(false);
  // Su stock y su historial no se borran: la baja es solo de catálogo.
  expect(consulta.body.stockActual).toBe(3);

  const movimientos = await api
    .get(`/api/parts/${creada.body.id}/movements`)
    .set(bearer(adminToken));
  expect(movimientos.status).toBe(200);
  expect(movimientos.body.total).toBe(1);
});

test('una refacción desactivada no puede agregarse a una orden (409 REFACCION_INACTIVA)', async () => {
  const codigo = `Ina-${suffix}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({ codigo, nombre: 'Refacción desactivada', categoria: 'Varios', stockInicial: 5 });
  expect(creada.status).toBe(201);

  const desactivada = await api
    .post(`/api/parts/${creada.body.id}/desactivar`)
    .set(bearer(adminToken));
  expect(desactivada.status).toBe(200);

  const orden = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Uso de refacción desactivada (integración)',
      fechaIngreso: '2026-10-15',
      kilometraje: 600,
    });
  expect(orden.status).toBe(201);

  const agregada = await api
    .post(`/api/service-orders/${orden.body.id}/refacciones`)
    .set(bearer(receptionistToken))
    .send({ partId: creada.body.id, cantidad: 1 });
  expect(agregada.status).toBe(409);
  expect(agregada.body.error.codigo).toBe('REFACCION_INACTIVA');
});
