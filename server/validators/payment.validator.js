// Esquemas de validación de los pagos (Sprint 4, US1).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
// El método es obligatorio y de los cuatro valores del contrato (FR-002); la
// anulación exige un motivo de 1 a 255 caracteres (FR-016).
import { z } from 'zod';

export const paymentSchema = z.object({
  ordenId: z
    .coerce
    .number({ required_error: 'La orden es obligatoria', invalid_type_error: 'La orden debe ser un número' })
    .int('La orden debe ser un número entero')
    .positive('La orden debe ser un número entero mayor a 0'),
  monto: z
    .coerce
    .number({ required_error: 'El monto es obligatorio', invalid_type_error: 'El monto debe ser un número' })
    .positive('El monto debe ser un número mayor a 0'),
  // HU2-3: si falta el método el mensaje es «método de pago requerido»; si
  // llega un valor fuera del enum se lista lo admitido.
  metodo: z.enum(['EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'MERCADO_PAGO'], {
    errorMap: (issue) => ({
      message:
        issue.code === 'invalid_type' && issue.received === 'undefined'
          ? 'método de pago requerido'
          : 'El método de pago debe ser EFECTIVO, TARJETA, TRANSFERENCIA o MERCADO_PAGO',
    }),
  }),
  fecha: z
    .string({ invalid_type_error: 'La fecha debe ser texto' })
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'La fecha debe tener el formato AAAA-MM-DD')
    .optional(),
});

export const paymentAnnulSchema = z.object({
  motivo: z
    .string({ required_error: 'El motivo de la anulación es obligatorio', invalid_type_error: 'El motivo debe ser texto' })
    .trim()
    .min(1, 'El motivo de la anulación es obligatorio')
    .max(255, 'El motivo no puede exceder 255 caracteres'),
});

// Listado de pagos de una orden con la paginación estándar.
export const paymentListQuerySchema = z.object({
  pagina: z.coerce.number().int().positive().optional(),
  porPagina: z.coerce.number().int().positive().max(50, 'No se muestran más de 50 registros por página').optional(),
});
