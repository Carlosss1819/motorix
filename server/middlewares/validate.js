// Middleware de validación de payloads con esquemas zod (Principio VI).
// Los mensajes de validación llegan en español desde los esquemas de validators/.
import { sendError } from '../utils/response.js';

export function validate(schema, source = 'body') {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const messages = result.error.issues.map((issue) => issue.message).join(' ');
      return sendError(res, 400, messages || 'Datos inválidos', 'VALIDACION');
    }
    req[source] = result.data;
    return next();
  };
}
