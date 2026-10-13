// Middleware centralizado de errores (Principio VI).
// Nunca expone trazas internas ni stack traces al usuario final (Principio IV).
import { HttpError } from '../utils/errors.js';
import { sendError } from '../utils/response.js';

export function notFoundHandler(req, res) {
  sendError(res, 404, 'Recurso no encontrado', 'NO_ENCONTRADO');
}

export function errorHandler(error, req, res, next) {
  if (res.headersSent) return next(error);

  if (error instanceof HttpError) {
    return sendError(res, error.status, error.message, error.code, error.extra);
  }

  if (error?.type === 'entity.parse.failed') {
    return sendError(res, 400, 'El cuerpo de la petición no es JSON válido', 'JSON_INVALIDO');
  }

  // El detalle del error solo se registra en el servidor, jamas se devuelve al cliente.
  console.error('[error]', new Date().toISOString(), error);
  sendError(res, 500, 'Error interno del servidor', 'ERROR_INTERNO');
}
