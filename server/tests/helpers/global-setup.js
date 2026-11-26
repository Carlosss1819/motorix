// Preparación de la base de pruebas UNA sola vez por corrida de Jest (hallazgo H-B01).
// Antes, cada suite llamaba a prepareTestDatabase() en su beforeAll y las 49 suites
// hacían fila en el lock de MySQL, lo que provocaba timeouts de 5000 ms en los hooks.
// globalSetup corre antes de setupFiles, por eso se importa primero env.js para
// garantizar que se use motorix_v2_test y nunca la base principal.
import './env.js';
import mysql from 'mysql2/promise';
import { prepareTestDatabase, TEST_DB_READY_FLAG } from './db.js';
import { config } from '../../config/env.js';

// Sprint 7 (FR-020, aclaración de la spec 007): en motorix_v2_test todos los
// usuarios existentes quedan con la aceptación de la versión vigente de los
// términos, para que las pruebas anteriores al sprint no reciban
// 403 TERMINOS_PENDIENTES. Los usuarios que crea cada prueba aceptan al
// iniciar sesión con `loginAs` (tests/helpers/api.js).
async function acceptCurrentTermsForExistingUsers() {
  const db = await mysql.createConnection(config.db);
  try {
    await db.query(
      `INSERT IGNORE INTO terms_acceptances (user_id, terms_version_id)
       SELECT u.id, tv.id
       FROM users u
       CROSS JOIN (
         SELECT id FROM terms_versions WHERE is_current = 1
         ORDER BY published_at DESC, id DESC LIMIT 1
       ) tv`,
    );
  } finally {
    await db.end();
  }
}

export default async function globalSetup() {
  await prepareTestDatabase();
  await acceptCurrentTermsForExistingUsers();
  // Los workers heredan process.env del proceso principal: con esta marca,
  // las llamadas a prepareTestDatabase() dentro de cada suite ya no repiten
  // migraciones ni seeds.
  process.env[TEST_DB_READY_FLAG] = '1';
}
