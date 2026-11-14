// Cierre del pool de MySQL al terminar cada archivo de prueba (hallazgo H-B01).
// Se registra en setupFilesAfterEnv: corre dentro del mismo registro de módulos
// que el archivo de prueba, así que cierra el mismo pool que usó la app.
// Sin este cierre, las conexiones abiertas a MySQL impiden que el worker de
// Jest termine solo ("A worker process has failed to exit gracefully").
import { pool } from '../../config/db.js';

afterAll(async () => {
  await pool.end();
});
