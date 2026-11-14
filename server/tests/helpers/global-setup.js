// Preparación de la base de pruebas UNA sola vez por corrida de Jest (hallazgo H-B01).
// Antes, cada suite llamaba a prepareTestDatabase() en su beforeAll y las 49 suites
// hacían fila en el lock de MySQL, lo que provocaba timeouts de 5000 ms en los hooks.
// globalSetup corre antes de setupFiles, por eso se importa primero env.js para
// garantizar que se use motorix_v2_test y nunca la base principal.
import './env.js';
import { prepareTestDatabase, TEST_DB_READY_FLAG } from './db.js';

export default async function globalSetup() {
  await prepareTestDatabase();
  // Los workers heredan process.env del proceso principal: con esta marca,
  // las llamadas a prepareTestDatabase() dentro de cada suite ya no repiten
  // migraciones ni seeds.
  process.env[TEST_DB_READY_FLAG] = '1';
}
