// Contrato (Sprint 7, US10, FR-030): las respuestas incluyen las cabeceras de
// seguridad de helmet y no revelan la tecnología del servidor.
import { api } from '../helpers/api.js';

test('test_las_respuestas_incluyen_cabeceras_de_seguridad', async () => {
  const response = await api.get('/api/salud');
  expect(response.status).toBe(200);
  expect(response.headers['x-content-type-options']).toBe('nosniff');
  expect(response.headers['x-frame-options']).toBe('SAMEORIGIN');
  expect(response.headers['strict-transport-security']).toBeDefined();
  expect(response.headers['content-security-policy']).toBeDefined();
  expect(response.headers['referrer-policy']).toBe('no-referrer');
  expect(response.headers['x-powered-by']).toBeUndefined();
});

test('test_las_respuestas_de_error_tambien_llevan_las_cabeceras', async () => {
  const response = await api.get('/api/no-existe');
  expect(response.status).toBe(404);
  expect(response.headers['x-content-type-options']).toBe('nosniff');
});
