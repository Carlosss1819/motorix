// Esquemas de validación de los tickets de servicio (Sprint 4, US4).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/tickets.md
// El cuerpo de generación solo trae `ordenId` entero mayor a 0 (FR-009).
import { z } from 'zod';

export const ticketGenerateSchema = z.object({
  ordenId: z
    .coerce
    .number({ required_error: 'La orden es obligatoria', invalid_type_error: 'La orden debe ser un número' })
    .int('La orden debe ser un número entero')
    .positive('La orden debe ser un número entero mayor a 0'),
});
