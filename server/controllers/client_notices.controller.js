// Controladores de «Clientes por avisar» (Sprint 6, US7).
import { listClientNotices, markNotified } from '../services/client_notice.service.js';
import { sendCreated, sendOk } from '../utils/response.js';

export async function listClientNoticesHandler(req, res) {
  sendOk(res, await listClientNotices());
}

export async function markNotifiedHandler(req, res) {
  sendCreated(res, await markNotified(req.user, req.body.clave));
}
