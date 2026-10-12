// Autenticación por JWT: verifica token, inactividad, vigencia de la sesión y estado
// activo del usuario en CADA petición. El rol y el estado se consultan en cada request
// (R-02 y RN-15), de modo que una desactivación o cambio de rol surte efecto inmediato
// (especificación, aclaración Q2).
import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import { findById as findUserById } from '../models/user.js';
import { sendError } from '../utils/response.js';
import * as sessionStore from '../utils/sessionStore.js';

export async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return sendError(res, 401, 'Debe iniciar sesión para acceder', 'SESION_REQUERIDA');
    }

    let payload;
    try {
      payload = jwt.verify(token, config.jwt.secret);
    } catch {
      return sendError(res, 401, 'La sesión es inválida o ha expirado', 'SESION_INVALIDA');
    }

    // Primero el estado de la cuenta: una desactivación debe responder
    // CUENTA_INACTIVA (la sesión se cerró justo al desactivar).
    const user = await findUserById(payload.sub);
    if (!user) {
      return sendError(res, 401, 'La sesión es inválida o ha expirado', 'SESION_INVALIDA');
    }

    if (user.status !== 'ACTIVE') {
      sessionStore.closeAllForUser(user.id);
      return sendError(res, 401, 'La cuenta está desactivada', 'CUENTA_INACTIVA');
    }

    if (!payload.jti || sessionStore.isIdle(payload.jti)) {
      return sendError(res, 401, 'La sesión se cerró o expiró', 'SESION_INVALIDA');
    }

    req.user = {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      sessionId: payload.jti,
    };
    sessionStore.touch(user.id, payload.jti);
    return next();
  } catch (error) {
    return next(error);
  }
}
