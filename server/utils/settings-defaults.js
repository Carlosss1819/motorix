// Valores de respaldo de la configuración del taller (Sprint 7, US1/US2).
// Son los que estaban fijos en el código antes del sprint (la constante TALLER
// de ticket.service.js y DEFAULT_ADVANCE_* de maintenance-status.js): se usan
// cuando una clave no tiene fila en la tabla settings (FR-003, CA-3), así que
// una instalación sin configurar sigue funcionando igual.
import { DEFAULT_ADVANCE_DAYS, DEFAULT_ADVANCE_KM } from './maintenance-status.js';

export const SETTING_KEYS = Object.freeze({
  shopName: 'shop.name',
  shopAddress: 'shop.address',
  shopPhone: 'shop.phone',
  advanceDays: 'maintenance.advance_days',
  advanceKm: 'maintenance.advance_km',
});

export const SETTINGS_DEFAULTS = Object.freeze({
  [SETTING_KEYS.shopName]: 'Motorix',
  [SETTING_KEYS.shopAddress]: 'Av. Ejemplo 123, Col. Centro',
  [SETTING_KEYS.shopPhone]: '55-0000-0000',
  [SETTING_KEYS.advanceDays]: String(DEFAULT_ADVANCE_DAYS),
  [SETTING_KEYS.advanceKm]: String(DEFAULT_ADVANCE_KM),
});

// Entero positivo guardado como texto; cualquier otro valor usa el respaldo.
function toPositiveInt(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : Number(fallback);
}

function textOr(value, fallback) {
  return typeof value === 'string' && value.trim() ? value : fallback;
}

// Combina las filas guardadas ({ clave: valor }) con el respaldo y devuelve el
// formato del contrato (specs/007-reportes-configuracion/contracts/settings.md).
export function resolveSettings(saved = {}) {
  return {
    taller: {
      nombre: textOr(saved[SETTING_KEYS.shopName], SETTINGS_DEFAULTS[SETTING_KEYS.shopName]),
      direccion: textOr(saved[SETTING_KEYS.shopAddress], SETTINGS_DEFAULTS[SETTING_KEYS.shopAddress]),
      telefono: textOr(saved[SETTING_KEYS.shopPhone], SETTINGS_DEFAULTS[SETTING_KEYS.shopPhone]),
    },
    mantenimiento: {
      antelacionDias: toPositiveInt(saved[SETTING_KEYS.advanceDays], SETTINGS_DEFAULTS[SETTING_KEYS.advanceDays]),
      antelacionKm: toPositiveInt(saved[SETTING_KEYS.advanceKm], SETTINGS_DEFAULTS[SETTING_KEYS.advanceKm]),
    },
  };
}
