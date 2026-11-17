// Criterio de «orden detenida» (Sprint 6, FR-006, R-04): una orden en estado
// no final sin cambio de estado por más de N × 24 horas. TERMINADO no cuenta
// (la orden lista aparece en «Clientes por avisar») ni ENTREGADO (es final).
import { ORDER_STATUSES } from './status-constants.js';

export const STALLED_ORDER_STATUSES = Object.freeze([
  ORDER_STATUSES.RECIBIDO,
  ORDER_STATUSES.DIAGNOSTICO,
  ORDER_STATUSES.EN_REPARACION,
  ORDER_STATUSES.ESPERANDO_REFACCION,
]);

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// `reference`: último cambio de estado (o el alta si no hay cambios).
export function isStalled({ status, reference, now, days }) {
  if (!STALLED_ORDER_STATUSES.includes(status)) return false;
  return now.getTime() - new Date(reference).getTime() > days * MS_PER_DAY;
}

// Días completos sin cambio (para la descripción del aviso).
export function daysWithoutChange(reference, now) {
  return Math.floor((now.getTime() - new Date(reference).getTime()) / MS_PER_DAY);
}
