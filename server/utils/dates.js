// Utilidades de fecha compartidas (Sprint 6, T009). Fecha local del servidor en
// `YYYY-MM-DD`, la misma convención que MySQL con timezone 'local' (R-11 del
// Sprint 3). Usan el reloj de utils/clock.js.
import { now } from './clock.js';

const pad = (number) => String(number).padStart(2, '0');

export function toIsoDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function todayIso() {
  return toIsoDate(now());
}

// `YYYY-MM-DD HH:MM:SS` local, para comparar con columnas DATETIME.
export function toDbDateTimeLocal(date) {
  return `${toIsoDate(date)} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

// `HH:MM:SS` local, para comparar con columnas TIME.
export function toDbTimeLocal(date) {
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}
