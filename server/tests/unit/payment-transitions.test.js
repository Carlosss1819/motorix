// Pruebas unitarias de la máquina de estados del pago (Sprint 4, D7). Módulo
// puro al estilo de order-transitions.js: sin base de datos.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/data-model.md (D7).
import {
  PAYMENT_STATUSES as S,
  allowedPaymentTransitions,
  evaluatePaymentTransition,
} from '../../utils/payment-transitions.js';

const transicion = (fromStatus, toStatus) =>
  evaluatePaymentTransition({ fromStatus, toStatus });

describe('PAYMENT_TRANSITIONS — mapa D7', () => {
  test('PENDIENTE admite PAGADO, RECHAZADO y CANCELADO (confirmación manual)', () => {
    expect(allowedPaymentTransitions(S.PENDIENTE)).toEqual([
      S.PAGADO,
      S.RECHAZADO,
      S.CANCELADO,
    ]);
  });

  test('PAGADO solo admite ANULADO (corrección administrativa, FR-016)', () => {
    expect(allowedPaymentTransitions(S.PAGADO)).toEqual([S.ANULADO]);
  });

  test('RECHAZADO, CANCELADO y ANULADO son estados finales sin salidas', () => {
    expect(allowedPaymentTransitions(S.RECHAZADO)).toEqual([]);
    expect(allowedPaymentTransitions(S.CANCELADO)).toEqual([]);
    expect(allowedPaymentTransitions(S.ANULADO)).toEqual([]);
  });
});

describe('evaluatePaymentTransition — transiciones permitidas', () => {
  test('una confirmación manual PENDIENTE → PAGADO es válida', () => {
    expect(transicion(S.PENDIENTE, S.PAGADO)).toEqual({ permitida: true });
  });

  test('la anulación PAGADO → ANULADO es válida (FR-016)', () => {
    expect(transicion(S.PAGADO, S.ANULADO)).toEqual({ permitida: true });
  });
});

describe('evaluatePaymentTransition — rechazos (409 TRANSICION_INVALIDA)', () => {
  test('no se puede re-registrar un pago ya PAGADO hacia otro estado que no sea ANULADO', () => {
    const resultado = transicion(S.PAGADO, S.PENDIENTE);
    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
    expect(resultado.codigo).toBe('TRANSICION_INVALIDA');
    expect(resultado.mensaje).toContain('PAGADO');
    expect(resultado.mensaje).toContain(S.ANULADO);
  });

  test('un estado final no admite ningún cambio', () => {
    for (const actual of [S.RECHAZADO, S.CANCELADO, S.ANULADO]) {
      const resultado = transicion(actual, S.PAGADO);
      expect(resultado.permitida).toBe(false);
      expect(resultado.httpStatus).toBe(409);
      expect(resultado.codigo).toBe('TRANSICION_INVALIDA');
      expect(resultado.mensaje).toContain('definitivo');
    }
  });

  test('el mensaje del rechazo está en español', () => {
    expect(transicion(S.ANULADO, S.PAGADO).mensaje).toMatch(/es definitivo/);
  });
});
