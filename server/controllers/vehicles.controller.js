// Controlador de vehiculos.
import { list, getById, create, update } from '../services/vehicle.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listVehiclesHandler(req, res) {
  sendOk(res, await list({ search: req.query.buscar, clientId: req.query.clienteId }));
}

export async function getVehicleHandler(req, res) {
  sendOk(res, await getById(Number(req.params.id)));
}

export async function createVehicleHandler(req, res) {
  sendCreated(res, await create(req.body));
}

export async function updateVehicleHandler(req, res) {
  sendOk(res, await update(Number(req.params.id), req.body));
}
