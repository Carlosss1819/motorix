// Pruebas de integración de las alertas de stock bajo (US8, Sprint 3): una
// salida real en una orden deja la refacción en alerta y el filtro la
// devuelve, mientras que un stock mínimo de 0 nunca entra en las alertas
// (FR-020, FR-021, R-10, V4). Fuente de verdad:
// specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let suffix;
let clientId;
let vehicleId;
let contador = 0;

async function crearRefaccion({ stockInicial, stockMinimo }) {
  contador += 1;
  const response = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `ALR-${suffix}-${contador}`,
      nombre: `Alerta de stock ${suffix} ${contador}`,
      categoria: 'Frenos',
      stockInicial,
      stockMinimo,
    });
  expect(response.status).toBe(201);
  return response.body;
}

async function crearOrden() {
  const response = await api
    .post('/api/service-orders')
    .set(bearer(receptionistToken))
    .send({
      clienteId: clientId,
      vehiculoId: vehicleId,
      motivoVisita: 'Alertas de stock bajo',
      fechaIngreso: '2026-10-14',
      kilometraje: 900,
    });
  expect(response.status).toBe(201);
  return response.body.id;
}

async function stockBajoDe(partId) {
  const response = await api
    .get(`/api/parts/${partId}`)
    .set(bearer(adminToken));
  expect(response.status).toBe(200);
  return response.body.stockBajo;
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Alertas ${suffix}`, telefono: `76${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Toyota',
      modelo: 'Corolla',
      anio: 2023,
      placas: `AL${suffix}`,
      kilometrajeActual: 900,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

test('la salida de una orden deja la refacción en alerta y el filtro la encuentra', async () => {
  const refaccion = await crearRefaccion({ stockInicial: 5, stockMinimo: 3 });
  expect(await stockBajoDe(refaccion.id)).toBe(false);

  const ordenId = await crearOrden();
  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 3 });
  expect(agregada.status).toBe(201);
  expect(agregada.body.stockActual).toBe(2);

  // 2 unidades restantes con mínimo 3: la alerta aparece al instante (SC-008).
  expect(await stockBajoDe(refaccion.id)).toBe(true);

  const filtrado = await api
    .get('/api/parts')
    .query({
      buscar: `Alerta de stock ${suffix} ${contador}`,
      stockBajo: 'true',
    })
    .set(bearer(adminToken));
  expect(filtrado.status).toBe(200);
  expect(filtrado.body.elementos).toHaveLength(1);
  expect(filtrado.body.elementos[0].codigo).toBe(refaccion.codigo);
  expect(filtrado.body.elementos[0].stockBajo).toBe(true);
});

test('la reposición recalcula la alerta junto con el stock (FR-026)', async () => {
  const refaccion = await crearRefaccion({ stockInicial: 4, stockMinimo: 4 });
  expect(await stockBajoDe(refaccion.id)).toBe(true);

  const ordenId = await crearOrden();
  const agregada = await api
    .post(`/api/service-orders/${ordenId}/refacciones`)
    .set(bearer(adminToken))
    .send({ partId: refaccion.id, cantidad: 2 });
  expect(agregada.status).toBe(201);
  expect(await stockBajoDe(refaccion.id)).toBe(true);

  const retirada = await api
    .delete(
      `/api/service-orders/${ordenId}/refacciones/${agregada.body.id}`,
    )
    .set(bearer(adminToken));
  expect(retirada.status).toBe(200);
  // El stock vuelve a su valor inicial, justo en el mínimo: sigue en alerta.
  expect(retirada.body.stockActual).toBe(4);
  expect(await stockBajoDe(refaccion.id)).toBe(true);

  // Con un mínimo menor que el stock, la alerta desaparece (FR-021).
  const editada = await api
    .put(`/api/parts/${refaccion.id}`)
    .set(bearer(adminToken))
    .send({ stockMinimo: 1 });
  expect(editada.status).toBe(200);
  expect(editada.body.stockBajo).toBe(false);
  expect(await stockBajoDe(refaccion.id)).toBe(false);
});

test('un stock mínimo de 0 nunca entra en el filtro de alertas (V4)', async () => {
  const sinMinimo = await crearRefaccion({ stockInicial: 0, stockMinimo: 0 });
  expect(await stockBajoDe(sinMinimo.id)).toBe(false);

  const response = await api
    .get('/api/parts')
    .query({ buscar: sinMinimo.codigo, stockBajo: 'true' })
    .set(bearer(adminToken));

  expect(response.status).toBe(200);
  expect(response.body.elementos).toHaveLength(0);
});
