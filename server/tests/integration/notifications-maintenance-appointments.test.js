// Avisos de mantenimiento y de citas de hoy (Sprint 6, US2, FR-003, FR-005,
// FR-007, FR-008, R-03). Reloj fijo a las 12:00 (M3).
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import {
  fijarReloj,
  liberarReloj,
  fecha,
  crearContextoAvisos,
  avisosDe,
  avisoPorClave,
} from '../helpers/notifications-fixtures.js';
import { shouldMarkExpiredAppointments } from '../../services/notification.service.js';

let ctx;
const ids = {};

beforeAll(async () => {
  await prepareTestDatabase();
  fijarReloj();
  ctx = await crearContextoAvisos('Avisos US2');
  ids.vehiculoDoble = await ctx.otroVehiculo(5000);

  ids.proximo = await ctx.mantenimiento({ fechaObjetivo: fecha(10) });
  ids.vencido = await ctx.mantenimiento({ fechaObjetivo: fecha(-5) });
  ids.normal = await ctx.mantenimiento({ fechaObjetivo: fecha(100) });
  ids.sinObjetivo = await ctx.mantenimiento();
  ids.proximoPorKm = await ctx.mantenimiento({ kmObjetivo: 1200 });
  ids.doble = await ctx.mantenimiento({
    vehiculoId: ids.vehiculoDoble,
    fechaObjetivo: fecha(-2),
    kmObjetivo: 4000,
  });

  ids.citaProgramada = await ctx.cita({ hora: '18:00:00' });
  ids.citaRecibida = await ctx.cita({ hora: '09:00:00', estado: 'RECIBIDA' });
  ids.citaCancelada = await ctx.cita({ hora: '15:00:00', estado: 'CANCELADA' });
  ids.citaNoPresentada = await ctx.cita({ hora: '16:00:00', estado: 'NO_PRESENTADA' });
  ids.citaManana = await ctx.cita({ dia: 1, hora: '10:00:00' });
  ids.citaVencida = await ctx.cita({ hora: '10:00:00' });
});

afterAll(() => liberarReloj());

describe('mantenimientos (FR-003)', () => {
  test('proximo_y_vencido_generan_aviso_con_la_clave_y_el_objetivo', async () => {
    const { avisos } = await avisosDe(ctx.tokens.recepcion);
    const proximo = avisoPorClave(avisos, `MANT_PROXIMO:${ids.proximo}:${fecha(10)}|-`);
    const vencido = avisoPorClave(avisos, `MANT_VENCIDO:${ids.vencido}:${fecha(-5)}|-`);
    expect(proximo).toMatchObject({
      tipo: 'MANT_PROXIMO',
      fechaReferencia: fecha(10),
      destino: { pantalla: 'VEHICULO', id: ctx.vehiculoId },
    });
    expect(vencido).toMatchObject({ tipo: 'MANT_VENCIDO', fechaReferencia: fecha(-5) });
    expect(proximo.descripcion).toContain('Servicio Avisos US2');
  });

  test('normal_y_sin_objetivos_no_generan_aviso', async () => {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    const claves = avisos.map((a) => a.clave);
    expect(claves.some((c) => c.includes(`:${ids.normal}:`) && c.startsWith('MANT_'))).toBe(false);
    expect(claves.some((c) => c.includes(`:${ids.sinObjetivo}:`) && c.startsWith('MANT_'))).toBe(
      false,
    );
  });

  test('solo_por_kilometraje_usa_la_fecha_del_calculo_como_referencia', async () => {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    const aviso = avisoPorClave(avisos, `MANT_PROXIMO:${ids.proximoPorKm}:-|1200`);
    expect(aviso).toMatchObject({ fechaReferencia: fecha(0) });
  });

  test('con_fecha_y_kilometraje_cumplidos_hay_un_solo_aviso_vencido', async () => {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    const delDoble = avisos.filter(
      (a) => a.tipo.startsWith('MANT_') && a.clave.split(':')[1] === String(ids.doble),
    );
    expect(delDoble).toHaveLength(1);
    expect(delDoble[0].tipo).toBe('MANT_VENCIDO');
  });

  test('coincide_con_la_lista_de_mantenimientos_para_el_mismo_vehiculo_FR_008', async () => {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    for (const estado of ['PROXIMO', 'VENCIDO']) {
      const lista = await api
        .get(`/api/maintenance?vehiculoId=${ctx.vehiculoId}&estado=${estado}&porPagina=50`)
        .set(bearer(ctx.tokens.admin));
      expect(lista.status).toBe(200);
      const delCentro = avisos.filter(
        (a) => a.tipo === `MANT_${estado}` && a.destino.id === ctx.vehiculoId,
      );
      expect(delCentro.map((a) => Number(a.clave.split(':')[1])).sort()).toEqual(
        lista.body.elementos.map((m) => m.id).sort(),
      );
    }
  });
});

describe('citas de hoy (FR-005)', () => {
  test('programada_y_recibida_de_hoy_generan_aviso_con_fecha_y_hora', async () => {
    const { avisos } = await avisosDe(ctx.tokens.recepcion);
    const programada = avisoPorClave(avisos, `CITA_HOY:${ids.citaProgramada}:${fecha(0)}`);
    const recibida = avisoPorClave(avisos, `CITA_HOY:${ids.citaRecibida}:${fecha(0)}`);
    expect(programada).toMatchObject({
      tipo: 'CITA_HOY',
      fechaReferencia: `${fecha(0)}T18:00`,
      destino: { pantalla: 'CITAS', id: ids.citaProgramada, fecha: fecha(0) },
    });
    expect(recibida).toMatchObject({ fechaReferencia: `${fecha(0)}T09:00` });
  });

  test('cancelada_no_presentada_y_de_otro_dia_no_generan_aviso', async () => {
    const { avisos } = await avisosDe(ctx.tokens.admin);
    const claves = avisos.map((a) => a.clave);
    for (const id of [ids.citaCancelada, ids.citaNoPresentada, ids.citaManana]) {
      expect(claves.some((c) => c.startsWith(`CITA_HOY:${id}:`))).toBe(false);
    }
  });

  test('una_programada_de_hoy_con_la_hora_pasada_queda_no_presentada_R_03', async () => {
    const { avisos } = await avisosDe(ctx.tokens.recepcion);
    expect(avisos.some((a) => a.clave.startsWith(`CITA_HOY:${ids.citaVencida}:`))).toBe(false);
    const [cita] = await sql('SELECT status FROM appointments WHERE id = ?', [ids.citaVencida]);
    expect(cita.status).toBe('NO_PRESENTADA');
  });

  test('el_total_de_citas_de_hoy_coincide_con_el_bloque_del_panel_FR_008', async () => {
    // Otras suites del sprint pueden crear citas de hoy en paralelo: se repite
    // la comparación hasta 3 veces para que un alta concurrente entre las dos
    // consultas no cuente como diferencia. El panel se consulta después del
    // centro, que ya marcó las citas vencidas (R-03).
    let iguales = false;
    for (let intento = 0; intento < 3 && !iguales; intento += 1) {
      const { avisos } = await avisosDe(ctx.tokens.admin);
      const panel = await api
        .get(`/api/dashboard?fecha=${fecha(0)}`)
        .set(bearer(ctx.tokens.admin));
      iguales = avisos.filter((a) => a.tipo === 'CITA_HOY').length === panel.body.citas.hoy;
    }
    expect(iguales).toBe(true);
  });

  test('la_marca_de_citas_vencidas_solo_corre_para_roles_con_avisos_de_cita_M2', () => {
    expect(shouldMarkExpiredAppointments('ADMIN')).toBe(true);
    expect(shouldMarkExpiredAppointments('RECEPTIONIST')).toBe(true);
    expect(shouldMarkExpiredAppointments('MECHANIC')).toBe(false);
  });
});

describe('permisos', () => {
  test('el_mecanico_no_recibe_avisos_de_mantenimiento_ni_de_citas', async () => {
    const { avisos } = await avisosDe(ctx.tokens.mecanico);
    expect(avisos.some((a) => a.tipo.startsWith('MANT_') || a.tipo === 'CITA_HOY')).toBe(false);
  });
});
