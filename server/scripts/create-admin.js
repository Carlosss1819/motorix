// Crea la cuenta inicial administrador si no existe (ejecucion manual/one-shot):
//   node scripts/create-admin.js
// La contraseña se toma de la variable de entorno ADMIN_PASSWORD (nunca se versiona).
import { findByUsername, createUser } from '../models/user.js';
import { hashPassword } from '../services/auth.service.js';

const username = process.env.ADMIN_USERNAME ?? 'admin';
const email = process.env.ADMIN_EMAIL ?? 'admin@motorix.local';
const password = process.env.ADMIN_PASSWORD;

if (!password) {
  console.error(
    'Falta la variable de entorno ADMIN_PASSWORD. Define una contraseña segura antes de ejecutar.',
  );
  process.exit(1);
}

const existing = await findByUsername(username);
if (existing) {
  console.log(`El usuario '${username}' ya existe; no se realiza ninguna acción.`);
  process.exit(0);
}

const passwordHash = await hashPassword(password);
const user = await createUser({ username, email, passwordHash, role: 'ADMIN' });
console.log(`Usuario administrador '${user.username}' creado con éxito (id ${user.id}).`);
process.exit(0);
