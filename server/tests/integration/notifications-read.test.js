// Lectura de avisos por usuario (Sprint 6, US6, FR-014, FR-015, FR-030,
// SC-004): la clave es tipo + objeto + estado; lo que lee un usuario no
// cambia a los demás; claves ajenas o inexistentes responden 204 sin guardar.
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  avisosDe,
  avisoPorClave,
  idDeUsuario,
} from '../helpers/notifications-fixtures.js';

let ctx;
let tokenRecepcionB;
let recepcionBId;

async function leer(token, clave) {
  return api.post('/api/notifications/read').set(bearer(token)).send({ clave });
}

async function lecturasDe(userId, clave) {
  const [fila] = await sql(
    'SELECT COUNT(*) AS n FROM notification_reads WHERE user_id = ? AND notice_key = ?',
    [userId, clave],
  );
  return Number(fila.n);
}

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Avisos US6');
  // Recepcionista propia de la suite: su contador no cambia por otras suites.
  const usuario = `recb_${ctx.suffix}`.slice(0, 40);
  const alta = await api
    .post('/api/users')
    .set(bearer(ctx.tokens.admin))
    .send({ username: usuario, email: `${usuario}@motorix.local`, rol: 'RECEPTIONIST', contrasena: 'RecepcionB2026!' });
  if (alta.status !== 201) throw new Error(`Usuario: ${JSON.stringify(alta.body)}`);
  recepcionBId = alta.body.id;
  tokenRecepcionB = await loginAs(usuario, 'RecepcionB2026!');
});

afterAll(() => liberarReloj());

test('marcar_como_leido_baja_el_contador_en_1_solo_para_ese_usuario_SC_004', async () => {
  const id = await ctx.mantenimiento({ fechaObjetivo: fecha(-1) });
  const clave = `MANT_VENCIDO:${id}:${fecha(-1)}|-`;
  const antesB = await avisosDe(tokenRecepcionB);
  const antesAdmin = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(antesB.avisos, clave).leido).toBe(false);

  const r = await leer(tokenRecepcionB, clave);
  expect(r.status).toBe(204);

  const despuesB = await avisosDe(tokenRecepcionB);
  expect(avisoPorClave(despuesB.avisos, clave).leido).toBe(true);
  // Otras suites crean y cambian avisos al mismo tiempo, así que el contador
  // se compara sobre los avisos presentes antes y después: entre ellos, solo
  // este usuario puede cambiar su `leido`, y debe bajar exactamente 1.
  const clavesDespues = new Set(despuesB.avisos.map((a) => a.clave));
  const comunesAntes = antesB.avisos.filter((a) => clavesDespues.has(a.clave));
  const clavesComunes = new Set(comunesAntes.map((a) => a.clave));
  const comunesDespues = despuesB.avisos.filter((a) => clavesComunes.has(a.clave));
  const noLeidos = (lista) => lista.filter((a) => !a.leido).length;
  expect(noLeidos(comunesDespues)).toBe(noLeidos(comunesAntes) - 1);
  // El contador del servidor es coherente con la lista que devuelve.
  expect(despuesB.cuerpo.noLeidos).toBe(noLeidos(despuesB.avisos));
  // El aviso leído sigue visible mientras su condición se cumpla (FR-014).
  expect(avisoPorClave(despuesB.avisos, clave)).toBeDefined();

  const despuesAdmin = await avisosDe(ctx.tokens.admin);
  expect(avisoPorClave(despuesAdmin.avisos, clave).leido).toBe(false);
  expect(antesAdmin).toBeDefined();
});

test('repetir_la_lectura_no_duplica_filas', async () => {
  const id = await ctx.mantenimiento({ fechaObjetivo: fecha(-2) });
  const clave = `MANT_VENCIDO:${id}:${fecha(-2)}|-`;
  await leer(tokenRecepcionB, clave);
  await leer(tokenRecepcionB, clave);
  expect(await lecturasDe(recepcionBId, clave)).toBe(1);
});

test('una_clave_inexistente_o_de_otro_rol_responde_204_y_no_guarda_FR_030', async () => {
  const refaccion = await ctx.refaccion({ existencia: 0, minimo: 2 });
  const deStock = `STOCK_AGOTADO:${refaccion}`;
  const r1 = await leer(tokenRecepcionB, deStock);
  expect(r1.status).toBe(204);
  expect(await lecturasDe(recepcionBId, deStock)).toBe(0);

  const inexistente = 'ORDEN_DETENIDA:999999999:RECIBIDO';
  const r2 = await leer(tokenRecepcionB, inexistente);
  expect(r2.status).toBe(204);
  expect(await lecturasDe(recepcionBId, inexistente)).toBe(0);
});

test('si_el_mantenimiento_empeora_el_aviso_nuevo_aparece_no_leido', async () => {
  const id = await ctx.mantenimiento({ fechaObjetivo: fecha(10) });
  const proximo = `MANT_PROXIMO:${id}:${fecha(10)}|-`;
  await leer(tokenRecepcionB, proximo);
  expect(avisoPorClave((await avisosDe(tokenRecepcionB)).avisos, proximo).leido).toBe(true);

  // Se mueve el objetivo al pasado: ahora está vencido (otro objetivo y otro estado).
  await sql('UPDATE maintenance SET target_date = ? WHERE id = ?', [fecha(-1), id]);
  const { avisos } = await avisosDe(tokenRecepcionB);
  expect(avisoPorClave(avisos, `MANT_VENCIDO:${id}:${fecha(-1)}|-`).leido).toBe(false);
  expect(avisoPorClave(avisos, proximo)).toBeUndefined();
});

test('con_el_mismo_objetivo_de_proximo_a_vencido_por_kilometraje_tambien_es_nuevo', async () => {
  const vehiculo = await ctx.otroVehiculo(1000);
  const id = await ctx.mantenimiento({ vehiculoId: vehiculo, kmObjetivo: 1300 });
  const proximo = `MANT_PROXIMO:${id}:-|1300`;
  await leer(tokenRecepcionB, proximo);
  await sql('UPDATE vehicles SET current_mileage = 1400 WHERE id = ?', [vehiculo]);
  const { avisos } = await avisosDe(tokenRecepcionB);
  expect(avisoPorClave(avisos, `MANT_VENCIDO:${id}:-|1300`).leido).toBe(false);
});

test('una_cita_reprogramada_a_hoy_es_un_aviso_nuevo', async () => {
  const id = await ctx.cita({ hora: '19:00:00' });
  const hoy = `CITA_HOY:${id}:${fecha(0)}`;
  await leer(tokenRecepcionB, hoy);
  expect(avisoPorClave((await avisosDe(tokenRecepcionB)).avisos, hoy).leido).toBe(true);
  // Se mueve a otro día y luego vuelve: la clave incluye la fecha, así que una
  // cita reprogramada desde otro día cuenta como aviso nuevo; aquí se simula
  // con una cita distinta reprogramada desde mañana.
  const otra = await ctx.cita({ dia: 1, hora: '19:30:00' });
  await sql('UPDATE appointments SET appointment_date = ? WHERE id = ?', [fecha(0), otra]);
  const { avisos } = await avisosDe(tokenRecepcionB);
  expect(avisoPorClave(avisos, `CITA_HOY:${otra}:${fecha(0)}`).leido).toBe(false);
});

test('el_admin_puede_leer_avisos_de_stock_y_se_guarda', async () => {
  const refaccion = await ctx.refaccion({ existencia: 1, minimo: 3 });
  const clave = `STOCK_BAJO:${refaccion}`;
  const r = await leer(ctx.tokens.admin, clave);
  expect(r.status).toBe(204);
  expect(await lecturasDe(await idDeUsuario('admin'), clave)).toBe(1);
});
