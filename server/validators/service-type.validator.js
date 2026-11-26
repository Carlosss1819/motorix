// Validación del catálogo de tipos de servicio (Sprint 7, FR-007).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/service-types.md.
// La regla «al menos un intervalo» la aplica el servicio (400 INTERVALO_REQUERIDO).
import { z } from 'zod';

const nombre = z
  .string({ required_error: 'El nombre del tipo de servicio es obligatorio', invalid_type_error: 'El nombre del tipo de servicio debe ser texto' })
  .trim()
  .min(1, 'El nombre del tipo de servicio es obligatorio')
  .max(120, 'El nombre del tipo de servicio no puede exceder 120 caracteres');

const intervalo = (campo, max) =>
  z
    .number({ invalid_type_error: `${campo} debe ser un número entero` })
    .int(`${campo} debe ser un número entero`)
    .min(1, `${campo} debe ser al menos 1`)
    .max(max, `${campo} no puede ser mayor a ${max}`)
    .nullable();

export const serviceTypeCreateSchema = z.object({
  nombre,
  intervaloDias: intervalo('El intervalo en días', 3650).optional(),
  intervaloKm: intervalo('El intervalo en kilómetros', 500000).optional(),
});

export const serviceTypeUpdateSchema = serviceTypeCreateSchema
  .partial()
  .refine((value) => Object.values(value).some((campo) => campo !== undefined), {
    message: 'Indique al menos un dato del tipo de servicio a modificar',
  });

export const serviceTypeListQuerySchema = z.object({
  incluirInactivos: z.enum(['true', 'false']).optional(),
});
