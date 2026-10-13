// Controlador de usuarios (gestion de cuentas, solo ADMIN; la lista de
// mecánicos activos también la usa recepción para asignar órdenes, FR-009).
import { list, listMechanics, create, update } from '../services/user.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listUsersHandler(req, res) {
  sendOk(res, await list());
}

export async function listMechanicsHandler(req, res) {
  sendOk(res, await listMechanics());
}

export async function createUserHandler(req, res) {
  const { username, email, rol, contrasena: password } = req.body;
  const user = await create({ username, email, rol, contrasena: password });
  sendCreated(res, user);
}

export async function updateUserHandler(req, res) {
  const { id } = req.params;
  const { rol, estado: statusApi } = req.body;
  const user = await update(Number(id), { rol, estado: statusApi });
  sendOk(res, user);
}
