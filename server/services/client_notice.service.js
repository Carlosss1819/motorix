// «Clientes por avisar» (Sprint 6, US7, FR-019 a FR-023, FR-029). La lista se
// calcula al consultar; marcar un hecho como avisado guarda quién y cuándo,
// una sola vez por hecho (orden, cita o mantenimiento con su objetivo).
import {
  insertNotice,
  findNoticeByFactKey,
  listActiveAppointmentsWithPhoneOn,
  listMaintenanceWithClient,
  listNoticedFactKeys,
  listReadyOrders,
} from '../models/client_notice.js';
import { calcMaintenanceState, MAINTENANCE_STATES } from '../utils/maintenance-status.js';
import { now } from '../utils/clock.js';
import { toDbDateTimeLocal, toIsoDate } from '../utils/dates.js';
import { factKey, maintenanceTarget } from '../utils/notice-keys.js';
import { conflict, notFound } from '../utils/errors.js';

export const REASONS = Object.freeze({
  VEHICULO_LISTO: 'Vehículo listo',
  CITA_MANANA: 'Cita de mañana',
  MANT_VENCIDO: 'Mantenimiento vencido',
  MANT_PROXIMO: 'Mantenimiento próximo',
});

// Orden de la lista por motivo (FR-029).
const REASON_ORDER = Object.keys(REASONS);

function item({ key, reason, row, date, destination }) {
  return {
    clave: key,
    motivo: reason,
    motivoTexto: REASONS[reason],
    cliente: { id: row.clientId, nombre: row.clientName, telefono: row.clientPhone },
    vehiculo: { id: row.vehicleId, descripcion: row.vehicleLabel, placas: row.plates },
    fecha: date,
    destino: destination,
  };
}

// Todos los hechos vigentes, sin excluir los ya avisados.
async function currentFacts() {
  const current = now();
  const today = toIsoDate(current);
  const tomorrowDate = new Date(current);
  tomorrowDate.setDate(tomorrowDate.getDate() + 1);
  const tomorrow = toIsoDate(tomorrowDate);

  const facts = [];
  for (const row of await listReadyOrders()) {
    facts.push(
      item({
        key: factKey.order(row.id),
        reason: 'VEHICULO_LISTO',
        row,
        date: row.date,
        destination: { pantalla: 'ORDEN', id: row.id },
      }),
    );
  }
  for (const row of await listActiveAppointmentsWithPhoneOn(tomorrow)) {
    facts.push(
      item({
        key: factKey.appointment(row.id),
        reason: 'CITA_MANANA',
        row,
        date: row.date,
        destination: { pantalla: 'CITAS', id: row.id, fecha: tomorrow },
      }),
    );
  }
  for (const row of await listMaintenanceWithClient()) {
    const state = calcMaintenanceState(row, today, row.vehicleCurrentMileage);
    if (state === MAINTENANCE_STATES.NORMAL) continue;
    facts.push(
      item({
        key: factKey.maintenance(row.id, maintenanceTarget(row)),
        reason: state === MAINTENANCE_STATES.VENCIDO ? 'MANT_VENCIDO' : 'MANT_PROXIMO',
        row,
        date: row.targetDate ?? today,
        destination: { pantalla: 'VEHICULO', id: row.vehicleId },
      }),
    );
  }
  return facts;
}

export async function listClientNotices() {
  const noticed = await listNoticedFactKeys();
  const elementos = (await currentFacts())
    .filter((fact) => !noticed.has(fact.clave))
    .sort(
      (a, b) =>
        REASON_ORDER.indexOf(a.motivo) - REASON_ORDER.indexOf(b.motivo) ||
        String(a.fecha).localeCompare(String(b.fecha)) ||
        a.clave.localeCompare(b.clave),
    );
  return { elementos, total: elementos.length };
}

function toApiNotice(row) {
  return {
    id: row.id,
    clave: row.fact_key,
    motivo: row.reason,
    clienteId: row.client_id,
    avisadoPor: { id: row.notified_by, nombre: row.username },
    // Hora local del servidor (como la guarda MySQL), no UTC (H-S6-06).
    avisadoEn: toDbDateTimeLocal(new Date(row.notified_at)).replace(' ', 'T'),
  };
}

// FR-020: un hecho se marca una sola vez (409 YA_AVISADO); un hecho que no
// está en la lista actual responde 404 HECHO_NO_VIGENTE.
export async function markNotified(user, key) {
  if (await findNoticeByFactKey(key)) {
    throw conflict('Este cliente ya fue avisado por este motivo', 'YA_AVISADO');
  }
  const fact = (await currentFacts()).find((f) => f.clave === key);
  if (!fact) {
    throw notFound(
      'El aviso ya no está vigente: recarga la lista de clientes por avisar',
      'HECHO_NO_VIGENTE',
    );
  }
  const row = await insertNotice({
    clientId: fact.cliente.id,
    reason: fact.motivo,
    factKey: key,
    notifiedBy: user.id,
  });
  return toApiNotice(row);
}
