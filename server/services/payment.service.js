// Logica de negocio de los pagos de las órdenes (Sprint 4, US1).
// Reglas aplicadas aquí: FR-004 (un pago por orden y solo en TERMINADO),
// FR-015 (el monto debe coincidir con el total calculado con precios
// vigentes), FR-016 (anulación con motivo, solo ADMIN, sin borrados) y
// RN-9 (la orden entregada es historial inmutable).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
import {
  createPayment,
  findPaymentById,
  listPaymentsByOrder,
  countPaymentsByStatus,
  findPaymentByStatus,
  updatePaymentStatus,
  findChargeContent,
} from '../models/payment.js';
import { findServiceOrderById } from '../models/service_order.js';
import { calcularTotal } from '../utils/order-total.js';
import {
  PAYMENT_STATUSES,
  PAYMENT_METHODS,
  evaluatePaymentTransition,
} from '../utils/payment-transitions.js';
import { crearPreferencia, modoPasarela } from './payment_gateway/index.js';
import { conflict, forbidden, notFound } from '../utils/errors.js';
import { ORDER_STATUSES } from '../utils/status-constants.js';

function formatDateTime(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

// Fecha y hora local como 'AAAA-MM-DD HH:MM:SS' para columnas DATETIME.
function toDbDateTime(date = new Date()) {
  const pad = (value) => String(value).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

function toApiPayment(payment) {
  return {
    id: payment.id,
    ordenId: payment.serviceOrderId,
    monto: Number(payment.amount),
    metodo: payment.method,
    estado: payment.status,
    referenciaExterna: payment.externalReference,
    enlacePago: payment.paymentLink,
    modoPasarela: payment.gatewayMode,
    motivoAnulacion: payment.annulmentReason,
    registradoPor: payment.createdByUsername,
    fecha: formatDateTime(payment.createdAt),
  };
}

// Total vigente de la orden: se calcula al cobrar con los precios actuales
// del catálogo (FR-015, aclaración 2), no con un total congelado.
export async function getOrderTotal(serviceOrderId) {
  const contenido = await findChargeContent(serviceOrderId);
  return calcularTotal(contenido);
}

// Total y desglose de la orden para el formulario de pago (FR-015, T062):
// misma fuente de verdad que valida el registro, para que el monto precargado
// en el cliente coincida con el que exige el backend.
export async function getOrderCharge(orderId) {
  const order = await assertOrderExists(orderId);
  const total = await getOrderTotal(order.id);
  return { ordenId: order.id, ...total };
}

async function assertOrderExists(orderId) {
  const order = await findServiceOrderById(orderId);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');
  return order;
}

// FR-004: el único estado cobrable es TERMINADO; el pago es previo a la
// entrega (aclaración 1).
function assertOrderChargeable(order) {
  if (order.status !== ORDER_STATUSES.TERMINADO) {
    throw conflict(
      `Solo se puede cobrar una orden en estado TERMINADO; esta orden está en ${order.status}`,
      'ORDEN_NO_COBRABLE',
    );
  }
}

// Registro de un pago (FR-001, FR-004, FR-005, FR-015). Los cobros
// presenciales nacen PAGADO (verificados en el momento); el cobro Mercado
// Pago nace PENDIENTE con su referencia externa, enlace y modo de pasarela
// (D1) hasta que se confirme manualmente (aclaración 3). Ninguna respuesta
// ni fila guarda datos de tarjeta ni credenciales (RN-14).
export async function registerPayment(data, user) {
  const order = await assertOrderExists(data.ordenId);
  assertOrderChargeable(order);

  if ((await countPaymentsByStatus(order.id, PAYMENT_STATUSES.PAGADO)) > 0) {
    throw conflict('La orden ya está liquidada: tiene un pago aprobado', 'ORDEN_YA_LIQUIDADA');
  }

  // Mientras exista un cobro Mercado Pago sin confirmar no se admite otro
  // intento (FR-005): la orden queda en disputa hasta confirmarlo o
  // rechazarlo, y así nunca conviven dos cobros abiertos.
  if ((await countPaymentsByStatus(order.id, PAYMENT_STATUSES.PENDIENTE)) > 0) {
    throw conflict(
      'La orden ya tiene un cobro Mercado Pago pendiente de confirmar',
      'PAGO_PENDIENTE',
    );
  }

  const total = await getOrderTotal(order.id);
  if (Number(data.monto) !== total.total) {
    throw conflict(
      `El monto debe coincidir con el total de la orden (${total.total.toFixed(2)})`,
      'MONTO_NO_COINCIDE',
    );
  }

  const esMercadoPago = data.metodo === PAYMENT_METHODS.MERCADO_PAGO;

  // D1: la pasarela (real o simulada) devuelve el id externo y el enlace del
  // cobro; nunca datos de tarjeta ni el access token (RN-14).
  let preferencia = null;
  if (esMercadoPago) {
    const referencia = `MOT-${order.id}-${Date.now()}`;
    preferencia = await crearPreferencia(order, total.total, referencia);
  }

  const created = await createPayment({
    serviceOrderId: order.id,
    amount: total.total,
    method: data.metodo,
    status: esMercadoPago ? PAYMENT_STATUSES.PENDIENTE : PAYMENT_STATUSES.PAGADO,
    externalReference: preferencia ? preferencia.idExterno : null,
    paymentLink: preferencia ? preferencia.enlace : null,
    gatewayMode: preferencia ? modoPasarela : null,
    createdBy: user.id,
  });

  return toApiPayment(created);
}

// Pagos de una orden, paginados; los anulados se conservan como historial
// (RN-9). El mecánico no consulta pagos (FR-003, RN-15: la ruta ya lo acota).
export async function listPaymentsByOrderId(orderId, filters) {
  await assertOrderExists(orderId);
  const page = Number(filters.pagina) || 1;
  const perPage = Number(filters.porPagina) || 10;
  const { rows, total } = await listPaymentsByOrder(orderId, { page, perPage });
  return {
    elementos: rows.map(toApiPayment),
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}

// Anulación de un pago por error de captura (FR-016, D6): solo ADMIN, el pago
// debe estar PAGADO y su orden no puede estar ENTREGADO (historial inmutable,
// RN-9). Nunca se borra el registro ni se devuelve dinero; la orden queda
// libre para un nuevo cobro.
export async function annulPayment(id, data, user) {
  if (user.role !== 'ADMIN') {
    throw forbidden(
      'Solo un administrador puede anular un pago',
      'ANULACION_NO_AUTORIZADA',
    );
  }

  const payment = await findPaymentById(id);
  if (!payment) throw notFound('El pago no existe', 'PAGO_NO_ENCONTRADO');

  const transition = evaluatePaymentTransition({
    fromStatus: payment.status,
    toStatus: PAYMENT_STATUSES.ANULADO,
  });
  if (!transition.permitida) {
    throw conflict(transition.mensaje, transition.codigo);
  }

  const order = await findServiceOrderById(payment.serviceOrderId);
  if (order.status === ORDER_STATUSES.ENTREGADO) {
    throw conflict(
      'No se puede anular el pago de una orden ya entregada: es historial inmutable',
      'ORDEN_ENTREGADA',
    );
  }

  const updated = await updatePaymentStatus(payment.id, {
    status: PAYMENT_STATUSES.ANULADO,
    annulmentReason: data.motivo.trim(),
    annulledBy: user.id,
    annulledAt: toDbDateTime(),
  });

  return toApiPayment(updated);
}

// Confirmación manual de un cobro Mercado Pago (FR-005, aclaración 3, D7): el
// recepcionista verifica el cobro en el panel del proveedor y marca el
// resultado. Solo aplica a pagos `PENDIENTE` de método `MERCADO_PAGO` y la
// transición sigue la máquina de estados; nunca se piden ni se guardan datos
// de tarjeta (RN-14). Al aprobarse, la orden queda liquidada (FR-004); al
// rechazarse o cancelarse, admite otro intento (HU3-3, HU3-4).
export async function confirmPayment(id, data) {
  const payment = await findPaymentById(id);
  if (!payment) throw notFound('El pago no existe', 'PAGO_NO_ENCONTRADO');

  if (payment.method !== PAYMENT_METHODS.MERCADO_PAGO) {
    throw conflict('Solo se confirma un cobro Mercado Pago pendiente', 'TRANSICION_INVALIDA');
  }

  const transition = evaluatePaymentTransition({
    fromStatus: payment.status,
    toStatus: data.estado,
  });
  if (!transition.permitida) {
    throw conflict(transition.mensaje, transition.codigo);
  }

  const updated = await updatePaymentStatus(payment.id, { status: data.estado });
  return toApiPayment(updated);
}

// Consulta interna para la regla de entrega (FR-014, D5): la orden tiene un
// pago aprobado que respalda su entrega.
export async function hasApprovedPayment(serviceOrderId) {
  const payment = await findPaymentByStatus(serviceOrderId, PAYMENT_STATUSES.PAGADO);
  return payment !== null;
}

// Excepción reutilizable por el servicio de órdenes cuando falta el pago
// (FR-014): el mismo 409 PAGO_PENDIENTE del contrato.
export function pagoPendienteError() {
  return conflict(
    'La orden no tiene un pago aprobado: primero debe registrarse el pago',
    'PAGO_PENDIENTE',
  );
}
