// Pruebas unitarias de la conversión monetaria (Sprint 5, R-06, D-08):
// los importes DECIMAL(10,2) que entrega mysql2 como cadena se convierten a
// centavos enteros sin pasar por flotante, y de centavos a número de dos
// decimales solo para responder.
// Fuente de verdad: specs/005-precios-refacciones-cobro/research.md (R-06).
import { toCents, fromCents, centsToDecimalString } from '../../utils/money.js';

describe('toCents — de DECIMAL en cadena a centavos enteros', () => {
  test('convierte_320_00_a_32000_centavos', () => {
    expect(toCents('320.00')).toBe(32000);
  });

  test('convierte_0_10_y_999999_99_sin_error_de_flotante', () => {
    expect(toCents('0.10')).toBe(10);
    expect(toCents('999999.99')).toBe(99999999);
    expect(toCents('33.33')).toBe(3333);
    expect(toCents('0.07')).toBe(7);
  });

  test('acepta_cadenas_sin_decimales_o_con_un_decimal', () => {
    expect(toCents('15')).toBe(1500);
    expect(toCents('10.5')).toBe(1050);
  });

  test('null_y_undefined_devuelven_null', () => {
    expect(toCents(null)).toBeNull();
    expect(toCents(undefined)).toBeNull();
  });

  test('acepta_numeros_con_hasta_dos_decimales', () => {
    expect(toCents(320)).toBe(32000);
    expect(toCents(180.33)).toBe(18033);
    expect(toCents(0.1)).toBe(10);
  });

  test('rechaza_textos_que_no_son_importes', () => {
    expect(() => toCents('abc')).toThrow();
  });
});

describe('fromCents — de centavos a número de dos decimales', () => {
  test('convierte_32000_a_320', () => {
    expect(fromCents(32000)).toBe(320);
  });

  test('conserva_los_centavos', () => {
    expect(fromCents(9999)).toBe(99.99);
    expect(fromCents(10)).toBe(0.1);
    expect(fromCents(0)).toBe(0);
  });

  test('null_devuelve_null', () => {
    expect(fromCents(null)).toBeNull();
  });
});

describe('centsToDecimalString — para guardar en DECIMAL(10,2)', () => {
  test('formatea_con_dos_decimales', () => {
    expect(centsToDecimalString(32000)).toBe('320.00');
    expect(centsToDecimalString(7)).toBe('0.07');
    expect(centsToDecimalString(99999999)).toBe('999999.99');
  });
});
