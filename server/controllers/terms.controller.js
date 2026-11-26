// Controlador de términos y aviso de privacidad (Sprint 7). Sin lógica de negocio.
import { getCurrent, accept, acceptances } from '../services/terms.service.js';
import { sendOk } from '../utils/response.js';

export async function getCurrentTermsHandler(req, res) {
  sendOk(res, await getCurrent(req.user.id));
}

export async function acceptTermsHandler(req, res) {
  sendOk(res, await accept(req.body.version, req.user));
}

export async function listAcceptancesHandler(req, res) {
  sendOk(res, await acceptances(req.query));
}
