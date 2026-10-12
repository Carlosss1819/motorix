// Conexion a MySQL local mediante pool de conexiones (driver mysql2, sin ORM).
// Solo el backend accede a la base de datos; el frontend nunca se conecta directo.
import mysql from 'mysql2/promise';
import { config } from './env.js';

export const pool = mysql.createPool({
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4',
  timezone: 'local',
});

// Ejecuta una consulta con parametros preparados y devuelve las filas.
export async function query(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

// Devuelve una conexión del pool (para transacciones).
export async function getConnection() {
  return pool.getConnection();
}
