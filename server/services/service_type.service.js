// Lógica de negocio del catálogo de tipos de servicio (Sprint 7, US3).
// - Nombre único sin distinguir mayúsculas (409 TIPO_SERVICIO_DUPLICADO).
// - Al menos un intervalo (400 INTERVALO_REQUERIDO, RN-12).
// - Sin borrado: desactivar lo oculta de las listas (FR-008).
// - Cada cambio queda en la bitácora (TIPO_SERVICIO_*, FR-022).
import {
  listServiceTypes,
  findServiceTypeById,
  findServiceTypeByName,
  insertServiceType,
  updateServiceType,
  setServiceTypeActive,
} from '../models/service_type.js';
import { badRequest, conflict, notFound } from '../utils/errors.js';
import { record } from './audit.service.js';

function assertSomeInterval(intervaloDias, intervaloKm) {
  if (!intervaloDias && !intervaloKm) {
    throw badRequest(
      'Indique al menos un intervalo: en días, en kilómetros o ambos',
      'INTERVALO_REQUERIDO',
    );
  }
}

async function assertUniqueName(nombre, exceptId = null) {
  const repetido = await findServiceTypeByName(nombre);
  if (repetido && repetido.id !== exceptId) {
    throw conflict('Ya existe un tipo de servicio con ese nombre', 'TIPO_SERVICIO_DUPLICADO');
  }
}

async function findOrFail(id) {
  const tipo = await findServiceTypeById(id);
  if (!tipo) throw notFound('El tipo de servicio no existe', 'TIPO_SERVICIO_NO_ENCONTRADO');
  return tipo;
}

function describir(tipo) {
  return `${tipo.nombre} (días: ${tipo.intervaloDias ?? '-'}, km: ${tipo.intervaloKm ?? '-'})`;
}

// Solo ADMIN puede ver los inactivos; para otro rol se ignora (contrato).
export async function list({ incluirInactivos }, role) {
  const includeInactive = incluirInactivos === 'true' && role === 'ADMIN';
  return { elementos: await listServiceTypes({ includeInactive }) };
}

export async function create(data, user) {
  assertSomeInterval(data.intervaloDias, data.intervaloKm);
  await assertUniqueName(data.nombre);
  const creado = await insertServiceType(data);
  await record({
    userId: user.id,
    action: 'TIPO_SERVICIO_CREADO',
    entityType: 'service_type',
    entityId: creado.id,
    detail: describir(creado),
  });
  return creado;
}

export async function update(id, data, user) {
  const actual = await findOrFail(id);
  const final = {
    nombre: data.nombre ?? actual.nombre,
    intervaloDias: data.intervaloDias !== undefined ? data.intervaloDias : actual.intervaloDias,
    intervaloKm: data.intervaloKm !== undefined ? data.intervaloKm : actual.intervaloKm,
  };
  assertSomeInterval(final.intervaloDias, final.intervaloKm);
  if (final.nombre !== actual.nombre) await assertUniqueName(final.nombre, actual.id);
  const editado = await updateServiceType(actual.id, final);
  await record({
    userId: user.id,
    action: 'TIPO_SERVICIO_EDITADO',
    entityType: 'service_type',
    entityId: editado.id,
    detail: `${describir(actual)} → ${describir(editado)}`,
  });
  return editado;
}

export async function setActive(id, active, user) {
  const actual = await findOrFail(id);
  if (actual.activo === active) return actual;
  const cambiado = await setServiceTypeActive(actual.id, active);
  await record({
    userId: user.id,
    action: active ? 'TIPO_SERVICIO_ACTIVADO' : 'TIPO_SERVICIO_DESACTIVADO',
    entityType: 'service_type',
    entityId: cambiado.id,
    detail: cambiado.nombre,
  });
  return cambiado;
}

// Para el alta de servicios en la orden (FR-010): solo tipos activos.
export async function findActiveOrFail(id) {
  const tipo = await findServiceTypeById(id);
  if (!tipo || !tipo.activo) {
    throw badRequest(
      'El tipo de servicio no existe o está desactivado',
      'TIPO_SERVICIO_INVALIDO',
    );
  }
  return tipo;
}
