// Autenticación por JWT: verifica token, inactividad, vigencia de la sesión y estado
// activo del usuario en CADA petición. El rol y el estado se consultan en cada request
// (R-02 y RN-15), de modo que una desactivación o cambio de rol surte efecto inmediato
// (especificación, aclaración Q2).
import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import { findById as findUserById } from '../models/user.js';
import { sendError } from '../utils/response.js';
import * as sessionStore from '../utils/sessionStore.js';
import { hasPendingTerms } from '../services/terms.service.js';

// Sprint 7 (US9, FR-020): con la aceptación de la versión vigente pendiente,
// solo se permiten estas operaciones; todo lo demás responde
// 403 TERMINOS_PENDIENTES (contracts/terms.md).
const TERMS_ALLOWLIST = new Set([
  'GET /api/auth/me',
  'POST /api/auth/logout',
  'GET /api/terms/current',
  'POST /api/terms/accept',
]);

function routeKey(req) {
  const path = (req.originalUrl ?? '').split('?')[0].replace(/\/+$/, '');
  return `${req.method} ${path}`;
}

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

    if (!TERMS_ALLOWLIST.has(routeKey(req)) && (await hasPendingTerms(user.id))) {
      return sendError(
        res,
        403,
        'Debe aceptar los términos y condiciones y el aviso de privacidad para continuar',
        'TERMINOS_PENDIENTES',
      );
    }
    return next();
  } catch (error) {
    return next(error);
  }
}
