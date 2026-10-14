// Controlador del panel de control (Sprint 4, US5).
import { getSummary } from '../services/dashboard.service.js';
import { sendOk } from '../utils/response.js';

export async function getDashboardHandler(req, res) {
  sendOk(res, await getSummary(req.query.fecha));
}
