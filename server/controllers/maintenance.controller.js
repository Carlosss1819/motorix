// Controlador de mantenimientos preventivos (US3/US4, Sprint 3).
import * as service from '../services/maintenance.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listMaintenanceHandler(req, res) {
  sendOk(res, await service.list(req.query));
}

export async function getMaintenanceHandler(req, res) {
  sendOk(res, await service.getById(Number(req.params.id)));
}

export async function createMaintenanceHandler(req, res) {
  sendCreated(res, await service.create(req.body, req.user));
}

export async function updateMaintenanceHandler(req, res) {
  sendOk(res, await service.update(Number(req.params.id), req.body));
}

export async function realizarMaintenanceHandler(req, res) {
  sendOk(res, await service.realizar(Number(req.params.id), req.body, req.user));
}
