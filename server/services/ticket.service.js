// Lógica de negocio de los tickets de servicio (Sprint 4, US4).
// Reglas aplicadas aquí: FR-009 (la orden debe tener un pago `PAGADO`),
// HU4-2 (la generación es idempotente: nunca se duplica el folio),
// FR-007/FR-012 (el comprobante se reconstruye desde la orden y su pago al
// consultarlo, sin copias en frío ni archivos PDF) y RN-14 (nunca datos de
// tarjeta ni credenciales).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/tickets.md
import {
  create,
  findById,
  findByFolio,
  findByServiceOrder,
  findOrderContext,
  nextFolio,
} from '../models/ticket.js';
import { findServiceOrderById } from '../models/service_order.js';
import {
  findChargeContent,
  findPaymentById,
  findPaymentByStatus,
} from '../models/payment.js';
import { calcularTotal } from '../utils/order-total.js';
import { PAYMENT_STATUSES } from '../utils/payment-transitions.js';
import { conflict, notFound } from '../utils/errors.js';

// Datos fijos del taller que encabezan el comprobante (contrato del ticket).
const TALLER = Object.freeze({
  nombre: 'Motorix',
  direccion: 'Av. Ejemplo 123, Col. Centro',
  telefono: '55-0000-0000',
});

function formatDateTime(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

// Reconstruye el comprobante completo desde la orden, su pago y el ticket
// persistido (FR-007, FR-012). Los subtotales salen del mismo cálculo que
// validó el cobro (`order-total.js`, FR-015) con `NULL` tratado como 0 (D2).
async function buildTicket(ticket) {
  const contexto = await findOrderContext(ticket.serviceOrderId);
  const pago = await findPaymentById(ticket.paymentId);
  const contenido = await findChargeContent(ticket.serviceOrderId);
  const total = calcularTotal(contenido);

  const servicios = contenido.manoDeObra.map((partida, index) => ({
    descripcion: partida.descripcion ?? 'Mano de obra',
    // Precio NULL → 0 (D2): `total.desglose` ya viene redondeado.
    manoDeObra: total.desglose.manoDeObra[index].precio,
    refacciones: [],
  }));

  // `order_parts` no guarda vínculo con una partida de mano de obra
  // (esquema del Sprint 2), así que las refacciones de la orden viajan
  // anidadas al primer servicio; sin servicios, se abre un concepto
  // «Refacciones» para que el comprobante las liste igual (FR-007).
  const refacciones = contenido.refacciones.map((fila, index) => {
    const linea = total.desglose.refacciones[index];
    return {
      codigo: fila.codigo,
      nombre: fila.nombre ?? fila.descripcion,
      cantidad: linea.cantidad,
      precioUnitario: linea.precioUnitario,
      subtotal: linea.subtotal,
    };
  });
  if (refacciones.length > 0) {
    if (servicios.length > 0) {
      servicios[0].refacciones = refacciones;
    } else {
      servicios.push({
        descripcion: 'Refacciones',
        manoDeObra: 0,
        refacciones,
      });
    }
  }

  const emitidoEn = formatDateTime(ticket.issuedAt);

  return {
    id: ticket.id,
    folio: ticket.folio,
    ordenId: ticket.serviceOrderId,
    pagoId: ticket.paymentId,
    emitidoPor: ticket.issuedByUsername ?? '',
    emitidoEn,
    taller: TALLER,
    cliente: {
      id: contexto?.client_id ?? null,
      nombre: contexto?.client_name ?? '',
      telefono: contexto?.client_phone ?? '',
    },
    vehiculo: {
      id: contexto?.vehicle_id ?? null,
      marca: contexto?.brand ?? '',
      modelo: contexto?.model ?? '',
      anio: contexto?.year ?? null,
      placas: contexto?.plates ?? '',
      kilometraje: contexto?.entry_mileage ?? 0,
    },
    servicios,
    subtotalManoDeObra: total.subtotalManoDeObra,
    subtotalRefacciones: total.subtotalRefacciones,
    total: total.total,
    metodoPago: pago?.method ?? '',
    estadoPago: pago?.status ?? '',
    // `fecha` del comprobante: el día de emisión (AAAA-MM-DD).
    fecha: emitidoEn ? emitidoEn.slice(0, 10) : null,
  };
}

// Genera el ticket de una orden pagada (FR-009). Idempotente (HU4-2): si la
// orden ya tiene ticket se devuelve el existente con su folio original y se
// responde `200` en lugar de `201`.
export async function generateTicket(ordenId, user) {
  const order = await findServiceOrderById(ordenId);
  if (!order) throw notFound('La orden no existe', 'ORDEN_NO_ENCONTRADA');

  const existente = await findByServiceOrder(ordenId);
  if (existente) {
    return { ticket: await buildTicket(existente), creado: false };
  }

  const pago = await findPaymentByStatus(ordenId, PAYMENT_STATUSES.PAGADO);
  if (!pago) {
    throw conflict(
      'La orden no tiene un pago aprobado: primero debe registrarse el pago',
      'TICKET_REQUIERE_PAGO',
    );
  }

  // Dos generaciones simultáneas pueden calcular el mismo folio: la
  // `UNIQUE KEY uq_tickets_folio` impide el duplicado y aquí se reintenta
  // con el siguiente número (HU4-2). Si la colisión es por la orden (ya se
  // creó el ticket en paralelo) se devuelve el existente como idempotente.
  let creado = null;
  for (let intento = 0; intento < 3 && !creado; intento += 1) {
    try {
      creado = await create({
        serviceOrderId: ordenId,
        paymentId: pago.id,
        folio: await nextFolio(),
        issuedBy: user.id,
      });
    } catch (error) {
      const duplicado = error?.code === 'ER_DUP_ENTRY' || error?.errno === 1062;
      if (!duplicado) throw error;
      const ganador = await findByServiceOrder(ordenId);
      if (ganador) return { ticket: await buildTicket(ganador), creado: false };
    }
  }
  if (!creado) {
    throw conflict('No se pudo asignar el folio del ticket: intenta de nuevo', 'FOLIO_EN_USO');
  }

  return { ticket: await buildTicket(creado), creado: true };
}

export async function getTicket(id) {
  const ticket = await findById(id);
  if (!ticket) throw notFound('El ticket no existe', 'TICKET_NO_ENCONTRADO');
  return buildTicket(ticket);
}

// Consulta si la orden ya tiene ticket, para mostrar u ocultar «Ver ticket»
// sin intentar generarlo (contrato `GET /api/tickets/orden/:ordenId`).
export async function getTicketByOrder(ordenId) {
  const order = await findServiceOrderById(ordenId);
  if (!order) throw notFound('La orden no existe', 'ORDEN_NO_ENCONTRADA');

  const ticket = await findByServiceOrder(ordenId);
  if (!ticket) return { existe: false, ticket: null };
  return { existe: true, ticket: await buildTicket(ticket) };
}

// Búsqueda por folio, disponible para pruebas y depuración (D3).
export async function getTicketByFolio(folio) {
  const ticket = await findByFolio(folio);
  if (!ticket) throw notFound('El ticket no existe', 'TICKET_NO_ENCONTRADO');
  return buildTicket(ticket);
}
