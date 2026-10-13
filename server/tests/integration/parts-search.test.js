// Pruebas de integración de la consulta de inventario (US6, Sprint 3):
// la búsqueda cubre nombre y código sin mostrar otras refacciones, el
// detalle de una refacción refleja su stock real y su historial de
// movimientos explica cada cambio hasta el stock vigente (SC-007, V4/V6).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;
let frenosId;
let aceiteId;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');

  const frenos = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `FRE-${suffix}`,
      // El sufijo también va en los nombres: la base de pruebas acumula datos
      // de corridas anteriores y una búsqueda por nombre fijo no sería estable.
      nombre: `Pastillas de freno delanteras ${suffix}`,
      categoria: 'Frenos',
      stockInicial: 5,
      stockMinimo: 2,
    });
  expect(frenos.status).toBe(201);
  frenosId = frenos.body.id;

  const aceite = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `ACE-${suffix}`,
      nombre: `Aceite de motor 5W30 ${suffix}`,
      categoria: 'Lubricantes',
      stockInicial: 20,
    });
  expect(aceite.status).toBe(201);
  aceiteId = aceite.body.id;
});

test('la búsqueda por nombre y por código devuelve solo las coincidencias (FR-018)', async () => {
  const porNombre = await api
    .get(`/api/parts?buscar=${encodeURIComponent(`Pastillas de freno delanteras ${suffix}`)}`)
    .set(bearer(adminToken));
  expect(porNombre.status).toBe(200);
  expect(porNombre.body.total).toBe(1);
  expect(porNombre.body.elementos[0].id).toBe(frenosId);

  const porCodigo = await api
    .get(`/api/parts?buscar=ACE-${suffix}`)
    .set(bearer(adminToken));
  expect(porCodigo.status).toBe(200);
  expect(porCodigo.body.total).toBe(1);
  expect(porCodigo.body.elementos[0].id).toBe(aceiteId);

  // El mismo término en el nombre y en el código devuelve exactamente las dos
  // refacciones de esta corrida, sin mezclar las de corridas anteriores.
  const deAmbas = await api
    .get(`/api/parts?buscar=${suffix}`)
    .set(bearer(adminToken));
  expect(deAmbas.status).toBe(200);
  expect(deAmbas.body.total).toBe(2);
  expect(deAmbas.body.elementos.map((part) => part.id).sort()).toEqual(
    [frenosId, aceiteId].sort(),
  );
});

test('cada movimiento explica un cambio y el último stockAfter es el stock real', async () => {
  // Entrada y ajuste sobre la refacción que nació con 5 unidades.
  const entrada = await api
    .post(`/api/parts/${frenosId}/movements`)
    .set(bearer(adminToken))
    .send({ tipo: 'ENTRADA', cantidad: 3, motivo: 'Pedido proveedor 77' });
  expect(entrada.status).toBe(201);

  const ajuste = await api
    .post(`/api/parts/${frenosId}/movements`)
    .set(bearer(adminToken))
    .send({ tipo: 'AJUSTE', cantidad: 2, motivo: 'Merma por daño en almacén' });
  expect(ajuste.status).toBe(201);

  const detalle = await api
    .get(`/api/parts/${frenosId}`)
    .set(bearer(adminToken));
  expect(detalle.status).toBe(200);
  expect(detalle.body.stockActual).toBe(10);

  const movimientos = await api
    .get(`/api/parts/${frenosId}/movements`)
    .set(bearer(adminToken));
  expect(movimientos.status).toBe(200);
  expect(movimientos.body.total).toBe(3);

  // Descendente: cada fila conserva su stock resultante (auditable, V6).
  expect(
    movimientos.body.elementos.map((movement) => movement.stockAfter),
  ).toEqual([10, 8, 5]);
  expect(movimientos.body.elementos[0].motivo).toBe('Merma por daño en almacén');
  expect(movimientos.body.elementos[1].motivo).toBe('Pedido proveedor 77');
  expect(movimientos.body.elementos[1].ordenId).toBeNull();

  // El filtro por tipo convive con el historial completo.
  const entradas = await api
    .get(`/api/parts/${frenosId}/movements?tipo=ENTRADA`)
    .set(bearer(adminToken));
  expect(entradas.body.total).toBe(2);
});

test('el historial de una refacción no se mezcla con el de otra', async () => {
  const deAceite = await api
    .get(`/api/parts/${aceiteId}/movements`)
    .set(bearer(adminToken));

  expect(deAceite.status).toBe(200);
  expect(deAceite.body.total).toBe(1);
  expect(deAceite.body.elementos[0]).toMatchObject({
    tipo: 'ENTRADA',
    motivo: 'Stock inicial',
    cantidad: 20,
    stockAfter: 20,
  });
});
