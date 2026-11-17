// Contrato de /api/client-notices (Sprint 6, contracts/client-notices.md).
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  crearContextoAvisos,
  CLAVES_DE_DINERO,
} from '../helpers/notifications-fixtures.js';

let ctx;
let ordenId;

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Contrato clientes');
  ordenId = await ctx.ordenConEstado({ estado: 'TERMINADO', horasSinCambio: 2 });
});

afterAll(() => liberarReloj());

test('sin_sesion_responde_401', async () => {
  expect((await api.get('/api/client-notices')).status).toBe(401);
  expect((await api.post('/api/client-notices').send({ clave: 'ORDEN:1' })).status).toBe(401);
});

test('el_mecanico_recibe_403_en_get_y_post', async () => {
  const g = await api.get('/api/client-notices').set(bearer(ctx.tokens.mecanico));
  const p = await api
    .post('/api/client-notices')
    .set(bearer(ctx.tokens.mecanico))
    .send({ clave: `ORDEN:${ordenId}` });
  for (const r of [g, p]) {
    expect(r.status).toBe(403);
    expect(r.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  }
});

test('GET_responde_la_forma_del_contrato_sin_importes', async () => {
  const r = await api.get('/api/client-notices').set(bearer(ctx.tokens.recepcion));
  expect(r.status).toBe(200);
  expect(Object.keys(r.body).sort()).toEqual(['elementos', 'total']);
  const nuestro = r.body.elementos.find((e) => e.clave === `ORDEN:${ordenId}`);
  expect(nuestro).toBeDefined();
  expect(Object.keys(nuestro).sort()).toEqual(
    ['clave', 'cliente', 'destino', 'fecha', 'motivo', 'motivoTexto', 'vehiculo'].sort(),
  );
  expect(Object.keys(nuestro.cliente).sort()).toEqual(['id', 'nombre', 'telefono']);
  expect(Object.keys(nuestro.vehiculo).sort()).toEqual(['descripcion', 'id', 'placas']);
  expect(nuestro).toMatchObject({
    motivo: 'VEHICULO_LISTO',
    motivoTexto: 'Vehículo listo',
    destino: { pantalla: 'ORDEN', id: ordenId },
  });
  expect(JSON.stringify(r.body.elementos)).not.toMatch(/"(subtotal\w*|precio\w*|importe\w*|monto\w*)"\s*:/i);
  expect(CLAVES_DE_DINERO).toBeDefined();
});

test('POST_valida_la_clave', async () => {
  for (const cuerpo of [{}, { clave: '' }, { clave: 'ORDEN:abc' }, { clave: 'X'.repeat(121) }]) {
    const r = await api.post('/api/client-notices').set(bearer(ctx.tokens.recepcion)).send(cuerpo);
    expect(r.status).toBe(400);
    expect(r.body.error.codigo).toBe('VALIDACION');
  }
});

test('POST_de_un_hecho_que_no_esta_en_la_lista_responde_404', async () => {
  const r = await api
    .post('/api/client-notices')
    .set(bearer(ctx.tokens.recepcion))
    .send({ clave: 'ORDEN:999999999' });
  expect(r.status).toBe(404);
  expect(r.body.error.codigo).toBe('HECHO_NO_VIGENTE');
});

test('POST_responde_201_y_un_segundo_intento_409', async () => {
  const r = await api
    .post('/api/client-notices')
    .set(bearer(ctx.tokens.recepcion))
    .send({ clave: `ORDEN:${ordenId}` });
  expect(r.status).toBe(201);
  expect(r.body).toMatchObject({
    clave: `ORDEN:${ordenId}`,
    motivo: 'VEHICULO_LISTO',
    clienteId: ctx.clienteId,
    avisadoPor: { nombre: 'recepcion' },
  });
  expect(r.body.avisadoEn).toEqual(expect.any(String));
  // H-S6-06: `avisadoEn` es la hora LOCAL guardada en MySQL (como el ejemplo
  // del contrato), no la hora UTC con formato local.
  const [guardado] = await sql(
    "SELECT DATE_FORMAT(notified_at, '%Y-%m-%dT%H:%i:%s') AS local FROM client_notices WHERE fact_key = ?",
    [`ORDEN:${ordenId}`],
  );
  expect(r.body.avisadoEn).toBe(guardado.local);

  const otra = await api
    .post('/api/client-notices')
    .set(bearer(ctx.tokens.admin))
    .send({ clave: `ORDEN:${ordenId}` });
  expect(otra.status).toBe(409);
  expect(otra.body.error.codigo).toBe('YA_AVISADO');
  const [fila] = await sql('SELECT COUNT(*) AS n FROM client_notices WHERE fact_key = ?', [
    `ORDEN:${ordenId}`,
  ]);
  expect(Number(fila.n)).toBe(1);
});
