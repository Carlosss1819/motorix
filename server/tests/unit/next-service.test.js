// Pruebas unitarias de la propuesta del próximo servicio (Sprint 7, FR-011/FR-012).
import { proposeNextService } from '../../utils/next-service.js';

describe('proposeNextService', () => {
  test('test_con_dias_y_km_propone_fecha_y_kilometraje', () => {
    expect(proposeNextService({ intervaloDias: 180, intervaloKm: 5000 }, '2026-11-26', 10000)).toEqual({
      fecha: '2027-05-25',
      kilometraje: 15000,
    });
  });

  test('test_solo_con_dias_propone_solo_la_fecha', () => {
    expect(proposeNextService({ intervaloDias: 365, intervaloKm: null }, '2026-11-26', 10000)).toEqual({
      fecha: '2027-11-26',
      kilometraje: null,
    });
  });

  test('test_solo_con_km_propone_solo_el_kilometraje', () => {
    expect(proposeNextService({ intervaloDias: null, intervaloKm: 10000 }, '2026-11-26', 25500)).toEqual({
      fecha: null,
      kilometraje: 35500,
    });
  });

  test('test_cruza_el_fin_de_anio_y_los_bisiestos', () => {
    expect(proposeNextService({ intervaloDias: 2 }, '2027-12-31', null).fecha).toBe('2028-01-02');
    expect(proposeNextService({ intervaloDias: 1 }, '2028-02-28', null).fecha).toBe('2028-02-29');
  });
});
