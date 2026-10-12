// Pruebas de integracion de clientes (US3): alta, consulta, detalle con vehiculos
// y aviso de teléfono repetido (decisión R-05).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

describe('flujo de registro y consulta de clientes (US3)', () => {
  test('un cliente creado aparece en el listado y en su detalle', async () => {
    const phone = `61${suffix}`;
    const created = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({
        nombre: `Flujo Cliente ${suffix}`,
        telefono: phone,
        email: `flujo_${suffix}@correo.com`,
      });
    expect(created.status).toBe(201);

    const listing = await api
      .get(`/api/clients?buscar=${phone}`)
      .set(bearer(adminToken));
    expect(listing.status).toBe(200);
    expect(listing.body.some((c) => c.id === created.body.id)).toBe(true);

    const detail = await api
      .get(`/api/clients/${created.body.id}`)
      .set(bearer(adminToken));
    expect(detail.status).toBe(200);
    expect(detail.body.nombre).toBe(`Flujo Cliente ${suffix}`);
    expect(detail.body.vehiculos).toEqual([]);
  });

  test('la busqueda por nombre encuentra al cliente', async () => {
    const listing = await api
      .get(`/api/clients?buscar=${encodeURIComponent(`Flujo Cliente`)}`)
      .set(bearer(adminToken));
    expect(listing.status).toBe(200);
    expect(Array.isArray(listing.body)).toBe(true);
    expect(listing.body.length).toBeGreaterThan(0);
  });
});

describe('aviso de teléfono repetido (R-05 / FR-012)', () => {
  test('avisa sin crear y, confirmado, crea el registro', async () => {
    const phone = `62${suffix}`;

    const first = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Telefono Rep A ${suffix}`, telefono: phone });
    expect(first.status).toBe(201);

    // Segunda vez sin confirmar: 200 con aviso y SIN crear.
    const warning = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Telefono Rep B ${suffix}`, telefono: phone });
    expect(warning.status).toBe(200);
    expect(warning.body.aviso).toBe('Ya existe un cliente con este teléfono');
    expect(warning.body.confirmarReenvio).toBe(true);

    const listing = await api
      .get(`/api/clients?buscar=${phone}`)
      .set(bearer(adminToken));
    expect(listing.body).toHaveLength(1);

    // Confirmado: si crea el segundo registro.
    const confirmado = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Telefono Rep B ${suffix}`, telefono: phone, confirmar: true });
    expect(confirmado.status).toBe(201);

    const finalListing = await api
      .get(`/api/clients?buscar=${phone}`)
      .set(bearer(adminToken));
    expect(finalListing.body).toHaveLength(2);
  });
});

describe('roles en clientes (SC-002)', () => {
  test('RECEPTIONIST puede consultar y crear clientes', async () => {
    const token = await loginAs('recepcion', 'Recepcion2026!');

    const listing = await api.get('/api/clients').set(bearer(token));
    expect(listing.status).toBe(200);

    const created = await api
      .post('/api/clients')
      .set(bearer(token))
      .send({ nombre: `Recep Cliente ${suffix}`, telefono: `63${suffix}` });
    expect(created.status).toBe(201);
  });

  test('MECHANIC no puede consultar clientes (403)', async () => {
    const token = await loginAs('mecanico', 'Mecanico2026!');
    const listing = await api.get('/api/clients').set(bearer(token));
    expect(listing.status).toBe(403);
  });
});
