// Respuestas JSON consistentes para toda la API (Principio VI de la constitucion).
// Formato de error: { error: { mensaje, codigo } } con mensajes en español.

export function sendOk(res, data) {
  res.status(200).json(data);
}

export function sendCreated(res, data) {
  res.status(201).json(data);
}

export function sendNoContent(res) {
  res.status(204).end();
}

export function sendError(res, status, mensaje, codigo) {
  res.status(status).json({ error: { mensaje, codigo } });
}
