// Claves de los avisos internos y de los hechos de «Clientes por avisar»
// (Sprint 6, R-05). Funciones puras, sin base de datos.
//
// Aviso = tipo + objeto + estado (FR-015): si el aviso empeora (de Próximo a
// Vencido, de Bajo a Agotado) o el objeto cambia de estado, la clave cambia y
// el aviso vuelve a mostrarse como no leído.
// Hecho = orden, cita o mantenimiento con su objetivo vigente (FR-021): cada
// mantenimiento es un solo registro que se actualiza al hacer el servicio, así
// que el objetivo distingue un ciclo del siguiente.

export const NOTICE_KEY_MAX_LENGTH = 120;

// Tipos de aviso en el orden fijo de los grupos del panel (FR-007a).
export const NOTICE_TYPES = Object.freeze({
  MANT_VENCIDO: 'MANT_VENCIDO',
  ORDEN_DETENIDA: 'ORDEN_DETENIDA',
  STOCK_AGOTADO: 'STOCK_AGOTADO',
  STOCK_BAJO: 'STOCK_BAJO',
  CITA_HOY: 'CITA_HOY',
  MANT_PROXIMO: 'MANT_PROXIMO',
});

export const NOTICE_GROUP_ORDER = Object.freeze(Object.values(NOTICE_TYPES));

const DATE = '\\d{4}-\\d{2}-\\d{2}';
const TARGET = `(?:${DATE}|-)\\|(?:\\d+|-)`;

const NOTICE_PATTERNS = [
  [new RegExp(`^(MANT_PROXIMO|MANT_VENCIDO):(\\d+):${TARGET}$`)],
  [/^(STOCK_BAJO|STOCK_AGOTADO):(\d+)$/],
  [new RegExp(`^(CITA_HOY):(\\d+):${DATE}$`)],
  [/^(ORDEN_DETENIDA):(\d+):(?:RECIBIDO|DIAGNOSTICO|EN_REPARACION|ESPERANDO_REFACCION)$/],
];

const FACT_PATTERNS = [
  /^(ORDEN):(\d+)$/,
  /^(CITA):(\d+)$/,
  new RegExp(`^(MANT):(\\d+):${TARGET}$`),
];

// Objetivo vigente del mantenimiento: `<fecha objetivo o ->|<km objetivo o ->`.
export function maintenanceTarget({ targetDate, targetMileage }) {
  return `${targetDate ?? '-'}|${targetMileage ?? '-'}`;
}

export const noticeKey = Object.freeze({
  // state: 'PROXIMO' | 'VENCIDO'
  maintenance: (state, id, target) => `MANT_${state}:${id}:${target}`,
  stock: (id, soldOut) => `${soldOut ? 'STOCK_AGOTADO' : 'STOCK_BAJO'}:${id}`,
  appointmentToday: (id, date) => `CITA_HOY:${id}:${date}`,
  stalledOrder: (id, status) => `ORDEN_DETENIDA:${id}:${status}`,
});

export const factKey = Object.freeze({
  order: (id) => `ORDEN:${id}`,
  appointment: (id) => `CITA:${id}`,
  maintenance: (id, target) => `MANT:${id}:${target}`,
});

// `{ type, id }` si la clave tiene un formato de aviso válido; si no, null.
export function parseNoticeKey(key) {
  if (typeof key !== 'string' || key.length > NOTICE_KEY_MAX_LENGTH) return null;
  for (const [pattern] of NOTICE_PATTERNS) {
    const match = pattern.exec(key);
    if (match) return { type: match[1], id: Number(match[2]) };
  }
  return null;
}

// `{ kind, id }` si la clave tiene un formato de hecho válido; si no, null.
export function parseFactKey(key) {
  if (typeof key !== 'string' || key.length > NOTICE_KEY_MAX_LENGTH) return null;
  for (const pattern of FACT_PATTERNS) {
    const match = pattern.exec(key);
    if (match) return { kind: match[1], id: Number(match[2]) };
  }
  return null;
}
