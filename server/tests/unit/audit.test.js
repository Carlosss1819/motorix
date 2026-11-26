// Pruebas unitarias de la bitácora (Sprint 7, US10, FR-023 y FR-025).
import { jest } from '@jest/globals';
import {
  sanitizeDetail,
  record,
  setAuditWriterForTests,
  AUDIT_ACTIONS,
} from '../../services/audit.service.js';

describe('bitácora: detalle y tolerancia a fallos', () => {
  afterEach(() => setAuditWriterForTests(null));

  test('test_recorta_el_detalle_a_255_caracteres', () => {
    const detalle = sanitizeDetail('x'.repeat(400));
    expect(detalle.length).toBe(255);
  });

  test('test_detalle_vacio_o_nulo_se_guarda_como_null', () => {
    expect(sanitizeDetail('   ')).toBeNull();
    expect(sanitizeDetail(null)).toBeNull();
  });

  test('test_detalle_multilinea_queda_en_una_linea', () => {
    expect(sanitizeDetail('a\n  b\tc')).toBe('a b c');
  });

  test('test_record_no_lanza_si_falla_la_insercion', async () => {
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    setAuditWriterForTests(async () => {
      throw new Error('base caída');
    });
    await expect(record({ action: 'LOGIN_FALLIDO' })).resolves.toBeUndefined();
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  test('test_record_envia_el_detalle_saneado', async () => {
    const escritas = [];
    setAuditWriterForTests(async (entrada) => escritas.push(entrada));
    await record({ userId: 1, action: 'CONFIG_ACTUALIZADA', detail: ' claves:  shop.name ' });
    expect(escritas).toEqual([
      {
        userId: 1,
        action: 'CONFIG_ACTUALIZADA',
        entityType: null,
        entityId: null,
        detail: 'claves: shop.name',
      },
    ]);
  });

  test('test_la_lista_de_acciones_incluye_las_del_contrato', () => {
    for (const accion of ['LOGIN_FALLIDO', 'PAGO_ANULADO', 'PAGO_CANCELADO', 'TERMINOS_ACEPTADOS']) {
      expect(AUDIT_ACTIONS).toContain(accion);
    }
  });
});
