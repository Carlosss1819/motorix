// Logica de negocio de autenticación: login por usuario o correo, bloqueo por intentos
// fallidos, JWT con tope de 8 horas y cambio de contraseña con política mínima.
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import {
  findByIdentifier,
  findById,
  updatePassword as updatePasswordModel,
  setLoginFailures,
  clearLoginFailures,
} from '../models/user.js';
import { unauthorized, forbidden, locked, badRequest, notFound } from '../utils/errors.js';
import * as sessionStore from '../utils/sessionStore.js';

const BCRYPT_ROUNDS = 10;
const MAX_FAILED_ATTEMPTS = 5;
const LOCK_MINUTES = 15;

function toApi(user) {
  return {
    id: user.id,
    username: user.username,
    email: user.email,
    rol: user.role,
  };
}

// Devuelve true si la cuenta está bloqueada por intentos fallidos.
export function isLocked(user) {
  return Boolean(user.lockedUntil) && new Date(user.lockedUntil).getTime() > Date.now();
}

export async function login(identifier, password) {
  const user = await findByIdentifier(identifier);

  if (!user) {
    // Mensaje genérico: no revela si faltó el usuario o la contraseña (FR-003).
    throw unauthorized('Credenciales inválidas', 'CREDENCIALES_INVALIDAS');
  }

  if (isLocked(user)) {
    throw locked(
      `Cuenta bloqueada tras ${MAX_FAILED_ATTEMPTS} intentos fallidos. Espere ${LOCK_MINUTES} minutos.`,
      'CUENTA_BLOQUEADA',
    );
  }

  if (user.status !== 'ACTIVE') {
    throw forbidden('La cuenta está desactivada', 'CUENTA_INACTIVA');
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    const attempts = (user.failedLoginAttempts ?? 0) + 1;
    if (attempts >= MAX_FAILED_ATTEMPTS) {
      const lockedUntil = new Date(Date.now() + LOCK_MINUTES * 60 * 1000);
      await setLoginFailures(user.id, 0, lockedUntil);
      // El quinto intento responde con el mismo mensaje genérico (quickstart V3).
      throw unauthorized('Credenciales inválidas', 'CREDENCIALES_INVALIDAS');
    }
    await setLoginFailures(user.id, attempts, null);
    throw unauthorized('Credenciales inválidas', 'CREDENCIALES_INVALIDAS');
  }

  await clearLoginFailures(user.id);

  const sessionId = sessionStore.createSessionTokenId();
  const token = jwt.sign(
    { sub: String(user.id), username: user.username, role: user.role, jti: sessionId },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn },
  );
  sessionStore.touch(user.id, sessionId);

  return { token, usuario: toApi(user) };
}

export async function changePassword(userId, currentPassword, newPassword) {
  const user = await findById(userId);
  if (!user) throw notFound('Usuario no encontrado', 'USUARIO_NO_ENCONTRADO');

  const valid = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!valid) {
    throw badRequest('La contraseña actual es incorrecta', 'CONTRASENA_ACTUAL_INVALIDA');
  }

  const hash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  await updatePasswordModel(user.id, hash);
  return { mensaje: 'Contraseña actualizada' };
}

// Hash para seeds y scripts (uso interno, p.ej. server/scripts/create-admin.js).
export async function hashPassword(password) {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}
