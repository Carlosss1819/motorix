// Controlador de órdenes de servicio (US1).
import { list, getById, create, update } from '../services/service_order.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listServiceOrdersHandler(req, res) {
  sendOk(res, await list(req.query, req.user));
}

export async function getServiceOrderHandler(req, res) {
  sendOk(res, await getById(Number(req.params.id), req.user));
}

export async function createServiceOrderHandler(req, res) {
  sendCreated(res, await create(req.body, req.user));
}

export async function updateServiceOrderHandler(req, res) {
  sendOk(res, await update(Number(req.params.id), req.body, req.user));
}
