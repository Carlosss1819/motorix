// Validación de términos y aviso de privacidad (Sprint 7, US9).
import { z } from 'zod';

export const termsAcceptSchema = z.object({
  version: z
    .string({ required_error: 'Indique la versión de los términos que acepta', invalid_type_error: 'La versión debe ser texto' })
    .trim()
    .min(1, 'Indique la versión de los términos que acepta')
    .max(20, 'La versión no es válida'),
});

export const termsAcceptancesQuerySchema = z.object({
  version: z.string().trim().max(20, 'La versión no es válida').optional(),
  pagina: z.coerce.number().int().positive('La página no es válida').optional(),
  porPagina: z.coerce.number().int().positive().max(50, 'No se muestran más de 50 registros por página').optional(),
});
