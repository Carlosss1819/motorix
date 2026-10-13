// Controlador de citas de recepcion (US2).
import {
  list,
  getById,
  create,
  update,
  cancel,
  receive,
} from '../services/appointment.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listAppointmentsHandler(req, res) {
  sendOk(res, await list(req.query));
}

export async function getAppointmentHandler(req, res) {
  sendOk(res, await getById(Number(req.params.id)));
}

export async function createAppointmentHandler(req, res) {
  sendCreated(res, await create(req.body, req.user));
}

export async function updateAppointmentHandler(req, res) {
  sendOk(res, await update(Number(req.params.id), req.body));
}

export async function cancelAppointmentHandler(req, res) {
  sendOk(res, await cancel(Number(req.params.id), req.body));
}

export async function receiveAppointmentHandler(req, res) {
  sendOk(res, await receive(Number(req.params.id)));
}
