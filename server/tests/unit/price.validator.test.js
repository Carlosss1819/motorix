// Pruebas unitarias del validador de precios (Sprint 5, FR-003, FR-032, R-13):
// numérico, ≥ 0, máximo 2 decimales y ≤ 999,999.99, con mensajes en español
// que nombran el campo.
import { priceSchema, PRECIO_MAXIMO } from '../../validators/price.js';

const esquema = priceSchema('El precio de venta');

describe('priceSchema — valores aceptados', () => {
  test.each([0, 10.5, 999999.99, 33.33, 0.01])('acepta_%p', (valor) => {
    const result = esquema.safeParse(valor);
    expect(result.success).toBe(true);
    expect(result.data).toBe(valor);
  });

  test('el_tope_es_999999_99', () => {
    expect(PRECIO_MAXIMO).toBe(999999.99);
  });
});

describe('priceSchema — valores rechazados', () => {
  test('rechaza_negativos_nombrando_el_campo', () => {
    const result = esquema.safeParse(-1);
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toContain('El precio de venta');
    expect(result.error.issues[0].message).toContain('negativo');
  });

  test('rechaza_un_texto_no_numerico', () => {
    const result = esquema.safeParse('abc');
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toContain('El precio de venta');
  });

  test('rechaza_tres_decimales', () => {
    const result = esquema.safeParse(10.005);
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toContain('2 decimales');
  });

  test('rechaza_un_millon', () => {
    const result = esquema.safeParse(1000000);
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toContain('999,999.99');
  });
});
