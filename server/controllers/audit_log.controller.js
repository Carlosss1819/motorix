// Controlador de la bitácora (Sprint 7, US10). Solo consulta.
import { list } from '../services/audit.service.js';
import { sendOk } from '../utils/response.js';

export async function listAuditLogHandler(req, res) {
  sendOk(res, await list(req.query));
}
