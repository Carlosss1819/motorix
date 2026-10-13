// Esquemas de validación de los mantenimientos preventivos (US3/US4, Sprint 3).
// Fuente de verdad: specs/003-historial-inventario/contracts/maintenance.md.
// La regla «al menos un objetivo» no vive aquí: el servicio responde
// 400 OBJETIVO_REQUERIDO con su mensaje propio (contrato, sección POST).
import { z } from 'zod';

const REGEX_FECHA = /^\d{4}-\d{2}-\d{2}$/;

const fechaSchema = z
  .string({ invalid_type_error: 'La fecha debe tener el formato AAAA-MM-DD' })
  .trim()
  .regex(REGEX_FECHA, 'La fecha debe tener el formato AAAA-MM-DD');

const enteroPositivo = (mensaje) =>
  z
    .coerce.number({ invalid_type_error: mensaje })
    .int(mensaje)
    .positive(mensaje);

export const maintenanceSchema = z.object({
  vehiculoId: z
    .coerce.number({ required_error: 'Seleccione el vehículo', invalid_type_error: 'Seleccione el vehículo' })
    .int('Seleccione el vehículo')
    .positive('Seleccione el vehículo'),
  tipoServicio: z
    .string({ required_error: 'El tipo de servicio es obligatorio', invalid_type_error: 'El tipo de servicio es obligatorio' })
    .trim()
    .min(1, 'El tipo de servicio es obligatorio')
    .max(120, 'El tipo de servicio no puede exceder 120 caracteres'),
  fechaObjetivo: fechaSchema.optional(),
  kilometrajeObjetivo: z
    .coerce.number({ invalid_type_error: 'El kilometraje objetivo debe ser un número' })
    .int('El kilometraje objetivo debe ser un número entero')
    .min(0, 'El kilometraje objetivo no puede ser negativo')
    .optional(),
  intervaloDias: enteroPositivo('El intervalo en días debe ser un entero positivo').optional(),
  intervaloKm: enteroPositivo('El intervalo en kilómetros debe ser un entero positivo').optional(),
  antelacionDias: enteroPositivo('La antelación en días debe ser un entero positivo').optional(),
  antelacionKm: enteroPositivo('La antelación en kilómetros debe ser un entero positivo').optional(),
  notas: z
    .string({ invalid_type_error: 'Las notas deben ser texto' })
    .trim()
    .max(255, 'Las notas no pueden exceder 255 caracteres')
    .optional(),
});

// Edición parcial (PUT): todo opcional, menos el vehículo, que no cambia.
export const maintenanceUpdateSchema = maintenanceSchema
  .omit({ vehiculoId: true })
  .partial();

// Renovación «servicio realizado» (FR-015): todo opcional; los objetivos del
// body solo se usan cuando el registro no tiene intervalos configurados.
export const realizarSchema = z.object({
  fechaServicio: fechaSchema.optional(),
  kilometrajeServicio: z
    .coerce.number({ invalid_type_error: 'El kilometraje debe ser un número' })
    .int('El kilometraje debe ser un número entero')
    .min(0, 'El kilometraje no puede ser negativo')
    .optional(),
  fechaObjetivo: fechaSchema.optional(),
  kilometrajeObjetivo: z
    .coerce.number({ invalid_type_error: 'El kilometraje objetivo debe ser un número' })
    .int('El kilometraje objetivo debe ser un número entero')
    .min(0, 'El kilometraje objetivo no puede ser negativo')
    .optional(),
  correccionKilometraje: z
    .string({ invalid_type_error: 'La corrección debe ser texto' })
    .trim()
    .max(255, 'La corrección no puede exceder 255 caracteres')
    .optional(),
});

export const maintenanceListQuerySchema = z.object({
  vehiculoId: z.coerce
    .number({ invalid_type_error: 'El vehículo indicado no es válido' })
    .int('El vehículo indicado no es válido')
    .positive('El vehículo indicado no es válido')
    .optional(),
  // El filtro se aplica sobre el ESTADO CALCULADO (R-04): el backend lo
  // normaliza a mayúsculas antes de comparar.
  estado: z.enum(['normal', 'proximo', 'vencido', 'NORMAL', 'PROXIMO', 'VENCIDO']).optional(),
  buscar: z
    .string({ invalid_type_error: 'El texto de búsqueda no es válido' })
    .trim()
    .max(120, 'El texto de búsqueda no puede exceder 120 caracteres')
    .optional(),
  pagina: z.coerce.number().int().positive().optional(),
  porPagina: z.coerce.number().int().positive().max(50, 'No se muestran más de 50 registros por página').optional(),
});
