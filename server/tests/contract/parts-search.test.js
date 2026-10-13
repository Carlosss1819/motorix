// Pruebas de contrato de la consulta de inventario (US6, Sprint 3):
// búsqueda por nombre o código (FR-018), detalle de la refacción y el
// historial de movimientos `GET /api/parts/:id/movements` con `?tipo=` y
// paginación R-10, en orden descendente (FR-030, SC-007).
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

  // Dos refacciones con nombre y código que comparten el término «Frenos».
  // El sufijo va también en los nombres: la base de pruebas acumula datos de
  // corridas anteriores y una búsqueda por nombre fijo dejaría de ser estable.
  partCode = `FRE-${suffix}`;
  const creada = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: partCode,
      nombre: `Disco de freno delantero ${suffix}`,
      categoria: 'Frenos',
      stockInicial: 6,
      stockMinimo: 2,
    });
  expect(creada.status).toBe(201);
  partId = creada.body.id;

  const otra = await api
    .post('/api/parts')
    .set(bearer(adminToken))
    .send({
      codigo: `OTR-${suffix}`,
      nombre: `Llamada de frenos trasera ${suffix}`,
      categoria: 'Frenos',
    });
  expect(otra.status).toBe(201);
});

describe('GET /api/parts?buscar= — búsqueda por nombre o código (FR-018)', () => {
  test('coincide por nombre y devuelve el formato del contrato', async () => {
    const response = await api
      .get(`/api/parts?buscar=${encodeURIComponent(`Disco de freno delantero ${suffix}`)}`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(1);
    expect(response.body.elementos[0]).toMatchObject({
      id: partId,
      codigo: partCode,
      nombre: `Disco de freno delantero ${suffix}`,
      categoria: 'Frenos',
      stockActual: 6,
      stockMinimo: 2,
      stockBajo: false,
      activa: true,
    });
  });

  test('coincide por código, sin importar mayúsculas del texto buscado', async () => {
    const response = await api
      .get(`/api/parts?buscar=fre-${suffix}`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBeGreaterThanOrEqual(1);
    expect(
      response.body.elementos.some((part) => part.codigo === partCode),
    ).toBe(true);
  });

  test('sin coincidencias responde 200 con total 0 (estado vacío)', async () => {
    const response = await api
      .get('/api/parts?buscar=no-existe-999')
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(0);
    expect(response.body.elementos).toHaveLength(0);
  });
});

describe('GET /api/parts/:id/movements — historial auditable (FR-030)', () => {
  test('lista los movimientos con su stock resultante y en orden descendente', async () => {
    // Dos movimientos más sobre la refacción que nació con stock 6.
    const entrada = await api
      .post(`/api/parts/${partId}/movements`)
      .set(bearer(adminToken))
      .send({ tipo: 'ENTRADA', cantidad: 4, motivo: 'Pedido proveedor 123' });
    expect(entrada.status).toBe(201);
    expect(entrada.body).toMatchObject({
      tipo: 'ENTRADA',
      cantidad: 4,
      motivo: 'Pedido proveedor 123',
      stockAfter: 10,
    });

    const ajuste = await api
      .post(`/api/parts/${partId}/movements`)
      .set(bearer(adminToken))
      .send({ tipo: 'AJUSTE', cantidad: 1, motivo: 'Conteo físico mensual' });
    expect(ajuste.status).toBe(201);
    expect(ajuste.body).toMatchObject({
      tipo: 'AJUSTE',
      cantidad: 1,
      motivo: 'Conteo físico mensual',
      // ENTRADA y AJUSTE siempre aumentan el stock (contrato, sección movements).
      stockAfter: 11,
    });

    const response = await api
      .get(`/api/parts/${partId}/movements`)
      .set(bearer(receptionistToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(3);
    // Orden descendente: el ajuste (último) encabeza la lista.
    expect(response.body.elementos[0]).toMatchObject({
      tipo: 'AJUSTE',
      cantidad: 1,
      stockAfter: 11,
      registradoPor: 'admin',
    });
    expect(response.body.elementos[1].tipo).toBe('ENTRADA');
    expect(response.body.elementos[2]).toMatchObject({
      tipo: 'ENTRADA',
      motivo: 'Stock inicial',
      stockAfter: 6,
    });
  });

  test('?tipo= filtra por tipo de movimiento', async () => {
    const response = await api
      .get(`/api/parts/${partId}/movements?tipo=ENTRADA`)
      .set(bearer(mechanicToken));

    expect(response.status).toBe(200);
    expect(response.body.total).toBe(2);
    for (const movement of response.body.elementos) {
      expect(movement.tipo).toBe('ENTRADA');
    }
  });

  test('la paginación R-10 recorta la página y reporta el total real', async () => {
    const response = await api
      .get(`/api/parts/${partId}/movements?porPagina=2&pagina=2`)
      .set(bearer(adminToken));

    expect(response.status).toBe(200);
    expect(response.body.pagina).toBe(2);
    expect(response.body.paginas).toBe(2);
    expect(response.body.total).toBe(3);
    expect(response.body.elementos).toHaveLength(1);
  });

  test('una refacción inexistente responde 404 REFACCION_NO_ENCONTRADA', async () => {
    const response = await api
      .get('/api/parts/99999999/movements')
      .set(bearer(adminToken));

    expect(response.status).toBe(404);
    expect(response.body.error.codigo).toBe('REFACCION_NO_ENCONTRADA');
  });

  test('un tipo de movimiento no válido responde 400 en español', async () => {
    const response = await api
      .get(`/api/parts/${partId}/movements?tipo=PRESTAMO`)
      .set(bearer(adminToken));

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain('ENTRADA');
  });

  test('los tres roles consultan el historial y sin token responde 401', async () => {
    for (const token of [adminToken, receptionistToken, mechanicToken]) {
      const response = await api
        .get(`/api/parts/${partId}/movements`)
        .set(bearer(token));
      expect(response.status).toBe(200);
    }

    const sinToken = await api.get(`/api/parts/${partId}/movements`);
    expect(sinToken.status).toBe(401);
  });
});

describe('POST /api/parts/:id/movements — entradas y ajustes (FR-029)', () => {
  test('un AJUSTE sin motivo responde 400 AJUSTE_SIN_MOTIVO', async () => {
    const response = await api
      .post(`/api/parts/${partId}/movements`)
      .set(bearer(adminToken))
      .send({ tipo: 'AJUSTE', cantidad: 1 });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('AJUSTE_SIN_MOTIVO');
  });

  test('una SALIDA directa no se acepta: la genera el uso en órdenes', async () => {
    const response = await api
      .post(`/api/parts/${partId}/movements`)
      .set(bearer(adminToken))
      .send({ tipo: 'SALIDA', cantidad: 1, motivo: 'Intento manual' });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('VALIDACION');
    expect(response.body.error.mensaje).toContain('ENTRADA');
  });

  test('recepción y mecánico reciben 403 al registrar movimientos', async () => {
    for (const token of [receptionistToken, mechanicToken]) {
      const response = await api
        .post(`/api/parts/${partId}/movements`)
        .set(bearer(token))
        .send({ tipo: 'ENTRADA', cantidad: 1 });
      expect(response.status).toBe(403);
      expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
    }
  });
});
