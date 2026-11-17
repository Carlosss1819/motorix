// Prueba unitaria de las claves de aviso y de hecho (Sprint 6, R-05, FR-015,
// FR-021): tipo + objeto + estado; el objetivo vigente distingue los ciclos
// de un mantenimiento.
import {
  maintenanceTarget,
  noticeKey,
  factKey,
  parseNoticeKey,
  parseFactKey,
  NOTICE_KEY_MAX_LENGTH,
} from '../../utils/notice-keys.js';

describe('objetivo del mantenimiento', () => {
  test('combina_fecha_y_kilometraje_objetivo', () => {
    expect(maintenanceTarget({ targetDate: '2026-12-01', targetMileage: 45000 })).toBe(
      '2026-12-01|45000',
    );
  });

  test('usa_guion_cuando_falta_uno_de_los_objetivos', () => {
    expect(maintenanceTarget({ targetDate: null, targetMileage: 45000 })).toBe('-|45000');
    expect(maintenanceTarget({ targetDate: '2026-12-01', targetMileage: null })).toBe(
      '2026-12-01|-',
    );
  });
});

describe('claves de aviso', () => {
  test('arma_las_claves_de_cada_tipo', () => {
    expect(noticeKey.maintenance('PROXIMO', 7, '2026-12-01|-')).toBe('MANT_PROXIMO:7:2026-12-01|-');
    expect(noticeKey.maintenance('VENCIDO', 7, '-|45000')).toBe('MANT_VENCIDO:7:-|45000');
    expect(noticeKey.stock(12, false)).toBe('STOCK_BAJO:12');
    expect(noticeKey.stock(12, true)).toBe('STOCK_AGOTADO:12');
    expect(noticeKey.appointmentToday(5, '2026-11-16')).toBe('CITA_HOY:5:2026-11-16');
    expect(noticeKey.stalledOrder(9, 'EN_REPARACION')).toBe('ORDEN_DETENIDA:9:EN_REPARACION');
  });

  test('si_el_aviso_empeora_la_clave_cambia', () => {
    const objetivo = '2026-12-01|-';
    expect(noticeKey.maintenance('PROXIMO', 7, objetivo)).not.toBe(
      noticeKey.maintenance('VENCIDO', 7, objetivo),
    );
    expect(noticeKey.stock(3, false)).not.toBe(noticeKey.stock(3, true));
  });

  test('ninguna_clave_supera_el_largo_maximo', () => {
    const larga = noticeKey.maintenance('VENCIDO', 2147483647, '2026-12-01|2147483647');
    expect(larga.length).toBeLessThanOrEqual(NOTICE_KEY_MAX_LENGTH);
    expect(NOTICE_KEY_MAX_LENGTH).toBe(120);
  });

  test('parsea_claves_validas_y_rechaza_formatos_invalidos', () => {
    expect(parseNoticeKey('MANT_VENCIDO:7:2026-12-01|45000')).toEqual({
      type: 'MANT_VENCIDO',
      id: 7,
    });
    expect(parseNoticeKey('STOCK_AGOTADO:12')).toEqual({ type: 'STOCK_AGOTADO', id: 12 });
    expect(parseNoticeKey('CITA_HOY:5:2026-11-16')).toEqual({ type: 'CITA_HOY', id: 5 });
    expect(parseNoticeKey('ORDEN_DETENIDA:9:DIAGNOSTICO')).toEqual({
      type: 'ORDEN_DETENIDA',
      id: 9,
    });
    for (const invalida of [
      '',
      'MANT_VENCIDO:7',
      'STOCK_BAJO:abc',
      'ORDEN_DETENIDA:9:TERMINADO',
      'CITA_HOY:5:16-11-2026',
      'OTRO:1',
    ]) {
      expect(parseNoticeKey(invalida)).toBeNull();
    }
  });
});

describe('claves de hecho (clientes por avisar)', () => {
  test('arma_las_claves_de_orden_cita_y_mantenimiento', () => {
    expect(factKey.order(60003)).toBe('ORDEN:60003');
    expect(factKey.appointment(41)).toBe('CITA:41');
    expect(factKey.maintenance(7, '2026-12-01|-')).toBe('MANT:7:2026-12-01|-');
  });

  test('un_ciclo_nuevo_del_mantenimiento_es_un_hecho_nuevo', () => {
    expect(factKey.maintenance(7, '2026-12-01|-')).not.toBe(factKey.maintenance(7, '2027-06-01|-'));
  });

  test('parsea_hechos_validos_y_rechaza_los_invalidos', () => {
    expect(parseFactKey('ORDEN:60003')).toEqual({ kind: 'ORDEN', id: 60003 });
    expect(parseFactKey('MANT:7:-|45000')).toEqual({ kind: 'MANT', id: 7 });
    expect(parseFactKey('CITA:x')).toBeNull();
    expect(parseFactKey('MANT:7')).toBeNull();
  });
});
