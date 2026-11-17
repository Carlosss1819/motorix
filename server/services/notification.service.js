// Avisos internos (Sprint 6, US1 a US6). Se calculan en cada consulta con las
// reglas existentes (R-01, R-02) y se filtran por rol en el servidor
// (FR-009 a FR-013). Solo se guarda la lectura por usuario (FR-014, FR-015).
// Ningún aviso incluye importes (FR-012).
import { config } from '../config/env.js';
import { listMaintenance } from '../models/maintenance.js';
import {
  insertRead,
  listActiveAppointmentsOn,
  listLowStockParts,
  listReadKeys,
  listStalledOrders,
  markExpiredAppointmentsOn,
} from '../models/notification.js';
import { calcMaintenanceState, MAINTENANCE_STATES } from '../utils/maintenance-status.js';
import { now } from '../utils/clock.js';
import { toDbDateTimeLocal, toDbTimeLocal, toIsoDate } from '../utils/dates.js';
import {
  maintenanceTarget,
  noticeKey,
  NOTICE_GROUP_ORDER,
  NOTICE_TYPES,
} from '../utils/notice-keys.js';
import { daysWithoutChange } from '../utils/stalled-order.js';

const GROUP_TITLES = Object.freeze({
  MANT_VENCIDO: 'Mantenimientos vencidos',
  ORDEN_DETENIDA: 'Órdenes detenidas',
  STOCK_AGOTADO: 'Refacciones agotadas',
  STOCK_BAJO: 'Refacciones con stock bajo',
  CITA_HOY: 'Citas de hoy',
  MANT_PROXIMO: 'Mantenimientos próximos',
});

const NOTICE_TITLES = Object.freeze({
  MANT_VENCIDO: 'Mantenimiento vencido',
  ORDEN_DETENIDA: 'Orden detenida',
  STOCK_AGOTADO: 'Refacción agotada',
  STOCK_BAJO: 'Stock bajo',
  CITA_HOY: 'Cita de hoy',
  MANT_PROXIMO: 'Mantenimiento próximo',
});

const ORDER_STATUS_TEXT = Object.freeze({
  RECIBIDO: 'Recibido',
  DIAGNOSTICO: 'En diagnóstico',
  EN_REPARACION: 'En reparación',
  ESPERANDO_REFACCION: 'Esperando refacción',
});

// Fuentes de aviso por rol (FR-009 a FR-011). MECHANIC solo recibe órdenes
// detenidas de sus órdenes asignadas.
const SOURCES_BY_ROLE = Object.freeze({
  ADMIN: ['maintenance', 'appointments', 'stock', 'stalledOrders'],
  RECEPTIONIST: ['maintenance', 'appointments', 'stalledOrders'],
  MECHANIC: ['stalledOrders'],
});

function sourcesFor(role) {
  return SOURCES_BY_ROLE[role] ?? [];
}

// M2: la detección de citas vencidas solo corre para roles con avisos de cita.
export function shouldMarkExpiredAppointments(role) {
  return sourcesFor(role).includes('appointments');
}

// `YYYY-MM-DDTHH:MM` local desde un Date (fecha de referencia con hora).
function toLocalMinute(date) {
  return toDbDateTimeLocal(new Date(date)).slice(0, 16).replace(' ', 'T');
}

function notice(type, key, description, referenceDate, destination) {
  return {
    clave: key,
    tipo: type,
    titulo: NOTICE_TITLES[type],
    descripcion: description,
    fechaReferencia: referenceDate,
    leido: false,
    destino: destination,
  };
}

async function maintenanceNotices(today) {
  const { rows } = await listMaintenance();
  const notices = [];
  for (const row of rows) {
    const state = calcMaintenanceState(row, today, row.vehicleCurrentMileage);
    if (state === MAINTENANCE_STATES.NORMAL) continue;
    const type = state === MAINTENANCE_STATES.VENCIDO ? NOTICE_TYPES.MANT_VENCIDO : NOTICE_TYPES.MANT_PROXIMO;
    notices.push(
      notice(
        type,
        noticeKey.maintenance(state, row.id, maintenanceTarget(row)),
        `${row.serviceType} · ${row.vehicleLabel} (${row.plates})`,
        row.targetDate ?? today,
        { pantalla: 'VEHICULO', id: row.vehicleId },
      ),
    );
  }
  return notices;
}

async function appointmentNotices(today, current, role) {
  if (shouldMarkExpiredAppointments(role)) {
    await markExpiredAppointmentsOn(today, toDbTimeLocal(current));
  }
  const rows = await listActiveAppointmentsOn(today);
  return rows.map((row) =>
    notice(
      NOTICE_TYPES.CITA_HOY,
      noticeKey.appointmentToday(row.id, today),
      `${row.time} · ${row.clientName} · ${row.vehicleLabel}`,
      `${today}T${row.time}`,
      { pantalla: 'CITAS', id: row.id, fecha: today },
    ),
  );
}

async function stockNotices(today) {
  const rows = await listLowStockParts();
  return rows.map((row) => {
    const soldOut = row.stockCurrent === 0;
    return notice(
      soldOut ? NOTICE_TYPES.STOCK_AGOTADO : NOTICE_TYPES.STOCK_BAJO,
      noticeKey.stock(row.id, soldOut),
      `${row.code} · ${row.name} · Existencia ${row.stockCurrent} · mínimo ${row.stockMin}`,
      today,
      { pantalla: 'REFACCION', id: row.id },
    );
  });
}

async function stalledOrderNotices(current, user) {
  const days = config.notifications.stalledOrderDays;
  const cutoff = toDbDateTimeLocal(new Date(current.getTime() - days * 24 * 60 * 60 * 1000));
  const rows = await listStalledOrders({
    cutoff,
    mechanicId: user.role === 'MECHANIC' ? user.id : null,
  });
  return rows.map((row) => {
    const sinCambio = daysWithoutChange(row.reference, current);
    return notice(
      NOTICE_TYPES.ORDEN_DETENIDA,
      noticeKey.stalledOrder(row.id, row.status),
      `Orden #${row.id} · ${row.vehicleLabel} (${row.plates}) · ${ORDER_STATUS_TEXT[row.status]} · ${sinCambio} días sin cambio`,
      toLocalMinute(row.reference),
      { pantalla: 'ORDEN', id: row.id },
    );
  });
}

// Avisos del usuario sin agrupar, con `leido` resuelto.
async function collectNotices(user) {
  const current = now();
  const today = toIsoDate(current);
  const sources = sourcesFor(user.role);
  const notices = [];
  if (sources.includes('maintenance')) notices.push(...(await maintenanceNotices(today)));
  if (sources.includes('appointments')) {
    notices.push(...(await appointmentNotices(today, current, user.role)));
  }
  if (sources.includes('stock')) notices.push(...(await stockNotices(today)));
  if (sources.includes('stalledOrders')) notices.push(...(await stalledOrderNotices(current, user)));

  const read = await listReadKeys(user.id);
  for (const item of notices) item.leido = read.has(item.clave);
  return notices;
}

// Agrupación del panel (FR-007a): grupos en orden fijo, sin grupos vacíos; no
// leídos primero y luego por fecha de referencia ascendente.
export function groupNotices(notices) {
  const byType = new Map(NOTICE_GROUP_ORDER.map((type) => [type, []]));
  for (const item of notices) byType.get(item.tipo)?.push(item);

  const grupos = [];
  for (const [tipo, avisos] of byType) {
    if (avisos.length === 0) continue;
    avisos.sort(
      (a, b) =>
        Number(a.leido) - Number(b.leido) ||
        String(a.fechaReferencia).localeCompare(String(b.fechaReferencia)) ||
        a.clave.localeCompare(b.clave),
    );
    grupos.push({
      tipo,
      titulo: GROUP_TITLES[tipo],
      cantidad: avisos.length,
      noLeidos: avisos.filter((a) => !a.leido).length,
      avisos,
    });
  }
  return {
    noLeidos: notices.filter((a) => !a.leido).length,
    totalAvisos: notices.length,
    grupos,
  };
}

export async function getNotifications(user) {
  return groupNotices(await collectNotices(user));
}

export async function countUnread(user) {
  const notices = await collectNotices(user);
  return { noLeidos: notices.filter((a) => !a.leido).length };
}

// FR-030: solo se guarda si la clave está entre los avisos actuales del
// usuario; si no, no se guarda nada y no se informa (no revela existencia).
export async function markRead(user, key) {
  const notices = await collectNotices(user);
  if (notices.some((item) => item.clave === key)) {
    await insertRead(user.id, key);
  }
}
