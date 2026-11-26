// Propuesta del próximo servicio a partir del intervalo de un tipo del
// catálogo (Sprint 7, US3/US8, FR-011 y FR-012). Función pura, sin base de
// datos, para probarla en unidad. RN-11/RN-12: la fecha y el kilometraje salen
// del intervalo configurado del tipo, nunca de valores universales.
import { addDays } from './maintenance-status.js';

// tipo: { intervaloDias, intervaloKm } (cualquiera puede ser null).
// fechaBase: 'AAAA-MM-DD'; kmBase: entero (puede ser null).
export function proposeNextService(tipo, fechaBase, kmBase) {
  const dias = tipo?.intervaloDias ?? null;
  const km = tipo?.intervaloKm ?? null;
  return {
    fecha: dias && fechaBase ? addDays(fechaBase, dias) : null,
    kilometraje: km && kmBase !== null && kmBase !== undefined ? Number(kmBase) + km : null,
  };
}
