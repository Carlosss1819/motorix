// Pruebas unitarias de la máquina de estados de la orden (US5): el mapa de
// transiciones R-02 y la matriz de permisos por rol R-03 / FR-022 (CA-8).
// Fuente de verdad: specs/002-citas-ordenes-servicio/contracts/service-orders.md
// (sección POST /api/service-orders/:id/estado).
import {
  ORDER_TRANSITIONS,
  allowedTransitions,
  evaluateTransition,
} from '../../utils/order-transitions.js';
import { ORDER_STATUSES as S } from '../../utils/status-constants.js';

// Evalúa como ADMIN, que siempre pasa el filtro de rol.
function comoAdmin(fromStatus, toStatus) {
  return evaluateTransition({
    fromStatus,
    toStatus,
    role: 'ADMIN',
    assignedMechanicId: 3,
    userId: 1,
  });
}

describe('mapa de transiciones R-02', () => {
  test('permite exactamente las transiciones del contrato', () => {
    expect(allowedTransitions(S.RECIBIDO)).toEqual([S.DIAGNOSTICO]);
    expect(allowedTransitions(S.DIAGNOSTICO)).toEqual([
      S.EN_REPARACION,
      S.ESPERANDO_REFACCION,
      S.TERMINADO,
    ]);
    expect(allowedTransitions(S.EN_REPARACION)).toEqual([
      S.ESPERANDO_REFACCION,
      S.TERMINADO,
    ]);
    expect(allowedTransitions(S.ESPERANDO_REFACCION)).toEqual([
      S.DIAGNOSTICO,
      S.EN_REPARACION,
      S.TERMINADO,
    ]);
    expect(allowedTransitions(S.TERMINADO)).toEqual([S.ENTREGADO]);
    expect(allowedTransitions(S.ENTREGADO)).toEqual([]);
  });

  test('cubre los seis estados de la orden', () => {
    expect(Object.keys(ORDER_TRANSITIONS).sort()).toEqual(
      [...Object.values(S)].sort(),
    );
  });

  test('todas las transiciones válidas del mapa pasan para ADMIN', () => {
    for (const desde of Object.keys(ORDER_TRANSITIONS)) {
      for (const hasta of allowedTransitions(desde)) {
        expect(comoAdmin(desde, hasta)).toEqual({ permitida: true });
      }
    }
  });
});

describe('transiciones inválidas (409 con estados permitidos, SC-004)', () => {
  test('RECIBIDO → ENTREGADO no existe y menciona DIAGNOSTICO', () => {
    const resultado = comoAdmin(S.RECIBIDO, S.ENTREGADO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
    expect(resultado.codigo).toBe('TRANSICION_INVALIDA');
    expect(resultado.mensaje).toContain(S.DIAGNOSTICO);
  });

  test('no hay retroceso desde TERMINADO (solo → ENTREGADO)', () => {
    const resultado = comoAdmin(S.TERMINADO, S.DIAGNOSTICO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
    expect(resultado.mensaje).toContain(S.ENTREGADO);
  });

  test('DIAGNOSTICO no regresa a RECIBIDO', () => {
    const resultado = comoAdmin(S.DIAGNOSTICO, S.RECIBIDO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
    expect(resultado.mensaje).toContain(S.EN_REPARACION);
  });

  test('EN_REPARACION no retrocede a DIAGNOSTICO', () => {
    const resultado = comoAdmin(S.EN_REPARACION, S.DIAGNOSTICO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
  });

  test('repetir el mismo estado también se rechaza', () => {
    const resultado = comoAdmin(S.RECIBIDO, S.RECIBIDO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
  });

  test('ENTREGADO es terminal y no admite ningún cambio', () => {
    const resultado = comoAdmin(S.ENTREGADO, S.TERMINADO);

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
    expect(resultado.codigo).toBe('TRANSICION_INVALIDA');
    expect(resultado.mensaje).toContain('ya no admite');
  });

  test('la transición inválida se reporta antes que el rol (409, no 403)', () => {
    const resultado = evaluateTransition({
      fromStatus: S.RECIBIDO,
      toStatus: S.ENTREGADO,
      role: 'RECEPTIONIST',
      assignedMechanicId: null,
      userId: 2,
    });

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(409);
  });
});

describe('matriz de permisos por rol R-03 (FR-022)', () => {
  const mecanicoAsignado = {
    role: 'MECHANIC',
    assignedMechanicId: 3,
    userId: 3,
  };

  test('el mecánico asignado gestiona el bloque medio', () => {
    expect(
      evaluateTransition({
        fromStatus: S.RECIBIDO,
        toStatus: S.DIAGNOSTICO,
        ...mecanicoAsignado,
      }),
    ).toEqual({ permitida: true });

    expect(
      evaluateTransition({
        fromStatus: S.DIAGNOSTICO,
        toStatus: S.TERMINADO,
        ...mecanicoAsignado,
      }),
    ).toEqual({ permitida: true });

    expect(
      evaluateTransition({
        fromStatus: S.ESPERANDO_REFACCION,
        toStatus: S.DIAGNOSTICO,
        ...mecanicoAsignado,
      }),
    ).toEqual({ permitida: true });
  });

  test('un mecánico sin asignación no puede cambiar la orden (403)', () => {
    const sinAsignar = evaluateTransition({
      fromStatus: S.RECIBIDO,
      toStatus: S.DIAGNOSTICO,
      role: 'MECHANIC',
      assignedMechanicId: null,
      userId: 3,
    });

    expect(sinAsignar.permitida).toBe(false);
    expect(sinAsignar.httpStatus).toBe(403);
    expect(sinAsignar.codigo).toBe('ORDEN_AJENA');

    const ajena = evaluateTransition({
      fromStatus: S.RECIBIDO,
      toStatus: S.DIAGNOSTICO,
      role: 'MECHANIC',
      assignedMechanicId: 9,
      userId: 3,
    });

    expect(ajena.permitida).toBe(false);
    expect(ajena.httpStatus).toBe(403);
    expect(ajena.codigo).toBe('ORDEN_AJENA');
  });

  test('el mecánico no puede entregar la orden (403)', () => {
    const resultado = evaluateTransition({
      fromStatus: S.TERMINADO,
      toStatus: S.ENTREGADO,
      ...mecanicoAsignado,
    });

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(403);
    expect(resultado.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('recepción no gestiona el bloque medio (403)', () => {
    const resultado = evaluateTransition({
      fromStatus: S.RECIBIDO,
      toStatus: S.DIAGNOSTICO,
      role: 'RECEPTIONIST',
      assignedMechanicId: null,
      userId: 2,
    });

    expect(resultado.permitida).toBe(false);
    expect(resultado.httpStatus).toBe(403);
    expect(resultado.codigo).toBe('ROL_NO_AUTORIZADO');
  });

  test('recepción entrega la orden TERMINADO → ENTREGADO', () => {
    const resultado = evaluateTransition({
      fromStatus: S.TERMINADO,
      toStatus: S.ENTREGADO,
      role: 'RECEPTIONIST',
      assignedMechanicId: 3,
      userId: 2,
    });

    expect(resultado).toEqual({ permitida: true });
  });

  test('ADMIN puede entregar y también gestionar el bloque medio', () => {
    expect(comoAdmin(S.TERMINADO, S.ENTREGADO)).toEqual({ permitida: true });
    expect(comoAdmin(S.RECIBIDO, S.DIAGNOSTICO)).toEqual({ permitida: true });
  });
});
