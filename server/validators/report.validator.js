// Validación de la consulta de los reportes (Sprint 7, Entrega B).
// Aquí solo se revisa la forma; el rango (`desde`/`hasta`, máximo 366 días)
// lo valida utils/report-range.js para responder `400 RANGO_INVALIDO`.
import { z } from 'zod';

export const reportQuerySchema = z.object({
  desde: z.string().trim().optional(),
  hasta: z.string().trim().optional(),
  formato: z
    .enum(['json', 'csv'], { errorMap: () => ({ message: 'El formato debe ser json o csv' }) })
    .default('json'),
});
