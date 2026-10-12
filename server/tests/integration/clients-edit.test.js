// Pruebas de integracion de la edicion de clientes (US4): los vehiculos asociados se
// conservan tras la edicion de los datos del cliente.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

describe('edicion de cliente con vehiculos asociados (US4)', () => {
  test('editar nombre, teléfono y correo conserva los vehiculos', async () => {
    const phone = `65${suffix}`;
    const created = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `Edit Me ${suffix}`, telefono: phone });
    expect(created.status).toBe(201);
    const clientId = created.body.id;

    // Se le dan dos vehiculos.
    for (const index of [1, 2]) {
      const vehicle = await api
        .post('/api/vehicles')
        .set(bearer(adminToken))
        .send({
          clienteId: clientId,
          marca: index === 1 ? 'Ford' : 'Chevrolet',
          modelo: index === 1 ? 'Focus' : 'Aveo',
          anio: 2018,
          placas: `ED${index}${suffix}`,
          vin: null,
          kilometrajeActual: 1000 * index,
        });
      expect(vehicle.status).toBe(201);
    }

    const edited = await api
      .put(`/api/clients/${clientId}`)
      .set(bearer(adminToken))
      .send({
        nombre: `Edit Me Twice ${suffix}`,
        telefono: `66${suffix}`,
        email: `edittwice_${suffix}@correo.com`,
      });
    expect(edited.status).toBe(200);
    expect(edited.body.nombre).toBe(`Edit Me Twice ${suffix}`);
    expect(edited.body.telefono).toBe(`66${suffix}`);

    const detail = await api
      .get(`/api/clients/${clientId}`)
      .set(bearer(adminToken));
    expect(detail.status).toBe(200);
    expect(detail.body.nombre).toBe(`Edit Me Twice ${suffix}`);
    expect(detail.body.vehiculos).toHaveLength(2);
    expect(detail.body.vehiculos.map((v) => v.dueno)).toEqual([
      `Edit Me Twice ${suffix}`,
      `Edit Me Twice ${suffix}`,
    ]);
  });

  test('cancelar la edicion no modifica el cliente (se válida en cliente; aqui el PUT no se envia)', async () => {
    const created = await api
      .post('/api/clients')
      .set(bearer(adminToken))
      .send({ nombre: `No Edit ${suffix}`, telefono: `67${suffix}` });

    const detail = await api
      .get(`/api/clients/${created.body.id}`)
      .set(bearer(adminToken));
    expect(detail.body.nombre).toBe(`No Edit ${suffix}`);
    expect(detail.body.telefono).toBe(`67${suffix}`);
  });
});
