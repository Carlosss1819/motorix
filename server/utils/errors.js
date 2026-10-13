// Error HTTP propio para traducir excepciones de negocio a respuestas con codigo apropiado.
export class HttpError extends Error {
  // `extra` permite agregar campos de negocio al cuerpo del error (por ejemplo
  // pendienteConfirmacion/confirmarReenvio en el conflicto de horario de citas).
  constructor(status, message, code, extra) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
    if (extra) this.extra = extra;
  }
}

export const badRequest = (message, code = 'VALIDACION') =>
  new HttpError(400, message, code);

export const unauthorized = (message, code = 'NO_AUTENTICADO') =>
  new HttpError(401, message, code);

export const forbidden = (message, code = 'ROL_NO_AUTORIZADO') =>
  new HttpError(403, message, code);

export const notFound = (message, code = 'NO_ENCONTRADO') =>
  new HttpError(404, message, code);

export const conflict = (message, code = 'CONFLICTO', extra) =>
  new HttpError(409, message, code, extra);

export const locked = (message, code = 'CUENTA_BLOQUEADA') =>
  new HttpError(423, message, code);
