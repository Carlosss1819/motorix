// Logica de negocio de usuarios: creacion de cuentas, cambio de rol y de estado con
// EFECTO INMEDIATO (especificación, aclaración Q2): desactivar cierra las sesiones
// abiertas y el nuevo rol rige en la siguiente operación.
import bcrypt from 'bcryptjs';
import {
  listUsers,
  listActiveMechanics,
  findById,
  findByUsername,
  findByEmail,
  createUser,
  updateUser,
} from '../models/user.js';
import { conflict, notFound } from '../utils/errors.js';
import * as sessionStore from '../utils/sessionStore.js';
import { record } from './audit.service.js';

const BCRYPT_ROUNDS = 10;

function toApi(user) {
  return {
    id: user.id,
    username: user.username,
    email: user.email,
    rol: user.role,
    estado: user.status === 'ACTIVE' ? 'ACTIVO' : 'INACTIVO',
  };
}

// Transicion de estado pura (probable unitariamente):
// devuelve el estado de base de datos, si cambió y si debe cerrar sesiones.
export function resolveStatusTransition(currentStatus, apiStatus) {
  const status = apiStatus === 'ACTIVO' ? 'ACTIVE' : 'INACTIVE';
  const changed = status !== currentStatus;
  return {
    status,
    changed,
    closesSessions: changed && status === 'INACTIVE',
  };
}

export async function list() {
  const users = await listUsers();
  return users.map(toApi);
}

// Listado ligero de mecánicos activos para asignar órdenes desde recepción
// (FR-009): el listado completo de usuarios sigue siendo solo de ADMIN.
export async function listMechanics() {
  return listActiveMechanics();
}

export async function create({ username, email, rol: role, contrasena: password }, actor = null) {
  const repeatedUsername = await findByUsername(username);
  if (repeatedUsername) {
    throw conflict('El nombre de usuario ya está en uso', 'USERNAME_EN_USO');
  }
  const repeatedEmail = await findByEmail(email);
  if (repeatedEmail) {
    throw conflict('El correo electrónico ya está en uso', 'EMAIL_EN_USO');
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const created = await createUser({ username, email, passwordHash, role });
  // Sprint 7 (FR-022): alta de usuario; nunca la contraseña ni el hash.
  await record({
    userId: actor?.id ?? null,
    action: 'USUARIO_CREADO',
    entityType: 'user',
    entityId: created.id,
    detail: `${created.username} (${created.role})`,
  });
  return toApi(created);
}

export async function update(id, { rol: role, estado: statusApi }, actor = null) {
  const user = await findById(id);
  if (!user) throw notFound('El usuario no existe', 'USUARIO_NO_ENCONTRADO');

  const fields = {};
  if (role !== undefined) fields.role = role;

  if (statusApi !== undefined) {
    const transition = resolveStatusTransition(user.status, statusApi);
    fields.status = transition.status;
    if (transition.closesSessions) {
      // Efecto inmediato: la sesión abierta del usuario desactivado se cierra.
      sessionStore.closeAllForUser(user.id);
    }
  }

  const updated = await updateUser(user.id, fields);

  // Sprint 7 (FR-022): cambio de rol y activación o desactivación.
  if (role !== undefined && role !== user.role) {
    await record({
      userId: actor?.id ?? null,
      action: 'USUARIO_ROL_CAMBIADO',
      entityType: 'user',
      entityId: user.id,
      detail: `${user.username}: ${user.role} → ${role}`,
    });
  }
  if (fields.status !== undefined && fields.status !== user.status) {
    await record({
      userId: actor?.id ?? null,
      action: fields.status === 'ACTIVE' ? 'USUARIO_ACTIVADO' : 'USUARIO_DESACTIVADO',
      entityType: 'user',
      entityId: user.id,
      detail: user.username,
    });
  }
  return toApi(updated);
}
