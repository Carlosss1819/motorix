// Pruebas de contrato del catálogo de refacciones (US5, Sprint 3): CRUD con
// código único (409 CODIGO_DUPLICADO), edición que no toca código ni stock,
// desactivación idempotente sin borrado y la matriz de permisos (escritura
// solo ADMIN, FR-022; lectura los tres roles, clarificación 4).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let receptionistToken;
let mechanicToken;
let suffix;
let partId;
let partCode;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  partCode = `PAD-${suffix}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: partCode,
      nombre: 'Juego de pastillas delanteras',
      categoria: 'Frenos',
      marca: 'Brembo',
      stockInicial: 10,
      stockMinimo: 5,
      precioCompra: 180,
      precioVenta: 320,
    });
  expect(creada.status).toBe(201);
  partId = creada.body.id;
});

describe('POST /api/parts — alta del catálogo (FR-017)', () => {
  test('responde 201 con la refacción en el formato del contrato', async () => {
    const response = await api
      .post('/api/parts')
      .set(bearer(adminToken))
      .send({
        codigo: `Buj-${suffix}`,
        nombre: 'Juego de bujías iridium',
        categoria: 'Encendido',
        marca: 'NGK',
        stockInicial: 4,
        stockMinimo: 2,
        precioCompra: 90,
        precioVenta: 150,
      });

    expect(response.status).toBe(201);
    expect(response.body).toMatchObject({
      id: expect.any(Number),
      codigo: `Buj-${suffix}`,
      nombre: 'Juego de bujías iridium',
      categoria: 'Encendido',
      marca: 'NGK',
      stockActual: 4,
      stockMinimo: 2,
      stockBajo: false,
      activa: true,
    });
    expect(Number(response.body.precioCompra)).toBe(90);
    expect(Number(response.body.precioVenta)).toBe(150);
  });

  test('un código repetido responde 409 CODIGO_DUPLICADO (FR-017)', async () => {
    const response = await api
      .post('/api/parts')
      .set(bearer(adminToken))
      .send({
        codigo: partCode,
        nombre: 'Otra pastilla con el mismo código',
        categoria: 'Frenos',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.codigo).toBe('CODIGO_DUPLICADO');
  });

  test('sin código responde 400 con el mensaje en español', async () => {
    const response = await api
      .post('/api/parts')
      .set(bearer(adminToken))
      .send({ nombre: 'Sin código', categoria: 'Frenos' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain('El código es obligatorio');
  });
});

describe('GET /api/parts — consulta del catálogo (FR-022)', () => {
  test('la refacción creada se consulta por id con todos sus campos', async () => {
    const response = await api
      .get(`/api/parts/${partId}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      id: partId,
      codigo: partCode,
      nombre: 'Juego de pastillas delanteras',
      categoria: 'Frenos',
      marca: 'Brembo',
      stockActual: 10,
      stockMinimo: 5,
      stockBajo: false,
      activa: true,
    });
  });

  test('una refacción inexistente responde 404 REFACCION_NO_ENCONTRADA', async () => {
    const response = await api
      .get('/api/parts/99999999')
      .set(bearer(adminToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REFACCION_NO_ENCONTRADA');
  });

  test('los tres roles consultan el listado con 200', async () => {
    for (const token of [adminToken, receptionistToken, mechanicToken]) {
      const response = await api.get('/api/parts').set(bearer(token));
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.elementos)).toBe(true);
    }
  });

  test('sin token responde 401', async () => {
    const response = await api.get('/api/parts');
    expect(response.status).toBe(401);
  });
});

describe('PUT /api/parts/:id — edición del catálogo (FR-022)', () => {
  test('actualiza el nombre y el stock mínimo sin tocar código ni stock', async () => {
    const response = await api
      .put(`/api/parts/${partId}`)
      .set(bearer(adminToken))
      .send({
        nombre: 'Pastillas delanteras Brembo',
        stockMinimo: 3,
        // El código es identificador y el stock solo cambia por movimientos:
        // el backend los ignora por contrato.
        codigo: `OTRO-${suffix}`,
        stockActual: 99,
      });

    expect(response.status).toBe(200);
    expect(response.body.nombre).toBe('Pastillas delanteras Brembo');
    expect(response.body.stockMinimo).toBe(3);
    expect(response.body.codigo).toBe(partCode);
    expect(response.body.stockActual).toBe(10);
  });

  test('una refacción inexistente responde 404 REFACCION_NO_ENCONTRADA', async () => {
    const response = await api
      .put('/api/parts/99999999')
      .set(bearer(adminToken))
      .send({ nombre: 'No existe' });

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REFACCION_NO_ENCONTRADA');
  });
});

describe('POST /api/parts/:id/desactivar — baja sin borrado (FR-019)', () => {
  test('responde 200 y vuelve a responder 200 al repetir (idempotente)', async () => {
    const codigo = `Des-${suffix}`;
    const creada = await api
      .post('/api/parts')
      .set(bearer(adminToken))
      .send({ codigo, nombre: 'Refacción para desactivar', categoria: 'Varios' });
    expect(creada.status).toBe(201);

    const primera = await api
      .post(`/api/parts/${creada.body.id}/desactivar`)
      .set(bearer(adminToken));
    expect(primera.status).toBe(200);
    expect(primera.body.mensaje).toBe('Refacción desactivada.');

    const consulta = await api
      .get(`/api/parts/${creada.body.id}`)
      .set(bearer(adminToken));
    expect(consulta.status).toBe(200);
    expect(consulta.body.activa).toBe(false);

    const segunda = await api
      .post(`/api/parts/${creada.body.id}/desactivar`)
      .set(bearer(adminToken));
    expect(segunda.status).toBe(200);
    expect(segunda.body.mensaje).toBe('Refacción desactivada.');
  });
});

describe('permisos del catálogo (clarificación 4, FR-022)', () => {
  test('recepción y mecánico reciben 403 en el alta', async () => {
    for (const token of [receptionistToken, mechanicToken]) {
      const response = await api
        .post('/api/parts')
        .set(bearer(token))
        .send({
          codigo: `Rol${suffix}${token.length}`,
          nombre: 'Sin permiso',
          categoria: 'Frenos',
        });
      expect(response.status).toBe(403);
      expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
    }
  });

  test('recepción y mecánico reciben 403 en la edición', async () => {
    for (const token of [receptionistToken, mechanicToken]) {
      const response = await api
        .put(`/api/parts/${partId}`)
        .set(bearer(token))
        .send({ nombre: 'Sin permiso' });
      expect(response.status).toBe(403);
      expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
    }
  });

  test('recepción y mecánico reciben 403 en la desactivación', async () => {
    for (const token of [receptionistToken, mechanicToken]) {
      const response = await api
        .post(`/api/parts/${partId}/desactivar`)
        .set(bearer(token));
      expect(response.status).toBe(403);
      expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
    }
  });
});
