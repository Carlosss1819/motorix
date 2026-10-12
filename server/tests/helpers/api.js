// Cliente HTTP único para las pruebas, usando la app Express real (sin servidor).
import request from 'supertest';
import { app } from '../../app.js';

export const api = request(app);

export async function loginAs(identifier, password) {
  const response = await api
    .post('/api/auth/login')
    .send({ identificador: identifier, contrasena: password });
  if (response.status !== 200) {
    throw new Error(
      `No se pudo iniciar sesión con '${identifier}': ${response.status} ${JSON.stringify(response.body)}`,
    );
  }
  return response.body.token;
}

export function bearer(token) {
  return { Authorization: `Bearer ${token}` };
}
