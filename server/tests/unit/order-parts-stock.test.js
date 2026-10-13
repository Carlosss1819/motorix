// Pruebas unitarias de las reglas puras de stock de las refacciones usadas en
// una orden (US7, Sprint 3): cálculo del `stock_after` y rechazo de una
// cantidad menor o igual a 0 (RN-8, FR-025, R-08).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import {
  evaluateQuantity,
  computeStockAfter,
  evaluateStock,
} from '../../utils/order-parts-stock.js';

describe('reglas puras de stock (US7)', () => {
  test('la cantidad debe ser un entero mayor o igual a 1', () => {
    expect(evaluateQuantity(1).valida).toBe(true);
    expect(evaluateQuantity(12).valida).toBe(true);

    for (const invalida of [0, -1, 2.5, NaN, null, undefined, '3']) {
      const resultado = evaluateQuantity(invalida);
      expect(resultado.valida).toBe(false);
      expect(resultado.httpStatus).toBe(400);
      expect(resultado.codigo).toBe('CANTIDAD_INVALIDA');
      expect(resultado.mensaje).toContain('entero mayor o igual a 1');
    }
  });

  test('el stock resultante se calcula restando la cantidad usada', () => {
    expect(computeStockAfter(5, 2)).toBe(3);
    expect(computeStockAfter(1, 1)).toBe(0);
    expect(computeStockAfter(0, 3)).toBe(-3);
  });

  test('un stock exacto es suficiente y nunca queda negativo (RN-8)', () => {
    const justa = evaluateStock(5, 5);
    expect(justa.suficiente).toBe(true);
    expect(justa.stockAfter).toBe(0);

    const holgada = evaluateStock(5, 2);
    expect(holgada.suficiente).toBe(true);
    expect(holgada.stockAfter).toBe(3);
  });

  test('sin stock suficiente responde con el 409 STOCK_INSUFICIENTE', () => {
    for (const [stockActual, cantidad] of [
      [0, 1],
      [3, 4],
      [5, 6],
    ]) {
      const resultado = evaluateStock(stockActual, cantidad);
      expect(resultado.suficiente).toBe(false);
      expect(resultado.httpStatus).toBe(409);
      expect(resultado.codigo).toBe('STOCK_INSUFICIENTE');
      expect(resultado.mensaje).toContain(`${stockActual}`);
      expect(resultado.mensaje).toContain(`${cantidad}`);
      expect(resultado.stockAfter).toBeLessThan(0);
    }
  });
});
