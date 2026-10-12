// Autorizacion por rol: se verifica en el backend en cada endpoint protegido
// (RN-5 y RN-15: ocultar botones en el frontend no es seguridad suficiente).
import { sendError } from '../utils/response.js';

export function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return sendError(res, 401, 'Debe iniciar sesión para acceder', 'SESION_REQUERIDA');
    }
    if (!roles.includes(req.user.role)) {
      return sendError(res, 403, 'No tiene permiso para realizar esta operación', 'ROL_NO_AUTORIZADO');
    }
    return next();
  };
}
