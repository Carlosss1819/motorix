// Controlador de usuarios (gestion de cuentas, solo ADMIN).
import { list, create, update } from '../services/user.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function listUsersHandler(req, res) {
  sendOk(res, await list());
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
