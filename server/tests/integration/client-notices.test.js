// Clientes por avisar (Sprint 6, US7, FR-019 a FR-023, FR-029, SC-005):
// cuatro motivos, una sola vez por hecho, hecho nuevo vuelve a aparecer,
// marcación concurrente con un solo registro y orden de la lista.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  idDeUsuario,
} from '../helpers/notifications-fixtures.js';

let ctx;
const ids = {};

async function lista(token = ctx.tokens.recepcion) {
  const r = await api.get('/api/client-notices').set(bearer(token));
  if (r.status !== 200) throw new Error(`Lista: ${r.status}`);
  return r.body.elementos;
}

const propias = (elementos) => elementos.filter((e) => e.cliente.id === ctx.clienteId);

async function marcar(clave, token = ctx.tokens.recepcion) {
  return api.post('/api/client-notices').set(bearer(token)).send({ clave });
}

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Clientes US7');
  ids.ordenLista = await ctx.ordenConEstado({ estado: 'TERMINADO', horasSinCambio: 5 });
  ids.ordenEnTaller = await ctx.ordenConEstado({ estado: 'EN_REPARACION', horasSinCambio: 5 });
  ids.citaManana = await ctx.cita({ dia: 1, hora: '10:00:00' });
  ids.citaMananaCancelada = await ctx.cita({ dia: 1, hora: '11:00:00', estado: 'CANCELADA' });
  ids.citaHoy = await ctx.cita({ hora: '18:00:00' });
  ids.mantProximo = await ctx.mantenimiento({ fechaObjetivo: fecha(5) });
  ids.mantVencido = await ctx.mantenimiento({ fechaObjetivo: fecha(-4) });
});

afterAll(() => liberarReloj());

test('aparecen_los_cuatro_motivos_con_cliente_telefono_y_vehiculo', async () => {
  const elementos = propias(await lista());
  const porClave = Object.fromEntries(elementos.map((e) => [e.clave, e]));
  expect(porClave[`ORDEN:${ids.ordenLista}`]).toMatchObject({ motivo: 'VEHICULO_LISTO' });
  expect(porClave[`CITA:${ids.citaManana}`]).toMatchObject({
    motivo: 'CITA_MANANA',
    destino: { pantalla: 'CITAS', id: ids.citaManana, fecha: fecha(1) },
  });
  expect(porClave[`MANT:${ids.mantProximo}:${fecha(5)}|-`]).toMatchObject({ motivo: 'MANT_PROXIMO' });
  expect(porClave[`MANT:${ids.mantVencido}:${fecha(-4)}|-`]).toMatchObject({ motivo: 'MANT_VENCIDO' });
  const cualquiera = porClave[`ORDEN:${ids.ordenLista}`];
  expect(cualquiera.cliente.telefono).toEqual(expect.any(String));
  expect(cualquiera.vehiculo).toMatchObject({ id: ctx.vehiculoId, descripcion: 'Nissan Versa 2020' });
});

test('no_aparecen_ordenes_en_taller_ni_citas_canceladas_ni_de_hoy', async () => {
  const claves = propias(await lista()).map((e) => e.clave);
  expect(claves).not.toContain(`ORDEN:${ids.ordenEnTaller}`);
  expect(claves).not.toContain(`CITA:${ids.citaMananaCancelada}`);
  expect(claves).not.toContain(`CITA:${ids.citaHoy}`);
});

test('la_lista_se_ordena_por_motivo_y_luego_por_fecha_FR_029', async () => {
  const motivos = propias(await lista()).map((e) => e.motivo);
  const orden = ['VEHICULO_LISTO', 'CITA_MANANA', 'MANT_VENCIDO', 'MANT_PROXIMO'];
  const posiciones = motivos.map((m) => orden.indexOf(m));
  expect(posiciones).toEqual([...posiciones].sort((a, b) => a - b));
  const todas = await lista();
  const fechasListo = todas.filter((e) => e.motivo === 'VEHICULO_LISTO').map((e) => e.fecha);
  expect(fechasListo).toEqual([...fechasListo].sort());
});

test('el_mecanico_no_accede_a_la_lista', async () => {
  const r = await api.get('/api/client-notices').set(bearer(ctx.tokens.mecanico));
  expect(r.status).toBe(403);
});

test('marcar_guarda_quien_y_cuando_y_saca_el_renglon', async () => {
  const clave = `ORDEN:${ids.ordenLista}`;
  const r = await marcar(clave);
  expect(r.status).toBe(201);
  const [fila] = await sql(
    'SELECT client_id, reason, notified_by, notified_at FROM client_notices WHERE fact_key = ?',
    [clave],
  );
  expect(fila).toMatchObject({
    client_id: ctx.clienteId,
    reason: 'VEHICULO_LISTO',
    notified_by: await idDeUsuario('recepcion'),
  });
  expect(fila.notified_at).toBeInstanceOf(Date);
  expect(propias(await lista()).map((e) => e.clave)).not.toContain(clave);
});

test('otra_orden_del_mismo_cliente_si_aparece', async () => {
  const otra = await ctx.ordenConEstado({ estado: 'TERMINADO', horasSinCambio: 1 });
  expect(propias(await lista()).map((e) => e.clave)).toContain(`ORDEN:${otra}`);
});

test('un_mantenimiento_avisado_como_proximo_no_reaparece_al_vencer', async () => {
  const id = await ctx.mantenimiento({ vehiculoId: await ctx.otroVehiculo(1000), kmObjetivo: 1200 });
  const clave = `MANT:${id}:-|1200`;
  expect((await marcar(clave)).status).toBe(201);
  await sql(
    'UPDATE vehicles v JOIN maintenance m ON m.vehicle_id = v.id SET v.current_mileage = 1500 WHERE m.id = ?',
    [id],
  );
  expect(propias(await lista()).map((e) => e.clave)).not.toContain(clave);
});

test('al_renovar_el_mantenimiento_el_ciclo_nuevo_reaparece', async () => {
  const clave = `MANT:${ids.mantVencido}:${fecha(-4)}|-`;
  expect((await marcar(clave)).status).toBe(201);
  expect(propias(await lista()).map((e) => e.clave)).not.toContain(clave);
  // Servicio realizado: el mismo registro con un objetivo nuevo (ya próximo).
  await sql('UPDATE maintenance SET target_date = ? WHERE id = ?', [fecha(20), ids.mantVencido]);
  const claves = propias(await lista()).map((e) => e.clave);
  expect(claves).toContain(`MANT:${ids.mantVencido}:${fecha(20)}|-`);
});

test('dos_marcaciones_simultaneas_dejan_un_registro_y_un_409_SC_005', async () => {
  const clave = `CITA:${ids.citaManana}`;
  const [a, b] = await Promise.all([marcar(clave), marcar(clave, ctx.tokens.admin)]);
  expect([a.status, b.status].sort()).toEqual([201, 409]);
  const [fila] = await sql('SELECT COUNT(*) AS n FROM client_notices WHERE fact_key = ?', [clave]);
  expect(Number(fila.n)).toBe(1);
});

test('la_lista_no_trae_importes', async () => {
  expect(JSON.stringify(await lista())).not.toMatch(/"(subtotal\w*|precio\w*|importe\w*|monto\w*)"\s*:/i);
});
