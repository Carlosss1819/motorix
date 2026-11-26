// Controlador de la configuración del taller (Sprint 7). Sin lógica de negocio.
import { getSettings, updateSettings } from '../services/settings.service.js';
import { sendOk } from '../utils/response.js';

export async function getSettingsHandler(req, res) {
  sendOk(res, await getSettings());
}

export async function updateSettingsHandler(req, res) {
  sendOk(res, await updateSettings(req.body, req.user));
}
