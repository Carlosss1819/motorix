// Constantes de estado compartidas por validadores y servicios del backend.
// Fuente de verdad: specs/002-citas-ordenes-servicio/data-model.md.

// Estados de una orden de servicio (FR-014) y su secuencia (project-context §6.4).
export const ORDER_STATUSES = Object.freeze({
  RECIBIDO: 'RECIBIDO',
  DIAGNOSTICO: 'DIAGNOSTICO',
  EN_REPARACION: 'EN_REPARACION',
  ESPERANDO_REFACCION: 'ESPERANDO_REFACCION',
  TERMINADO: 'TERMINADO',
  ENTREGADO: 'ENTREGADO',
});

export const ORDER_STATUS_VALUES = Object.freeze(Object.values(ORDER_STATUSES));

// Estados de una cita de recepción (FR-005, FR-006).
export const APPOINTMENT_STATUSES = Object.freeze({
  PROGRAMADA: 'PROGRAMADA',
  RECIBIDA: 'RECIBIDA',
  CANCELADA: 'CANCELADA',
  NO_PRESENTADA: 'NO_PRESENTADA',
});

export const APPOINTMENT_STATUS_VALUES = Object.freeze(
  Object.values(APPOINTMENT_STATUSES),
);

// Orden considerada "abierta" para el panel de recepción (todo lo no entregado).
export const OPEN_ORDER_STATUSES = Object.freeze([
  ORDER_STATUSES.RECIBIDO,
  ORDER_STATUSES.DIAGNOSTICO,
  ORDER_STATUSES.EN_REPARACION,
  ORDER_STATUSES.ESPERANDO_REFACCION,
  ORDER_STATUSES.TERMINADO,
]);
