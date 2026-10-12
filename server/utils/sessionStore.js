// Control de sesiones en memoria: inactividad (30 min), cierre por logout y cierre
// masivo por desactivación de cuenta. Cada token tiene su propio identificador (jti),
// de modo que cerrar una sesión no afecta a las demás sesiones del mismo usuario.
import { randomUUID } from 'node:crypto';
import { config } from '../config/env.js';

const activity = new Map(); // jti -> { userId, last }
const byUser = new Map(); // userId -> Set<jti>

export function createSessionTokenId() {
  return randomUUID();
}

// Registra la última actividad de una sesión.
export function touch(userId, sessionId) {
  const key = String(sessionId);
  activity.set(key, { userId: String(userId), last: Date.now() });
  if (!byUser.has(String(userId))) byUser.set(String(userId), new Set());
  byUser.get(String(userId)).add(key);
}

// true si la sesión superó el tiempo máximo de inactividad (o no existe).
export function isIdle(sessionId) {
  const entry = activity.get(String(sessionId));
  if (!entry) return true;
  return Date.now() - entry.last > config.session.idleMs;
}

// Cierra una sesión concreta (logout).
export function close(sessionId) {
  const key = String(sessionId);
  const entry = activity.get(key);
  activity.delete(key);
  if (entry) byUser.get(entry.userId)?.delete(key);
}

// Cierra TODAS las sesiones de un usuario (desactivación de cuenta, aclaración Q2).
export function closeAllForUser(userId) {
  const sessions = byUser.get(String(userId));
  if (!sessions) return;
  for (const sessionId of sessions) activity.delete(sessionId);
  byUser.delete(String(userId));
}

// Solo para pruebas: envejece una sesión para simular inactividad.
export function setLastActivity(sessionId, timestamp) {
  const entry = activity.get(String(sessionId));
  if (entry) entry.last = timestamp;
}

// Solo para pruebas: limpia el registro de sesiones.
export function reset() {
  activity.clear();
  byUser.clear();
}
