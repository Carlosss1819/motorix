// Controlador de órdenes de servicio (US1; la US3 agrega la asignación, la
// US4 el contenido y la US5 las transiciones de estado).
import {
  list,
  getById,
  create,
  update,
  assign,
  saveDiagnosis,
  addService,
  removeService,
  addPart,
  removePart,
  saveRecommendations,
  changeStatus,
} from '../services/service_order.service.js';
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

export async function assignServiceOrderHandler(req, res) {
  sendOk(res, await assign(Number(req.params.id), req.body, req.user));
}

export async function saveDiagnosisHandler(req, res) {
  sendOk(res, await saveDiagnosis(Number(req.params.id), req.body, req.user));
}

export async function addServiceHandler(req, res) {
  sendCreated(res, await addService(Number(req.params.id), req.body, req.user));
}

export async function removeServiceHandler(req, res) {
  sendOk(
    res,
    await removeService(Number(req.params.id), Number(req.params.servicioId), req.user),
  );
}

export async function addPartHandler(req, res) {
  sendCreated(res, await addPart(Number(req.params.id), req.body, req.user));
}

export async function removePartHandler(req, res) {
  sendOk(
    res,
    await removePart(Number(req.params.id), Number(req.params.repuestoId), req.user),
  );
}

export async function saveRecommendationsHandler(req, res) {
  sendOk(res, await saveRecommendations(Number(req.params.id), req.body, req.user));
}

export async function changeServiceOrderStatusHandler(req, res) {
  sendOk(res, await changeStatus(Number(req.params.id), req.body, req.user));
}
