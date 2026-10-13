// Pruebas de integración del mantenimiento preventivo (US3, Sprint 3):
// ciclo completo alta → estado calculado → «servicio realizado» que renueva
// el MISMO registro (mismo id, últimos servicio y objetivos recalculados,
// estado vuelve a NORMAL) sin duplicados (clarificación 2, R-05).
// Fuente de verdad: specs/003-historial-inventario/spec.md (HU3).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let mechanicToken;
let suffix;
let clientId;
let vehicleId;

// Diferencia de días entre dos fechas ISO (para recortar objetivos sin
// depender de la fecha real del sistema).
function diasDespues(iso, dias) {
  const date = new Date(`${iso}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + dias);
  return date.toISOString().substring(0, 10);
}

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
  mechanicToken = await loginAs('mecanico', 'Mecanico2026!');

  const client = await api
    .post('/api/clients')
    .set(bearer(adminToken))
    .send({ nombre: `MantInt ${suffix}`, telefono: `78${suffix}` });
  expect(client.status).toBe(201);
  clientId = client.body.id;

  const vehicle = await api
    .post('/api/vehicles')
    .set(bearer(adminToken))
    .send({
      clienteId: clientId,
      marca: 'Mazda',
      modelo: 'CX-5',
      anio: 2022,
      placas: `MI${suffix}`,
      kilometrajeActual: 20000,
    });
  expect(vehicle.status).toBe(201);
  vehicleId = vehicle.body.id;
});

describe('ciclo de vida del mantenimiento (HU3, FR-008 a FR-015)', () => {
  test('alta, estado calculado, renovación del mismo registro y sin duplicados', async () => {
    // 1) Alta con objetivo de km alcanzable y intervalo configurado.
    const hoy = new Date().toISOString().substring(0, 10);
    const alta = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Cambio de aceite y filtro',
        fechaObjetivo: diasDespues(hoy, 200),
        kilometrajeObjetivo: 20400,
        intervaloDias: 90,
        intervaloKm: 5000,
      });
    expect(alta.status).toBe(201);
    const id = alta.body.id;
    expect(alta.body.kilometrajeUltimoServicio).toBeNull();
    // 20,000 km está dentro de los 500 km de antelación de 20,400 (FR-012).
    expect(alta.body.estado).toBe('PROXIMO');
    expect(alta.body.kilometrajeObjetivo).toBe(20400);

    // 2) El listado por vehículo lo encuentra exactamente una vez.
    const listado = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(mechanicToken));
    expect(listado.status).toBe(200);
    expect(listado.body.elementos).toHaveLength(1);

    // 3) «Servicio realizado» con el kilometraje vigente del vehículo.
    const realizar = await api
      .post(`/api/maintenance/${id}/realizar`)
      .set(bearer(mechanicToken))
      .send({ kilometrajeServicio: 21000 });

    expect(realizar.status).toBe(200);
    // Mismo registro, no una copia (clarificación 2).
    expect(realizar.body.id).toBe(id);
    expect(realizar.body.fechaUltimoServicio).toBeTruthy();
    expect(realizar.body.kilometrajeUltimoServicio).toBe(21000);
    // Objetivos recalculados desde los intervalos (R-05).
    expect(realizar.body.kilometrajeObjetivo).toBe(26000);
    expect(realizar.body.fechaObjetivo).toBeTruthy();
    // Con el objetivo recién recalculado lejos, vuelve a NORMAL.
    expect(realizar.body.estado).toBe('NORMAL');

    // 4) El kilometraje vigente del vehículo sube a 21,000 (FR-007).
    const vehiculo = await api
      .get(`/api/vehicles/${vehicleId}`)
      .set(bearer(adminToken));
    expect(vehiculo.body.kilometrajeActual).toBe(21000);

    // 5) Sigue habiendo un solo registro por vehículo y tipo.
    const listadoFinal = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(mechanicToken));
    expect(listadoFinal.body.total).toBe(1);
    expect(listadoFinal.body.elementos[0].id).toBe(id);
  });

  test('el filtro por estado se aplica sobre el estado calculado', async () => {
    // Un mantenimiento vencido: objetivo de km por debajo del vigente.
    const vencido = await api
      .post('/api/maintenance')
      .set(bearer(mechanicToken))
      .send({
        vehiculoId: vehicleId,
        tipoServicio: 'Revisión de frenos',
        kilometrajeObjetivo: 15000,
      });
    expect(vencido.status).toBe(201);
    expect(vencido.body.estado).toBe('VENCIDO');

    const filtro = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&estado=vencido`)
      .set(bearer(mechanicToken));
    expect(filtro.status).toBe(200);
    expect(filtro.body.elementos).toHaveLength(1);
    expect(filtro.body.elementos[0].tipoServicio).toBe('Revisión de frenos');

    const filtroNormal = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}&estado=normal`)
      .set(bearer(mechanicToken));
    expect(filtroNormal.status).toBe(200);
    expect(filtroNormal.body.elementos).toHaveLength(1);
    expect(filtroNormal.body.elementos[0].tipoServicio).toBe('Cambio de aceite y filtro');
  });

  test('realizar con kilometraje menor al vigente se rechaza sin corrección (400)', async () => {
    const listado = await api
      .get(`/api/maintenance?vehiculoId=${vehicleId}`)
      .set(bearer(mechanicToken));
    const id = listado.body.elementos.find(
      (item) => item.tipoServicio === 'Cambio de aceite y filtro',
    ).id;

    const response = await api
      .post(`/api/maintenance/${id}/realizar`)
      .set(bearer(mechanicToken))
      .send({ kilometrajeServicio: 20500 });

    expect(response.status).toBe(400);
    expect(response.body.error.codigo).toBe('KILOMETRAJE_INVALIDO');
  });
});
