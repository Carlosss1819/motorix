// Controlador de autenticación: traduce HTTP <-> servicios. Sin logica de negocio.
import { login, changePassword } from '../services/auth.service.js';
import { sendOk } from '../utils/response.js';
import * as sessionStore from '../utils/sessionStore.js';

export async function loginHandler(req, res) {
  const { identificador: identifier, contrasena: password } = req.body;
  const result = await login(identifier, password);
  sendOk(res, result);
}

export async function logoutHandler(req, res) {
  sessionStore.close(req.user.sessionId);
  sendOk(res, { mensaje: 'Sesión cerrada' });
}

export async function meHandler(req, res) {
  sendOk(res, {
    id: req.user.id,
    username: req.user.username,
    email: req.user.email,
    rol: req.user.role,
  });
}

export async function changePasswordHandler(req, res) {
  const { actual, nueva } = req.body;
  const result = await changePassword(req.user.id, actual, nueva);
  sendOk(res, result);
}
