// Preparacion idempotente de la base de pruebas: crea motorix_v2_test si no existe y
// aplica las migraciones y seeds del repositorio. Nunca toca la base principal.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { config } from '../../config/env.js';

const repoRoot = path.resolve(import.meta.dirname, '..', '..', '..');

function sqlFilesIn(relativeDir) {
  const dir = path.join(repoRoot, relativeDir);
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((file) => file.endsWith('.sql'))
    .sort()
    .map((file) => path.join(dir, file));
}

export async function prepareTestDatabase() {
  const { host, port, user, password, database } = config.db;

  const admin = await mysql.createConnection({
    host,
    port,
    user,
    password,
    multipleStatements: true,
  });
  await admin.query(
    `CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
  );
  await admin.end();

  const db = await mysql.createConnection({
    host,
    port,
    user,
    password,
    database,
    multipleStatements: true,
  });

  // Serializa la preparación entre suites que corren en paralelo: sin este lock,
  // migraciones y seeds simultáneos provocan deadlocks en MySQL.
  const lockName = `motorix_setup_${database}`;
  const [lockRows] = await db.query('SELECT GET_LOCK(?, 60) AS taken', [lockName]);
  if (!lockRows[0]?.taken) {
    await db.end();
    throw new Error(`No se pudo obtener el lock de preparación de ${database}`);
  }

  try {
    for (const file of sqlFilesIn('database/migrations')) {
      await db.query(readFileSync(file, 'utf8'));
    }
    for (const file of sqlFilesIn('database/seeds')) {
      await db.query(readFileSync(file, 'utf8'));
    }
  } finally {
    await db.query('SELECT RELEASE_LOCK(?)', [lockName]);
    await db.end();
  }
}

// Sufijo único para datos de prueba (evita colisiones entre archivos de prueba).
export function uniqueSuffix() {
  return `${Date.now()}${Math.floor(Math.random() * 10000)}`;
}
