// Controlador del catalogo de refacciones (US5, Sprint 3).
import * as service from '../services/part.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listPartsHandler(req, res) {
  sendOk(res, await service.list(req.query));
}

export async function getPartHandler(req, res) {
  sendOk(res, await service.getById(Number(req.params.id)));
}

export async function getPartMovementsHandler(req, res) {
  sendOk(res, await service.listMovements(Number(req.params.id), req.query));
}

export async function createPartMovementHandler(req, res) {
  sendCreated(
    res,
    await service.registerMovement(Number(req.params.id), req.body, req.user),
  );
}

export async function createPartHandler(req, res) {
  sendCreated(res, await service.create(req.body, req.user));
}

export async function updatePartHandler(req, res) {
  sendOk(res, await service.update(Number(req.params.id), req.body));
}

export async function deactivatePartHandler(req, res) {
  sendOk(res, await service.deactivate(Number(req.params.id)));
}
