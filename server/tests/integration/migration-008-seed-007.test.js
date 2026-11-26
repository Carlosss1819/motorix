// Prueba de integración de la migración 008 y el seed 007 (Sprint 7, T005):
// el esquema nuevo existe en motorix_v2_test, el seed es idempotente y deja
// exactamente una versión vigente de los términos.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { prepareTestDatabase } from '../helpers/db.js';
import { sql } from '../helpers/fixtures.js';
import { config } from '../../config/env.js';

const SEED_007 = path.resolve(
  import.meta.dirname, '..', '..', '..', 'database', 'seeds', '007_ejemplos_configuracion_terminos.sql',
);

async function correrSeed() {
  const db = await mysql.createConnection({ ...config.db, multipleStatements: true });
  try {
    await db.query(readFileSync(SEED_007, 'utf8'));
  } finally {
    await db.end();
  }
}

async function contar() {
  const [settings] = await sql(
    "SELECT COUNT(*) AS n FROM settings WHERE setting_key IN ('shop.name','shop.address','shop.phone','maintenance.advance_days','maintenance.advance_km')",
  );
  const [tipos] = await sql('SELECT COUNT(*) AS n FROM service_types WHERE id BETWEEN 70001 AND 70005');
  const [terminos] = await sql("SELECT COUNT(*) AS n FROM terms_versions WHERE version = '1.0'");
  return { settings: settings.n, tipos: tipos.n, terminos: terminos.n };
}

beforeAll(async () => {
  await prepareTestDatabase();
});

describe('migración 008 y seed 007', () => {
  test('test_existen_las_tablas_nuevas_y_la_columna_del_tipo_de_servicio', async () => {
    const tablas = await sql(
      `SELECT table_name AS t FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name IN ('settings','service_types','terms_versions','terms_acceptances','audit_log')`,
    );
    expect(tablas).toHaveLength(5);
    const columnas = await sql(
      `SELECT is_nullable AS n FROM information_schema.columns
       WHERE table_schema = DATABASE() AND table_name = 'order_services' AND column_name = 'service_type_id'`,
    );
    expect(columnas).toEqual([{ n: 'YES' }]);
  });

  test('test_el_seed_007_es_idempotente', async () => {
    const antes = await contar();
    await correrSeed();
    await correrSeed();
    expect(await contar()).toEqual(antes);
    expect(antes).toEqual({ settings: 5, tipos: 5, terminos: 1 });
  });

  test('test_el_seed_007_deja_datos_de_reportes_en_el_mes_y_es_idempotente', async () => {
    // Se cuentan los ids exactos del seed: después de insertar el 70001, el
    // AUTO_INCREMENT continúa en 70002 y las demás suites crean filas propias
    // dentro del rango (no son del seed).
    const idsDelSeed = {
      clients: 1, vehicles: 1, parts: 2, service_orders: 3, order_status_history: 12,
      order_services: 4, order_labor: 4, order_parts: 3, payments: 4, inventory_movements: 5,
    };
    const contarReportes = async () => {
      const conteo = {};
      for (const [tabla, n] of Object.entries(idsDelSeed)) {
        const [fila] = await sql(`SELECT COUNT(*) AS n FROM ${tabla} WHERE id BETWEEN 70001 AND ?`, [70000 + n]);
        conteo[tabla] = Number(fila.n);
      }
      return conteo;
    };
    const antes = await contarReportes();
    await correrSeed();
    expect(await contarReportes()).toEqual(antes);
    expect(antes).toEqual({
      clients: 1, vehicles: 1, parts: 2, service_orders: 3, order_status_history: 12,
      order_services: 4, order_labor: 4, order_parts: 3, payments: 4, inventory_movements: 5,
    });
    // Los pagos aprobados del seed suman 3630.00 y caen en un mismo mes (el
    // mes en que se aplicó el seed; la base de pruebas lo conserva después).
    const [pagos] = await sql(
      `SELECT SUM(amount) AS total, COUNT(*) AS n,
              COUNT(DISTINCT DATE_FORMAT(created_at, '%Y-%m')) AS meses
       FROM payments WHERE id BETWEEN 70001 AND 70099 AND status = 'PAGADO'`,
    );
    expect(pagos).toEqual({ total: '3630.00', n: 3, meses: 1 });
  });

  test('test_el_aviso_de_privacidad_incluye_los_elementos_minimos_y_la_nota_academica', async () => {
    const [version] = await sql("SELECT terms_text, privacy_text FROM terms_versions WHERE version = '1.0'");
    for (const texto of ['Responsable', 'Datos que recabamos', 'Finalidades', 'ARCO', 'revocar', 'Transferencias', 'Cambios al aviso']) {
      expect(version.privacy_text).toContain(texto);
    }
    expect(version.privacy_text).toContain('Plantilla académica');
    expect(version.terms_text).toContain('Plantilla académica');
  });

  test('test_un_tipo_de_servicio_sin_intervalos_lo_rechaza_la_base', async () => {
    await expect(
      sql("INSERT INTO service_types (name) VALUES ('Sin intervalo prueba 008')"),
    ).rejects.toThrow();
  });
});
