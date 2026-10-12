// Envuelve controladores asincronos para propagar errores al middleware centralizado
// (Express 4 no las reenvia automaticamente).
export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
