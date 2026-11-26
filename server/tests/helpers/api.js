// Cliente HTTP único para las pruebas, usando la app Express real (sin servidor).
import request from 'supertest';
import { app } from '../../app.js';

export const api = request(app);

// Inicia sesión y, si el usuario tiene pendiente la versión vigente de los
// términos (Sprint 7, FR-020), la acepta por la API real para que las
// pruebas existentes no fallen con 403 TERMINOS_PENDIENTES (aclaración de la
// spec 007: «el helper deja a los usuarios de prueba con la aceptación
// vigente»). Las pruebas de términos usan `loginSinAceptar`.
export async function loginAs(identifier, password) {
  const body = await loginSinAceptar(identifier, password);
  if (body.terminosPendientes) {
    const vigente = await api
      .get('/api/terms/current')
      .set({ Authorization: `Bearer ${body.token}` });
    const aceptar = await api
      .post('/api/terms/accept')
      .set({ Authorization: `Bearer ${body.token}` })
      .send({ version: vigente.body.version });
    if (aceptar.status !== 200) {
      throw new Error(
        `No se pudieron aceptar los términos para '${identifier}': ${aceptar.status} ${JSON.stringify(aceptar.body)}`,
      );
    }
  }
  return body.token;
}

// Inicio de sesión sin aceptar los términos: devuelve el cuerpo completo.
export async function loginSinAceptar(identifier, password) {
  const response = await api
    .post('/api/auth/login')
    .send({ identificador: identifier, contrasena: password });
  if (response.status !== 200) {
    throw new Error(
      `No se pudo iniciar sesión con '${identifier}': ${response.status} ${JSON.stringify(response.body)}`,
    );
  }
  return response.body;
}

export function bearer(token) {
  return { Authorization: `Bearer ${token}` };
}
