// Controlador de clientes.
import { list, getById, create, update } from '../services/client.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listClientsHandler(req, res) {
  sendOk(res, await list(req.query.buscar));
}

export async function getClientHandler(req, res) {
  sendOk(res, await getById(Number(req.params.id)));
}

export async function createClientHandler(req, res) {
  const result = await create(req.body);
  if (result.pendienteConfirmacion) {
    // Teléfono repetido: aviso con confirmación, sin crear el registro aun (R-05).
    sendOk(res, { aviso: result.aviso, confirmarReenvio: result.confirmarReenvio });
    return;
  }
  sendCreated(res, result.cliente);
}

export async function updateClientHandler(req, res) {
  sendOk(res, await update(Number(req.params.id), req.body));
}
