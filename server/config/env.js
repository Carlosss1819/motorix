// Carga la configuracion del backend desde variables de entorno.
// Lee server/.env si existe (sin dependencias externas); en produccion las variables
// vienen del entorno del sistema. Los secretos NUNCA se versionan.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));

function loadEnvFile() {
  const envPath = path.join(currentDir, '..', '.env');
  try {
    const content = readFileSync(envPath, 'utf8');
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const equalIndex = trimmed.indexOf('=');
      if (equalIndex === -1) continue;
      const key = trimmed.slice(0, equalIndex).trim();
      const value = trimmed.slice(equalIndex + 1).trim();
      if (!(key in process.env)) process.env[key] = value;
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

loadEnvFile();

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

// Entero mayor que 0; cualquier otro valor usa el de defecto.
const toPositiveInt = (value, fallback) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
};

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: toNumber(process.env.PORT, 3000),
  db: {
    host: process.env.DB_HOST ?? 'localhost',
    port: toNumber(process.env.DB_PORT, 3306),
    user: process.env.DB_USER ?? 'motorix_app',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_NAME ?? 'motorix_v2',
  },
  jwt: {
    // Secreto solo de desarrollo local; en cualquier despliegue real DEBE venir del entorno.
    secret: process.env.JWT_SECRET ?? 'motorix_dev_secret_no_usar_en_produccion',
    expiresIn: process.env.JWT_EXPIRA_EN ?? '8h',
  },
  session: {
    // Cierre automatico por inactividad: 30 minutos (especificación, aclaración Q1).
    idleMs: toNumber(process.env.SESSION_IDLE_MS, 30 * 60 * 1000),
  },
  // Pasarela de cobro (Sprint 4, D1, CA-7): credenciales SOLO por variables
  // de entorno; con access token se usa Mercado Pago real en sandbox, sin él
  // la simulada. El token nunca se registra ni se devuelve en respuestas
  // (RN-14, FR-006).
  payments: {
    mpAccessToken: process.env.MP_ACCESS_TOKEN ?? '',
    mpPublicUrl: process.env.MP_PUBLIC_URL ?? 'http://localhost:3000',
    // Sprint 5 (FR-037, R-09): horas de vigencia de las preferencias nuevas
    // de Mercado Pago. Entero > 0; 24 por defecto.
    mpPreferenciaVigenciaHoras: toPositiveInt(process.env.MP_PREFERENCIA_VIGENCIA_HORAS, 24),
  },
  // Sprint 6 (FR-006, R-04): días sin cambio de estado para considerar una
  // orden «detenida». Entero > 0; 3 por defecto.
  notifications: {
    stalledOrderDays: toPositiveInt(process.env.NOTIF_ORDEN_DETENIDA_DIAS, 3),
  },
};
