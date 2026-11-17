// Esquemas de validación de los avisos internos y de «Clientes por avisar»
// (Sprint 6, contracts/notifications.md y contracts/client-notices.md).
import { z } from 'zod';
import { NOTICE_KEY_MAX_LENGTH, parseFactKey } from '../utils/notice-keys.js';

const clave = z
  .string({ required_error: 'La clave del aviso es obligatoria', invalid_type_error: 'La clave del aviso debe ser texto' })
  .min(1, 'La clave del aviso es obligatoria')
  .max(NOTICE_KEY_MAX_LENGTH, `La clave del aviso no puede exceder ${NOTICE_KEY_MAX_LENGTH} caracteres`);

// Lectura: cualquier clave de 1 a 120 caracteres; si no es un aviso actual del
// usuario, el servicio responde 204 sin guardar (FR-030).
export const readNoticeSchema = z.object({ clave });

// Cliente avisado: la clave debe tener el formato de un hecho.
export const clientNoticeSchema = z.object({
  clave: clave.refine((value) => parseFactKey(value) !== null, 'La clave del aviso no es válida'),
});
