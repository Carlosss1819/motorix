// Máquina de estados del pago (Sprint 4, D7): qué transiciones de estado
// admite un pago. Es una función pura al estilo de order-transitions.js para
// probarla en unidad sin tocar la base de datos.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/data-model.md (D7).

export const PAYMENT_STATUSES = Object.freeze({
  PENDIENTE: 'PENDIENTE',
  PAGADO: 'PAGADO',
  RECHAZADO: 'RECHAZADO',
  CANCELADO: 'CANCELADO',
  ANULADO: 'ANULADO',
});

export const PAYMENT_METHODS = Object.freeze({
  EFECTIVO: 'EFECTIVO',
  TARJETA: 'TARJETA',
  TRANSFERENCIA: 'TRANSFERENCIA',
  MERCADO_PAGO: 'MERCADO_PAGO',
});

// Mapa D7: desde cada estado, los únicos estados alcanzables. RECHAZADO,
// CANCELADO y ANULADO son estados finales (la orden admite un nuevo intento).
export const PAYMENT_TRANSITIONS = Object.freeze({
  [PAYMENT_STATUSES.PENDIENTE]: Object.freeze([
    PAYMENT_STATUSES.PAGADO,
    PAYMENT_STATUSES.RECHAZADO,
    PAYMENT_STATUSES.CANCELADO,
  ]),
  [PAYMENT_STATUSES.PAGADO]: Object.freeze([PAYMENT_STATUSES.ANULADO]),
  [PAYMENT_STATUSES.RECHAZADO]: Object.freeze([]),
  [PAYMENT_STATUSES.CANCELADO]: Object.freeze([]),
  [PAYMENT_STATUSES.ANULADO]: Object.freeze([]),
});

// Estados alcanzables desde un estado dado (vacío en un estado final).
export function allowedPaymentTransitions(fromStatus) {
  return PAYMENT_TRANSITIONS[fromStatus] ?? [];
}

// Evalúa el cambio de estado de un pago. Devuelve `{ permitida: true }` o un
// rechazo listo para la capa HTTP con `409 TRANSICION_INVALIDA` y los estados
// permitidos en el mensaje.
export function evaluatePaymentTransition({ fromStatus, toStatus }) {
  const permitidos = allowedPaymentTransitions(fromStatus);

  if (!permitidos.includes(toStatus)) {
    if (permitidos.length === 0) {
      return {
        permitida: false,
        httpStatus: 409,
        codigo: 'TRANSICION_INVALIDA',
        mensaje: `El pago en estado ${fromStatus} es definitivo y no admite cambios`,
      };
    }
    return {
      permitida: false,
      httpStatus: 409,
      codigo: 'TRANSICION_INVALIDA',
      mensaje: `El pago en ${fromStatus} solo puede pasar a: ${permitidos.join(', ')}`,
    };
  }

  return { permitida: true };
}
