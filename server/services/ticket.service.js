// Lógica de negocio de los tickets de servicio (Sprint 4, US4; Sprint 5, US4).
// Reglas aplicadas aquí: FR-009 (la orden debe tener un pago `PAGADO`),
// HU4-2 / SC-013 (la generación es idempotente por pago: nunca se duplica el
// folio) y RN-14 (nunca datos de tarjeta ni credenciales).
//
// Sprint 5:
// - FR-019: el comprobante se guarda como COPIA con versión de formato al
//   emitirse (versión 2) y se lee de esa copia, no se reconstruye; así un
//   cambio de precio en el catálogo no lo altera (SC-002).
// - FR-033: un ticket por cada pago PAGADO; si el pago se anula y se cobra de
//   nuevo, el pago nuevo genera un ticket nuevo con otro folio.
// - FR-022: el ticket de un pago anulado se sigue consultando, con
//   `pagoAnulado: true` y `vigente: false` (se calculan al consultar).
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/tickets.md.
import {
  create,
  findById,
  findByFolio,
  findByPaymentId,
  listByServiceOrder,
  findOrderContext,
  findOrderServiceTypes,
  nextFolio,
} from '../models/ticket.js';
import { proposeNextService } from '../utils/next-service.js';
import { findServiceOrderById } from '../models/service_order.js';
import { findChargeContent, findPaymentByStatus } from '../models/payment.js';
import { calcularTotal } from '../utils/order-total.js';
import { PAYMENT_STATUSES } from '../utils/payment-transitions.js';
import { withOrderLock } from './order-lock.js';
import { conflict, notFound } from '../utils/errors.js';
// Sprint 7 (US1, FR-002): los datos del taller salen de la configuración
// vigente al emitir y quedan en la copia; el respaldo de la antigua constante
// TALLER vive en utils/settings-defaults.js (FR-003).
import { getShopData } from './settings.service.js';

// Versión del formato de la copia que escribe la aplicación (Sprint 5).
export const FORMATO_ACTUAL = 2;


const pad = (number) => String(number).padStart(2, '0');

function formatDateTime(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

// Arma la copia del comprobante (versión 2) desde la orden, su pago y su
// contenido con el precio congelado de cada línea (FR-017, FR-018). Los
// subtotales salen del mismo cálculo que validó el cobro (`order-total.js`).
async function buildContent({ folio, ordenId, pago, emitidoPor, emitidoEn }, connection) {
  const contexto = await findOrderContext(ordenId, connection);
  const contenido = await findChargeContent(ordenId, connection);
  const total = calcularTotal(contenido);

  const servicios = contenido.manoDeObra.map((partida, index) => ({
    descripcion: partida.descripcion ?? 'Mano de obra',
    // Precio NULL → 0 (D2): `total.desglose` ya viene redondeado.
    manoDeObra: total.desglose.manoDeObra[index].precio,
    // FR-018: «sin precio registrado» igual que el desglose del pago.
    avisoManoDeObra: total.desglose.manoDeObra[index].aviso,
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
      // FR-018: «sin precio registrado» en las líneas sin precio.
      aviso: linea.aviso,
    };
  });
  if (refacciones.length > 0) {
    if (servicios.length > 0) {
      servicios[0].refacciones = refacciones;
    } else {
      servicios.push({
        descripcion: 'Refacciones',
        manoDeObra: 0,
        avisoManoDeObra: null,
        refacciones,
      });
    }
  }

  return {
    folio,
    ordenId,
    pagoId: pago.id,
    emitidoPor,
    emitidoEn,
    taller: await getShopData(),
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
    metodoPago: pago.method ?? '',
    // `fecha` del comprobante: el día de emisión (AAAA-MM-DD).
    fecha: emitidoEn ? emitidoEn.slice(0, 10) : null,
    formatoVersion: FORMATO_ACTUAL,
    desgloseNoCoincide: false,
    nota: null,
    // Sprint 7 (US8, FR-012/FR-013): próximo servicio por tipo con
    // intervalo; base = fecha de emisión y kilometraje de entrada. Campo
    // opcional de la copia v2: los tickets anteriores no lo traen.
    proximosServicios: await buildNextServices(ordenId, emitidoEn, contexto?.entry_mileage, connection),
  };
}

async function buildNextServices(ordenId, emitidoEn, kmEntrada, connection) {
  const tipos = await findOrderServiceTypes(ordenId, connection);
  const fechaBase = emitidoEn ? emitidoEn.slice(0, 10) : null;
  return tipos.map((tipo) => ({
    tipoServicio: tipo.nombre,
    ...proposeNextService(tipo, fechaBase, kmEntrada ?? null),
  }));
}

// Campos calculados al consultar (no se guardan en la copia).
function estadoDelTicket(ticket) {
  const vigente = ticket.paymentStatus === PAYMENT_STATUSES.PAGADO;
  return {
    estadoPago: ticket.paymentStatus ?? '',
    pagoAnulado: ticket.paymentStatus === PAYMENT_STATUSES.ANULADO,
    vigente,
    formatoAnterior: ticket.formatVersion === 1,
  };
}

// Respuesta del ticket: la copia guardada más los campos calculados. Si una
// fila no tuviera copia (solo antes de correr el 006 o el seed 005), se arma
// en el momento con los datos actuales, sin guardarla.
async function toApiTicket(ticket) {
  let copia = ticket.content;
  if (!copia) {
    const pago = { id: ticket.paymentId, method: '' };
    copia = await buildContent({
      folio: ticket.folio,
      ordenId: ticket.serviceOrderId,
      pago,
      emitidoPor: ticket.issuedByUsername ?? '',
      emitidoEn: formatDateTime(ticket.issuedAt),
    });
  }
  return {
    id: ticket.id,
    ...copia,
    // Los totales de una copia v1 llegan de MySQL como número JSON.
    total: Number(copia.total),
    subtotalManoDeObra: Number(copia.subtotalManoDeObra),
    subtotalRefacciones: Number(copia.subtotalRefacciones),
    formatoVersion: ticket.formatVersion ?? copia.formatoVersion ?? null,
    desgloseNoCoincide: Boolean(copia.desgloseNoCoincide),
    nota: copia.nota ?? null,
    ...estadoDelTicket(ticket),
  };
}

function toApiResumen(ticket) {
  const { vigente, pagoAnulado, formatoAnterior } = estadoDelTicket(ticket);
  return {
    id: ticket.id,
    folio: ticket.folio,
    pagoId: ticket.paymentId,
    emitidoEn: formatDateTime(ticket.issuedAt),
    vigente,
    pagoAnulado,
    formatoAnterior,
  };
}

function esDuplicado(error) {
  return error?.code === 'ER_DUP_ENTRY' || error?.errno === 1062;
}

// Genera el ticket del pago PAGADO no anulado de la orden (FR-009, FR-033,
// R-14). Con el candado de la orden (R-07): si ese pago ya tiene ticket, se
// devuelve el existente con `200` (idempotente, SC-013); si no, se emite uno
// nuevo con folio consecutivo y copia en versión 2 (`201`). Ya no devuelve
// el ticket de un pago anulado (corrige H2).
export async function generateTicket(ordenId, user) {
  const order = await findServiceOrderById(ordenId);
  if (!order) throw notFound('La orden no existe', 'ORDEN_NO_ENCONTRADA');

  const resultado = await withOrderLock(order.id, async (connection) => {
    const pago = await findPaymentByStatus(order.id, PAYMENT_STATUSES.PAGADO, connection);
    if (!pago) {
      throw conflict(
        'La orden no tiene un pago aprobado: primero debe registrarse el pago',
        'TICKET_REQUIERE_PAGO',
      );
    }

    const existente = await findByPaymentId(pago.id, connection);
    if (existente) return { ticket: existente, creado: false };

    const emitidoEn = formatDateTime(new Date());
    const base = await buildContent(
      { folio: null, ordenId: order.id, pago, emitidoPor: user.username ?? '', emitidoEn },
      connection,
    );

    // Dos órdenes distintas pueden calcular el mismo folio a la vez: la
    // `UNIQUE KEY uq_tickets_folio` impide el duplicado y se reintenta con el
    // siguiente número (HU4-2).
    for (let intento = 0; intento < 3; intento += 1) {
      const folio = await nextFolio();
      try {
        const creado = await create(
          {
            serviceOrderId: order.id,
            paymentId: pago.id,
            folio,
            issuedBy: user.id,
            issuedAt: emitidoEn,
            content: { ...base, folio },
            formatVersion: FORMATO_ACTUAL,
          },
          connection,
        );
        return { ticket: creado, creado: true };
      } catch (error) {
        if (!esDuplicado(error)) throw error;
        const ganador = await findByPaymentId(pago.id, connection);
        if (ganador) return { ticket: ganador, creado: false };
      }
    }
    throw conflict('No se pudo asignar el folio del ticket: intenta de nuevo', 'FOLIO_EN_USO');
  });

  return { ticket: await toApiTicket(resultado.ticket), creado: resultado.creado };
}

export async function getTicket(id) {
  const ticket = await findById(id);
  if (!ticket) throw notFound('El ticket no existe', 'TICKET_NO_ENCONTRADO');
  return toApiTicket(ticket);
}

// Consulta los tickets de la orden (contrato `GET /api/tickets/orden/:ordenId`,
// R-14): `ticket` es el vigente (o null) y `tickets` la lista completa, del
// más reciente al más antiguo. `existe` se conserva por compatibilidad.
export async function getTicketByOrder(ordenId) {
  const order = await findServiceOrderById(ordenId);
  if (!order) throw notFound('La orden no existe', 'ORDEN_NO_ENCONTRADA');

  const tickets = await listByServiceOrder(ordenId);
  const vigente = tickets.find((ticket) => ticket.paymentStatus === PAYMENT_STATUSES.PAGADO);
  return {
    existe: Boolean(vigente),
    ticket: vigente ? await toApiTicket(vigente) : null,
    tickets: tickets.map(toApiResumen),
  };
}

// Búsqueda por folio, disponible para pruebas y depuración (D3).
export async function getTicketByFolio(folio) {
  const ticket = await findByFolio(folio);
  if (!ticket) throw notFound('El ticket no existe', 'TICKET_NO_ENCONTRADO');
  return toApiTicket(ticket);
}
