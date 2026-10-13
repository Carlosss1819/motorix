// Máquina de estados de la orden de servicio (US5): mapa de transiciones
// R-02 y matriz de permisos por rol R-03 / FR-022. Es una función pura para
// poder probarla en unidad sin tocar la base de datos.
// Fuente de verdad: specs/002-citas-ordenes-servicio/contracts/service-orders.md
// (sección POST /api/service-orders/:id/estado).
import { ORDER_STATUSES } from './status-constants.js';

// Mapa R-02: desde cada estado, los únicos estados alcanzables.
export const ORDER_TRANSITIONS = Object.freeze({
  [ORDER_STATUSES.RECIBIDO]: Object.freeze([ORDER_STATUSES.DIAGNOSTICO]),
  [ORDER_STATUSES.DIAGNOSTICO]: Object.freeze([
    ORDER_STATUSES.EN_REPARACION,
    ORDER_STATUSES.ESPERANDO_REFACCION,
    ORDER_STATUSES.TERMINADO,
  ]),
  [ORDER_STATUSES.EN_REPARACION]: Object.freeze([
    ORDER_STATUSES.ESPERANDO_REFACCION,
    ORDER_STATUSES.TERMINADO,
  ]),
  [ORDER_STATUSES.ESPERANDO_REFACCION]: Object.freeze([
    ORDER_STATUSES.DIAGNOSTICO,
    ORDER_STATUSES.EN_REPARACION,
    ORDER_STATUSES.TERMINADO,
  ]),
  [ORDER_STATUSES.TERMINADO]: Object.freeze([ORDER_STATUSES.ENTREGADO]),
  [ORDER_STATUSES.ENTREGADO]: Object.freeze([]),
});

// Estados alcanzables desde un estado dado (vacío en la orden entregada).
export function allowedTransitions(fromStatus) {
  return ORDER_TRANSITIONS[fromStatus] ?? [];
}

// Evalúa la transición pedida por el usuario actual. Devuelve
// `{ permitida: true }` o un rechazo listo para la capa HTTP:
// - `409 TRANSICION_INVALIDA` cuando la transición no está en el mapa R-02,
//   con los estados permitidos en el mensaje (SC-004);
// - `403 ROL_NO_AUTORIZADO` cuando el rol no corresponde a la transición
//   (entrega solo recepción/administración; bloque medio solo el mecánico
//   asignado o administración, R-03 / FR-022);
// - `403 ORDEN_AJENA` cuando un mecánico intenta cambiar una orden que no
//   es suya (FR-010, RN-15).
export function evaluateTransition({
  fromStatus,
  toStatus,
  role,
  assignedMechanicId,
  userId,
}) {
  const permitidos = allowedTransitions(fromStatus);

  if (!permitidos.includes(toStatus)) {
    if (permitidos.length === 0) {
      return {
        permitida: false,
        httpStatus: 409,
        codigo: 'TRANSICION_INVALIDA',
        mensaje: 'La orden entregada ya no admite cambios de estado',
      };
    }
    return {
      permitida: false,
      httpStatus: 409,
      codigo: 'TRANSICION_INVALIDA',
      mensaje: `La orden en ${fromStatus} solo puede pasar a: ${permitidos.join(', ')}`,
    };
  }

  // Entrega (TERMINADO → ENTREGADO): solo recepción o administración.
  if (toStatus === ORDER_STATUSES.ENTREGADO) {
    if (role !== 'ADMIN' && role !== 'RECEPTIONIST') {
      return {
        permitida: false,
        httpStatus: 403,
        codigo: 'ROL_NO_AUTORIZADO',
        mensaje: 'Solo recepción o administración puede entregar la orden',
      };
    }
    return { permitida: true };
  }

  // Bloque medio (RECIBIDO … TERMINADO): el mecánico asignado o ADMIN.
  if (role === 'ADMIN') {
    return { permitida: true };
  }
  if (role !== 'MECHANIC') {
    return {
      permitida: false,
      httpStatus: 403,
      codigo: 'ROL_NO_AUTORIZADO',
      mensaje:
        'Solo el mecánico asignado o un administrador puede cambiar el estado de la orden',
    };
  }
  if (assignedMechanicId == null || assignedMechanicId !== userId) {
    return {
      permitida: false,
      httpStatus: 403,
      codigo: 'ORDEN_AJENA',
      mensaje: 'Solo el mecánico asignado a la orden puede cambiar su estado',
    };
  }

  return { permitida: true };
}
