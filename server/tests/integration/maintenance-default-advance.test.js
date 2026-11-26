// Integración (Sprint 7, US2, FR-005): los márgenes de «Próximo» configurados
// son la antelación por defecto de los mantenimientos nuevos. Para no cambiar
// la base compartida con otras suites en paralelo, el margen distinto se fija
// con la superposición de pruebas del servicio (mismo proceso); la escritura
// real en la tabla settings la cubre tests/contract/settings.test.js.
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';
import { setSettingsOverridesForTests } from '../../services/settings.service.js';

let adminToken;
let vehicleId;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `Margen S7 ${suffix}`, telefono: `71${suffix}`.slice(0, 20) });
  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: client.body.id,
      marca: 'Mazda',
      modelo: '3',
      anio: 2021,
      placas: `MG${suffix}`.slice(0, 20),
      kilometrajeActual: 10000,
    });
  vehicleId = vehicle.body.id;
});

afterEach(() => setSettingsOverridesForTests(null));

function crear(tipo, extra = {}) {
  return api
    .post('/api/maintenance')
    .set(bearer(adminToken))
    .send({ vehiculoId: vehicleId, tipoServicio: `${tipo} ${suffix}`, fechaObjetivo: '2027-06-30', ...extra });
}

test('test_sin_antelacion_en_el_cuerpo_usa_el_margen_configurado', async () => {
  setSettingsOverridesForTests({ mantenimiento: { antelacionDias: 15, antelacionKm: 800 } });
  const response = await crear('Margen configurado');
  expect(response.status).toBe(201);
  expect(response.body).toMatchObject({ antelacionDias: 15, antelacionKm: 800 });
});

test('test_la_antelacion_del_cuerpo_gana_sobre_el_margen_configurado', async () => {
  setSettingsOverridesForTests({ mantenimiento: { antelacionDias: 15, antelacionKm: 800 } });
  const response = await crear('Margen propio', { antelacionDias: 45, antelacionKm: 1200 });
  expect(response.status).toBe(201);
  expect(response.body).toMatchObject({ antelacionDias: 45, antelacionKm: 1200 });
});

test('test_cambiar_el_margen_no_altera_los_mantenimientos_existentes', async () => {
  const creado = await crear('Margen existente');
  expect(creado.status).toBe(201);
  const antes = creado.body.antelacionDias;
  setSettingsOverridesForTests({ mantenimiento: { antelacionDias: 7 } });
  const leido = await api.get(`/api/maintenance/${creado.body.id}`).set(bearer(adminToken));
  expect(leido.body.antelacionDias).toBe(antes);
  expect(leido.body.estado).toBe(creado.body.estado);
});
