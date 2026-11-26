// Integración (Sprint 7, US10, FR-029, CA-25): intentos de inyección en los
// buscadores no rompen la API ni devuelven filas ajenas. Las consultas usan
// parámetros y los comodines de LIKE se escapan.
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';

const ATAQUES = [
  "' OR 1=1 --",
  "' OR '1'='1",
  '%',
  '_',
  '\\',
  '"; DROP TABLE clients; --',
  "') UNION SELECT password_hash FROM users --",
];

const BUSCADORES = [
  '/api/clients',
  '/api/vehicles',
  '/api/appointments',
  '/api/service-orders',
  '/api/maintenance',
  '/api/parts',
];

let adminToken;

beforeAll(async () => {
  await prepareTestDatabase();
  adminToken = await loginAs('admin', 'Admin2026!');
});

describe.each(BUSCADORES)('buscador %s', (ruta) => {
  test.each(ATAQUES)('test_la_cadena_%s_no_provoca_error_ni_fuga', async (ataque) => {
    const response = await api.get(ruta).query({ buscar: ataque }).set(bearer(adminToken));
    expect([200, 400]).toContain(response.status);
    const texto = JSON.stringify(response.body);
    expect(texto).not.toMatch(/\$2[aby]\$/);
    expect(texto).not.toMatch(/password_hash|ER_|SQL syntax/i);
    if (response.status === 200) {
      const filas = response.body.elementos ?? response.body.datos ?? response.body;
      if (Array.isArray(filas)) {
        // Los comodines de LIKE se escapan: si hay filas, cada una contiene el
        // carácter literal buscado (por ejemplo, el «_» de un correo). Las
        // demás cadenas de ataque no coinciden con datos reales.
        for (const fila of filas) expect(JSON.stringify(fila)).toContain(JSON.stringify(ataque).slice(1, -1));
      }
    }
  });
});

test('test_las_tablas_siguen_intactas_despues_de_los_intentos', async () => {
  const [clientes] = await sql('SELECT COUNT(*) AS n FROM clients');
  expect(clientes.n).toBeGreaterThan(0);
});
