// Rango de fechas de los reportes (Sprint 7, Entrega B, FR-031, R-08).
// `desde` y `hasta` en `AAAA-MM-DD`, obligatorios, `desde <= hasta` y como
// máximo 366 días contando ambos extremos (un año bisiesto completo). Si algo
// falla se responde `400 RANGO_INVALIDO` con un mensaje claro.
// Las fechas son locales del servidor (hora de Ciudad de México, R-11 del
// Sprint 3): el rango cubre de `desde 00:00:00` a antes de `hasta + 1 día`.
import { HttpError } from './errors.js';

export const MAX_REPORT_DAYS = 366;

const PATRON_FECHA = /^(\d{4})-(\d{2})-(\d{2})$/;
const MS_POR_DIA = 24 * 60 * 60 * 1000;

function rangoInvalido(mensaje) {
  return new HttpError(400, mensaje, 'RANGO_INVALIDO');
}

// Fecha `AAAA-MM-DD` → milisegundos UTC del día, o `null` si no existe
// (por ejemplo 2026-02-30).
function parseFecha(valor) {
  if (typeof valor !== 'string') return null;
  const partes = PATRON_FECHA.exec(valor.trim());
  if (!partes) return null;
  const [anio, mes, dia] = partes.slice(1).map(Number);
  const ms = Date.UTC(anio, mes - 1, dia);
  const fecha = new Date(ms);
  if (fecha.getUTCFullYear() !== anio || fecha.getUTCMonth() !== mes - 1 || fecha.getUTCDate() !== dia) {
    return null;
  }
  return ms;
}

// Valida el rango y devuelve `{ desde, hasta, dias }` con las fechas
// normalizadas. Lanza `HttpError 400 RANGO_INVALIDO`.
export function parseReportRange({ desde, hasta } = {}) {
  if (desde === undefined || desde === null || desde === '' || hasta === undefined || hasta === null || hasta === '') {
    throw rangoInvalido('Indica la fecha inicial y la fecha final del reporte (AAAA-MM-DD).');
  }
  const inicio = parseFecha(desde);
  const fin = parseFecha(hasta);
  if (inicio === null || fin === null) {
    throw rangoInvalido('Las fechas del reporte deben ser fechas válidas con el formato AAAA-MM-DD.');
  }
  if (inicio > fin) {
    throw rangoInvalido('La fecha inicial no puede ser posterior a la fecha final.');
  }
  const dias = Math.round((fin - inicio) / MS_POR_DIA) + 1;
  if (dias > MAX_REPORT_DAYS) {
    throw rangoInvalido(`El rango del reporte no puede pasar de ${MAX_REPORT_DAYS} días (un año).`);
  }
  return { desde: desde.trim(), hasta: hasta.trim(), dias };
}
