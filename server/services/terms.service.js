// Lógica de negocio de los términos y el aviso de privacidad (Sprint 7, US9).
// - Una aceptación por usuario y versión (FR-018); repetir es idempotente.
// - Sin versión vigente publicada no hay nada pendiente.
// - La aceptación se valida en backend en cada petición (middleware auth,
//   FR-020); aquí está la regla para no duplicarla.
// Fuente de verdad: specs/007-reportes-configuracion/contracts/terms.md.
import {
  findPendingStatus,
  findCurrentVersion,
  insertAcceptance,
  listAcceptances,
} from '../models/terms.js';
import { conflict, notFound } from '../utils/errors.js';
import { record } from './audit.service.js';

export async function hasPendingTerms(userId) {
  const status = await findPendingStatus(userId);
  return Boolean(status && !status.accepted);
}

export async function getCurrent(userId) {
  const current = await findCurrentVersion(userId);
  if (!current) {
    throw notFound('No hay términos y condiciones publicados', 'TERMINOS_NO_PUBLICADOS');
  }
  return current;
}

export async function accept(version, user) {
  const current = await findCurrentVersion(user.id);
  if (!current) {
    throw notFound('No hay términos y condiciones publicados', 'TERMINOS_NO_PUBLICADOS');
  }
  if (current.version !== version) {
    throw conflict(
      'La versión que intenta aceptar ya no es la vigente: vuelva a cargar los términos',
      'VERSION_NO_VIGENTE',
    );
  }
  const nueva = await insertAcceptance(user.id, current.id);
  if (nueva) {
    await record({
      userId: user.id,
      action: 'TERMINOS_ACEPTADOS',
      entityType: 'terms',
      entityId: current.id,
      detail: `Versión ${current.version}`,
    });
  }
  const releido = await findCurrentVersion(user.id);
  return { version: releido.version, aceptadoEn: releido.aceptadoEn };
}

export async function acceptances(filters) {
  const page = filters.pagina ?? 1;
  const perPage = filters.porPagina ?? 20;
  const { total, rows } = await listAcceptances({ version: filters.version, page, perPage });
  return {
    elementos: rows,
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}
