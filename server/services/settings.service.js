// Lógica de negocio de la configuración del taller (Sprint 7, US1/US2).
// - Solo ADMIN la consulta y modifica (la ruta lo valida, FR-006).
// - Sin fila guardada se usa el respaldo del código (FR-003, CA-3).
// - Cada guardado queda en la bitácora (CONFIG_ACTUALIZADA, FR-022).
import { findAllSettings, saveSettings } from '../models/settings.js';
import { resolveSettings, SETTING_KEYS } from '../utils/settings-defaults.js';
import { record } from './audit.service.js';

// Solo para pruebas y en el mismo proceso: superpone valores sin tocar la base
// que comparten las suites que corren en paralelo.
let overrides = null;
export function setSettingsOverridesForTests(value) {
  overrides = value ?? null;
}

function applyOverrides(settings) {
  if (!overrides) return settings;
  return {
    taller: { ...settings.taller, ...(overrides.taller ?? {}) },
    mantenimiento: { ...settings.mantenimiento, ...(overrides.mantenimiento ?? {}) },
  };
}

export async function getSettings() {
  return applyOverrides(resolveSettings(await findAllSettings()));
}

export async function getShopData() {
  return (await getSettings()).taller;
}

export async function getMaintenanceDefaults() {
  return (await getSettings()).mantenimiento;
}

const FIELD_TO_KEY = Object.freeze({
  nombreTaller: SETTING_KEYS.shopName,
  direccionTaller: SETTING_KEYS.shopAddress,
  telefonoTaller: SETTING_KEYS.shopPhone,
  antelacionDias: SETTING_KEYS.advanceDays,
  antelacionKm: SETTING_KEYS.advanceKm,
});

export async function updateSettings(data, user) {
  const entries = {};
  for (const [field, key] of Object.entries(FIELD_TO_KEY)) {
    if (data[field] !== undefined) entries[key] = data[field];
  }
  await saveSettings(entries, user.id);
  await record({
    userId: user.id,
    action: 'CONFIG_ACTUALIZADA',
    entityType: 'settings',
    detail: `Claves: ${Object.keys(entries).join(', ')}`,
  });
  return getSettings();
}
