// Esquemas de validación del panel de control (Sprint 4, US5).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md
import { z } from 'zod';

// `?fecha=AAAA-MM-DD`: día de referencia para los indicadores; sin el
// parámetro se usa la fecha actual (el contrato lo fija como opcional).
export const dashboardQuerySchema = z.object({
  fecha: z
    .string({ invalid_type_error: 'La fecha debe ser texto' })
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'La fecha debe tener el formato AAAA-MM-DD')
    .optional(),
});
