// Logica de negocio de los pagos de las órdenes (Sprint 4, US1; Sprint 5).
// Reglas aplicadas aquí: FR-004 (un pago por orden y solo en TERMINADO),
// FR-015 (el monto debe coincidir con el total calculado con el precio
// congelado de cada línea, Sprint 5), FR-014 del Sprint 5 (candado por
// orden, R-07), D-04 (pago pendiente desfasado, R-08), FR-016 (anulación con
// motivo, solo ADMIN, sin borrados) y RN-9 (la orden entregada es historial
// inmutable).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md y
// specs/005-precios-refacciones-cobro/contracts/payments.md.
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
import { calcularTotalCentavos } from '../utils/order-total.js';
import { toCents, fromCents, centsToDecimalString } from '../utils/money.js';
import {
  PAYMENT_STATUSES,
  PAYMENT_METHODS,
  evaluatePaymentTransition,
} from '../utils/payment-transitions.js';
import { crearPreferencia, modoPasarela } from './payment_gateway/index.js';
import { withOrderLock } from './order-lock.js';
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
    // Sprint 5 (FR-016): IMPORTE_DESFASADO, MANUAL o null.
    motivoCancelacion: payment.cancellationReason ?? null,
    registradoPor: payment.createdByUsername,
    fecha: formatDateTime(payment.createdAt),
  };
}

// Total de la orden para cobrar (Sprint 5, FR-008, FR-015): mano de obra +
// refacciones con su precio CONGELADO, calculado en centavos. `connection`
// permite calcularlo dentro de la transacción con el candado de la orden.
async function getOrderTotalCentavos(serviceOrderId, connection = null) {
  const contenido = await findChargeContent(serviceOrderId, connection);
  return calcularTotalCentavos(contenido);
}

export async function getOrderTotal(serviceOrderId) {
  return (await getOrderTotalCentavos(serviceOrderId)).resultado;
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
// entrega (aclaración 1). Acepta la orden completa o la fila bloqueada.
function assertOrderChargeable(order) {
  if (order.status !== ORDER_STATUSES.TERMINADO) {
    throw conflict(
      `Solo se puede cobrar una orden en estado TERMINADO; esta orden está en ${order.status}`,
      'ORDEN_NO_COBRABLE',
    );
  }
}

// FR-004 / FR-005: ni un pago PAGADO ni un cobro Mercado Pago PENDIENTE: la
// orden ya está liquidada o en disputa hasta confirmarlo o rechazarlo.
async function assertSinPagoAbierto(orderId, connection = null) {
  if ((await countPaymentsByStatus(orderId, PAYMENT_STATUSES.PAGADO, connection)) > 0) {
    throw conflict('La orden ya está liquidada: tiene un pago aprobado', 'ORDEN_YA_LIQUIDADA');
  }
  if ((await countPaymentsByStatus(orderId, PAYMENT_STATUSES.PENDIENTE, connection)) > 0) {
    throw conflict(
      'La orden ya tiene un cobro Mercado Pago pendiente de confirmar',
      'PAGO_PENDIENTE',
    );
  }
}

// Monto recibido → centavos, solo si tiene como máximo dos decimales; si no,
// devuelve null y nunca coincide con el total (igualdad exacta, R-06).
function montoEnCentavos(monto) {
  const valor = Number(monto);
  if (!Number.isFinite(valor)) return null;
  const centavos = Math.round(valor * 100);
  return Math.abs(valor * 100 - centavos) < 1e-6 ? centavos : null;
}

// FR-015: el monto debe coincidir AL CENTAVO con el total calculado.
function assertMontoCoincide(monto, totalCentavos) {
  if (montoEnCentavos(monto) !== totalCentavos) {
    throw conflict(
      `El monto debe coincidir con el total de la orden (${centsToDecimalString(totalCentavos)})`,
      'MONTO_NO_COINCIDE',
    );
  }
}

// Registro de un pago (FR-001, FR-004, FR-005, FR-015). Los cobros
// presenciales nacen PAGADO (verificados en el momento); el cobro Mercado
// Pago nace PENDIENTE con su referencia externa, enlace y modo de pasarela
// (D1) hasta que se confirme manualmente (aclaración 3). Ninguna respuesta
// ni fila guarda datos de tarjeta ni credenciales (RN-14).
//
// Sprint 5 (FR-013, FR-014, R-07): 1) se valida sin candado; 2) la
// preferencia de Mercado Pago se crea FUERA del candado (sin red dentro de la
// transacción); 3) con el candado de la orden se vuelve a validar (estado,
// sin PAGADO ni PENDIENTE y total igual en centavos) y se inserta. De dos
// solicitudes simultáneas, solo una se registra; la otra recibe 409.
export async function registerPayment(data, user) {
  const order = await assertOrderExists(data.ordenId);
  assertOrderChargeable(order);
  await assertSinPagoAbierto(order.id);

  const { totalCentavos, resultado: total } = await getOrderTotalCentavos(order.id);
  assertMontoCoincide(data.monto, totalCentavos);

  const esMercadoPago = data.metodo === PAYMENT_METHODS.MERCADO_PAGO;

  // Si la segunda validación falla, la preferencia sobrante caduca sola (R-09).
  let preferencia = null;
  if (esMercadoPago) {
    const referencia = `MOT-${order.id}-${Date.now()}`;
    preferencia = await crearPreferencia(order, total.total, referencia);
  }

  const created = await withOrderLock(order.id, async (connection, locked) => {
    assertOrderChargeable(locked);
    await assertSinPagoAbierto(order.id, connection);
    const actual = await getOrderTotalCentavos(order.id, connection);
    assertMontoCoincide(data.monto, actual.totalCentavos);

    return createPayment(
      {
        serviceOrderId: order.id,
        amount: centsToDecimalString(actual.totalCentavos),
        method: data.metodo,
        status: esMercadoPago ? PAYMENT_STATUSES.PENDIENTE : PAYMENT_STATUSES.PAGADO,
        externalReference: preferencia ? preferencia.idExterno : null,
        paymentLink: preferencia ? preferencia.enlace : null,
        gatewayMode: preferencia ? modoPasarela : null,
        createdBy: user.id,
      },
      connection,
    );
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
// libre para un nuevo cobro. Sprint 5 (FR-014, R-07): con el candado de la
// orden se revalidan el pago y el estado de la orden.
export async function annulPayment(id, data, user) {
  if (user.role !== 'ADMIN') {
    throw forbidden(
      'Solo un administrador puede anular un pago',
      'ANULACION_NO_AUTORIZADA',
    );
  }

  const payment = await findPaymentById(id);
  if (!payment) throw notFound('El pago no existe', 'PAGO_NO_ENCONTRADO');

  const updated = await withOrderLock(payment.serviceOrderId, async (connection, locked) => {
    const actual = await findPaymentById(payment.id, connection);
    const transition = evaluatePaymentTransition({
      fromStatus: actual.status,
      toStatus: PAYMENT_STATUSES.ANULADO,
    });
    if (!transition.permitida) {
      throw conflict(transition.mensaje, transition.codigo);
    }

    if (locked.status === ORDER_STATUSES.ENTREGADO) {
      throw conflict(
        'No se puede anular el pago de una orden ya entregada: es historial inmutable',
        'ORDEN_ENTREGADA',
      );
    }

    return updatePaymentStatus(
      payment.id,
      {
        status: PAYMENT_STATUSES.ANULADO,
        annulmentReason: data.motivo.trim(),
        annulledBy: user.id,
        annulledAt: toDbDateTime(),
      },
      connection,
    );
  });

  return toApiPayment(updated);
}

// Mensaje de D-04 con las cifras del pago y del total actual.
function importeDesfasadoError(importeCentavos, totalCentavos) {
  return conflict(
    `El importe del pago (${centsToDecimalString(importeCentavos)}) ya no coincide ` +
      `con el total de la orden (${centsToDecimalString(totalCentavos)}); el pago se ` +
      'canceló. Antes de generar uno nuevo, revisa en el panel de Mercado Pago si el ' +
      'cliente ya pagó.',
    'IMPORTE_DESFASADO',
    {
      importePago: fromCents(importeCentavos),
      totalActual: fromCents(totalCentavos),
      diferencia: fromCents(importeCentavos - totalCentavos),
    },
  );
}

// Confirmación manual de un cobro Mercado Pago (FR-005, aclaración 3, D7): el
// recepcionista verifica el cobro en el panel del proveedor y marca el
// resultado. Solo aplica a pagos `PENDIENTE` de método `MERCADO_PAGO` y la
// transición sigue la máquina de estados; nunca se piden ni se guardan datos
// de tarjeta (RN-14). Al aprobarse, la orden queda liquidada (FR-004); al
// rechazarse o cancelarse, admite otro intento (HU3-3, HU3-4).
//
// Sprint 5 (D-04, FR-016, R-08): con el candado de la orden se recalcula el
// total. Si al confirmar como PAGADO el importe ya no coincide, el pago pasa a
// CANCELADO con el motivo IMPORTE_DESFASADO, se guarda (commit) y se responde
// 409 con las cifras. Una cancelación manual guarda el motivo MANUAL; un
// RECHAZADO no compara el importe.
export async function confirmPayment(id, data) {
  const payment = await findPaymentById(id);
  if (!payment) throw notFound('El pago no existe', 'PAGO_NO_ENCONTRADO');

  if (payment.method !== PAYMENT_METHODS.MERCADO_PAGO) {
    throw conflict('Solo se confirma un cobro Mercado Pago pendiente', 'TRANSICION_INVALIDA');
  }

  const updated = await withOrderLock(payment.serviceOrderId, async (connection) => {
    const actual = await findPaymentById(payment.id, connection);
    const transition = evaluatePaymentTransition({
      fromStatus: actual.status,
      toStatus: data.estado,
    });
    if (!transition.permitida) {
      throw conflict(transition.mensaje, transition.codigo);
    }

    if (data.estado === PAYMENT_STATUSES.PAGADO) {
      const importeCentavos = toCents(actual.amount);
      const { totalCentavos } = await getOrderTotalCentavos(actual.serviceOrderId, connection);
      if (importeCentavos !== totalCentavos) {
        await updatePaymentStatus(
          actual.id,
          { status: PAYMENT_STATUSES.CANCELADO, cancellationReason: 'IMPORTE_DESFASADO' },
          connection,
        );
        return { commitAndThrow: importeDesfasadoError(importeCentavos, totalCentavos) };
      }
    }

    return updatePaymentStatus(
      actual.id,
      {
        status: data.estado,
        cancellationReason: data.estado === PAYMENT_STATUSES.CANCELADO ? 'MANUAL' : null,
      },
      connection,
    );
  });

  return toApiPayment(updated);
}

// Consulta interna para la regla de entrega (FR-014, D5): la orden tiene un
// pago aprobado que respalda su entrega.
export async function hasApprovedPayment(serviceOrderId, connection = null) {
  const payment = await findPaymentByStatus(
    serviceOrderId,
    PAYMENT_STATUSES.PAGADO,
    connection,
  );
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
