// Validación de los filtros de la bitácora (Sprint 7, FR-024).
import { z } from 'zod';
import { AUDIT_ACTIONS } from '../services/audit.service.js';

const fecha = z
  .string()
  .trim()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'La fecha debe tener el formato AAAA-MM-DD');

export const auditListQuerySchema = z
  .object({
    desde: fecha.optional(),
    hasta: fecha.optional(),
    usuarioId: z.coerce
      .number({ invalid_type_error: 'El usuario indicado no es válido' })
      .int('El usuario indicado no es válido')
      .positive('El usuario indicado no es válido')
      .optional(),
    accion: z
      .enum(AUDIT_ACTIONS, { errorMap: () => ({ message: 'La acción indicada no es válida' }) })
      .optional(),
    pagina: z.coerce.number().int().positive('La página no es válida').optional(),
    porPagina: z.coerce
      .number()
      .int()
      .positive()
      .max(50, 'No se muestran más de 50 registros por página')
      .optional(),
  })
  .refine((value) => !value.desde || !value.hasta || value.desde <= value.hasta, {
    message: 'La fecha inicial no puede ser posterior a la final',
  });
