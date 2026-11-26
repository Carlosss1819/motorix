// Pruebas unitarias del respaldo de la configuración (Sprint 7, FR-003, CA-3).
import { resolveSettings, SETTING_KEYS } from '../../utils/settings-defaults.js';

describe('resolveSettings', () => {
  test('test_sin_filas_guardadas_usa_los_valores_de_respaldo', () => {
    expect(resolveSettings({})).toEqual({
      taller: {
        nombre: 'Motorix',
        direccion: 'Av. Ejemplo 123, Col. Centro',
        telefono: '55-0000-0000',
      },
      mantenimiento: { antelacionDias: 30, antelacionKm: 500 },
    });
  });

  test('test_una_configuracion_a_medias_completa_lo_faltante_con_el_respaldo', () => {
    const resultado = resolveSettings({ [SETTING_KEYS.shopName]: 'Taller Prueba' });
    expect(resultado.taller.nombre).toBe('Taller Prueba');
    expect(resultado.taller.telefono).toBe('55-0000-0000');
    expect(resultado.mantenimiento.antelacionKm).toBe(500);
  });

  test('test_los_margenes_guardados_se_devuelven_como_enteros', () => {
    const resultado = resolveSettings({
      [SETTING_KEYS.advanceDays]: '15',
      [SETTING_KEYS.advanceKm]: '800',
    });
    expect(resultado.mantenimiento).toEqual({ antelacionDias: 15, antelacionKm: 800 });
  });

  test('test_un_margen_invalido_guardado_usa_el_respaldo', () => {
    const resultado = resolveSettings({ [SETTING_KEYS.advanceDays]: 'abc' });
    expect(resultado.mantenimiento.antelacionDias).toBe(30);
  });
});
