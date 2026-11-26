// Contrato (Sprint 7, US3, FR-010): tipo de servicio opcional en las líneas de
// la orden. Fuente: specs/007-reportes-configuracion/contracts/tickets-y-ordenes.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto } from '../helpers/fixtures.js';

let ctx;
let ordenId;
let tipoInactivoId;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Tipo en orden S7');
  ordenId = await ctx.crearOrden();
  const inactivo = await api
    .post('/api/service-types')
    .set(bearer(ctx.tokens.admin))
    .send({ nombre: `Inactivo orden ${ctx.suffix}`, intervaloDias: 30 });
  tipoInactivoId = inactivo.body.id;
  await api.post(`/api/service-types/${tipoInactivoId}/desactivar`).set(bearer(ctx.tokens.admin));
});

function agregar(body) {
  return api
    .post(`/api/service-orders/${ordenId}/servicios`)
    .set(bearer(ctx.tokens.admin))
    .send({ duracionMinutos: 30, precio: 200, ...body });
}

test('test_agrega_un_servicio_con_tipo_y_el_detalle_lo_devuelve', async () => {
  const response = await agregar({ descripcion: 'Cambio de aceite sintético', tipoServicioId: 70001 });
  expect(response.status).toBe(201);
  expect(response.body.servicio).toMatchObject({ tipoServicioId: 70001, tipoServicio: 'Cambio de aceite' });

  const detalle = await api.get(`/api/service-orders/${ordenId}`).set(bearer(ctx.tokens.admin));
  const linea = detalle.body.servicios.find((s) => s.id === response.body.servicio.id);
  expect(linea).toMatchObject({ tipoServicioId: 70001, tipoServicio: 'Cambio de aceite' });
});

test('test_una_linea_sin_tipo_sigue_funcionando_como_antes', async () => {
  const response = await agregar({ descripcion: 'Revisión general' });
  expect(response.status).toBe(201);
  expect(response.body.servicio).not.toHaveProperty('tipoServicioId');
});

test.each([
  ['inactivo', () => tipoInactivoId],
  ['inexistente', () => 999999],
])('test_un_tipo_%s_responde_400_tipo_servicio_invalido', async (_caso, id) => {
  const response = await agregar({ descripcion: 'Con tipo inválido', tipoServicioId: id() });
  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('TIPO_SERVICIO_INVALIDO');
});

test('test_un_tipo_con_texto_responde_400_de_validacion', async () => {
  const response = await agregar({ descripcion: 'Con tipo de texto', tipoServicioId: 'abc' });
  expect(response.status).toBe(400);
  expect(response.body.error.codigo).toBe('VALIDACION');
});
