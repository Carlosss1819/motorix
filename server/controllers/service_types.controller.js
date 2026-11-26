// Controlador del catálogo de tipos de servicio (Sprint 7). Sin lógica de negocio.
import { list, create, update, setActive } from '../services/service_type.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listServiceTypesHandler(req, res) {
  sendOk(res, await list(req.query, req.user.role));
}

export async function createServiceTypeHandler(req, res) {
  sendCreated(res, await create(req.body, req.user));
}

export async function updateServiceTypeHandler(req, res) {
  sendOk(res, await update(Number(req.params.id), req.body, req.user));
}

export async function deactivateServiceTypeHandler(req, res) {
  sendOk(res, await setActive(Number(req.params.id), false, req.user));
}

export async function activateServiceTypeHandler(req, res) {
  sendOk(res, await setActive(Number(req.params.id), true, req.user));
}
