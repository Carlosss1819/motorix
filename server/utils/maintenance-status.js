// Cálculo del estado del mantenimiento preventivo (US3, Sprint 3): el estado
// (normal/proximo/vencido) NO se persiste, se deriva en cada consulta de la
// fecha objetivo, del kilometraje objetivo y de la antelación propia del
// registro (R-04, FR-011, FR-012, clarificación 1). Es una función pura al
// estilo de order-transitions.js para probarla en unidad sin base de datos.
// Fuente de verdad: specs/003-historial-inventario/contracts/maintenance.md.

// Antelaciones por defecto cuando el registro no define las suyas.
export const DEFAULT_ADVANCE_DAYS = 30;
export const DEFAULT_ADVANCE_KM = 500;

export const MAINTENANCE_STATES = Object.freeze({
  NORMAL: 'NORMAL',
  PROXIMO: 'PROXIMO',
  VENCIDO: 'VENCIDO',
});

// Suma días a una fecha ISO `YYYY-MM-DD` (aritmética en UTC para no depender
// de la zona horaria del servidor).
export function addDays(iso, days) {
  const date = new Date(`${iso}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().substring(0, 10);
}

// Estado del mantenimiento el día `hoy` con el kilometraje vigente del
// vehículo. «Vence primero lo que se cumple»: basta con alcanzar el km o la
// fecha para VENCIDO; dentro de la antelación de cualquiera de los dos es
// PROXIMO; sin objetivos configurados es NORMAL (RN-12).
export function calcMaintenanceState(maintenance, hoy, kmActual) {
  const advanceDays = maintenance.advanceDays ?? DEFAULT_ADVANCE_DAYS;
  const advanceKm = maintenance.advanceKm ?? DEFAULT_ADVANCE_KM;

  let state = MAINTENANCE_STATES.NORMAL;

  // Por kilometraje (solo si el registro tiene objetivo de km).
  if (maintenance.targetMileage != null && kmActual != null) {
    if (kmActual >= maintenance.targetMileage) {
      return MAINTENANCE_STATES.VENCIDO;
    }
    if (kmActual >= maintenance.targetMileage - advanceKm) {
      state = MAINTENANCE_STATES.PROXIMO;
    }
  }

  // Por fecha (solo si el registro tiene fecha objetivo; las comparaciones de
  // fechas ISO `YYYY-MM-DD` son lexicográficas).
  if (maintenance.targetDate != null && hoy) {
    if (hoy >= maintenance.targetDate) {
      return MAINTENANCE_STATES.VENCIDO;
    }
    if (hoy >= addDays(maintenance.targetDate, -advanceDays)) {
      state = MAINTENANCE_STATES.PROXIMO;
    }
  }

  return state;
}
